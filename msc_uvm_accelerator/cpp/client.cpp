// Original work license:
/******************************************************************************
* (C) Copyright 2021 AMIQ Consulting
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* MODULE:      AMIQ OFC client
* PROJECT:     Amiq Open-Source Framework for Co-Emulation
*******************************************************************************/
// Changed by Andreas Lildballe for Master Thesis, 2026:
/******************************************************************************
* (C) Copyright 2026 Andreas Lildballe
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* MODULE:      ACCEL CPP Client
* PROJECT:     Accelerating UVM testbenches using Co-Emulation in FPGAs
*******************************************************************************/

///////////////////////////////////////////////////////////////////////
//////////////////////////////// Defines //////////////////////////////
///////////////////////////////////////////////////////////////////////
#define BUFFER_SIZE 16384
#define DO_LOGGING 1
#define ENABLE_METRICS 1

///////////////////////////////////////////////////////////////////////
////////////////////////////// Imports ////////////////////////////////
///////////////////////////////////////////////////////////////////////
#include <arpa/inet.h>
#include <errno.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <unistd.h>
#include <netinet/tcp.h>
#include <thread>
#include <cstring>
#include <string>
#include <svdpi.h>

#if ENABLE_METRICS
#include <mutex>
#include <chrono>
#include <vector>
#include <fstream>
#endif

///////////////////////////////////////////////////////////////////////
////////////////// Extern SystemVerilog functions used ////////////////
///////////////////////////////////////////////////////////////////////
extern "C" void recv_callback(const unsigned char *msg, int len);
extern "C" void consume_time();

///////////////////////////////////////////////////////////////////////
//////////////////////// Silent Period Metrics ////////////////////////
///////////////////////////////////////////////////////////////////////
#if ENABLE_METRICS
static std::chrono::steady_clock::time_point last_recv_time =
    std::chrono::steady_clock::now();
static bool first_packet_received = false;

static std::chrono::steady_clock::time_point last_send_time =
    std::chrono::steady_clock::now();
static bool first_send_completed = false;

struct MetricStats {
    long long count = 0;
    long long total_us = 0;
    long long min_us = -1;
    long long max_us = 0;

    void add(long long value_us) {
        count++;
        total_us += value_us;
        if (min_us == -1 || value_us < min_us) {
            min_us = value_us;
        }
        if (value_us > max_us) {
            max_us = value_us;
        }
    }

    double avg_us() const {
        return (count > 0) ? static_cast<double>(total_us) / count : 0.0;
    }
};

struct SilentSample {
    long long silent_us;
    int frame_bytes;
};

static MetricStats recv_silent_stats;
static MetricStats send_silent_stats;

// Raw silent-period samples for export/plotting
static std::vector<SilentSample> send_silent_samples;
static std::vector<SilentSample> recv_silent_samples;

static long long total_bytes_sent = 0;
static long long total_bytes_received = 0;
static long long send_call_count = 0;
static long long recv_call_count = 0;

// Would-block / readiness related counters
static long long send_would_block_count = 0;
static long long recv_would_block_count = 0;

// Optional breakdown for analysis
static long long send_poll_not_ready_count = 0;
static long long recv_poll_timeout_count = 0;
static long long send_eagain_count = 0;
static long long recv_eagain_count = 0;
static long long send_eintr_count = 0;
static long long recv_eintr_count = 0;

static std::mutex metrics_mutex;
#endif

///////////////////////////////////////////////////////////////////////
/////////////////////////// Global Variables //////////////////////////
///////////////////////////////////////////////////////////////////////
static int wait_for_nonblocking_connect(int sockfd, int timeout_ms) {
    pollfd conn_event;
    memset(&conn_event, 0, sizeof(conn_event));
    conn_event.fd = sockfd;
    conn_event.events = POLLOUT;

    int event_ready = poll(&conn_event, 1, timeout_ms);
    if (event_ready <= 0) {
        return -1;
    }

    if (conn_event.revents & (POLLERR | POLLHUP | POLLNVAL)) {
        return -1;
    }

    int so_error = 0;
    socklen_t so_error_len = sizeof(so_error);
    if (getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &so_error, &so_error_len) != 0) {
        return -1;
    }

    if (so_error != 0) {
        errno = so_error;
        return -1;
    }

    return 0;
}

