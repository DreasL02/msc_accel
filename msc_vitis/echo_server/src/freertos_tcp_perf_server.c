/*
 * Copyright (C) 2018 - 2019 Xilinx, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
 * SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 */

#include "freertos_tcp_perf_server.h"
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>

extern struct netif server_netif;
static struct perf_stats server;

typedef struct server_message {
	size_t len;
	char data[];
} server_message_t;

typedef struct server_connection {
	int sock;
	QueueHandle_t out_msg_fifo;
	enum report_type final_report_type;
} server_connection_t;

/* Interval time in seconds */
#define REPORT_INTERVAL_TIME (INTERIM_REPORT_INTERVAL * 1000)
#define TCP_SERVER_OUT_MSG_FIFO_DEPTH 100

void print_app_header(void)
{
	xil_printf("TCP server listening on port %d\r\n",
			TCP_CONN_PORT);
#if LWIP_IPV6==1
	xil_printf("On Host: Run $iperf -V -c %s%%<interface> -i %d -t 300 -w 2M\r\n",
			inet6_ntoa(server_netif.ip6_addr[0]),
			INTERIM_REPORT_INTERVAL);
#else
	xil_printf("On Host: Run $iperf -c %s -i %d -t 300 -w 2M\r\n",
			inet_ntoa(server_netif.ip_addr),
			INTERIM_REPORT_INTERVAL);
#endif /* LWIP_IPV6 */
}

static void print_tcp_conn_stats(int sock)
{
#if LWIP_IPV6==1
	struct sockaddr_in6 local, remote;
#else
	struct sockaddr_in local, remote;
#endif /* LWIP_IPV6 */
	int size;

	size = sizeof(local);
	getsockname(sock, (struct sockaddr *)&local, (socklen_t *)&size);
	getpeername(sock, (struct sockaddr *)&remote, (socklen_t *)&size);
#if LWIP_IPV6==1
	xil_printf("[%3d] local %s port %d connected with ", server.client_id,
			inet6_ntoa(local.sin6_addr), ntohs(local.sin6_port));
	xil_printf("%s port %d\r\n", inet6_ntoa(remote.sin6_addr),
			ntohs(local.sin6_port));
#else
	xil_printf("[%3d] local %s port %d connected with ", server.client_id,
			inet_ntoa(local.sin_addr), ntohs(local.sin_port));
	xil_printf("%s port %d\r\n", inet_ntoa(remote.sin_addr),
			ntohs(local.sin_port));
#endif /* LWIP_IPV6 */
	xil_printf("[ ID] Interval    Recv Bytes    Sent Bytes    Rx Bandwidth   Tx Bandwidth\n\r");
}

static void stats_buffer(char* outString, double data, enum measure_t type)
{
	int conv = KCONV_UNIT;
	const char *format;
	double unit = 1024.0;

	if (type == SPEED)
		unit = 1000.0;

	while (data >= unit && conv <= KCONV_GIGA) {
		data /= unit;
		conv++;
	}

	/* Fit data in 4 places */
	if (data < 9.995) { /* 9.995 rounded to 10.0 */
		format = "%4.2f %c"; /* #.## */
	} else if (data < 99.95) { /* 99.95 rounded to 100 */
		format = "%4.1f %c"; /* ##.# */
	} else {
		format = "%4.0f %c"; /* #### */
	}
	sprintf(outString, format, data, kLabel[conv]);
}

static server_message_t *alloc_server_message(const char *data, size_t len)
{
	server_message_t *message;

	message = pvPortMalloc(sizeof(*message) + len);
	if (!message)
		return NULL;

	message->len = len;
	if (len)
		memcpy(message->data, data, len);

	return message;
}

static BaseType_t queue_server_message(QueueHandle_t fifo, const char *data,
					       size_t len, BaseType_t close_after_send)
{
	server_message_t *message;

	if (close_after_send) {
		message = NULL;
		if (xQueueSend(fifo, &message, portMAX_DELAY) != pdPASS)
			return pdFAIL;
		return pdPASS;
	}

	message = alloc_server_message(data, len);
	if (!message)
		return pdFAIL;

	if (xQueueSend(fifo, &message, portMAX_DELAY) != pdPASS) {
		vPortFree(message);
		return pdFAIL;
	}

	return pdPASS;
}

static BaseType_t queue_echo_chunk(server_connection_t *connection,
					   const char *data, size_t len)
{
	return queue_server_message(connection->out_msg_fifo, data, len, pdFALSE);
}

