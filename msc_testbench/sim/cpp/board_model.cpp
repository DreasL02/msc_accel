#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#include <algorithm>
#include <cctype>

#include <string>

#include <svdpi.h>

static int g_board_sockfd = -1;
static int g_listen_sockfd = -1;
static pollfd g_send_event;
static pollfd g_recv_event;
static int g_timeout_ms = 10;
static const char *g_default_hostname = "localhost";
static const int g_default_port = 9095;
static std::string g_last_recv_payload;

static int board_socket_check_connect_complete(int sockfd, int timeout_ms) {
  pollfd conn_event;
  conn_event.fd = sockfd;
  conn_event.events = POLLOUT;
  conn_event.revents = 0;

  int event_ready = poll(&conn_event, 1, timeout_ms);
  if (event_ready <= 0) {
    printf("[BOARD_SOCKET] connect timed out while waiting for completion\n");
    fflush(stdout);
    return -1;
  }

  if (conn_event.revents & (POLLERR | POLLHUP | POLLNVAL)) {
    int so_error = 0;
    socklen_t so_error_len = sizeof(so_error);
    (void)getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &so_error, &so_error_len);
    if (so_error == 0) {
      so_error = errno;
    }
    printf("[BOARD_SOCKET] connect failed during completion: %s\n", strerror(so_error));
    fflush(stdout);
    return -1;
  }

  int so_error = 0;
  socklen_t so_error_len = sizeof(so_error);
  if (getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &so_error, &so_error_len) != 0 || so_error != 0) {
    if (so_error == 0) {
      so_error = errno;
    }
    printf("[BOARD_SOCKET] connect failed (SO_ERROR): %s\n", strerror(so_error));
    fflush(stdout);
    return -1;
  }

  return 0;
}

static void board_socket_close_internal() {
  if (g_board_sockfd != -1) {
    close(g_board_sockfd);
    g_board_sockfd = -1;
  }

  if (g_listen_sockfd != -1) {
    close(g_listen_sockfd);
    g_listen_sockfd = -1;
  }

  g_last_recv_payload.clear();
}

extern "C" const char *board_socket_get_last_payload() {
  return g_last_recv_payload.c_str();
}

static void board_socket_assign_connected_socket(int sockfd) {
  g_board_sockfd = sockfd;
  g_send_event.fd = sockfd;
  g_send_event.events = POLLOUT;
  g_recv_event.fd = sockfd;
  g_recv_event.events = POLLIN;
}

extern "C" int board_socket_connect(const char *hostname, int port) {
  if (hostname == nullptr || hostname[0] == '\0') {
    hostname = g_default_hostname;
  }

  if (port <= 0) {
    port = g_default_port;
  }

  board_socket_close_internal();

  int sockfd = socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0);
  if (sockfd == -1) {
    printf("[BOARD_SOCKET] socket creation failed: %s\n", strerror(errno));
    fflush(stdout);
    return -1;
  }

  sockaddr_in servaddr;
  memset(&servaddr, 0, sizeof(servaddr));
  servaddr.sin_family = AF_INET;
  servaddr.sin_port = htons(port);

  hostent *server = gethostbyname(hostname);
  if (server == nullptr) {
    servaddr.sin_addr.s_addr = inet_addr(hostname);
  } else {
    memcpy((char *)&(servaddr.sin_addr.s_addr), server->h_addr, server->h_length);
  }

  int status = connect(sockfd, (sockaddr *)&servaddr, sizeof(servaddr));
  if (status != 0 && errno != EINPROGRESS) {
    printf("[BOARD_SOCKET] connect failed to %s:%d: %s\n", hostname, port, strerror(errno));
    fflush(stdout);
    close(sockfd);
    return -1;
  }

  if (status != 0 && errno == EINPROGRESS) {
    if (board_socket_check_connect_complete(sockfd, g_timeout_ms) != 0) {
      close(sockfd);
      return -1;
    }
  }

  board_socket_assign_connected_socket(sockfd);

  printf("[BOARD_SOCKET] connected to %s:%d\n", hostname, port);
  fflush(stdout);
  return 0;
}

extern "C" int board_socket_connect_default() {
  return board_socket_connect(g_default_hostname, g_default_port);
}