static void print_socket_payload(const char *direction, const unsigned char *data, int len) {
    if (data == nullptr || len <= 0) {
        printf("[DPI-C] [%s] len=%d\n", direction, len);
        fflush(stdout);
        return;
    }

    printf("[DPI-C] [%s] len=%d payload_hex=", direction, len);
    for (int i = 0; i < len; i++) {
        printf("%02x", data[i]);
    }
    printf("\n");
    fflush(stdout);
}

#if ENABLE_METRICS
static void export_samples_to_csv(const char *filename,
                                  const std::vector<SilentSample> &samples) {
    std::ofstream ofs(filename);
    if (!ofs.is_open()) {
        printf("[DPI-C] Failed to open metrics file: %s\n", filename);
        return;
    }

    ofs << "sample_idx,silent_us,silent_ms,frame_bytes\n";
    for (size_t i = 0; i < samples.size(); ++i) {
        ofs << i
            << "," << samples[i].silent_us
            << "," << (samples[i].silent_us / 1000.0)
            << "," << samples[i].frame_bytes
            << "\n";
    }

    ofs.close();
    printf("[DPI-C] Exported %zu samples to %s\n", samples.size(), filename);
}
#endif

///////////////////////////////////////////////////////////////////////
/////////////////////////// Client Arguments //////////////////////////
///////////////////////////////////////////////////////////////////////
/*********************************************************************
* Structure that holds the hostname and number of the server
*********************************************************************/
struct ConnConfiguration {
    int   port;      // the port number
    char *hostname;  // the name of server's host
};

/*********************************************************************
* Enum that holds the possible states of a connection
*********************************************************************/
enum class ConnectionState {
    UNCONFIGURED,
    CONFIGURED,
    CONNECTED
};

/*********************************************************************
* Structure that holds the actual connection
*********************************************************************/
struct Connection {
    /*
    * Use this to get the actual connection
    */
    static Connection &instance() {
        static Connection conn;
        return conn;
    }

    /*
    * Destructor closes socket.
    */
    ~Connection() {
        if (sock_fd != -1) {
            close(sock_fd);
        }
    }

    /*
    * Turn the state of the connection into string.
    */
    std::string state_to_string() const {
        switch (state) {
        case ConnectionState::UNCONFIGURED:
            return "Unconfigured";
        case ConnectionState::CONFIGURED:
            return "Configured";
        case ConnectionState::CONNECTED:
            return "Connected";
        default:
            break;
        }
        return "Error";
    }

    // Get the state of the connection.
    ConnectionState get_state() const {
        return state;
    }

    /*
    * Set the state of the connection.
    *
    * @param new_state -> This will be the new state of the connection
    *                  -> (Type: ConnectionState)
    */
    void set_state(const ConnectionState new_state) {
        // If there was a connection configured, close the socket
        if (state == ConnectionState::CONNECTED
            && new_state == ConnectionState::CONFIGURED) {
            // Cleanup
            close(sock_fd);
            sock_fd = -1;
        }
        state = new_state;
    }

    /*
    * Set the socket for the connection.
    *
    * @param sockfd -> This will be the socket used for the connection
    */
    void set_sockfd(const int sockfd) {
        sock_fd = sockfd;
        // Assign pollfd events
        recv_event.fd = sockfd;
        recv_event.events = POLLIN;
        send_event.fd = sockfd;
        send_event.events = POLLOUT;
    }

