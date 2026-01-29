/*
 * wiifit_reader.c
 * Wii Fit save file parser implementation
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <ogc/isfs.h>
#include <ogc/es.h>
#include "wiifit_reader.h"

// Save file paths to try
// Wii Fit Plus uses FitPlus0.dat, original Wii Fit uses RPHealth.dat
// Title IDs: RFPE (USA), RFPP (PAL), RFPJ (JPN) for Plus
//            RFNE (USA), RFNP (PAL), RFNJ (JPN) for original
static const char* SAVE_PATHS[] = {
    // Wii Fit Plus - FitPlus0.dat (primary save) - lowercase hex
    "/title/00010000/5246504a/data/FitPlus0.dat",  // RFPJ - JPN (try first)
    "/title/00010000/52465045/data/FitPlus0.dat",  // RFPE - USA
    "/title/00010000/52465050/data/FitPlus0.dat",  // RFPP - PAL
    // Wii Fit Plus - uppercase hex variant (just in case)
    "/title/00010000/5246504A/data/FitPlus0.dat",  // RFPJ - JPN uppercase
    // Wii Fit Plus - RPHealth.dat (alternate name used by some versions)
    "/title/00010000/5246504a/data/RPHealth.dat",  // RFPJ - JPN
    "/title/00010000/52465045/data/RPHealth.dat",  // RFPE - USA
    "/title/00010000/52465050/data/RPHealth.dat",  // RFPP - PAL
    // Wii Fit Plus Channel (might be separate from disc)
    "/title/00010004/5246504a/data/FitPlus0.dat",  // Channel JPN
    "/title/00010004/52465045/data/FitPlus0.dat",  // Channel USA
    // Original Wii Fit - RPHealth.dat
    "/title/00010000/52464e4a/data/RPHealth.dat",  // RFNJ - JPN
    "/title/00010000/52464e45/data/RPHealth.dat",  // RFNE - USA
    "/title/00010000/52464e50/data/RPHealth.dat",  // RFNP - PAL
};
#define NUM_SAVE_PATHS (sizeof(SAVE_PATHS) / sizeof(SAVE_PATHS[0]))

// Last attempted path (for error reporting)
static const char* last_tried_path = NULL;

static u8* save_buffer = NULL;
static u32 save_size = 0;
static int initialized = 0;

// Wii Fit date format - standard bitfield encoding
// Source: https://jansenprice.com/blog?id=9-Extracting-Data-from-Wii-Fit-Plus-Savegame-Files
//         https://gist.github.com/yoshi314/c63664debc140593c7fccdadc5cea632
//
// 32-bit packed date/time:
//   bits 30-20 (11 bits): year
//   bits 19-16 (4 bits):  month (0-indexed, add 1)
//   bits 15-11 (5 bits):  day
//   bits 10-6  (5 bits):  hour
//   bits 5-0   (6 bits):  minute
//
// Verified: 0x7E7455CF = May 10, 2023 23:15

// Helper: Parse Wii Fit date to time_t
static time_t parse_wiifit_date(u32 packed_date, int debug) {
    struct tm tm_info;
    memset(&tm_info, 0, sizeof(tm_info));

    // Extract using standard bitfield format
    int year   = (packed_date >> 20) & 0x7FF;   // bits 30-20 (11 bits)
    int month  = ((packed_date >> 16) & 0xF) + 1; // bits 19-16 (4 bits, 0-indexed)
    int day    = (packed_date >> 11) & 0x1F;    // bits 15-11 (5 bits)
    int hour   = (packed_date >> 6) & 0x1F;     // bits 10-6 (5 bits)
    int min    = packed_date & 0x3F;            // bits 5-0 (6 bits)

    // Sanity checks
    if (year < 2006 || year > 2030) year = 2020;
    if (month < 1 || month > 12) month = 1;
    if (day < 1 || day > 31) day = 1;
    if (hour < 0 || hour > 23) hour = 0;
    if (min < 0 || min > 59) min = 0;

    if (debug) {
        printf("Date 0x%08X -> %04d-%02d-%02d %02d:%02d\n",
               packed_date, year, month, day, hour, min);
    }

    tm_info.tm_year = year - 1900;
    tm_info.tm_mon  = month - 1;
    tm_info.tm_mday = day;
    tm_info.tm_hour = hour;
    tm_info.tm_min  = min;
    tm_info.tm_sec  = 0;

    return mktime(&tm_info);
}

// Record structure from actual hex dump analysis:
// Offset 0x38AD (0x38A1 + 12-byte header)
// Each record is 16 bytes:
// +0-3:   timestamp (packed bitfield)
// +4-5:   weight * 10 (big-endian)
// +6-7:   BMI * 100 (big-endian)
// +8-9:   balance * 10 (big-endian)
// +10-11: unknown field
// +12-15: padding/reserved
//
// Note: Online docs say 21 bytes but actual Japanese Wii Fit Plus data shows 16 bytes

#define MEASUREMENT_RECORD_SIZE 21  // Each body test record is 21 bytes
// Measurements start 576 bytes BEFORE 0x38A1 (28 records × 21 bytes - 12 byte header)
#define ACTUAL_MEASUREMENT_OFFSET 0x3661

// Helper: Convert UTF-16BE to UTF-8
static void utf16be_to_utf8(const u8* src, char* dst, int max_chars) {
    int i, j = 0;
    for (i = 0; i < max_chars && j < 23; i++) {
        u16 ch = (src[i*2] << 8) | src[i*2 + 1];
        if (ch == 0) break;

        if (ch < 0x80) {
            dst[j++] = (char)ch;
        } else if (ch < 0x800) {
            dst[j++] = 0xC0 | (ch >> 6);
            dst[j++] = 0x80 | (ch & 0x3F);
        } else {
            dst[j++] = 0xE0 | (ch >> 12);
            dst[j++] = 0x80 | ((ch >> 6) & 0x3F);
            dst[j++] = 0x80 | (ch & 0x3F);
        }
    }
    dst[j] = '\0';
}

// Helper: Read big-endian u16
static inline u16 read_be16(const u8* ptr) {
    return (ptr[0] << 8) | ptr[1];
}

// Helper: Read big-endian u32
static inline u32 read_be32(const u8* ptr) {
    return (ptr[0] << 24) | (ptr[1] << 16) | (ptr[2] << 8) | ptr[3];
}

// Parse a single profile
static int parse_profile(const u8* profile_data, WiiFitProfile* profile) {
    // Read Mii name (UTF-16BE, 10 characters at offset 0x08)
    utf16be_to_utf8(profile_data + PROFILE_NAME_OFFSET, profile->name, 10);

    // Skip empty profiles
    if (profile->name[0] == '\0') {
        return 0;
    }

    // Read height (1 byte at offset 0x1F)
    profile->height_cm = profile_data[PROFILE_HEIGHT_OFFSET];

    // Read DOB (BCD format at offset 0x20)
    // Format: YY YY MM DD (BCD)
    u16 year_bcd = read_be16(profile_data + PROFILE_DOB_OFFSET);
    profile->birth_year = ((year_bcd >> 12) & 0xF) * 1000 +
                          ((year_bcd >> 8) & 0xF) * 100 +
                          ((year_bcd >> 4) & 0xF) * 10 +
                          (year_bcd & 0xF);
    profile->birth_month = ((profile_data[PROFILE_DOB_OFFSET + 2] >> 4) & 0xF) * 10 +
                           (profile_data[PROFILE_DOB_OFFSET + 2] & 0xF);
    profile->birth_day = ((profile_data[PROFILE_DOB_OFFSET + 3] >> 4) & 0xF) * 10 +
                         (profile_data[PROFILE_DOB_OFFSET + 3] & 0xF);

    // Parse body measurements
    const u8* meas_ptr = profile_data + ACTUAL_MEASUREMENT_OFFSET;
    profile->measurement_count = 0;

    printf("Meas @ 0x%X, rec=%d\n", ACTUAL_MEASUREMENT_OFFSET, MEASUREMENT_RECORD_SIZE);

    // Scan backwards from our offset to find if there's earlier data
    printf("Scan before offset:\n");
    for (int i = -3; i < 0; i++) {
        const u8* r = meas_ptr + (i * MEASUREMENT_RECORD_SIZE);
        if (r >= profile_data) {
            u16 w = read_be16(r + 4);
            u32 ts = read_be32(r);
            printf(" [%d] @0x%04lX ts=%08X w=%u\n", i, (unsigned long)(r - profile_data), ts, w);
        }
    }

    // Show first 5 records
    printf("First records:\n");
    for (int i = 0; i < 5; i++) {
        const u8* r = meas_ptr + (i * MEASUREMENT_RECORD_SIZE);
        u16 w = read_be16(r + 4);
        u32 ts = read_be32(r);
        // Parse date inline for quick view
        int yr = (ts >> 20) & 0x7FF;
        int mo = ((ts >> 16) & 0xF) + 1;
        int dy = (ts >> 11) & 0x1F;
        printf(" [%d] %04d-%02d-%02d w=%.1f\n", i, yr, mo, dy, w/10.0f);
    }

    // Read all valid measurements
    for (int i = 0; i < MAX_MEASUREMENTS; i++) {
        const u8* record = meas_ptr + (i * MEASUREMENT_RECORD_SIZE);

        if ((u32)((record - profile_data) + MEASUREMENT_RECORD_SIZE) > PROFILE_SIZE) break;

        u16 weight_raw = read_be16(record + 4);
        if (weight_raw < 300 || weight_raw > 1500) {
            printf("Stop@%d w=%u\n", i, weight_raw);
            break;
        }

        WiiFitMeasurement* m = &profile->measurements[profile->measurement_count];
        m->timestamp = parse_wiifit_date(read_be32(record), 0);
        m->weight_kg = weight_raw / 10.0f;
        m->bmi = read_be16(record + 6) / 100.0f;
        m->balance_pct = read_be16(record + 8) / 10.0f;
        m->has_extended_data = 0;
        profile->measurement_count++;
    }

    // Show first and last parsed
    printf("Found %d measurements\n", profile->measurement_count);
    if (profile->measurement_count > 0) {
        WiiFitMeasurement* first = &profile->measurements[0];
        WiiFitMeasurement* last = &profile->measurements[profile->measurement_count - 1];
        struct tm* t1 = localtime(&first->timestamp);
        printf("First: %04d-%02d-%02d %.1fkg\n", t1->tm_year+1900, t1->tm_mon+1, t1->tm_mday, first->weight_kg);
        struct tm* t2 = localtime(&last->timestamp);
        printf("Last:  %04d-%02d-%02d %.1fkg\n", t2->tm_year+1900, t2->tm_mon+1, t2->tm_mday, last->weight_kg);
    }

    // Activity data parsing (offset ~0x95, 10-byte records)
    // TODO: Reverse engineer activity format by comparing save files
    profile->activity_count = 0;

    return 1;
}

int wiifit_init(void) {
    if (initialized) return WIIFIT_SUCCESS;

    // Initialize ISFS (NAND filesystem)
    s32 ret = ISFS_Initialize();
    if (ret < 0) {
        return WIIFIT_ERR_INIT;
    }

    initialized = 1;
    return WIIFIT_SUCCESS;
}

int wiifit_read_save(WiiFitSaveData* save_data) {
    if (!initialized) {
        snprintf(save_data->error_msg, sizeof(save_data->error_msg),
                 "Reader not initialized");
        save_data->error_code = WIIFIT_ERR_INIT;
        return WIIFIT_ERR_INIT;
    }

    memset(save_data, 0, sizeof(WiiFitSaveData));

    // Try to find and open save file
    s32 fd = -1;
    s32 last_error = 0;
    int paths_tried = 0;

    for (int i = 0; i < NUM_SAVE_PATHS && fd < 0; i++) {
        last_tried_path = SAVE_PATHS[i];
        paths_tried++;
        fd = ISFS_Open(SAVE_PATHS[i], ISFS_OPEN_READ);
        if (fd < 0) {
            last_error = fd;
        }
    }

    if (fd < 0) {
        // Include last error code in message for debugging
        snprintf(save_data->error_msg, sizeof(save_data->error_msg),
                 "Save not found (ISFS error %d). Tried %d paths. "
                 "Last: %s",
                 last_error, paths_tried,
                 last_tried_path ? last_tried_path : "none");
        save_data->error_code = WIIFIT_ERR_NOT_FOUND;
        return WIIFIT_ERR_NOT_FOUND;
    }

    // Get file size
    fstats stats __attribute__((aligned(32)));
    s32 ret = ISFS_GetFileStats(fd, &stats);
    if (ret < 0) {
        ISFS_Close(fd);
        snprintf(save_data->error_msg, sizeof(save_data->error_msg),
                 "Failed to get file stats (error %d)", ret);
        save_data->error_code = WIIFIT_ERR_READ;
        return WIIFIT_ERR_READ;
    }

    save_size = stats.file_length;

    // Allocate buffer (must be 32-byte aligned for NAND access)
    if (save_buffer) {
        free(save_buffer);
    }
    save_buffer = (u8*)memalign(32, save_size);
    if (!save_buffer) {
        ISFS_Close(fd);
        snprintf(save_data->error_msg, sizeof(save_data->error_msg),
                 "Failed to allocate %u bytes", save_size);
        save_data->error_code = WIIFIT_ERR_MEMORY;
        return WIIFIT_ERR_MEMORY;
    }

    // Read file
    ret = ISFS_Read(fd, save_buffer, save_size);
    ISFS_Close(fd);

    if (ret < 0 || (u32)ret != save_size) {
        snprintf(save_data->error_msg, sizeof(save_data->error_msg),
                 "Failed to read save file (error %d)", ret);
        save_data->error_code = WIIFIT_ERR_READ;
        return WIIFIT_ERR_READ;
    }

    // Parse profiles
    save_data->profile_count = 0;

    for (int i = 0; i < MAX_PROFILES; i++) {
        u32 profile_offset = i * PROFILE_SIZE;
        if (profile_offset + PROFILE_SIZE > save_size) break;

        WiiFitProfile* profile = &save_data->profiles[save_data->profile_count];

        if (parse_profile(save_buffer + profile_offset, profile)) {
            save_data->profile_count++;
        }
    }

    if (save_data->profile_count == 0) {
        snprintf(save_data->error_msg, sizeof(save_data->error_msg),
                 "No profiles found in save file");
        save_data->error_code = WIIFIT_ERR_PARSE;
        return WIIFIT_ERR_PARSE;
    }

    save_data->error_code = WIIFIT_SUCCESS;
    return WIIFIT_SUCCESS;
}

const char* wiifit_error_string(int error_code) {
    switch (error_code) {
        case WIIFIT_SUCCESS:       return "Success";
        case WIIFIT_ERR_INIT:      return "Initialization failed";
        case WIIFIT_ERR_NOT_FOUND: return "Save file not found";
        case WIIFIT_ERR_READ:      return "Read error";
        case WIIFIT_ERR_PARSE:     return "Parse error";
        case WIIFIT_ERR_DECRYPT:   return "Decryption error";
        case WIIFIT_ERR_MEMORY:    return "Memory allocation failed";
        default:                    return "Unknown error";
    }
}

void wiifit_cleanup(void) {
    if (save_buffer) {
        free(save_buffer);
        save_buffer = NULL;
    }
    save_size = 0;

    if (initialized) {
        ISFS_Deinitialize();
        initialized = 0;
    }
}

const char** wiifit_get_search_paths(int* count) {
    if (count) {
        *count = NUM_SAVE_PATHS;
    }
    return SAVE_PATHS;
}

const char* wiifit_get_last_tried_path(void) {
    return last_tried_path;
}

// Debug: Try to open specific Wii Fit save files to see what exists
int wiifit_scan_titles(char* output, int max_len) {
    int pos = 0;

    // Try opening each save path directly and report error codes
    pos += snprintf(output + pos, max_len - pos, "Checking save paths:\n");

    for (int i = 0; i < NUM_SAVE_PATHS && pos < max_len - 100; i++) {
        s32 fd = ISFS_Open(SAVE_PATHS[i], ISFS_OPEN_READ);
        if (fd >= 0) {
            pos += snprintf(output + pos, max_len - pos, "  FOUND: %s\n", SAVE_PATHS[i]);
            ISFS_Close(fd);
        } else {
            // Just show first few paths with errors to save space
            if (i < 5) {
                pos += snprintf(output + pos, max_len - pos, "  [%d] %s\n", fd, SAVE_PATHS[i]);
            }
        }
    }

    return pos;
}