static void tcp_conn_report(u64_t diff, enum report_type report_type);

static void tcp_send_perf_traffic(void *p)
{
	server_connection_t *connection = (server_connection_t *)p;
	server_message_t *message;
	int sent_bytes;
	int total_sent;

	for (;;) {
		if (!connection->out_msg_fifo) {
			vTaskDelay(pdMS_TO_TICKS(10));
			continue;
		}

		if (xQueueReceive(connection->out_msg_fifo, &message, portMAX_DELAY) != pdPASS)
			continue;

		if (!message)
			break;

		total_sent = 0;
		while (total_sent < (int)message->len) {
			int to_send = (int)(message->len - total_sent);
			sent_bytes = lwip_send(connection->sock,
					message->data + total_sent,
					message->len - total_sent, 0);
			if (sent_bytes <= 0) {
				vPortFree(message);
				connection->final_report_type = TCP_ABORTED_REMOTE;
				tcp_conn_report(sys_now() - server.start_time, TCP_ABORTED_REMOTE);
				goto close_connection;
			}

			total_sent += sent_bytes;
			server.total_bytes_tx += (u64_t)sent_bytes;
			server.i_report.total_bytes_tx += (u64_t)sent_bytes;
		}

		vPortFree(message);
	}

	tcp_conn_report(sys_now() - server.start_time, connection->final_report_type);

close_connection:
	if (connection->out_msg_fifo) {
		vQueueDelete(connection->out_msg_fifo);
		connection->out_msg_fifo = NULL;
	}
	if (connection->sock >= 0)
		close(connection->sock);
	connection->sock = -1;
	vTaskDelete(NULL);
}

/* The report function of a TCP server session */
static void tcp_conn_report(u64_t diff, enum report_type report_type)
{
	u64_t total_len_rx;
	u64_t total_len_tx;
	double duration, bandwidth = 0;
	char data_rx[16], data_tx[16], perf[16], time[64];

	if (report_type == INTER_REPORT) {
		total_len_rx = server.i_report.total_bytes_rx;
		total_len_tx = server.i_report.total_bytes_tx;
	} else {
		server.i_report.last_report_time = 0;
		total_len_rx = server.total_bytes_rx;
		total_len_tx = server.total_bytes_tx;
	}

	/* Converting duration from milliseconds to secs,
	 * and bandwidth to bits/sec .
	 */
	duration = diff / 1000.0; /* secs */
	if (duration)
		bandwidth = (total_len_rx / duration) * 8.0;
	double tx_bandwidth = 0;
	if (duration)
		tx_bandwidth = (total_len_tx / duration) * 8.0;

	stats_buffer(data_rx, total_len_rx, BYTES);
	stats_buffer(data_tx, total_len_tx, BYTES);
	stats_buffer(perf, bandwidth, SPEED);
	{
		char perf_tx[16];
		stats_buffer(perf_tx, tx_bandwidth, SPEED);
		sprintf(time, "%4.1f-%4.1f sec",
			(double)server.i_report.last_report_time,
			(double)(server.i_report.last_report_time + duration));
		xil_printf("[%3d] %s  %sBytes  %sBytes  %sbits/sec  %sbits/sec\n\r", server.client_id,
				time, data_rx, data_tx, perf, perf_tx);
	}

	if (report_type == INTER_REPORT)
		server.i_report.last_report_time += duration;
}

