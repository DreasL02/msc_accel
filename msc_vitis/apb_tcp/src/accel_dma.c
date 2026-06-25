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
 */


#include "accel_dma.h"

#include "debug_print.h"

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "xil_cache.h"
#include "xstatus.h"
#include "xparameters.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xaxidma.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>

#define DMA_SERVER_AXI_DMA_DEVICE_ID XPAR_AXIDMA_0_DEVICE_ID

extern XScuGic xInterruptController;

static XAxiDma g_axi_dma;
static SemaphoreHandle_t g_dma_mm2s_lock;
static SemaphoreHandle_t g_dma_s2mm_lock;
static SemaphoreHandle_t g_dma_mm2s_sem;
static SemaphoreHandle_t g_dma_s2mm_sem;

static dma_server_connection_t *g_active_connection;

void init_active_connection(dma_server_connection_t *connection)
{
	g_active_connection = connection;
}

static void drain_binary_semaphore(SemaphoreHandle_t sem)
{
	/* Drain any posted binary semaphore but yield to other tasks
	 * to avoid tight busy-waiting that starves the scheduler. */
	while (xSemaphoreTake(sem, 0) == pdTRUE) {
		taskYIELD();
	}
}

static dma_transaction_t *alloc_dma_transaction(const u8 *data, size_t len)
{
	dma_transaction_t *transaction;

	transaction = pvPortMalloc(sizeof(*transaction) + len);
	if (!transaction)
		return NULL;

	transaction->len = len;
	if (len > 0)
		memcpy(transaction->data, data, len);

	return transaction;
}

BaseType_t queue_dma_transaction(QueueHandle_t fifo, const u8 *data, size_t len)
{
	dma_transaction_t *transaction;

	transaction = alloc_dma_transaction(data, len);
	if (!transaction)
		return pdFAIL;

	debug_print("DMA ENQUEUER: allocated dma_transaction len=%u\r\n", (unsigned)len);

	if (xQueueSend(fifo, &transaction, portMAX_DELAY) != pdPASS) {
		vPortFree(transaction);
		return pdFAIL;
	}

	return pdPASS;
}

static void cleanup_dma_resources(void)
{
	if (g_dma_mm2s_lock) {
		vSemaphoreDelete(g_dma_mm2s_lock);
		g_dma_mm2s_lock = NULL;
	}
	if (g_dma_s2mm_lock) {
		vSemaphoreDelete(g_dma_s2mm_lock);
		g_dma_s2mm_lock = NULL;
	}
	if (g_dma_mm2s_sem) {
		vSemaphoreDelete(g_dma_mm2s_sem);
		g_dma_mm2s_sem = NULL;
	}
	if (g_dma_s2mm_sem) {
		vSemaphoreDelete(g_dma_s2mm_sem);
		g_dma_s2mm_sem = NULL;
	}
}