    /*
    * Set the timeout for receive and send operations.
    *
    * @param milliseconds -> This will be the timeout, measured in milliseconds
    */
    void set_timeout(const int milliseconds) {
        timeout = (milliseconds <= 0) ? 1 : milliseconds;
    }

    /*
    * This function is used by the send_data extern function.
    *
    * Throws:
    * -1 -> on error
    * 1  -> if sending would block (unlikely)
    *
    * Returns number of bytes sent to remote
    *
    * @param data  -> The data that will be sent to the server
    * @param len   -> The length of the data that will be sent to the server
    *              -> measured in bytes
    *
    * @see send_data
    */
    int do_send(const unsigned char *data, int len) {
        int status = can_use_connection();
        if (!status) {
            return status;
        }

        int event_ready = poll(&send_event, 1, timeout);
        if (event_ready == -1) {
            if (errno == EINTR) {
#if ENABLE_METRICS
                {
                    std::lock_guard<std::mutex> lock(metrics_mutex);
                    send_would_block_count++;
                    send_eintr_count++;
                }
#endif
                consume_time();
                throw 1;
            }
            throw -1;
        }

        if (send_event.revents & (POLLERR | POLLHUP | POLLNVAL)) {
            int so_error = 0;
            socklen_t so_error_len = sizeof(so_error);
            if (getsockopt(sock_fd, SOL_SOCKET, SO_ERROR, &so_error, &so_error_len) == 0
                && so_error != 0) {
                errno = so_error;
            }
            set_state(ConnectionState::CONFIGURED);
            throw -1;
        }

        int can_send = send_event.revents & POLLOUT;
        if (!can_send) {
#if ENABLE_METRICS
            {
                std::lock_guard<std::mutex> lock(metrics_mutex);
                send_would_block_count++;
                send_poll_not_ready_count++;
            }
#endif
            consume_time();
            throw 1;
        }

#if DO_LOGGING
        print_socket_payload("SOCKET SEND", data, len);
#endif

#if ENABLE_METRICS
        bool have_send_silent_sample = false;
        long long send_silent_us = 0;
        auto send_now = std::chrono::steady_clock::now();
        if (first_send_completed) {
            send_silent_us =
                std::chrono::duration_cast<std::chrono::microseconds>(
                    send_now - last_send_time).count();
            have_send_silent_sample = true;
        }
#endif

        int sent = send(sock_fd, reinterpret_cast<const char *>(data), len, 0);

        if (sent > 0) {
#if ENABLE_METRICS
            last_send_time = std::chrono::steady_clock::now();
            first_send_completed = true;
            {
                std::lock_guard<std::mutex> lock(metrics_mutex);
                total_bytes_sent += sent;
                send_call_count++;
                if (have_send_silent_sample) {
                    send_silent_stats.add(send_silent_us);
                    send_silent_samples.push_back({send_silent_us, sent});
                }
            }
#endif
        }

        if (sent < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
#if ENABLE_METRICS
                {
                    std::lock_guard<std::mutex> lock(metrics_mutex);
                    send_would_block_count++;
                    if (errno == EINTR) {
                        send_eintr_count++;
                    } else {
                        send_eagain_count++;
                    }
                }
#endif
                consume_time();
                throw 1;
            }
            set_state(ConnectionState::CONFIGURED);
            throw -1;
        }

#if DO_LOGGING
        printf("[DPI-C] [SOCKET SEND RESULT] requested=%d sent=%d\n", len, sent);
#endif
        fflush(stdout);
        return sent;
    }

    /*
    * This function is used by the do_recv_forever function.
    *
    * Throws:
    * -1  -> on error
    * 1   -> if recv would block
    *
    * Returns number of bytes received from remote
    *
    * @param data  -> The data that is received from remote
    *              -> output
    * @param len   -> The length of the data that is received from remote
    *              -> measured in bytes
    *
    * @see do_recv_forever
    */
    int do_recv(unsigned char *data, int len) {
        int status = can_use_connection();
        if (!status) {
            return status;
        }

        int event_ready = poll(&recv_event, 1, timeout);
        if (event_ready == -1) {
            if (errno == EINTR) {
#if ENABLE_METRICS
                {
                    std::lock_guard<std::mutex> lock(metrics_mutex);
                    recv_would_block_count++;
                    recv_eintr_count++;
                }
#endif
                throw 1;
            }
            throw -1;
        }

        if (event_ready == 0) {
#if ENABLE_METRICS
            {
                std::lock_guard<std::mutex> lock(metrics_mutex);
                recv_would_block_count++;
                recv_poll_timeout_count++;
            }
#endif
            throw 1;
        }

        if (recv_event.revents & (POLLERR | POLLHUP | POLLNVAL)) {
            set_state(ConnectionState::CONFIGURED);
            throw -1;
        }

        int can_read = recv_event.revents & POLLIN;
        if (!can_read) {
#if ENABLE_METRICS
            {
                std::lock_guard<std::mutex> lock(metrics_mutex);
                recv_would_block_count++;
                recv_poll_timeout_count++;
            }
#endif
            throw 1;
        }

        int received = recv(sock_fd, data, len, 0);

        if (received == 0) {
            printf("[DPI-C] Remote socket peer closed the connection. Disabling recv/send polling.\n");
            set_state(ConnectionState::CONFIGURED);
            return 0;
        }

        if (received < 0) {
            // EAGAIN and EWOULDBLOCK indicate that there is no data to read,
            // or that the socket buffer was consumed by an interrupt before
            // we could read it. In both cases, we can just try again later,
            // so we throw 1 to indicate a would-block condition.
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
#if ENABLE_METRICS
                {
                    std::lock_guard<std::mutex> lock(metrics_mutex);
                    recv_would_block_count++;
                    if (errno == EINTR) {
                        recv_eintr_count++;
                    } else {
                        recv_eagain_count++;
                    }
                }
#endif
                throw 1;
            }
            // For other errors, we consider the connection to be broken,
            // so we disable the connection and throw -1.
            set_state(ConnectionState::CONFIGURED);
            throw -1;
        }

