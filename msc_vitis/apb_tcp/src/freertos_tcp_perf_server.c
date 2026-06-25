/*
 * Copyright (C) 2018 - 2019 Xilinx, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
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
#include "semphr.h"
#include "xil_cache.h"
#include "xstatus.h"
#include "xparameters.h"
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>

#include "xscugic.h"
#include "xil_exception.h"

#include "debug_print.h"

#include "accel_dma.h"

#define DBG_HEARTBEAT 0

extern struct netif server_netif;
static struct perf_stats server;
// Loopback mode for testing without DMA offload, where the server just echoes back received data. 
// This can be used to test the TCP server functionality and measure overhead without involving the DMA and hardware acceleration parts. It can be enabled by defining TCP_LOOPBACK_MODE to 1.
#define TCP_LOOPBACK_MODE 0

/* labels for formats [KMG] */
const char kLabel[] =
{
	' ',
	'K',
	'M',
	'G'
};

/* Interval time in seconds */
#define REPORT_INTERVAL_TIME (INTERIM_REPORT_INTERVAL * 1000)

#define TCP_SERVER_IN_TRANSACTION_DEPTH 2500
#define TCP_SERVER_OUT_TRANSACTION_FIFO_DEPTH 2500
#define TCP_SERVER_OUT_MSG_FIFO_DEPTH 2500

typedef struct server_message {
	size_t len;
	char data[];
} server_message_t;

typedef struct server_connection {
	int sock;
	char rx_line_buf[2048];          // Buffer for accumulating received data until complete lines are formed
	size_t rx_line_fill;             // Amount of data currently in the rx_line_buf
	dma_server_connection_t dma_connection; // Connection to DMA (contains binary data FIFOs and buffers)
	QueueHandle_t out_msg_fifo;     // Queue of text messages (server_message_t *) to send to client
} server_connection_t;


BaseType_t init_server_connection(server_connection_t *connection)
{
	connection->sock = -1;
	connection->rx_line_fill = 0;
	memset(connection->rx_line_buf, 0, sizeof(connection->rx_line_buf));
	init_active_connection(&connection->dma_connection);
	
	connection->dma_connection.dma_in_fifo = xQueueCreate(TCP_SERVER_IN_TRANSACTION_DEPTH, sizeof(dma_transaction_t *));
	if (!connection->dma_connection.dma_in_fifo) goto cleanup;

	connection->dma_connection.dma_out_fifo = xQueueCreate(TCP_SERVER_OUT_TRANSACTION_FIFO_DEPTH, sizeof(dma_transaction_t *));
	if (!connection->dma_connection.dma_out_fifo) goto cleanup;
    
	connection->out_msg_fifo = xQueueCreate(TCP_SERVER_OUT_MSG_FIFO_DEPTH, sizeof(server_message_t *));
	if (!connection->out_msg_fifo) goto cleanup;
	
	if (dma_init() != XST_SUCCESS) goto cleanup;
	
	return pdPASS;

cleanup:
	// Clean up any allocated queues
	if (connection->dma_connection.dma_out_fifo) vQueueDelete(connection->dma_connection.dma_out_fifo);
	if (connection->dma_connection.dma_in_fifo) vQueueDelete(connection->dma_connection.dma_in_fifo);
	if (connection->out_msg_fifo) vQueueDelete(connection->out_msg_fifo);
	return pdFAIL;
}

void print_app_header(void)
{
	ordinary_print("TCP server listening on port %d\r\n",
			TCP_CONN_PORT);
}


static void print_received_data(const u8 *buf, size_t len)
{
	size_t i;

	debug_print("Printing data recieved: %u bytes\r\n", (unsigned)len);
	for (i = 0; i < len; ++i) {
		unsigned byte = (unsigned)buf[i];

		debug_print("%02X", byte);
		if (((i + 1) % 23) == 0)
			debug_print("\r\n");
		else
			debug_print(" ");
	}
	debug_print("\r\n");
}

