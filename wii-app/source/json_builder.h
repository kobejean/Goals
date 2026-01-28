/*
 * json_builder.h
 * Simple JSON builder for Wii Fit data
 */

#ifndef JSON_BUILDER_H
#define JSON_BUILDER_H

#include "wiifit_reader.h"

/**
 * Build JSON response from Wii Fit save data.
 * @param save_data Parsed save data
 * @param buffer Output buffer for JSON
 * @param buffer_size Size of output buffer
 * @return Length of JSON string, or negative on error
 */
int json_build_response(const WiiFitSaveData* save_data, char* buffer, int buffer_size);

/**
 * Build JSON error response.
 * @param error_code Error code
 * @param error_msg Error message
 * @param buffer Output buffer for JSON
 * @param buffer_size Size of output buffer
 * @return Length of JSON string
 */
int json_build_error(int error_code, const char* error_msg, char* buffer, int buffer_size);

#endif // JSON_BUILDER_H