#if ENABLE_METRICS
        // Measure silent/idle period between received packets
        auto now = std::chrono::steady_clock::now();
        if (first_packet_received) {
            auto silent_us =
                std::chrono::duration_cast<std::chrono::microseconds>(
                    now - last_recv_time).count();
            {
                std::lock_guard<std::mutex> lock(metrics_mutex);
                recv_silent_stats.add(silent_us);
                recv_silent_samples.push_back({silent_us, received});
            }
        }
        last_recv_time = now;
        first_packet_received = true;
        {
            std::lock_guard<std::mutex> lock(metrics_mutex);
            total_bytes_received += received;
            recv_call_count++;
        }
#endif

#if DO_LOGGING
        if (received > 0) {
            print_socket_payload("SOCKET RECV", data, received);
        }
#endif
        return received;
    }

    void do_recv_forever() {
        int r;
        unsigned char data[BUFFER_SIZE + 1];
        printf("[DPI-C] do_recv_forever started\n");

        // receive transactions forever
        while (true) {
            try {
                r = do_recv(data, BUFFER_SIZE);
                if (r > 0) {
                    recv_callback(data, r);
                } else {
                    // Yield simulator time when disconnected or no data is available.
                    consume_time();
                }
            } catch (int e) {
                if (e == 1) {
                    // Make a context switch
                    consume_time();
                } else if (e == -1) {
                    printf("[DPI-C] Error while polling socket! fd=%d errno=%d (%s). Disabling recv polling.\n",
                           sock_fd,
                           errno,
                           std::strerror(errno));
                    set_state(ConnectionState::CONFIGURED);
                    consume_time();
                }
            }
        }
    }