static void tcp_send_server_traffic(void *p)
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
			debug_print("TCP send: requesting %d bytes (already sent %d)\r\n", to_send, total_sent);
			sent_bytes = lwip_send(connection->sock,
					message->data + total_sent,
					message->len - total_sent, 0);
			debug_print("TCP send: sent %d bytes\r\n", sent_bytes);
			if (sent_bytes > 0) {
				/* Dump the chunk that was just sent */
				print_received_data((const u8*)(message->data + total_sent), (size_t)sent_bytes);
				server.total_bytes_sent += sent_bytes;
				server.i_report.total_bytes_sent += sent_bytes;
			}
			if (sent_bytes <= 0) {
				debug_print("TCP send: lwip_send failed ret=%d errno=%d closing sock %d\r\n",
					sent_bytes, errno, connection->sock);
				vPortFree(message);
				goto close_connection;
			}
			total_sent += sent_bytes;
			server.total_bytes_sent += sent_bytes;
		}

		vPortFree(message);
	}

close_connection:
	ordinary_print("TCP send: closing connection sock %d\r\n", connection->sock);
	close(connection->sock);
	/* Note: DMA FIFOs and queues are cleaned up by close_dma_and_connection */
	vTaskDelete(NULL);
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

/* The report function of a TCP server session */
static void tcp_conn_report(u64_t diff, enum report_type report_type)
{
	u64_t total_len, total_sent;
	double duration, rx_bandwidth = 0, tx_bandwidth = 0;
	char data_rx[16], data_tx[16], perf_rx[16], perf_tx[16], time[64];

	if (report_type == INTER_REPORT) {
		total_len = server.i_report.total_bytes;
		total_sent = server.i_report.total_bytes_sent;
	} else {
		server.i_report.last_report_time = 0;
		total_len = server.total_bytes;
		total_sent = server.total_bytes_sent;
	}

	/* Converting duration from milliseconds to secs,
	 * and bandwidth to bits/sec .
	 */
	duration = diff / 1000.0; /* secs */
	if (duration) {
		rx_bandwidth = (total_len / duration) * 8.0;
		tx_bandwidth = (total_sent / duration) * 8.0;
	}

	stats_buffer(data_rx, total_len, BYTES);
	stats_buffer(data_tx, total_sent, BYTES);
	stats_buffer(perf_rx, rx_bandwidth, SPEED);
	stats_buffer(perf_tx, tx_bandwidth, SPEED);
	/* On 32-bit platforms, xil_printf is not able to print
	 * u64_t values, so converting these values in strings and
	 * displaying results
	 */
	sprintf(time, "%4.1f-%4.1f sec",
			(double)server.i_report.last_report_time,
			(double)(server.i_report.last_report_time + duration));
	ordinary_print("[%3d] %s  RX:%sBytes  TX:%sBytes  RX:%sbits/sec  TX:%sbits/sec\n\r", server.client_id,
			time, data_rx, data_tx, perf_rx, perf_tx);

	if (report_type == INTER_REPORT)
		server.i_report.last_report_time += duration;
}


static BaseType_t route_binary_frame(server_connection_t *connection, const u8 *frame_data, size_t frame_len)
{
	u8 frame_id;
	u8 frame_header;
	BaseType_t queue_ok;


	if (frame_len < 23) {
		xil_printf("TCP server: received malformed frame with len=%u, expected at least 23 bytes\r\n", (unsigned)frame_len);
		return pdPASS;  // Skip malformed frames silently
	}

	frame_id = frame_data[0];
	frame_header = frame_data[1];

	debug_print("TCP server: binary frame id=0x%02x header=0x%02x\r\n",
		(unsigned)frame_id, (unsigned)frame_header);

	// Pass the entire frame (23 bytes) as payload to DMA
	if (connection->dma_connection.dma_ready) {
		debug_print("TCP server: queuing binary frame to DMA len=%u\r\n", (unsigned)frame_len);
		queue_ok = queue_dma_transaction(connection->dma_connection.dma_in_fifo, frame_data, frame_len);
		return queue_ok;
	}

	ordinary_print("TCP server: DMA not ready, cannot queue frame len=%u\r\n", (unsigned)frame_len);
	return pdFAIL;
}

