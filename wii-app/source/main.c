/*
 * main.c
 * Wii Fit Sync - Homebrew application for syncing Wii Fit data to iOS
 *
 * Usage:
 * 1. Install to SD:/apps/wiifitsync/boot.dol
 * 2. Launch from Homebrew Channel
 * 3. Note the displayed IP address
 * 4. Enter IP in Goals iOS app settings
 * 5. Sync from iOS app
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <gccore.h>
#include <ogc/machine/processor.h>
#include <wiiuse/wpad.h>
#include <fat.h>

#include "wiifit_reader.h"
#include "network.h"
#include "json_builder.h"
#include "iospatch.h"

// Application states
typedef enum {
    STATE_INIT,
    STATE_MENU,
    STATE_WAITING,
    STATE_SYNCING,
    STATE_ERROR,
    STATE_EXIT
} AppState;

static AppState current_state = STATE_INIT;
static WiiFitSaveData save_data;
static char json_buffer[MAX_MESSAGE_SIZE];
static char recv_buffer[1024];

static void* xfb = NULL;
static GXRModeObj* rmode = NULL;

// Console colors
#define CON_BLACK   0
#define CON_RED     1
#define CON_GREEN   2
#define CON_YELLOW  3
#define CON_BLUE    4
#define CON_MAGENTA 5
#define CON_CYAN    6
#define CON_WHITE   7

static void set_color(int fg) {
    printf("\x1b[3%dm", fg);
}

static void reset_color(void) {
    printf("\x1b[39m");
}

static void clear_screen(void) {
    printf("\x1b[2J\x1b[H");
}

static void print_header(void) {
    set_color(CON_CYAN);
    printf("====================================\n");
    printf("     Wii Fit Sync v1.0\n");
    printf("====================================\n\n");
    reset_color();
}

static void init_video(void) {
    VIDEO_Init();
    rmode = VIDEO_GetPreferredMode(NULL);
    xfb = MEM_K0_TO_K1(SYS_AllocateFramebuffer(rmode));
    console_init(xfb, 20, 20, rmode->fbWidth, rmode->xfbHeight,
                 rmode->fbWidth * VI_DISPLAY_PIX_SZ);
    VIDEO_Configure(rmode);
    VIDEO_SetNextFramebuffer(xfb);
    VIDEO_SetBlack(FALSE);
    VIDEO_Flush();
    VIDEO_WaitVSync();
    if (rmode->viTVMode & VI_NON_INTERLACE) VIDEO_WaitVSync();
}

// Check if we have AHBPROT (hardware access)
static int have_ahbprot(void) {
    return (*(vu32*)0xcd800064 == 0xFFFFFFFF);
}

static int init_systems(void) {
    printf("Initializing systems...\n");

    // Show current IOS and AHBPROT status
    s32 current_ios = IOS_GetVersion();
    printf("Running on IOS%d\n", current_ios);

    int has_ahb = have_ahbprot();
    if (has_ahb) {
        set_color(CON_GREEN);
        printf("AHBPROT: Enabled (NAND access available)\n");
        reset_color();
    } else {
        set_color(CON_YELLOW);
        printf("AHBPROT: Disabled (may not have NAND access)\n");
        printf("Try launching from Homebrew Channel 1.0.8+\n");
        reset_color();
    }

    // Initialize FAT (for potential logging)
    if (!fatInitDefault()) {
        set_color(CON_YELLOW);
        printf("Warning: FAT init failed (SD card access unavailable)\n");
        reset_color();
    }

    // ===== PHASE 1: Read NAND data while we have AHBPROT =====
    printf("Initializing Wii Fit reader...\n");
    int ret = wiifit_init();
    if (ret < 0) {
        set_color(CON_RED);
        printf("Error: %s\n", wiifit_error_string(ret));
        reset_color();
        return ret;
    }

    // Pre-read the save data while we have AHBPROT access
    printf("Reading Wii Fit save data...\n");
    ret = wiifit_read_save(&save_data);
    if (ret == 0) {
        set_color(CON_GREEN);
        printf("Save data loaded: %d profile(s)\n", save_data.profile_count);
        reset_color();
    } else {
        set_color(CON_YELLOW);
        printf("Could not load save data: %s\n", save_data.error_msg);
        reset_color();
    }

    // Clean up ISFS before IOS reload
    wiifit_cleanup();

    // ===== PHASE 2: Reload IOS for working network =====
    // The HBC's async network callback interferes with network operations.
    // Solution: Patch ES to preserve AHBPROT, then reload IOS to get fresh network stack.
    // Reference: https://gbatemp.net/threads/how-to-fix-the-connection-issue-while-running-in-ahbprot-mode.301061/

    if (has_ahb) {
        printf("Patching IOS for network compatibility...\n");
        u32 patched = iospatch_ahbprot();
        if (patched > 0) {
            set_color(CON_GREEN);
            printf("ES patched successfully\n");
            reset_color();

            // Reload IOS to get fresh network stack
            printf("Reloading IOS%d...\n", current_ios);
            ret = IOS_ReloadIOS(current_ios);
            if (ret < 0) {
                set_color(CON_YELLOW);
                printf("IOS reload failed (error %d), continuing anyway...\n", ret);
                reset_color();
            } else {
                set_color(CON_GREEN);
                printf("IOS reloaded successfully\n");
                reset_color();
            }
        } else {
            set_color(CON_YELLOW);
            printf("ES patch failed, network may not work\n");
            reset_color();
        }
    }

    // ===== PHASE 3: Initialize network with fresh IOS =====
    // Initialize WPAD for controller input (must be after IOS reload)
    WPAD_Init();
    WPAD_SetDataFormat(WPAD_CHAN_0, WPAD_FMT_BTNS_ACC_IR);

    printf("Initializing network...\n");
    ret = network_init();
    if (ret < 0) {
        set_color(CON_RED);
        printf("Network error: %s\n", network_get_error());
        printf("Network features will not be available.\n");
        reset_color();
        // Don't return error - still allow viewing data
    } else {
        const char* ip = network_get_ip();
        if (ip) {
            set_color(CON_GREEN);
            printf("Network ready: %s\n", ip);
            reset_color();
        }
    }

    return 0;
}

static void show_menu(void) {
    clear_screen();
    print_header();

    const char* ip = network_get_ip();
    if (ip) {
        printf("IP Address: ");
        set_color(CON_GREEN);
        printf("%s\n", ip);
        reset_color();
        printf("Port: %d\n\n", SYNC_PORT);
    } else {
        set_color(CON_YELLOW);
        printf("Network not available\n\n");
        reset_color();
    }

    // Show pre-loaded save data status (don't re-read, we may have lost AHBPROT)
    if (save_data.error_code == 0 && save_data.profile_count > 0) {
        printf("Wii Fit Data: ");
        set_color(CON_GREEN);
        printf("Loaded %d profile(s)\n", save_data.profile_count);
        reset_color();

        for (int i = 0; i < save_data.profile_count; i++) {
            printf("  - %s: %d measurements\n",
                   save_data.profiles[i].name,
                   save_data.profiles[i].measurement_count);
        }
    } else {
        printf("Wii Fit Data: ");
        set_color(CON_RED);
        printf("Not loaded\n");
        reset_color();
        if (save_data.error_msg[0]) {
            printf("  %s\n", save_data.error_msg);
        }
    }

    printf("\n");
    set_color(CON_CYAN);
    if (ip) {
        printf("Press A to start sync server\n");
    } else {
        printf("Network unavailable - cannot sync\n");
    }
    printf("Press HOME to exit\n");
    reset_color();
}

static void show_waiting_screen(void) {
    clear_screen();
    print_header();

    const char* ip = network_get_ip();
    printf("Waiting for connection from iOS app...\n\n");
    printf("Connect to: ");
    set_color(CON_GREEN);
    printf("%s:%d\n", ip ? ip : "N/A", SYNC_PORT);
    reset_color();

    printf("\n");
    set_color(CON_CYAN);
    printf("Press B to go back\n");
    printf("Press HOME to exit\n");
    reset_color();
}

static void handle_client(void) {
    // Wait for request with timeout (5 seconds)
    int recv_len = 0;
    int timeout_ms = 5000;
    int waited_ms = 0;

    printf("Waiting for sync request...\n");

    while (waited_ms < timeout_ms) {
        recv_len = network_receive(recv_buffer, sizeof(recv_buffer) - 1);

        if (recv_len > 0) {
            break;  // Got data
        } else if (recv_len == NET_ERR_DISCONNECTED) {
            printf("Client disconnected\n");
            network_close_client();
            return;
        } else if (recv_len < 0 && recv_len != NET_ERR_DISCONNECTED) {
            set_color(CON_RED);
            printf("Receive error: %s\n", network_get_error());
            reset_color();
            network_close_client();
            return;
        }

        // No data yet, wait a bit
        usleep(10000);  // 10ms
        waited_ms += 10;
    }

    if (recv_len <= 0) {
        set_color(CON_YELLOW);
        printf("Timeout waiting for request\n");
        reset_color();
        network_close_client();
        return;
    }

    recv_buffer[recv_len] = '\0';

    // Check for sync request
    if (strstr(recv_buffer, "\"action\"") && strstr(recv_buffer, "\"sync\"")) {
        printf("Sync request received\n");

        // Clear buffer before building (prevent stale data)
        memset(json_buffer, 0, sizeof(json_buffer));

        int json_len;
        if (save_data.error_code == 0 && save_data.profile_count > 0) {
            json_len = json_build_response(&save_data, json_buffer, sizeof(json_buffer));
        } else {
            json_len = json_build_error(save_data.error_code, save_data.error_msg, json_buffer, sizeof(json_buffer));
        }

        printf("JSON: %d bytes\n", json_len);

        if (json_len <= 0 || json_len > (int)sizeof(json_buffer)) {
            printf("Bad length!\n");
            network_close_client();
            return;
        }

        // Send response
        int ret = network_send(json_buffer, json_len);
        printf("Sent: %d\n", ret);

        // Wait for ACK with timeout
        waited_ms = 0;
        while (waited_ms < 2000) {
            recv_len = network_receive(recv_buffer, sizeof(recv_buffer) - 1);
            if (recv_len > 0) {
                recv_buffer[recv_len] = '\0';
                if (strstr(recv_buffer, "\"ack\"")) {
                    set_color(CON_GREEN);
                    printf("Sync completed successfully!\n");
                    reset_color();
                }
                break;
            }
            usleep(10000);
            waited_ms += 10;
        }
    } else {
        set_color(CON_YELLOW);
        printf("Unknown request: %.50s...\n", recv_buffer);
        reset_color();
    }

    // Close connection after handling request
    network_close_client();
}

int main(int argc, char** argv) {
    init_video();
    clear_screen();
    print_header();

    int ret = init_systems();
    if (ret < 0) {
        printf("\nInitialization failed. Press HOME to exit.\n");
        current_state = STATE_ERROR;
    } else {
        printf("\nInitialization complete!\n");
        sleep(2);
        current_state = STATE_MENU;
    }

    // Main loop
    while (current_state != STATE_EXIT) {
        WPAD_ScanPads();
        u32 pressed = WPAD_ButtonsDown(0);

        switch (current_state) {
            case STATE_MENU:
                show_menu();

                // Wait for button press
                while (1) {
                    WPAD_ScanPads();
                    pressed = WPAD_ButtonsDown(0);

                    if (pressed & WPAD_BUTTON_A) {
                        // Start server
                        ret = network_start_server();
                        if (ret == 0) {
                            current_state = STATE_WAITING;
                        } else {
                            set_color(CON_RED);
                            printf("Failed to start server: %s\n", network_get_error());
                            reset_color();
                            sleep(2);
                        }
                        break;
                    }

                    if (pressed & WPAD_BUTTON_HOME) {
                        current_state = STATE_EXIT;
                        break;
                    }

                    VIDEO_WaitVSync();
                }
                break;

            case STATE_WAITING:
                show_waiting_screen();

                // Poll for connections
                while (current_state == STATE_WAITING) {
                    WPAD_ScanPads();
                    pressed = WPAD_ButtonsDown(0);

                    if (pressed & WPAD_BUTTON_B) {
                        network_shutdown();
                        current_state = STATE_MENU;
                        break;
                    }

                    if (pressed & WPAD_BUTTON_HOME) {
                        current_state = STATE_EXIT;
                        break;
                    }

                    // Check for incoming connections
                    ret = network_accept_client();
                    if (ret > 0) {
                        current_state = STATE_SYNCING;
                        printf("Client connected!\n");
                        break;
                    }

                    VIDEO_WaitVSync();
                }
                break;

            case STATE_SYNCING:
                handle_client();
                current_state = STATE_WAITING;
                show_waiting_screen();
                break;

            case STATE_ERROR:
                // Wait for HOME button
                if (pressed & WPAD_BUTTON_HOME) {
                    current_state = STATE_EXIT;
                }
                break;

            default:
                break;
        }

        VIDEO_WaitVSync();
    }

    // Cleanup
    network_shutdown();
    wiifit_cleanup();
    WPAD_Shutdown();

    return 0;
}