extern "C" int board_socket_listen(const char *bind_host, int port) {
  if (port <= 0) {
    port = g_default_port;
  }

  // Reset any previous socket state before starting a fresh listen endpoint.
  board_socket_close_internal();

  int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
  if (listen_fd == -1) {
    printf("[BOARD_SOCKET] listen socket creation failed: %s\n", strerror(errno));
    fflush(stdout);
    return -1;
  }

  int reuse_addr = 1;
  if (setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &reuse_addr, sizeof(reuse_addr)) != 0) {
    printf("[BOARD_SOCKET] setsockopt(SO_REUSEADDR) failed: %s\n", strerror(errno));
    fflush(stdout);
    close(listen_fd);
    return -1;
  }

  sockaddr_in servaddr;
  memset(&servaddr, 0, sizeof(servaddr));
  servaddr.sin_family = AF_INET;
  servaddr.sin_port = htons(port);

  if (bind_host == nullptr || bind_host[0] == '\0') {
    servaddr.sin_addr.s_addr = htonl(INADDR_ANY);
  } else {
    hostent *server = gethostbyname(bind_host);
    if (server == nullptr) {
      unsigned long parsed_addr = inet_addr(bind_host);
      if (parsed_addr == INADDR_NONE) {
        printf("[BOARD_SOCKET] bind host '%s' is invalid\n", bind_host);
        fflush(stdout);
        close(listen_fd);
        return -1;
      }
      servaddr.sin_addr.s_addr = parsed_addr;
    } else {
      memcpy((char *)&(servaddr.sin_addr.s_addr), server->h_addr, server->h_length);
    }
  }

  if (bind(listen_fd, (sockaddr *)&servaddr, sizeof(servaddr)) != 0) {
    printf("[BOARD_SOCKET] bind failed on %s:%d: %s\n",
           (bind_host == nullptr || bind_host[0] == '\0') ? "0.0.0.0" : bind_host,
           port,
           strerror(errno));
    fflush(stdout);
    close(listen_fd);
    return -1;
  }

  if (listen(listen_fd, 1) != 0) {
    printf("[BOARD_SOCKET] listen failed: %s\n", strerror(errno));
    fflush(stdout);
    close(listen_fd);
    return -1;
  }

  g_listen_sockfd = listen_fd;
  printf("[BOARD_SOCKET] listening on %s:%d\n",
         (bind_host == nullptr || bind_host[0] == '\0') ? "0.0.0.0" : bind_host,
         port);
  fflush(stdout);
  return 0;
}

extern "C" int board_socket_accept() {
  if (g_listen_sockfd == -1) {
    printf("[BOARD_SOCKET] accept rejected, listen socket is not active\n");
    fflush(stdout);
    return -1;
  }

  pollfd accept_event;
  accept_event.fd = g_listen_sockfd;
  accept_event.events = POLLIN;
  accept_event.revents = 0;

  while (true) {
    int event_ready = poll(&accept_event, 1, g_timeout_ms);
    if (event_ready <= 0) {
      continue;
    }

    if (accept_event.revents & (POLLERR | POLLHUP | POLLNVAL)) {
      printf("[BOARD_SOCKET] accept poll error/hup/nval (revents=0x%x)\n", accept_event.revents);
      fflush(stdout);
      return -1;
    }

    sockaddr_in peeraddr;
    socklen_t peeraddr_len = sizeof(peeraddr);
    int accepted_fd = accept(g_listen_sockfd, (sockaddr *)&peeraddr, &peeraddr_len);
    if (accepted_fd < 0) {
      if (errno == EINTR) {
        continue;
      }
      printf("[BOARD_SOCKET] accept failed: %s\n", strerror(errno));
      fflush(stdout);
      return -1;
    }

    if (g_board_sockfd != -1) {
      close(g_board_sockfd);
      g_board_sockfd = -1;
    }

    board_socket_assign_connected_socket(accepted_fd);
    printf("[BOARD_SOCKET] accepted connection from %s:%d\n",
           inet_ntoa(peeraddr.sin_addr),
           ntohs(peeraddr.sin_port));
    fflush(stdout);
    return 0;
  }
}

extern "C" void board_socket_set_timeout(int milliseconds) {
  g_timeout_ms = (milliseconds <= 0) ? 1 : milliseconds;
}

extern "C" int board_socket_send(const svOpenArrayHandle data_h, int len, int *sent) {
  const unsigned char *data = reinterpret_cast<const unsigned char *>(svGetArrayPtr(data_h));

  if (data == nullptr) {
    if (sent != nullptr) {
      *sent = 0;
    }
    printf("[BOARD_SOCKET] send rejected, payload buffer is unavailable\n");
    fflush(stdout);
    return -1;
  }

  if (sent != nullptr) {
    *sent = 0;
  }

  if (g_board_sockfd == -1) {
    printf("[BOARD_SOCKET] send rejected, socket is not connected\n");
    fflush(stdout);
    return -1;
  }

  int event_ready = poll(&g_send_event, 1, g_timeout_ms);
  if (event_ready <= 0) {
    return 0;
  }

  if (g_send_event.revents & (POLLERR | POLLHUP | POLLNVAL)) {
    printf("[BOARD_SOCKET] send poll error/hup/nval (revents=0x%x)\n", g_send_event.revents);
    fflush(stdout);
    board_socket_close_internal();
    return -1;
  }

  if (!(g_send_event.revents & POLLOUT)) {
    return 0;
  }

  int bytes_sent = send(g_board_sockfd, reinterpret_cast<const char *>(data), len, 0);
  if (bytes_sent < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
      return 0;
    }
    printf("[BOARD_SOCKET] send error: %s\n", strerror(errno));
    fflush(stdout);
    board_socket_close_internal();
    return -1;
  }

  if (sent != nullptr) {
    *sent = bytes_sent;
  }

  printf("[BOARD_SOCKET] sent len=%d payload_hex=", bytes_sent);
  for (int i = 0; i < bytes_sent; i++) {
    printf("%02x", data[i]);
  }
  if (bytes_sent > 256) {
    printf(" ...<truncated>");
  }
  printf("\n");
  fflush(stdout);

  return 1;
}