/* thread spawned for each connection */
void tcp_recv_perf_traffic(void *p)
{
	u8 recv_buf[RECV_BUF_SIZE];
	int read_bytes;
	server_connection_t *connection = (server_connection_t *)p;
	int sock = connection->sock;
	BaseType_t queue_ok;
	size_t frame_len;
	const size_t FRAME_SIZE = 23;  // Binary frame size: 1 id + 1 header + 21 payload bytes


	server.start_time = sys_now();
	server.client_id++;
	server.i_report.last_report_time = 0;
	server.i_report.start_time = 0;
	server.i_report.total_bytes = 0;
	server.i_report.total_bytes_sent = 0;
	server.total_bytes = 0;
	server.total_bytes_sent = 0;
	server.total_bytes_sent = 0;

	while (1) {
		/* read a max of RECV_BUF_SIZE bytes from socket (now binary) */
		debug_print("TCP recv: requesting up to %d bytes\r\n", RECV_BUF_SIZE);
		debug_print("TCP recv: rx_line_fill before recv = %zu\r\n", connection->rx_line_fill);
		if ((read_bytes = lwip_recvfrom(sock, (char *)recv_buf, RECV_BUF_SIZE,
						0, NULL, NULL)) < 0) { // error case (e.g. remote side aborted)
			/* Log error details to help determine if remote closed or recv failed */
			debug_print("TCP recv: lwip_recvfrom error ret=%d errno=%d\r\n", read_bytes, errno);
			u64_t now = sys_now();
			u64_t diff_ms = now - server.start_time;
			tcp_conn_report(diff_ms, TCP_ABORTED_REMOTE);
			close_dma_and_connection(&connection->dma_connection);
			break;
		}

		if (read_bytes == 0) { // connection closed
			ordinary_print("TCP recv: lwip_recvfrom returned 0 (peer closed)\r\n");
			u64_t now = sys_now();
			u64_t diff_ms = now - server.start_time;
			tcp_conn_report(diff_ms, TCP_DONE_SERVER);
			ordinary_print("TCP server session closed successfully\n\r");
			close_dma_and_connection(&connection->dma_connection);
			break;
		}

		debug_print("TCP recv: received %d bytes, rx_line_fill after recv = %u\r\n", (unsigned)read_bytes, (unsigned)connection->rx_line_fill);

		/* Log received data (length + hex dump, truncated) for debugging */
		print_received_data((const u8*)recv_buf, (size_t)read_bytes);

		if ((connection->rx_line_fill + (size_t)read_bytes) >= sizeof(connection->rx_line_buf)) {
			size_t max_len = sizeof(connection->rx_line_buf);
			xil_printf("TCP recv: buffer overflow risk! incoming data (%u bytes) + existing buffer fill (%u bytes) exceeds buffer size (%u bytes). Discarding received data to prevent overflow.\r\n",
				(unsigned)read_bytes, (unsigned)connection->rx_line_fill, (unsigned)max_len);
			connection->rx_line_fill = 0;
			continue;
		}

		// Append received binary data to buffer
		memcpy(&connection->rx_line_buf[connection->rx_line_fill], recv_buf, (size_t)read_bytes);
		connection->rx_line_fill += (size_t)read_bytes;
		debug_print("TCP recv: rx_line_fill after append = %u\r\n", (unsigned)connection->rx_line_fill);

		// Process complete 23-byte binary frames in the buffer
		while (connection->rx_line_fill >= FRAME_SIZE) {
			const u8 *frame_data = (const u8 *)connection->rx_line_buf;
			frame_len = FRAME_SIZE;

#if TCP_LOOPBACK_MODE
			xil_printf("TCP loopback mode: echoing back received frame of len=%u bytes\r\n", (unsigned)frame_len);
			// Echo the frame back to the client
			server_message_t *message = pvPortMalloc(sizeof(server_message_t) + frame_len);
			if (message) {
				message->len = frame_len;
				memcpy(message->data, frame_data, frame_len);
				if (xQueueSend(connection->out_msg_fifo, &message, portMAX_DELAY) != pdPASS) {
					vPortFree(message);
				}
			}
#else
			// Route the binary frame to DMA
			queue_ok = route_binary_frame(connection, frame_data, frame_len);
			if (queue_ok != pdPASS) {
				xil_printf("TCP recv: failed to queue binary frame to DMA, closing connection\r\n");
				u64_t now = sys_now();
				u64_t diff_ms = now - server.start_time;
				tcp_conn_report(diff_ms, TCP_ABORTED_REMOTE);
				close_dma_and_connection(&connection->dma_connection);
				vTaskDelete(NULL);
			}
#endif

			// Shift buffer: remove processed frame
			memmove(connection->rx_line_buf, &connection->rx_line_buf[FRAME_SIZE], 
					connection->rx_line_fill - FRAME_SIZE);
			connection->rx_line_fill -= FRAME_SIZE;
		}

		if (REPORT_INTERVAL_TIME) {
			u64_t now = sys_now();
			server.i_report.total_bytes += read_bytes;
			if (server.i_report.start_time) {
				u64_t diff_ms = now - server.i_report.start_time;

				if (diff_ms >= REPORT_INTERVAL_TIME) {
					tcp_conn_report(diff_ms, INTER_REPORT);
					server.i_report.start_time = 0;
					server.i_report.total_bytes = 0;
					server.i_report.total_bytes_sent = 0;
				}
			} else {
				server.i_report.start_time = now;
			}
		}
		/* Record total bytes for final report */
		server.total_bytes += read_bytes;
	}

	vTaskDelete(NULL);
}

