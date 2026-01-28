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
#include <wiiuse/wpad.h>
#include <fat.h>

#include "wiifit_reader.h"
#include "network.h"
#include "json_builder.h"

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

static int init_systems(void) {
    printf("Initializing systems...\n");

    // Initialize WPAD for controller input
    WPAD_Init();
    WPAD_SetDataFormat(WPAD_CHAN_0, WPAD_FMT_BTNS_ACC_IR);

    // Initialize FAT (for potential logging)
    if (!fatInitDefault()) {
        set_color(CON_YELLOW);
        printf("Warning: FAT init failed (SD card access unavailable)\n");
        reset_color();
    }

    // Initialize Wii Fit reader
    printf("Initializing Wii Fit reader...\n");
    int ret = wiifit_init();
    if (ret < 0) {
        set_color(CON_RED);
        printf("Error: %s\n", wiifit_error_string(ret));
        reset_color();
        return ret;
    }

    // Initialize network
    printf("Initializing network...\n");
    ret = network_init();
    if (ret < 0) {
        set_color(CON_RED);
        printf("Error: %s\n", network_get_error());
        reset_color();
        return ret;
    }

    const char* ip = network_get_ip();
    if (ip) {
        set_color(CON_GREEN);
        printf("Network ready: %s\n", ip);
        reset_color();
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

    // Read save data status
    int ret = wiifit_read_save(&save_data);
    if (ret == 0) {
        printf("Wii Fit Data: ");
        set_color(CON_GREEN);
        printf("Found %d profile(s)\n", save_data.profile_count);
        reset_color();

        for (int i = 0; i < save_data.profile_count; i++) {
            printf("  - %s: %d measurements\n",
                   save_data.profiles[i].name,
                   save_data.profiles[i].measurement_count);
        }
    } else {
        printf("Wii Fit Data: ");
        set_color(CON_RED);
        printf("Not found\n");
        reset_color();
        printf("  %s\n", save_data.error_msg);
    }

    printf("\n");
    set_color(CON_CYAN);
    printf("Press A to start sync server\n");
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
    // Receive request
    int recv_len = network_receive(recv_buffer, sizeof(recv_buffer) - 1);

    if (recv_len > 0) {
        recv_buffer[recv_len] = '\0';

        // Check for sync request
        if (strstr(recv_buffer, "\"action\"") && strstr(recv_buffer, "\"sync\"")) {
            printf("Sync request received, sending data...\n");

            // Read fresh save data
            int ret = wiifit_read_save(&save_data);
            int json_len;

            if (ret == 0) {
                json_len = json_build_response(&save_data, json_buffer, sizeof(json_buffer));
            } else {
                json_len = json_build_error(ret, save_data.error_msg, json_buffer, sizeof(json_buffer));
            }

            // Send response
            ret = network_send(json_buffer, json_len);
            if (ret > 0) {
                set_color(CON_GREEN);
                printf("Sent %d bytes\n", ret);
                reset_color();
            } else {
                set_color(CON_RED);
                printf("Send failed: %s\n", network_get_error());
                reset_color();
            }

            // Wait for ACK
            usleep(100000); // 100ms
            recv_len = network_receive(recv_buffer, sizeof(recv_buffer) - 1);
            if (recv_len > 0 && strstr(recv_buffer, "\"ack\"")) {
                printf("Sync completed successfully!\n");
            }
        }

        // Close connection after handling request
        network_close_client();
    } else if (recv_len == NET_ERR_DISCONNECTED) {
        printf("Client disconnected\n");
        network_close_client();
    }
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
