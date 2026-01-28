/*
 * network.c
 * TCP server implementation for Wii
 */

#include <stdio.h>
#include <string.h>
#include <network.h>
#include <errno.h>
#include <fcntl.h>
#include "network.h"

static NetworkState current_state = NET_STATE_INIT;
static char error_msg[256] = {0};
static char ip_string[32] = {0};

static int server_socket = -1;
static int client_socket = -1;

static struct sockaddr_in server_addr;
static struct sockaddr_in client_addr;

int network_init(void) {
    current_state = NET_STATE_INIT;

    // Initialize network interface
    s32 ret = if_config(ip_string, NULL, NULL, true, 20);
    if (ret < 0) {
        snprintf(error_msg, sizeof(error_msg),
                 "Network init failed (error %d)", ret);
        current_state = NET_STATE_ERROR;
        return NET_ERR_INIT;
    }

    return NET_SUCCESS;
}

const char* network_get_ip(void) {
    if (ip_string[0] == '\0') return NULL;
    return ip_string;
}

int network_start_server(void) {
    // Create socket
    server_socket = net_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (server_socket < 0) {
        snprintf(error_msg, sizeof(error_msg),
                 "Failed to create socket (error %d)", server_socket);
        current_state = NET_STATE_ERROR;
        return NET_ERR_SOCKET;
    }

    // Set socket options
    int yes = 1;
    net_setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    // Set non-blocking
    int flags = net_fcntl(server_socket, F_GETFL, 0);
    net_fcntl(server_socket, F_SETFL, flags | O_NONBLOCK);

    // Bind to port
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(SYNC_PORT);
    server_addr.sin_addr.s_addr = INADDR_ANY;

    s32 ret = net_bind(server_socket, (struct sockaddr*)&server_addr, sizeof(server_addr));
    if (ret < 0) {
        snprintf(error_msg, sizeof(error_msg),
                 "Failed to bind to port %d (error %d)", SYNC_PORT, ret);
        net_close(server_socket);
        server_socket = -1;
        current_state = NET_STATE_ERROR;
        return NET_ERR_BIND;
    }

    // Start listening
    ret = net_listen(server_socket, 1);
    if (ret < 0) {
        snprintf(error_msg, sizeof(error_msg),
                 "Failed to listen (error %d)", ret);
        net_close(server_socket);
        server_socket = -1;
        current_state = NET_STATE_ERROR;
        return NET_ERR_LISTEN;
    }

    current_state = NET_STATE_WAITING;
    return NET_SUCCESS;
}

int network_accept_client(void) {
    if (server_socket < 0) {
        return NET_ERR_SOCKET;
    }

    if (client_socket >= 0) {
        // Already have a client
        return 1;
    }

    socklen_t client_len = sizeof(client_addr);
    client_socket = net_accept(server_socket, (struct sockaddr*)&client_addr, &client_len);

    if (client_socket < 0) {
        if (client_socket == -EAGAIN || client_socket == -EWOULDBLOCK) {
            // No connection pending
            return 0;
        }
        snprintf(error_msg, sizeof(error_msg),
                 "Accept failed (error %d)", client_socket);
        return NET_ERR_ACCEPT;
    }

    // Set client socket non-blocking
    int flags = net_fcntl(client_socket, F_GETFL, 0);
    net_fcntl(client_socket, F_SETFL, flags | O_NONBLOCK);

    current_state = NET_STATE_CONNECTED;
    return 1;
}

int network_receive(char* buffer, int max_len) {
    if (client_socket < 0) {
        return NET_ERR_DISCONNECTED;
    }

    current_state = NET_STATE_RECEIVING;

    s32 ret = net_recv(client_socket, buffer, max_len, 0);

    if (ret == 0) {
        // Client disconnected
        return NET_ERR_DISCONNECTED;
    }

    if (ret < 0) {
        if (ret == -EAGAIN || ret == -EWOULDBLOCK) {
            // No data available
            current_state = NET_STATE_CONNECTED;
            return 0;
        }
        snprintf(error_msg, sizeof(error_msg),
                 "Receive error (error %d)", ret);
        return NET_ERR_RECV;
    }

    current_state = NET_STATE_CONNECTED;
    return ret;
}

int network_send(const char* data, int len) {
    if (client_socket < 0) {
        return NET_ERR_DISCONNECTED;
    }

    current_state = NET_STATE_SENDING;

    int total_sent = 0;
    while (total_sent < len) {
        s32 ret = net_send(client_socket, data + total_sent, len - total_sent, 0);

        if (ret < 0) {
            if (ret == -EAGAIN || ret == -EWOULDBLOCK) {
                // Would block, try again
                continue;
            }
            snprintf(error_msg, sizeof(error_msg),
                     "Send error (error %d)", ret);
            current_state = NET_STATE_ERROR;
            return NET_ERR_SEND;
        }

        total_sent += ret;
    }

    current_state = NET_STATE_CONNECTED;
    return total_sent;
}

void network_close_client(void) {
    if (client_socket >= 0) {
        net_close(client_socket);
        client_socket = -1;
    }
    current_state = NET_STATE_WAITING;
}

void network_shutdown(void) {
    network_close_client();

    if (server_socket >= 0) {
        net_close(server_socket);
        server_socket = -1;
    }

    current_state = NET_STATE_INIT;
}

NetworkState network_get_state(void) {
    return current_state;
}

const char* network_get_error(void) {
    return error_msg;
}