/* Task: process DMA frames and send wire bytes directly */
static void dma_frame_processor(void *p)
{
	server_connection_t *connection = (server_connection_t *)p;
	dma_transaction_t *frame;
	server_message_t *message;

	for (;;) {
		// If the connection or DMA out FIFO is not ready, wait and retry. 
		// This can happen at the start of the connection before everything is initialized, 
		// or if the connection is lost and we're in the process of cleaning up resources.
		if (!connection || !connection->dma_connection.dma_out_fifo) {
			vTaskDelay(pdMS_TO_TICKS(10));
			ordinary_print("DMA frame processor: waiting for connection and DMA out FIFO to be ready\r\n");
			continue;
		}

		if (xQueueReceive(connection->dma_connection.dma_out_fifo, &frame, portMAX_DELAY) != pdPASS)
			continue;

		if (!frame) {
			debug_print("DMA frame processor: NULL frame received, shutting down\r\n");
			break;
		}

		message = pvPortMalloc(sizeof(*message) + frame->len);
		if (message) {
			message->len = frame->len;
			for (size_t i = 0; i < frame->len; ++i) {
				message->data[i] = frame->data[frame->len - 1 - i];
			}
			if (xQueueSend(connection->out_msg_fifo, &message, portMAX_DELAY) != pdPASS) {
				vPortFree(message);
			}
		}
		vPortFree(frame);
	}

	vTaskDelete(NULL);
}