private:
    /*
    * The socket used for the connection
    */
    int sock_fd;

    /*
    * The state of the connection
    */
    ConnectionState state;

    /*
    * Send and receive events
    */
    pollfd recv_event;
    pollfd send_event;

    /*
    * The timeout before a send or receive operation is dropped
    */
    int timeout;

    /*
    * Constructor for the connection
    * This shall not be used, the Connection::instance() should be used instead
    */
    Connection() {
        state = ConnectionState::UNCONFIGURED;
        sock_fd = -1;
        timeout = 0;
        memset(&recv_event, 0, sizeof(recv_event));
        memset(&send_event, 0, sizeof(send_event));
    }

    /*
    * This structure does not allow copy constructors or equal operations
    */
    Connection(const Connection &) = delete;
    Connection &operator=(const Connection &) = delete;

    /*
    * Check if the connection has been established
    */
    int can_use_connection() const {
        if (state != ConnectionState::CONNECTED) {
            return false;
        }
        return true;
    }
};

///////////////////////////////////////////////////////////////////////
/////// Functions that will be used in the SystemVerilog code /////////
///////////////////////////////////////////////////////////////////////
extern "C" int configure(const char *hostname, int port) {
    Connection &conn = Connection::instance();
    printf("[DPI-C] Configuring with %s:%u\n", hostname, port);
    conn.set_state(ConnectionState::CONFIGURED);
    printf("[DPI-C] State of connection set, creating socket\n");

    // Create socket
    int sockfd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);

    // SOCK_STREAM -> TCP socket
    // SOCK_DGRAM  -> UDP socket
    if (sockfd == -1) {
        perror("[DPI-C] Failed to create socket");
        return 1;
    }

    printf("[DPI-C] Socket created. Assigning port\n");

    // Assign PORT
    struct sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(port);

    // See if we got an ip or a hostname (like localhost)
    struct hostent *server = gethostbyname(hostname);
    if (server == NULL) {
        servaddr.sin_addr.s_addr = inet_addr(hostname);
    } else {
        memcpy((char *)&(servaddr.sin_addr.s_addr), server->h_addr, server->h_length);
    }

    printf("[DPI-C] Trying to connect\n");

    // Try to connect (non-blocking)
    int status = connect(sockfd, (sockaddr *)&servaddr, sizeof(servaddr));
    if (status != 0 && errno == EINPROGRESS) {
        status = wait_for_nonblocking_connect(sockfd, 1000);
    }

    if (status != 0) {
        perror("[DPI-C] Connect failed");
        close(sockfd);
        return 1;
    }

    printf("[DPI-C] Connected to %s:%u\n", hostname, port);
    conn.set_state(ConnectionState::CONNECTED);
    conn.set_sockfd(sockfd);
    return conn.get_state() != ConnectionState::CONNECTED;
}

extern "C" void set_timeout(const int milliseconds) {
    Connection &conn = Connection::instance();
    conn.set_timeout(milliseconds);
}

extern "C" void send_data(const svOpenArrayHandle data_h, int len, int *result) {
    Connection &conn = Connection::instance();
    if (conn.get_state() != ConnectionState::CONNECTED) {
        *result = -2;
        return;
    }

    const unsigned char *data =
        reinterpret_cast<const unsigned char *>(svGetArrayPtr(data_h));
    if (data == nullptr) {
        *result = -4;
        return;
    }

    try {
        *result = conn.do_send(data, len);
    } catch (int i) {
        if (i == 1) {
            *result = -3;
            return;
        } else if (i == -1) {
            *result = -4;
            printf("[DPI-C] Error while polling socket! errno=%d (%s)\n",
                   errno, std::strerror(errno));
            return;
        }
        *result = -4;
    }
}

extern "C" void recv_thread() {
#if DO_LOGGING
    printf("[DPI-C] recv_thread started\n");
#endif
    Connection &conn = Connection::instance();
    conn.do_recv_forever();
}

