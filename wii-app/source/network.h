/*
 * network.h
 * TCP server for Wii Fit sync
 */

#ifndef NETWORK_H
#define NETWORK_H

#include <gctypes.h>

// TCP port for sync service
#define SYNC_PORT 8888

// Maximum message size
#define MAX_MESSAGE_SIZE 65536

// Network states
typedef enum {
    NET_STATE_INIT,
    NET_STATE_WAITING,
    NET_STATE_CONNECTED,
    NET_STATE_RECEIVING,
    NET_STATE_SENDING,
    NET_STATE_ERROR
} NetworkState;

/**
 * Initialize networking.
 * @return 0 on success, negative on error
 */
int network_init(void);

/**
 * Get current IP address as string.
 * @return IP address string (e.g., "192.168.1.100") or NULL if not connected
 */
const char* network_get_ip(void);

/**
 * Start TCP server on SYNC_PORT.
 * @return 0 on success, negative on error
 */
int network_start_server(void);

/**
 * Accept incoming connection (non-blocking).
 * @return 1 if client connected, 0 if no connection pending, negative on error
 */
int network_accept_client(void);

/**
 * Receive data from connected client (non-blocking).
 * @param buffer Buffer to store received data
 * @param max_len Maximum bytes to receive
 * @return Number of bytes received, 0 if no data, negative on error/disconnect
 */
int network_receive(char* buffer, int max_len);

/**
 * Send data to connected client.
 * @param data Data to send
 * @param len Length of data
 * @return Number of bytes sent, negative on error
 */
int network_send(const char* data, int len);

/**
 * Close client connection (but keep server running).
 */
void network_close_client(void);

/**
 * Shut down networking.
 */
void network_shutdown(void);

/**
 * Get current network state.
 * @return Current NetworkState
 */
NetworkState network_get_state(void);

/**
 * Get last error message.
 * @return Error message string
 */
const char* network_get_error(void);

// Error codes
#define NET_SUCCESS          0
#define NET_ERR_INIT        -1
#define NET_ERR_SOCKET      -2
#define NET_ERR_BIND        -3
#define NET_ERR_LISTEN      -4
#define NET_ERR_ACCEPT      -5
#define NET_ERR_SEND        -6
#define NET_ERR_RECV        -7
#define NET_ERR_TIMEOUT     -8
#define NET_ERR_DISCONNECTED -9

#endif // NETWORK_H