/* thread spawned for each connection */
void tcp_recv_perf_traffic(void *p)
{
	char recv_buf[RECV_BUF_SIZE];
	int read_bytes;
	server_connection_t *connection = (server_connection_t *)p;
	int sock = connection->sock;

	server.start_time = sys_now();
	server.client_id++;
	server.i_report.last_report_time = 0;
	server.i_report.start_time = 0;
	server.i_report.total_bytes_rx = 0;
	server.i_report.total_bytes_tx = 0;
	server.total_bytes_rx = 0;
	server.total_bytes_tx = 0;

	print_tcp_conn_stats(sock);

	while (1) {
		/* read a max of RECV_BUF_SIZE bytes from socket */
		if ((read_bytes = lwip_recvfrom(sock, recv_buf, RECV_BUF_SIZE,
						0, NULL, NULL)) < 0) {
			connection->final_report_type = TCP_ABORTED_REMOTE;
			(void)queue_server_message(connection->out_msg_fifo, NULL, 0, pdTRUE);
			break;
		}

		/* break if client closed connection */
		if (read_bytes == 0) {
			connection->final_report_type = TCP_DONE_SERVER;
			(void)queue_server_message(connection->out_msg_fifo, NULL, 0, pdTRUE);
			xil_printf("TCP test passed Successfully\n\r");
			break;
		}

		if (queue_echo_chunk(connection, recv_buf, (size_t)read_bytes) != pdPASS) {
			connection->final_report_type = TCP_ABORTED_REMOTE;
			(void)queue_server_message(connection->out_msg_fifo, NULL, 0, pdTRUE);
			break;
		}

		/* Track received bytes; the send thread tracks transmitted bytes. */
		server.i_report.total_bytes_rx += (u64_t)read_bytes;
		server.total_bytes_rx += (u64_t)read_bytes;

		if (REPORT_INTERVAL_TIME) {
			u64_t now = sys_now();
			if (server.i_report.start_time) {
				u64_t diff_ms = now - server.i_report.start_time;

				if (diff_ms >= REPORT_INTERVAL_TIME) {
					tcp_conn_report(diff_ms, INTER_REPORT);
					server.i_report.start_time = 0;
					server.i_report.total_bytes_rx = 0;
					server.i_report.total_bytes_tx = 0;
				}
			} else {
				server.i_report.start_time = now;
			}
		}
	}
	vTaskDelete(NULL);
}

void start_application(void)
{
	int sock, new_sd;
	static server_connection_t connection;
#if LWIP_IPV6==1
	struct sockaddr_in6 address, remote;
#else
	struct sockaddr_in address, remote;
#endif /* LWIP_IPV6 */
	int size;
	BaseType_t spawn_failed;

	connection.sock = -1;
	connection.out_msg_fifo = NULL;
	connection.final_report_type = TCP_DONE_SERVER;

	/* set up address to connect to */
        memset(&address, 0, sizeof(address));
#if LWIP_IPV6==1
	if ((sock = lwip_socket(AF_INET6, SOCK_STREAM, 0)) < 0) {
		xil_printf("TCP server: Error creating Socket\r\n");
		return;
	}
	address.sin6_family = AF_INET6;
	address.sin6_port = htons(TCP_CONN_PORT);
	address.sin6_len = sizeof(address);
#else
	if ((sock = lwip_socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		xil_printf("TCP server: Error creating Socket\r\n");
		return;
	}
	address.sin_family = AF_INET;
	address.sin_port = htons(TCP_CONN_PORT);
	address.sin_addr.s_addr = INADDR_ANY;
#endif /* LWIP_IPV6 */

	if (bind(sock, (struct sockaddr *)&address, sizeof (address)) < 0) {
		xil_printf("TCP server: Unable to bind to port %d\r\n",
				TCP_CONN_PORT);
		close(sock);
		return;
	}

	if (listen(sock, 1) < 0) {
		xil_printf("TCP server: tcp_listen failed\r\n");
		close(sock);
		return;
	}

	size = sizeof(remote);

	while (1) {
		if ((new_sd = accept(sock, (struct sockaddr *)&remote,
						(socklen_t *)&size)) > 0)
		{
			if (connection.sock >= 0) {
				close(new_sd);
				continue;
			}

			connection.sock = new_sd;
			connection.out_msg_fifo = xQueueCreate(TCP_SERVER_OUT_MSG_FIFO_DEPTH,
					sizeof(server_message_t *));
			if (!connection.out_msg_fifo) {
				close(new_sd);
				connection.sock = -1;
				continue;
			}

			if (sys_thread_new("TCP_send_perf thread",
					tcp_send_perf_traffic, (void *)&connection,
					TCP_SERVER_THREAD_STACKSIZE,
					DEFAULT_THREAD_PRIO + 1) == NULL) {
				vQueueDelete(connection.out_msg_fifo);
				connection.out_msg_fifo = NULL;
				close(new_sd);
				connection.sock = -1;
				continue;
			}

			if (sys_thread_new("TCP_recv_perf thread",
					tcp_recv_perf_traffic, (void *)&connection,
					TCP_SERVER_THREAD_STACKSIZE,
					DEFAULT_THREAD_PRIO + 1) == NULL) {
				close(new_sd);
				(void)queue_server_message(connection.out_msg_fifo, NULL, 0, pdTRUE);
				connection.sock = -1;
				continue;
			}
		}
	}
}