extern "C" void print_metric_statistics() {
#if ENABLE_METRICS
    std::lock_guard<std::mutex> lock(metrics_mutex);
    export_samples_to_csv("send_silent_periods.csv", send_silent_samples);
    export_samples_to_csv("recv_silent_periods.csv", recv_silent_samples);

    printf("\n");
    printf("============================================================\n");
    printf("[DPI-C] METRIC STATISTICS SUMMARY\n");
    printf("============================================================\n");

    printf("[DPI-C] SEND:\n");
    printf("  calls                : %lld\n", send_call_count);
    printf("  total bytes          : %lld\n", total_bytes_sent);
    if (send_call_count > 0) {
        printf("  avg bytes per call   : %0.3f\n",
               static_cast<double>(total_bytes_sent) / send_call_count);
    } else {
        printf("  avg bytes per call   : n/a\n");
    }
    printf("  would-block count    : %lld\n", send_would_block_count);
    printf("    poll not ready     : %lld\n", send_poll_not_ready_count);
    printf("    EAGAIN/EWOULDBLOCK : %lld\n", send_eagain_count);
    printf("    EINTR              : %lld\n", send_eintr_count);
    printf("  silent periods       : %lld\n", send_silent_stats.count);
    if (send_silent_stats.count > 0) {
        printf("  silent total         : %lld us (%0.3f ms)\n",
               send_silent_stats.total_us,
               send_silent_stats.total_us / 1000.0);
        printf("  silent min           : %lld us (%0.3f ms)\n",
               send_silent_stats.min_us,
               send_silent_stats.min_us / 1000.0);
        printf("  silent max           : %lld us (%0.3f ms)\n",
               send_silent_stats.max_us,
               send_silent_stats.max_us / 1000.0);
        printf("  silent avg           : %0.3f us (%0.3f ms)\n",
               send_silent_stats.avg_us(),
               send_silent_stats.avg_us() / 1000.0);
        printf("  sample count         : %zu\n", send_silent_samples.size());
    } else {
        printf("  silent stats         : no samples\n");
    }

    printf("[DPI-C] RECV:\n");
    printf("  packets              : %lld\n", recv_call_count);
    printf("  total bytes          : %lld\n", total_bytes_received);
    if (recv_call_count > 0) {
        printf("  avg bytes per call   : %0.3f\n",
               static_cast<double>(total_bytes_received) / recv_call_count);
    } else {
        printf("  avg bytes per call   : n/a\n");
    }
    printf("  would-block count    : %lld\n", recv_would_block_count);
    printf("    poll timeout       : %lld\n", recv_poll_timeout_count);
    printf("    EAGAIN/EWOULDBLOCK : %lld\n", recv_eagain_count);
    printf("    EINTR              : %lld\n", recv_eintr_count);
    printf("  silent periods       : %lld\n", recv_silent_stats.count);
    if (recv_silent_stats.count > 0) {
        printf("  silent total         : %lld us (%0.3f ms)\n",
               recv_silent_stats.total_us,
               recv_silent_stats.total_us / 1000.0);
        printf("  silent min           : %lld us (%0.3f ms)\n",
               recv_silent_stats.min_us,
               recv_silent_stats.min_us / 1000.0);
        printf("  silent max           : %lld us (%0.3f ms)\n",
               recv_silent_stats.max_us,
               recv_silent_stats.max_us / 1000.0);
        printf("  silent avg           : %0.3f us (%0.3f ms)\n",
               recv_silent_stats.avg_us(),
               recv_silent_stats.avg_us() / 1000.0);
        printf("  sample count         : %zu\n", recv_silent_samples.size());
    } else {
        printf("  silent stats         : no samples\n");
    }

    printf("============================================================\n");
#else
    printf("[DPI-C] Metric statistics disabled at compile time (ENABLE_METRICS=0)\n");
#endif
    fflush(stdout);
}