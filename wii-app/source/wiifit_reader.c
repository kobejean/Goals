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

// Save file paths to try (Wii Fit Plus - RFPE01 USA, RFPP01 PAL, RFPJ01 JPN)
static const char* SAVE_PATHS[] = {
    "/title/00010000/52465045/data/RPHealth.dat",
    "/title/00010000/52465050/data/RPHealth.dat",
    "/title/00010000/5246504a/data/RPHealth.dat",
};

static u8* save_buffer = NULL;
static u32 save_size = 0;
static int initialized = 0;

// Helper: Parse date bitfield to time_t
static time_t parse_date_bitfield(u32 bitfield) {
    struct tm tm_info;
    memset(&tm_info, 0, sizeof(tm_info));

    // Extract fields from bitfield
    tm_info.tm_year = ((bitfield >> 21) & 0x7FF) - 1900;
    tm_info.tm_mon  = ((bitfield >> 17) & 0x0F) - 1;
    tm_info.tm_mday = (bitfield >> 12) & 0x1F;
    tm_info.tm_hour = (bitfield >> 7) & 0x1F;
    tm_info.tm_min  = (bitfield >> 1) & 0x3F;
    tm_info.tm_sec  = 0;

    return mktime(&tm_info);
}

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

    // Parse body measurements starting at BODY_MEASUREMENT_OFFSET
    const u8* meas_ptr = profile_data + BODY_MEASUREMENT_OFFSET;
    profile->measurement_count = 0;

    // Read measurements until we hit empty records or max
    for (int i = 0; i < MAX_MEASUREMENTS; i++) {
        const u8* record = meas_ptr + (i * BODY_MEASUREMENT_SIZE);

        // Check if record is empty (all zeros in date field)
        u32 date_field = read_be32(record);
        if (date_field == 0) break;

        WiiFitMeasurement* m = &profile->measurements[profile->measurement_count];

        // Parse date
        m->timestamp = parse_date_bitfield(date_field);

        // Parse weight (big-endian u16 at +4, value is kg * 10)
        u16 weight_raw = read_be16(record + 4);
        m->weight_kg = weight_raw / 10.0f;

        // Parse BMI (big-endian u16 at +6, value is BMI * 100)
        u16 bmi_raw = read_be16(record + 6);
        m->bmi = bmi_raw / 100.0f;

        // Parse balance (big-endian u16 at +8, value is % * 10)
        u16 balance_raw = read_be16(record + 8);
        m->balance_pct = balance_raw / 10.0f;

        // Check for extended data
        m->has_extended_data = (record[10] != 0);

        profile->measurement_count++;
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
    for (int i = 0; i < NUM_TITLE_IDS && fd < 0; i++) {
        fd = ISFS_Open(SAVE_PATHS[i], ISFS_OPEN_READ);
    }

    if (fd < 0) {
        snprintf(save_data->error_msg, sizeof(save_data->error_msg),
                 "Wii Fit save file not found (error %d)", fd);
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