static void axi_dma_tx_intr_handler(void *callback)
{
	u32 irq_status;
	BaseType_t xHigherPriorityTaskWoken = pdFALSE;

	irq_status = XAxiDma_IntrGetIrq(&g_axi_dma, XAXIDMA_DMA_TO_DEVICE);
	XAxiDma_IntrAckIrq(&g_axi_dma, irq_status, XAXIDMA_DMA_TO_DEVICE);
	XAxiDma_IntrDisable(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

	xSemaphoreGiveFromISR(g_dma_mm2s_sem, &xHigherPriorityTaskWoken);
	portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void axi_dma_rx_intr_handler(void *callback)
{
	u32 irq_status;
	BaseType_t xHigherPriorityTaskWoken = pdFALSE;

	irq_status = XAxiDma_IntrGetIrq(&g_axi_dma, XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrAckIrq(&g_axi_dma, irq_status, XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrDisable(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

	xSemaphoreGiveFromISR(g_dma_s2mm_sem, &xHigherPriorityTaskWoken);
	portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static BaseType_t start_mm2s_transfer(size_t transfer_len)
{
	if (transfer_len == 0)
		return pdPASS;

	if (transfer_len > sizeof(g_active_connection->dma_tx_buf)) {
		debug_print("DMA: MM2S batch too large len=%u\r\n", (unsigned)transfer_len);
		return pdFAIL;
	}

	Xil_DCacheFlushRange((UINTPTR)g_active_connection->dma_tx_buf, transfer_len);
	drain_binary_semaphore(g_dma_mm2s_sem);
	XAxiDma_IntrDisable(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
	XAxiDma_IntrAckIrq(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
	XAxiDma_IntrEnable(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
	if (XAxiDma_SimpleTransfer(&g_axi_dma,
			(UINTPTR)g_active_connection->dma_tx_buf,
			transfer_len,
			XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) {
		debug_print("DMA: failed to start MM2S transfer\r\n");
		return pdFAIL;
	}

	debug_print("DMA: MM2S transfer started, waiting for IRQ (len=%u)\r\n", (unsigned)transfer_len);
	if (xSemaphoreTake(g_dma_mm2s_sem,
			pdMS_TO_TICKS(DMA_IRQ_TIMEOUT_MS)) == pdTRUE) {
		debug_print("DMA: MM2S IRQ received\r\n");
	} else {
		debug_print("DMA: MM2S DMA interrupt timeout\r\n");
		XAxiDma_IntrDisable(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
	}
	debug_print("DMA: MM2S transfer complete\r\n");

	return pdPASS;
}



BaseType_t dma_init(void)
{
	XAxiDma_Config *dma_cfg;
	int status;

	ordinary_print("DMA: entering DMA init\r\n");

	if (!g_active_connection) {
		ordinary_print("DMA: no active connection\r\n");
		return XST_FAILURE;
	}

	if (g_active_connection->dma_ready) {
		return XST_SUCCESS;
	}

	dma_cfg = XAxiDma_LookupConfig(DMA_SERVER_AXI_DMA_DEVICE_ID);
	if (!dma_cfg) {
		ordinary_print("DMA: DMA config lookup failed\r\n");
		return XST_FAILURE;
	}

	status = XAxiDma_CfgInitialize(&g_axi_dma, dma_cfg);
	if (status != XST_SUCCESS) {
		ordinary_print("DMA: DMA cfg init failed %d\r\n", status);
		return status;
	}

	if (XAxiDma_HasSg(&g_axi_dma)) {
		ordinary_print("DMA: DMA is SG mode, expected simple mode\r\n");
		return XST_FAILURE;
	}

	g_dma_mm2s_lock = xSemaphoreCreateMutex();
	g_dma_s2mm_lock = xSemaphoreCreateMutex();
	if (!g_dma_mm2s_lock || !g_dma_s2mm_lock) {
		cleanup_dma_resources();
		return XST_FAILURE;
	}

	g_dma_mm2s_sem = xSemaphoreCreateBinary();
	g_dma_s2mm_sem = xSemaphoreCreateBinary();
	if (!g_dma_mm2s_sem || !g_dma_s2mm_sem) {
		ordinary_print("DMA: failed to create DMA semaphores\r\n");
		cleanup_dma_resources();
		return XST_FAILURE;
	}

#ifdef XPAR_FABRIC_AXIDMA_0_MM2S_INTROUT_VEC_ID
	XScuGic_SetPriorityTriggerType(&xInterruptController, XPAR_FABRIC_AXIDMA_0_MM2S_INTROUT_VEC_ID, 0xA0, 0x3);
	status = XScuGic_Connect(&xInterruptController, XPAR_FABRIC_AXIDMA_0_MM2S_INTROUT_VEC_ID,
				(Xil_ExceptionHandler)axi_dma_tx_intr_handler, &g_axi_dma);
	if (status != XST_SUCCESS) {
		ordinary_print("DMA: MM2S IRQ connect failed %d\r\n", status);
		cleanup_dma_resources();
		return XST_FAILURE;
	}
	XScuGic_Enable(&xInterruptController, XPAR_FABRIC_AXIDMA_0_MM2S_INTROUT_VEC_ID);
#else
	ordinary_print("DMA: MM2S IRQ vector macro missing\r\n");
	cleanup_dma_resources();
	return XST_FAILURE;
#endif

#ifdef XPAR_FABRIC_AXIDMA_0_S2MM_INTROUT_VEC_ID
	XScuGic_SetPriorityTriggerType(&xInterruptController, XPAR_FABRIC_AXIDMA_0_S2MM_INTROUT_VEC_ID, 0xA0, 0x3);
	status = XScuGic_Connect(&xInterruptController, XPAR_FABRIC_AXIDMA_0_S2MM_INTROUT_VEC_ID,
				(Xil_ExceptionHandler)axi_dma_rx_intr_handler, &g_axi_dma);
	if (status != XST_SUCCESS) {
		ordinary_print("DMA: S2MM IRQ connect failed %d\r\n", status);
		cleanup_dma_resources();
		return XST_FAILURE;
	}
	XScuGic_Enable(&xInterruptController, XPAR_FABRIC_AXIDMA_0_S2MM_INTROUT_VEC_ID);
#else
	ordinary_print("DMA: S2MM IRQ vector macro missing\r\n");
	cleanup_dma_resources();
	return XST_FAILURE;
#endif
	ordinary_print("DMA: DMA interrupt init complete\r\n");
	g_active_connection->dma_ready = pdTRUE;
	return XST_SUCCESS;
}

void close_dma_and_connection(dma_server_connection_t *connection)
{
	dma_server_connection_t *conn = connection ? connection : g_active_connection;

	if (!conn) {
		ordinary_print("DMA: no active connection\r\n");
		return;
	}

	if (conn->dma_ready) {
		if (conn->dma_in_fifo) {
			struct dma_transaction *null_req = NULL;
			xQueueSend(conn->dma_in_fifo, &null_req, portMAX_DELAY);
		}
	} else {
		ordinary_print("DMA: connection not DMA-ready, skipping DMA shutdown\r\n");
	}

	conn->closing = pdTRUE;

	/* If this was the global active connection, clear the global pointer
	 * to avoid accidental further use. The connection object itself is
	 * owned by the caller. */
	if (conn == g_active_connection) {
		g_active_connection = NULL;
	}
}

void dma_write_traffic(void *p)
{
	struct dma_transaction *request;
	size_t pending_bytes = 0;
	size_t pending_chunks = 0;
	BaseType_t batch_ok;
	BaseType_t saw_close = pdFALSE;

	debug_print("DMA: DMA write task started\r\n");

	for (;;) {
		if (xQueueReceive(g_active_connection->dma_in_fifo, &request, portMAX_DELAY) != pdPASS)
			continue;

		if (!request) {
			// request is null, which is a signal to close the connection and stop the task
			saw_close = pdTRUE;
		} else {
			debug_print("DMA: write dequeued request %p len=%u\r\n", request, (unsigned)request->len);

			if (request->len > sizeof(g_active_connection->dma_tx_buf)) {
				ordinary_print("DMA: request too large len=%u\r\n", (unsigned)request->len);
				vPortFree(request);
				continue;
			}

			if (pending_bytes + request->len > sizeof(g_active_connection->dma_tx_buf)) {
				if (pending_bytes > 0) {
					// print a debug message about the batch that is about to be sent
					debug_print("DMA: starting MM2S transfer due to batch full with pending_bytes=%u pending_chunks=%u request_len=%u\r\n", (unsigned)pending_bytes, (unsigned)pending_chunks, (unsigned)request->len);
					for (size_t i = 0; i < pending_bytes; ++i) {
						debug_print("%02X ", g_active_connection->dma_tx_buf[i]);
						if (((i + 1) % request->len) == 0)
							debug_print("\r\n");
					}
					debug_print("\r\n");
					if (xSemaphoreTake(g_dma_mm2s_lock, portMAX_DELAY) != pdTRUE) {
						vPortFree(request);
						continue;
					}
					batch_ok = start_mm2s_transfer(pending_bytes);
					xSemaphoreGive(g_dma_mm2s_lock);
					pending_bytes = 0;
					pending_chunks = 0;
					g_active_connection->chunk_fill = 0;
					if (batch_ok != pdPASS) {
						vPortFree(request);
						continue;
					}
				}
			}

			/* Copy request data into DMA TX buffer.
			 * Allow configurable reversal to handle downstream byte-order mismatches.
			 */
			for (size_t i = 0; i < request->len; ++i) {
				g_active_connection->dma_tx_buf[pending_bytes + i] = request->data[request->len - 1 - i];
			}

			pending_bytes += request->len;
			pending_chunks++;
			g_active_connection->chunk_fill = pending_bytes;
			vPortFree(request);
			debug_print("DMA: write request added to batch with pending_bytes=%u pending_chunks=%u\r\n", (unsigned)pending_bytes, (unsigned)pending_chunks);
			while (pending_chunks < DMA_TRANSACTIONS_IN) {
				if (xQueueReceive(g_active_connection->dma_in_fifo, &request, 0) != pdPASS) {
					debug_print("DMA: no more pending DMA requests in queue\r\n");
					break;
				}

				if (!request) {
					saw_close = pdTRUE;
					break;
				}

				debug_print("DMA: batching DMA request %p len=%u\r\n", request, (unsigned)request->len);

				if (request->len > sizeof(g_active_connection->dma_tx_buf)) {
					ordinary_print("DMA: request too large len=%u\r\n", (unsigned)request->len);
					vPortFree(request);
					continue;
				}

				if ((pending_bytes + request->len) > sizeof(g_active_connection->dma_tx_buf)) {
					vPortFree(request);
					debug_print("DMA: batch full, cannot add request to batch, sending batch for transfer\r\n");
					break;
				}

				debug_print("DMA: adding request to batch, pending_bytes=%u pending_chunks=%u\r\n", (unsigned)pending_bytes, (unsigned)pending_chunks);
				// Copy request data into DMA TX buffer with reversal
				for (size_t i = 0; i < request->len; ++i) {
					g_active_connection->dma_tx_buf[pending_bytes + i] = request->data[request->len - 1 - i];
				}
	
				pending_bytes += request->len;
				pending_chunks++;
				g_active_connection->chunk_fill = pending_bytes;
				vPortFree(request);
			}
		}

		if (pending_bytes == 0) {
			if (saw_close) {
				g_active_connection->closing = pdTRUE;
				ordinary_print("DMA: write received close signal\r\n");
				break;
			}
			continue;
		}

		debug_print("DMA: starting MM2S transfer due to batch ready with pending_bytes=%u pending_chunks=%u\r\n", (unsigned)pending_bytes, (unsigned)pending_chunks);
		for (size_t i = 0; i < pending_bytes; ++i) {
			debug_print("%02X ", g_active_connection->dma_tx_buf[i]);
			if (((i + 1) % 16) == 0)
				debug_print("\r\n");
		}
		debug_print("\r\n");
		if (xSemaphoreTake(g_dma_mm2s_lock, portMAX_DELAY) != pdTRUE) {
			pending_bytes = 0;
			pending_chunks = 0;
			g_active_connection->chunk_fill = 0;
			continue;
		}

		batch_ok = start_mm2s_transfer(pending_bytes);
		xSemaphoreGive(g_dma_mm2s_lock);
		pending_bytes = 0;
		pending_chunks = 0;
		g_active_connection->chunk_fill = 0;

		if (batch_ok != pdPASS) {
			ordinary_print("DMA: failed to start MM2S transfer for DMA write batch\r\n");
			continue;
		}
		if (saw_close) {
			g_active_connection->closing = pdTRUE;
			ordinary_print("DMA: DMA write received close signal\r\n");
			break;
		}
	}
	vTaskDelete(NULL);
}

void dma_read_traffic(void *p)
{
	const size_t frame_size = 23;
	// only the first frame_size bytes of the DMA buffer are guaranteed to be valid data, so stop processing frames once we reach that offset
	
	dma_server_connection_t *conn = g_active_connection;
	const size_t buf_capacity = sizeof(conn->dma_rx_buf);

	debug_print("DMA: DMA read task started\r\n");

	for (;;) {
		if (!conn) {
			vTaskDelay(pdMS_TO_TICKS(10));
			continue;
		}
		if (conn->closing)
			break;


		if (xSemaphoreTake(g_dma_s2mm_lock, portMAX_DELAY) != pdTRUE) {
			vTaskDelay(pdMS_TO_TICKS(10));
			continue;
		}

		drain_binary_semaphore(g_dma_s2mm_sem);
		XAxiDma_IntrDisable(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
		XAxiDma_IntrAckIrq(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
		XAxiDma_IntrEnable(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
		memset(conn->dma_rx_buf, 0, buf_capacity);
		Xil_DCacheInvalidateRange((UINTPTR)conn->dma_rx_buf, buf_capacity);
		if (XAxiDma_SimpleTransfer(&g_axi_dma,
				(UINTPTR)conn->dma_rx_buf,
				buf_capacity,
				XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
			xSemaphoreGive(g_dma_s2mm_lock);
			ordinary_print("DMA: failed to start S2MM transfer\r\n");
			vTaskDelay(pdMS_TO_TICKS(10));
			continue;
		}

		debug_print("DMA: S2MM transfer started, waiting for IRQ\r\n");
		if (xSemaphoreTake(g_dma_s2mm_sem,
				pdMS_TO_TICKS(DMA_IRQ_TIMEOUT_MS)) != pdTRUE) {
			ordinary_print("DMA: S2MM DMA interrupt timeout\r\n");
			XAxiDma_IntrDisable(&g_axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
			xSemaphoreGive(g_dma_s2mm_lock);
			ordinary_print("DMA: failed to receive S2MM IRQ, aborting read\r\n");
			vTaskDelay(pdMS_TO_TICKS(10));
			continue;
		}

		Xil_DCacheInvalidateRange((UINTPTR)conn->dma_rx_buf, buf_capacity);
		xSemaphoreGive(g_dma_s2mm_lock);

		debug_print("DMA: S2MM transfer of size %u complete, processing it into %u byte frames, here is full buffer:\r\n", (unsigned)buf_capacity, (unsigned)frame_size);
		for (size_t i = 0; i < buf_capacity; ++i) {
			debug_print("%02X ", conn->dma_rx_buf[i]);
			if (((i + 1) % frame_size) == 0)
				debug_print("\r\n");
		}
		debug_print("\r\n");
		for (size_t offset = 0; offset + frame_size <= buf_capacity; offset += frame_size) {
			if (conn->closing)
				break;
			
			// Is not valid if the total frame is zeroes
			int non_zero = 0;
			for (size_t i = 0; i < frame_size; ++i) {
				if (conn->dma_rx_buf[offset + i] != 0) {
					non_zero = 1;
					break;
				}
			}
			if (!non_zero) {
				debug_print("DMA: skipping DMA frame at offset %u, all values are zero\r\n", (unsigned)offset);
				continue;
			}
			debug_print("DMA: processing DMA frame at offset %u\r\n", (unsigned)offset);

			/* Allocate a dma_transaction for the frame and enqueue it to the dma_out_fifo for processing by the monitor line builder task. The monitor line builder is responsible for freeing the transaction after processing. */
			if (queue_dma_transaction(conn->dma_out_fifo, &conn->dma_rx_buf[offset], frame_size) != pdPASS) {
				ordinary_print("DMA: failed to queue DMA read transaction\r\n");
				break;
			}			
		}

		debug_print("DMA: read processing complete\r\n");
		taskYIELD();
	}
	ordinary_print("DMA: read task exiting due to connection closing\r\n");
	vTaskDelete(NULL);
}
