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

#ifndef FREERTOS_TCP_PERF_DMA_H
#define FREERTOS_TCP_PERF_DMA_H

#include "FreeRTOS.h"
#include <stddef.h>
#include <stdint.h>
#include "queue.h"
#include "semphr.h"
#include "xil_types.h"

#define TRANSACTION_SIZE 23 

#define DMA_TRANSACTIONS_IN 100
#define DMA_TX_BUF_SIZE (TRANSACTION_SIZE * DMA_TRANSACTIONS_IN)
#define DMA_TRANSACTIONS_OUT 40 // corresponds to the depth of the offloader
#define DMA_RX_BUF_SIZE (TRANSACTION_SIZE * DMA_TRANSACTIONS_OUT)

#define DMA_IRQ_TIMEOUT_MS 50000U

typedef struct dma_server_connection {
	QueueHandle_t dma_out_fifo;
	QueueHandle_t dma_in_fifo;
	u8 dma_tx_buf[DMA_TX_BUF_SIZE] __attribute__((aligned(64)));
	u8 dma_rx_buf[DMA_RX_BUF_SIZE] __attribute__((aligned(64)));
	size_t chunk_fill;
	BaseType_t dma_ready;
	volatile BaseType_t closing;
} dma_server_connection_t;

typedef struct dma_transaction {
	size_t len;
	u8 data[1];
} dma_transaction_t;
	

void init_active_connection(dma_server_connection_t *connection);
BaseType_t dma_init(void);
void dma_write_traffic(void *p);
void dma_read_traffic(void *p);
void close_dma_and_connection(dma_server_connection_t *connection);
BaseType_t queue_dma_transaction(QueueHandle_t fifo, const u8 *data, size_t len);

#endif