extern "C" int board_socket_try_recv(const svOpenArrayHandle data_h, int max_len, int *received) {
  unsigned char *data = reinterpret_cast<unsigned char *>(svGetArrayPtr(data_h));

  if (data == nullptr) {
    if (received != nullptr) {
      *received = 0;
    }
    printf("[BOARD_SOCKET] recv rejected, payload buffer is unavailable\n");
    fflush(stdout);
    return -1;
  }

  if (received != nullptr) {
    *received = 0;
  }

  if (g_board_sockfd == -1) {
    return -1;
  }

  int event_ready = poll(&g_recv_event, 1, g_timeout_ms);
  if (event_ready <= 0) {
    return 0;
  }

  if (g_recv_event.revents & (POLLERR | POLLHUP | POLLNVAL)) {
    printf("[BOARD_SOCKET] recv poll error/hup/nval (revents=0x%x)\n", g_recv_event.revents);
    fflush(stdout);
    board_socket_close_internal();
    return -1;
  }

  if (!(g_recv_event.revents & POLLIN)) {
    return 0;
  }

  int bytes_received = recv(g_board_sockfd, data, max_len, 0);
  if (bytes_received == 0) {
    printf("[BOARD_SOCKET] recv detected remote close\n");
    fflush(stdout);
    board_socket_close_internal();
    return -1;
  }

  if (bytes_received < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
      return 0;
    }
    printf("[BOARD_SOCKET] recv error: %s\n", strerror(errno));
    fflush(stdout);
    board_socket_close_internal();
    return -1;
  }

  if (bytes_received <= 0) {
    return 0;
  }

  if (received != nullptr) {
    *received = bytes_received;
  }

  g_last_recv_payload.assign(reinterpret_cast<const char *>(data), static_cast<size_t>(bytes_received));

  printf("[BOARD_SOCKET] recv len=%d payload_hex=", bytes_received);
  for (int i = 0; i < bytes_received; i++) {
    printf("%02x", data[i]);
  }
  if (bytes_received > 256) {
    printf(" ...<truncated>");
  }
  printf("\n");
  fflush(stdout);

  return 1;
}

extern "C" int board_socket_try_recv_match(const char *needle, int max_len, int *received, int *matched) {
  if (received != nullptr) {
    *received = 0;
  }
  if (matched != nullptr) {
    *matched = 0;
  }

  if (g_board_sockfd == -1) {
    return -1;
  }

  int event_ready = poll(&g_recv_event, 1, g_timeout_ms);
  if (event_ready <= 0) {
    return 0;
  }

  if (g_recv_event.revents & (POLLERR | POLLHUP | POLLNVAL)) {
    printf("[BOARD_SOCKET] recv poll error/hup/nval (revents=0x%x)\n", g_recv_event.revents);
    fflush(stdout);
    board_socket_close_internal();
    return -1;
  }

  if (!(g_recv_event.revents & POLLIN)) {
    return 0;
  }

  std::string recv_buf;
  recv_buf.resize(max_len);

  char *data = &recv_buf[0];
  int bytes_received = recv(g_board_sockfd, data, max_len, 0);
  if (bytes_received == 0) {
    printf("[BOARD_SOCKET] recv detected remote close\n");
    fflush(stdout);
    board_socket_close_internal();
    return -1;
  }

  if (bytes_received < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
      return 0;
    }
    printf("[BOARD_SOCKET] recv error: %s\n", strerror(errno));
    fflush(stdout);
    board_socket_close_internal();
    return -1;
  }

  if (bytes_received <= 0) {
    return 0;
  }

  if (received != nullptr) {
    *received = bytes_received;
  }

  std::string payload(data, bytes_received);
  g_last_recv_payload = payload;
  if (matched != nullptr && needle != nullptr && needle[0] != '\0') {
    std::string payload_fold = payload;
    std::string needle_fold = needle;
    std::transform(payload_fold.begin(), payload_fold.end(), payload_fold.begin(),
      [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    std::transform(needle_fold.begin(), needle_fold.end(), needle_fold.begin(),
      [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

    if (payload_fold.find(needle_fold) != std::string::npos) {
      *matched = 1;
    }
  }

  printf("[BOARD_SOCKET] recv len=%d payload='%.*s'%s\n",
         bytes_received,
         (bytes_received > 256) ? 256 : bytes_received,
         data,
         (bytes_received > 256) ? " ...<truncated>" : "");
  fflush(stdout);

  return 1;
}

extern "C" void board_socket_close() {
  board_socket_close_internal();
  printf("[BOARD_SOCKET] closed\n");
  fflush(stdout);
}