void start_application(void)
{
	int sock, new_sd;
	server_connection_t *connection;
#if LWIP_IPV6==1
	struct sockaddr_in6 address, remote;
#else
	struct sockaddr_in address, remote;
#endif /* LWIP_IPV6 */
	int size;

	/* set up address to connect to */
        memset(&address, 0, sizeof(address));
#if LWIP_IPV6==1
	if ((sock = lwip_socket(AF_INET6, SOCK_STREAM, 0)) < 0) {
		ordinary_print("TCP server: Error creating Socket\r\n");
		return;
	}
	address.sin6_family = AF_INET6;
	address.sin6_port = htons(TCP_CONN_PORT);
	address.sin6_len = sizeof(address);
#else
	if ((sock = lwip_socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		ordinary_print("TCP server: Error creating Socket\r\n");
		return;
	}
	address.sin_family = AF_INET;
	address.sin_port = htons(TCP_CONN_PORT);
	address.sin_addr.s_addr = INADDR_ANY;
#endif /* LWIP_IPV6 */

	if (bind(sock, (struct sockaddr *)&address, sizeof (address)) < 0) {
		ordinary_print("TCP server: Unable to bind to port %d\r\n",
				TCP_CONN_PORT);
		close(sock);
		return;
	}

	if (listen(sock, 1) < 0) {
		ordinary_print("TCP server: tcp_listen failed\r\n");
		close(sock);
		return;
	}

	if (lwip_fcntl(sock, F_SETFL, O_NONBLOCK) < 0) {
		ordinary_print("TCP server: failed to set listen socket nonblocking\r\n");
		close(sock);
		return;
	}

	// initialize active dma connection:
	connection = pvPortMalloc(sizeof(server_connection_t));
	if (!connection) {
		ordinary_print("TCP server: failed to allocate memory for connection\r\n");
		close(sock);
		return;
	}

	if (init_server_connection(connection) != pdPASS) {
		ordinary_print("TCP server: failed to initialize server connection\r\n");
		vPortFree(connection);
		close(sock);
		return;
	}
	
	if (!connection->dma_connection.dma_ready) {
		ordinary_print("TCP server: failed to initialize DMA\r\n");
		vPortFree(connection);
		close(sock);
		return;
	}

	ordinary_print("TCP server: Beyond the DMA, waiting for connections...\r\n");

	size = sizeof(remote);

	while (1) {
		size = sizeof(remote);
		new_sd = accept(sock, (struct sockaddr *)&remote,
					(socklen_t *)&size);
		#if DBG_HEARTBEAT
		ordinary_print("TCP server: accept returned %d\r\n", new_sd);
		#endif
		if (new_sd >= 0) {
			ordinary_print("TCP server: accepting socket %d (before %d)\r\n", new_sd, connection->sock);
			connection->sock = new_sd;

			// Spawn threads for this connection. If any spawn fails, cleanly shutdown the new connection.
			BaseType_t spawn_failed = pdFALSE;

#if TCP_LOOPBACK_MODE
			ordinary_print("TCP server: TCP_LOOPBACK_MODE enabled, skipping DMA and monitor threads\r\n");
#else
			if (sys_thread_new("TCP_dma_write thread",
				dma_write_traffic, (void *)connection,
				TCP_SERVER_THREAD_STACKSIZE,
				DEFAULT_THREAD_PRIO) == NULL) {
				ordinary_print("TCP server: failed to create DMA write thread\r\n");
				spawn_failed = pdTRUE;
			} else {
				ordinary_print("TCP server: DMA write thread created\r\n");
			}

			if (sys_thread_new("TCP_dma_read thread",
				dma_read_traffic, (void *)connection,
				TCP_SERVER_THREAD_STACKSIZE,
				DEFAULT_THREAD_PRIO) == NULL) {
				ordinary_print("TCP server: failed to create DMA read thread\r\n");
				spawn_failed = pdTRUE;
			} else {
				ordinary_print("TCP server: DMA read thread created\r\n");
			}

			if (sys_thread_new("TCP_dma_frame_proc",
				dma_frame_processor, (void *)connection,
				TCP_SERVER_THREAD_STACKSIZE,
				DEFAULT_THREAD_PRIO) == NULL) {
				ordinary_print("TCP server: failed to create DMA frame processor thread\r\n");
				spawn_failed = pdTRUE;
			} else {
				ordinary_print("TCP server: DMA frame processor thread created\r\n");
			}
#endif /* TCP_LOOPBACK_MODE */

			if (sys_thread_new("TCP_send_server thread",
				tcp_send_server_traffic, (void *)connection,
				TCP_SERVER_THREAD_STACKSIZE,
				DEFAULT_THREAD_PRIO+3) == NULL) {
				xil_printf("TCP server: failed to create TCP send server thread\r\n");
				spawn_failed = pdTRUE;
			} else {
				ordinary_print("TCP server: TCP_send_server thread created\r\n");
			}

			if (sys_thread_new("TCP_recv_perf thread",
				tcp_recv_perf_traffic, (void *)connection,
				TCP_SERVER_THREAD_STACKSIZE,
				DEFAULT_THREAD_PRIO+3) == NULL) {
				xil_printf("TCP server: failed to create TCP receive performance thread\r\n");
				spawn_failed = pdTRUE;
			} else {
				ordinary_print("TCP server: TCP_recv_perf thread created\r\n");
			}

			if (spawn_failed) {
				xil_printf("TCP server: spawn failure, shutting down connection %d\r\n", new_sd);
				/* signal DMA tasks to shutdown */
				close_dma_and_connection(&connection->dma_connection);
				close(new_sd);
				continue;
			}
			continue;
		} else {
			if ((errno == EWOULDBLOCK) || (errno == EAGAIN) || (errno == 0)) {
				#if DBG_HEARTBEAT
				ordinary_print("TCP server heartbeat: waiting for incoming connections\r\n");
				#endif
				vTaskDelay(pdMS_TO_TICKS(1000));
				continue;
			}
			ordinary_print("TCP server: accept failed errno=%d\r\n", errno);
			vTaskDelay(pdMS_TO_TICKS(1000));
		}
	}
}
