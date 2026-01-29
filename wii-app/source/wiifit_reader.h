/*
 * wiifit_reader.h
 * Wii Fit save file parser
 *
 * Parses the Wii Fit save data from NAND to extract:
 * - Body measurements (weight, BMI, balance)
 * - Profile information (name, height, DOB)
 * - Exercise/activity data (future expansion)
 */

#ifndef WIIFIT_READER_H
#define WIIFIT_READER_H

#include <gctypes.h>
#include <time.h>

// Maximum profiles in a Wii Fit save
#define MAX_PROFILES 8

// Maximum measurements per profile
#define MAX_MEASUREMENTS 1024

// Maximum activities per profile
#define MAX_ACTIVITIES 2048

// Profile header offsets
#define PROFILE_SIZE 0x9289
#define PROFILE_NAME_OFFSET 0x08
#define PROFILE_HEIGHT_OFFSET 0x1F
#define PROFILE_DOB_OFFSET 0x20

// Body measurement offsets (relative to profile start)
#define BODY_MEASUREMENT_OFFSET 0x38A1
#define BODY_MEASUREMENT_SIZE 21

// Date bitfield layout (32 bits):
// Bits 21-31: Year (11 bits)
// Bits 17-20: Month (4 bits)
// Bits 12-16: Day (5 bits)
// Bits 7-11:  Hour (5 bits)
// Bits 1-6:   Minute (6 bits)
// Bit 0:      Unknown flag

// Activity types
typedef enum {
    ACTIVITY_YOGA = 0,
    ACTIVITY_STRENGTH = 1,
    ACTIVITY_AEROBICS = 2,
    ACTIVITY_BALANCE = 3,
    ACTIVITY_TRAINING = 4
} WiiFitActivityType;

// Body measurement record
typedef struct {
    time_t timestamp;
    float weight_kg;      // Weight in kilograms
    float bmi;            // Body Mass Index
    float balance_pct;    // Balance percentage (50.0 = perfect)
    u8 has_extended_data; // Whether extended test data is available
} WiiFitMeasurement;

// Activity record
typedef struct {
    time_t timestamp;
    WiiFitActivityType type;
    char name[64];        // Activity name (e.g., "Half Moon", "Push-Up Challenge")
    u16 duration_min;     // Duration in minutes
    u16 calories;         // Calories burned
    u16 score;            // Score/rating (0 if not applicable)
} WiiFitActivity;

// Profile info
typedef struct {
    char name[24];        // Mii name (UTF-8 converted from UTF-16BE)
    u8 height_cm;         // Height in centimeters
    u16 birth_year;
    u8 birth_month;
    u8 birth_day;

    // Measurements
    WiiFitMeasurement measurements[MAX_MEASUREMENTS];
    int measurement_count;

    // Activities
    WiiFitActivity activities[MAX_ACTIVITIES];
    int activity_count;
} WiiFitProfile;

// Complete save data
typedef struct {
    WiiFitProfile profiles[MAX_PROFILES];
    int profile_count;
    int error_code;       // 0 = success, non-zero = error
    char error_msg[256];
} WiiFitSaveData;

/**
 * Initialize the Wii Fit reader.
 * Must be called before any other functions.
 * @return 0 on success, negative on error
 */
int wiifit_init(void);

/**
 * Read and parse Wii Fit save data from NAND.
 * @param save_data Pointer to save data structure to fill
 * @return 0 on success, negative on error
 */
int wiifit_read_save(WiiFitSaveData* save_data);

/**
 * Get human-readable error message.
 * @param error_code Error code from wiifit_* functions
 * @return Static string describing the error
 */
const char* wiifit_error_string(int error_code);

/**
 * Clean up resources.
 */
void wiifit_cleanup(void);

/**
 * Get array of save file paths being searched.
 * @param count Output: number of paths in array
 * @return Array of path strings
 */
const char** wiifit_get_search_paths(int* count);

/**
 * Get the last path that was tried during search.
 * Useful for debugging when save file is not found.
 * @return Path string or NULL if no search attempted
 */
const char* wiifit_get_last_tried_path(void);

/**
 * Debug: Scan title directories to see what exists.
 * @param output Buffer to write results to
 * @param max_len Maximum buffer length
 * @return Number of characters written
 */
int wiifit_scan_titles(char* output, int max_len);

// Error codes
#define WIIFIT_SUCCESS           0
#define WIIFIT_ERR_INIT         -1
#define WIIFIT_ERR_NOT_FOUND    -2
#define WIIFIT_ERR_READ         -3
#define WIIFIT_ERR_PARSE        -4
#define WIIFIT_ERR_DECRYPT      -5
#define WIIFIT_ERR_MEMORY       -6

#endif // WIIFIT_READER_H
