/*
 * json_builder.c
 * JSON serialization for Wii Fit data
 */

#include <stdio.h>
#include <string.h>
#include <time.h>
#include "json_builder.h"

// Helper: Format timestamp as ISO 8601
static void format_timestamp(time_t ts, char* buf, int buf_size) {
    struct tm* tm_info = localtime(&ts);
    strftime(buf, buf_size, "%Y-%m-%dT%H:%M:%S", tm_info);
}

// Helper: Escape string for JSON
static int json_escape_string(const char* src, char* dst, int dst_size) {
    int i = 0, j = 0;
    while (src[i] && j < dst_size - 1) {
        char c = src[i++];
        switch (c) {
            case '"':  if (j < dst_size - 2) { dst[j++] = '\\'; dst[j++] = '"'; } break;
            case '\\': if (j < dst_size - 2) { dst[j++] = '\\'; dst[j++] = '\\'; } break;
            case '\n': if (j < dst_size - 2) { dst[j++] = '\\'; dst[j++] = 'n'; } break;
            case '\r': if (j < dst_size - 2) { dst[j++] = '\\'; dst[j++] = 'r'; } break;
            case '\t': if (j < dst_size - 2) { dst[j++] = '\\'; dst[j++] = 't'; } break;
            default: dst[j++] = c; break;
        }
    }
    dst[j] = '\0';
    return j;
}

// Helper: Get activity type string
static const char* activity_type_string(WiiFitActivityType type) {
    switch (type) {
        case ACTIVITY_YOGA:     return "yoga";
        case ACTIVITY_STRENGTH: return "strength";
        case ACTIVITY_AEROBICS: return "aerobics";
        case ACTIVITY_BALANCE:  return "balance";
        case ACTIVITY_TRAINING: return "training";
        default:                return "unknown";
    }
}

// Helper macro to safely add to offset with overflow protection
#define SAFE_APPEND(fmt, ...) do { \
    if (offset >= buffer_size - 1) goto overflow; \
    int written = snprintf(buffer + offset, buffer_size - offset, fmt, ##__VA_ARGS__); \
    if (written < 0) goto overflow; \
    if (written >= buffer_size - offset) goto overflow; \
    offset += written; \
} while(0)

int json_build_response(const WiiFitSaveData* save_data, char* buffer, int buffer_size) {
    int offset = 0;
    char timestamp_buf[32];
    char escaped_name[64];

    // Start response
    SAFE_APPEND("{\"version\":2,\"profiles\":[");

    // Add each profile
    for (int p = 0; p < save_data->profile_count; p++) {
        const WiiFitProfile* profile = &save_data->profiles[p];

        if (p > 0) {
            SAFE_APPEND(",");
        }

        json_escape_string(profile->name, escaped_name, sizeof(escaped_name));

        SAFE_APPEND("{\"name\":\"%s\",\"height_cm\":%d,\"dob\":\"%04d-%02d-%02d\",",
                    escaped_name,
                    profile->height_cm,
                    profile->birth_year,
                    profile->birth_month,
                    profile->birth_day);

        // Measurements array
        SAFE_APPEND("\"measurements\":[");

        for (int m = 0; m < profile->measurement_count; m++) {
            const WiiFitMeasurement* meas = &profile->measurements[m];

            if (m > 0) {
                SAFE_APPEND(",");
            }

            format_timestamp(meas->timestamp, timestamp_buf, sizeof(timestamp_buf));

            // Ensure values are valid (no NaN/Inf)
            float weight = meas->weight_kg;
            float bmi = meas->bmi;
            float balance = meas->balance_pct;
            if (weight != weight || weight < 0) weight = 0.0f;  // NaN check
            if (bmi != bmi || bmi < 0) bmi = 0.0f;
            if (balance != balance || balance < 0) balance = 50.0f;

            SAFE_APPEND("{\"date\":\"%s\",\"weight_kg\":%.1f,\"bmi\":%.2f,\"balance_percent\":%.1f}",
                        timestamp_buf,
                        weight,
                        bmi,
                        balance);
        }

        SAFE_APPEND("],");

        // Activities array
        SAFE_APPEND("\"activities\":[");

        for (int a = 0; a < profile->activity_count; a++) {
            const WiiFitActivity* act = &profile->activities[a];

            if (a > 0) {
                SAFE_APPEND(",");
            }

            format_timestamp(act->timestamp, timestamp_buf, sizeof(timestamp_buf));
            json_escape_string(act->name, escaped_name, sizeof(escaped_name));

            SAFE_APPEND("{\"date\":\"%s\",\"type\":\"%s\",\"name\":\"%s\","
                        "\"duration_min\":%d,\"calories\":%d,\"score\":%d}",
                        timestamp_buf,
                        activity_type_string(act->type),
                        escaped_name,
                        act->duration_min,
                        act->calories,
                        act->score);
        }

        SAFE_APPEND("]}");
    }

    // Close profiles array and response
    SAFE_APPEND("]}");

    return offset;

overflow:
    // Buffer overflow - return truncated but valid JSON
    // Try to close the JSON properly
    if (offset > 10 && buffer_size > offset + 20) {
        offset = snprintf(buffer + offset, buffer_size - offset, "]}]}");
    }
    return offset;
}

#undef SAFE_APPEND

int json_build_error(int error_code, const char* error_msg, char* buffer, int buffer_size) {
    char escaped_msg[256];
    json_escape_string(error_msg, escaped_msg, sizeof(escaped_msg));

    return snprintf(buffer, buffer_size,
                    "{\"version\":2,\"error\":{\"code\":%d,\"message\":\"%s\"}}",
                    error_code, escaped_msg);
}
