`ifndef BOARD_TB_INCLUDED_
`define BOARD_TB_INCLUDED_

`ifndef BOARD_TEST_TIMEOUT_NS
`define BOARD_TEST_TIMEOUT_NS 2000000
`endif

module board_tb;
	import board_dpi_pkg::*;
	import board_dpi_codec_utils_pkg::*;
	import board_dpi_item_encoder_pkg::*;
	import board_dpi_item_decoder_pkg::*;
	import board_socket_demo_types_pkg::*;

	localparam int UVM_ITEM_WIDTH = 184; // 23*8
	localparam int UVM_ITEM_BYTES = (UVM_ITEM_WIDTH + 7) / 8;
	localparam int AXIS_CMD_TDATA_WIDTH = INCOMING_REQ_WIDTH;
	localparam int AXIS_MON_TDATA_WIDTH = OUTGOING_RSP_WIDTH;

	localparam int INFRA_CLK_HALF_PERIOD_NS = 20;
	localparam int DUT_CLK_HALF_PERIOD_NS = 20;

	logic pclk;
	logic infra_clk;
	logic preset_n;

	logic [AXIS_CMD_TDATA_WIDTH-1:0]     s_axis_cmd_tdata;
	logic [(AXIS_CMD_TDATA_WIDTH/8)-1:0] s_axis_cmd_tkeep;
	logic                                 s_axis_cmd_tvalid;
	logic                                 s_axis_cmd_tready;
	logic                                 s_axis_cmd_tlast;

	logic [AXIS_MON_TDATA_WIDTH-1:0]     m_axis_mon_tdata;
	logic [(AXIS_MON_TDATA_WIDTH/8)-1:0] m_axis_mon_tkeep;
	logic                                 m_axis_mon_tvalid;
	logic                                 m_axis_mon_tready;
	logic                                 m_axis_mon_tlast;

	logic s_apb_pselect;
	logic s_apb_penable;
	logic s_apb_pwrite;
	logic [APB_ADDR_WIDTH-1:0] s_apb_paddr;
	logic [APB_DATA_WIDTH-1:0] s_apb_pwdata;
	logic [APB_DATA_WIDTH-1:0] s_apb_prdata;
	logic s_apb_pready;
	logic s_apb_pslverr;

	logic m_apb_pselect;
	logic m_apb_penable;
	logic m_apb_pwrite;
	logic [APB_ADDR_WIDTH-1:0] m_apb_paddr;
	logic [APB_DATA_WIDTH-1:0] m_apb_pwdata;
	logic [APB_DATA_WIDTH-1:0] m_apb_prdata;
	logic m_apb_pready;
	logic m_apb_pslverr;

	typedef byte unsigned byte_array_t[];

	class byte_array_msg;
		rand byte unsigned data[];
		function new(byte unsigned arr[] = '{ });
			if (arr.size() > 0) begin
				data = new[arr.size()];
				for (int i = 0; i < arr.size(); i++) data[i] = arr[i];
			end else begin
				data = new[0];
			end
		endfunction
	endclass

	mailbox #(byte_array_msg) tx_message_mb;

	initial begin
		pclk = 1'b0;
		forever #DUT_CLK_HALF_PERIOD_NS pclk = ~pclk;
	end

	assign m_axis_mon_tlast = 1'b1;
	assign m_axis_mon_tkeep = {OUTGOING_RSP_BYTES{1'b1}};

`ifdef ASYNC_MODE
	initial begin
		infra_clk = 1'b0;
		forever #INFRA_CLK_HALF_PERIOD_NS infra_clk = ~infra_clk;
	end
`else
	assign infra_clk = pclk;
`endif

	initial begin
		preset_n = 1'b0;
		repeat (3) @(posedge infra_clk);
		preset_n = 1'b1;
	end


	function automatic void append_bytes(inout byte_array_t dst, input byte_array_t src, input int len);
		int old_size;

		old_size = dst.size();
		dst = new[old_size + len](dst);
		for (int i = 0; i < len; i++) begin
			dst[old_size + i] = src[i];
		end
	endfunction

	function automatic void packed_item_to_bytes(input logic [UVM_ITEM_WIDTH-1:0] packed_item, output byte_array_t bytes);
		bytes = new[UVM_ITEM_BYTES];
		for (int i = 0; i < UVM_ITEM_BYTES; i++) begin
			bytes[i] = packed_item[(UVM_ITEM_WIDTH-1) - (8*i) -: 8];
		end
	endfunction

	function automatic logic [UVM_ITEM_WIDTH-1:0] bytes_to_packed_item(input byte_array_t bytes);
		logic [UVM_ITEM_WIDTH-1:0] packed_item;

		packed_item = '0;
		for (int i = 0; i < bytes.size() && i < UVM_ITEM_BYTES; i++) begin
			packed_item[(UVM_ITEM_WIDTH-1) - (8*i) -: 8] = bytes[i];
		end

		return packed_item;
	endfunction


	task automatic send_axis_cmd_payload(
		input  logic [INCOMING_REQ_WIDTH-1:0] payload,
		output bit err
	);
		localparam int AXIS_BYTES = AXIS_CMD_TDATA_WIDTH/8;

		logic [AXIS_CMD_TDATA_WIDTH-1:0] beat_data;
		logic [AXIS_BYTES-1:0]           beat_keep;
		int byte_ptr;
		int bytes_this_beat;
		int bit_idx;
		int bits_left;
		$display("AXIS PAYLOAD: %0h", payload);

		err = 1'b0;
		byte_ptr = 0;

		s_axis_cmd_tdata  <= '0;
		s_axis_cmd_tkeep  <= '0;
		s_axis_cmd_tlast  <= 1'b0;
		s_axis_cmd_tvalid <= 1'b0;

		if (!preset_n) begin
			@(posedge infra_clk);
			wait (preset_n);
		end

		// align to clock so first beat is stable well before sampling edge
		@(negedge infra_clk);

		while (byte_ptr < INCOMING_REQ_BYTES) begin
			beat_data       = '0;
			beat_keep       = '0;
			bytes_this_beat = 0;

			for (int b = 0; b < AXIS_BYTES; b++) begin
				bit_idx   = 8*(byte_ptr + b);
				bits_left = INCOMING_REQ_WIDTH - bit_idx;

				if (bits_left > 0) begin
					beat_keep[b] = 1'b1;
					bytes_this_beat++;

					if (bits_left >= 8)
						beat_data[8*b +: 8] = payload[bit_idx +: 8];
					else
						for (int k = 0; k < bits_left; k++)
							beat_data[8*b + k] = payload[bit_idx + k];
				end
			end

			// drive before next rising edge
			s_axis_cmd_tdata  <= beat_data;
			s_axis_cmd_tkeep  <= beat_keep;
			s_axis_cmd_tlast  <= ((byte_ptr + bytes_this_beat) >= INCOMING_REQ_BYTES);
			s_axis_cmd_tvalid <= 1'b1;

			$display("[TB %0t] present beat: tdata=%08h tkeep=%b tlast=%0b",
					$time, beat_data, beat_keep, ((byte_ptr + bytes_this_beat) >= INCOMING_REQ_BYTES));

			// wait until a rising edge where handshake occurs
			do begin
				@(posedge infra_clk);
			end while (!(s_axis_cmd_tvalid && s_axis_cmd_tready));

			$display("[TB %0t] handshake beat: tdata=%08h tkeep=%b tlast=%0b",
					$time, s_axis_cmd_tdata, s_axis_cmd_tkeep, s_axis_cmd_tlast);

			// hold through the handshake edge, then drop/change on next falling edge
			@(negedge infra_clk);
			s_axis_cmd_tvalid <= 1'b0;
			s_axis_cmd_tlast  <= 1'b0;
			s_axis_cmd_tdata  <= '0;
			s_axis_cmd_tkeep  <= '0;

			byte_ptr += bytes_this_beat;
		end
	endtask

	task automatic emit_monitor_message(input logic [OUTGOING_RSP_WIDTH-1:0] mon_payload);
		outgoing_rsp_t outgoing_rsp;
		logic [UVM_ITEM_WIDTH-1:0] outgoing_bits;
		byte_array_t tx_bytes;
		byte_array_msg tx_msg;

		outgoing_rsp = outgoing_rsp_t'(mon_payload);

		$display("MON PAYLOAD: %0h", mon_payload);
		$display("NEW OUTGOING TRANSACTION PAYLOAD: %0h", mon_payload);
		print_outgoing_rsp(outgoing_rsp,"NEW OUTGOING TRANSACTION PAYLOAD:");
		outgoing_bits = mon_payload;
		packed_item_to_bytes(outgoing_bits, tx_bytes);

		$display("[TB %0t] EMIT MONITOR FRAME: frame_len=%0d id=0x%02h header=0x%02h",
			$time, tx_bytes.size(), outgoing_rsp.id, outgoing_rsp.outgoing_apb_item.header);
		tx_msg = new(tx_bytes);
		tx_message_mb.put(tx_msg);
	endtask

	task automatic route_rx_bytes_to_axis(input byte_array_t packet_bytes);
		logic [UVM_ITEM_WIDTH-1:0] packet_bits;
		incoming_req_t incoming_req;
		bit send_err;
		
		$display("[TB %0t] route_rx_bytes_to_axis: len=%0d id=0x%02h header=0x%02h",
				$time, packet_bytes.size(), (packet_bytes.size() > 0 ? packet_bytes[0] : 8'h00),
				(packet_bytes.size() > 1 ? packet_bytes[1] : 8'h00));

		if (packet_bytes.size() == 0) begin
			$display("[TB %0t] route_rx_bytes_to_axis: empty packet, ignoring", $time);
			return;
		end

		if (packet_bytes.size() != UVM_ITEM_BYTES) begin
			$display("[TB %0t] route_rx_bytes_to_axis: WARNING: expected %0d byte frame, got %0d",
					$time, UVM_ITEM_BYTES, packet_bytes.size());
		end

		packet_bits = bytes_to_packed_item(packet_bytes);
		incoming_req = incoming_req_t'(packet_bits);
		print_incoming_req(incoming_req, "NEW INCOMING REQ: ");
		send_axis_cmd_payload(incoming_req, send_err);
	endtask

	board_test_infrastructure #(
		.AXIS_CMD_TDATA_WIDTH(AXIS_CMD_TDATA_WIDTH),
		.AXIS_MON_TDATA_WIDTH(AXIS_MON_TDATA_WIDTH),
		.MASTER_REQ_FIFO_DEPTH(512),
		.SLAVE_REQ_FIFO_DEPTH(512),
		.M_CMD_RSP_MON_FIFO_DEPTH(512),
		.S_CMD_RSP_MON_FIFO_DEPTH(512),
		.M_ITEM_MON_FIFO_DEPTH(512),
		.S_ITEM_MON_FIFO_DEPTH(512),
		.M_ASSERT_MON_FIFO_DEPTH(512),
		.S_ASSERT_MON_FIFO_DEPTH(512),
		.M_RSP_MON_FIFO_DEPTH(512),
		.S_RSP_MON_FIFO_DEPTH(512)
	) u_board_test_infrastructure (
		.pclk(pclk),
		.infra_clk(infra_clk),
		.preset_n(preset_n),
		.s_axis_cmd_tdata(s_axis_cmd_tdata),
		.s_axis_cmd_tvalid(s_axis_cmd_tvalid),
		.s_axis_cmd_tready(s_axis_cmd_tready),
		.m_axis_mon_tdata(m_axis_mon_tdata),
		.m_axis_mon_tvalid(m_axis_mon_tvalid),
		.m_axis_mon_tready(m_axis_mon_tready),
		.s_apb_pselect(s_apb_pselect),
		.s_apb_penable(s_apb_penable),
		.s_apb_pwrite(s_apb_pwrite),
		.s_apb_paddr(s_apb_paddr),
		.s_apb_pwdata(s_apb_pwdata),
		.s_apb_prdata(s_apb_prdata),
		.s_apb_pready(s_apb_pready),
		.s_apb_pslverr(s_apb_pslverr),
		.m_apb_pselect(m_apb_pselect),
		.m_apb_penable(m_apb_penable),
		.m_apb_pwrite(m_apb_pwrite),
		.m_apb_paddr(m_apb_paddr),
		.m_apb_pwdata(m_apb_pwdata),
		.m_apb_prdata(m_apb_prdata),
		.m_apb_pready(m_apb_pready),
		.m_apb_pslverr(m_apb_pslverr)
	);

`ifdef PASS_THROUGH
	example_design #(
		.ADDR_WIDTH(APB_ADDR_WIDTH),
		.DATA_WIDTH(APB_DATA_WIDTH)
	) u_example_design (
		.PCLK(pclk),
		.PRESETn(preset_n),
		.s_pselect(s_apb_pselect),
		.s_penable(s_apb_penable),
		.s_pwrite(s_apb_pwrite),
		.s_paddr(s_apb_paddr),
		.s_pwdata(s_apb_pwdata),
		.s_prdata(s_apb_prdata),
		.s_pready(s_apb_pready),
		.s_pslverr(s_apb_pslverr),
		.m_pselect(m_apb_pselect),
		.m_penable(m_apb_penable),
		.m_pwrite(m_apb_pwrite),
		.m_paddr(m_apb_paddr),
		.m_pwdata(m_apb_pwdata),
		.m_prdata(m_apb_prdata),
		.m_pready(m_apb_pready),
		.m_pslverr(m_apb_pslverr)
	);
`else 
	apb_register_file #(
		.ADDR_WIDTH(APB_ADDR_WIDTH),
		.DATA_WIDTH(APB_DATA_WIDTH)
	) u_example_design (
		.PCLK(pclk),
		.PRESETn(preset_n),
		.s_pselect(s_apb_pselect),
		.s_penable(s_apb_penable),
		.s_pwrite(s_apb_pwrite),
		.s_paddr(s_apb_paddr),
		.s_pwdata(s_apb_pwdata),
		.s_prdata(s_apb_prdata),
		.s_pready(s_apb_pready),
		.s_pslverr(s_apb_pslverr)
	);
`endif

	initial begin
		int received;
		int recv_status;
		int send_status;
		int chunk_sent;
		int status;
		int accept_status;
		int board_port;
		int newline_idx;
		bit done;
		int unsigned board_test_timeout_ns;
		time test_timeout_deadline;
		bit enable_vcd;

		string board_bind_host;
		string vcd_path;
		byte_array_t rx_chunk_bytes;
		byte_array_t rx_accum;
		byte_array_t rx_packet;
		byte_array_msg tx_message;
		byte_array_t pending_tx;

		$timeformat(-9, 2, " ns", 12);

		s_axis_cmd_tdata = '0;
		s_axis_cmd_tkeep = '0;
		s_axis_cmd_tvalid = 1'b0;
		s_axis_cmd_tlast = 1'b0;
		m_axis_mon_tready = 1'b1;

		board_bind_host = "0.0.0.0";
		board_port = 9095;

		enable_vcd = 1'b1;
		vcd_path = "board_tb.vcd";
		if (enable_vcd) begin
			$dumpfile(vcd_path);
			$dumpvars(0, board_tb);
		end

		$display("BYTE WIDTHS FOR SYNTHESIS INCOMING: %0d (%0d bits)", INCOMING_REQ_BYTES, INCOMING_REQ_WIDTH);
		$display("BYTE WIDTHS FOR SYNTHESIS OUTGOING: %0d (%0d bits)", OUTGOING_RSP_BYTES, OUTGOING_RSP_WIDTH);

		tx_message_mb = new();
		rx_accum = new[0];

		status = board_socket_listen(board_bind_host, board_port);
		board_socket_set_timeout(10);
		if (status != 0) begin
			$error("[TB %0t] board socket listen failed", $time);
			#1;
			$finish;
		end

		accept_status = board_socket_accept();
		if (accept_status != 0) begin
			$error("[TB %0t] board socket accept failed", $time);
			board_socket_close();
			#1;
			$finish;
		end

		board_test_timeout_ns = `BOARD_TEST_TIMEOUT_NS;
		test_timeout_deadline = $time + (board_test_timeout_ns * 1ns);
		$display("[TB %0t] board test timeout configured for %0d ns", $time, board_test_timeout_ns);

		done = 1'b0;

		fork : TB_WORKERS
			begin : timeout_thread
				wait (done || ($time >= test_timeout_deadline));
				if (!done) begin
					$error("[TB %0t] board test timed out after %0d ns", $time, board_test_timeout_ns);
					done = 1'b1;
				end
			end

			begin : rx_thread
				while (!done) begin
					rx_chunk_bytes = new[2048];
					recv_status = board_socket_try_recv(rx_chunk_bytes, 2048, received);

					if (recv_status < 0) begin
						$error("[TB %0t] board socket receive failed/disconnected (ending test)", $time);
						done = 1'b1;
					end else if ((recv_status > 0) && (received > 0)) begin
						append_bytes(rx_accum, rx_chunk_bytes, received);

						while (rx_accum.size() >= UVM_ITEM_BYTES) begin
							rx_packet = new[UVM_ITEM_BYTES];
							for (int i = 0; i < UVM_ITEM_BYTES; i++) begin
								rx_packet[i] = rx_accum[i];
							end

							if (rx_accum.size() > UVM_ITEM_BYTES) begin
								byte_array_t remaining_rx;
								remaining_rx = new[rx_accum.size() - UVM_ITEM_BYTES];
								for (int i = UVM_ITEM_BYTES; i < rx_accum.size(); i++) begin
									remaining_rx[i - UVM_ITEM_BYTES] = rx_accum[i];
								end
								rx_accum = remaining_rx;
							end else begin
								rx_accum = new[0];
							end

								$display("[TB %0t] RX PACKET: len=%0d id=0x%02h header=0x%02h", $time, rx_packet.size(),
										(rx_packet.size() > 0 ? rx_packet[0] : 8'h00), (rx_packet.size() > 1 ? rx_packet[1] : 8'h00));
								route_rx_bytes_to_axis(rx_packet);
						end
					end

					@(posedge infra_clk);
				end
			end

			begin : axis_monitor_thread
				logic [OUTGOING_RSP_WIDTH-1:0] mon_payload_accum;
				int mon_byte_count;
				int next_count;
				bit frame_done;
				bit frame_error;

				mon_payload_accum = '0;
				mon_byte_count = 0;

				while (!done) begin
					@(posedge infra_clk);

					if (m_axis_mon_tvalid && m_axis_mon_tready) begin
						next_count  = mon_byte_count;
						frame_error = 1'b0;

						for (int b = 0; b < (AXIS_MON_TDATA_WIDTH/8); b++) begin
							if (m_axis_mon_tkeep[b]) begin
								if (next_count < OUTGOING_RSP_BYTES) begin
									mon_payload_accum[8*next_count +: 8] = m_axis_mon_tdata[8*b +: 8];
								end else begin
									frame_error = 1'b1; // too many bytes
								end
								next_count++;
							end
						end

						frame_done = m_axis_mon_tlast;

						if (frame_done) begin
							if (frame_error) begin
								string s = "ERR monitor payload frame too long\n";
								byte_array_msg err_msg = new();
								err_msg.data = new[s.len()];
								for (int i = 0; i < s.len(); i++) err_msg.data[i] = s.getc(i);
								tx_message_mb.put(err_msg);
							end else if (next_count < OUTGOING_RSP_BYTES) begin
								string s = "ERR incomplete monitor payload frame\n";
								byte_array_msg err_msg = new();
								err_msg.data = new[s.len()];
								for (int i = 0; i < s.len(); i++) err_msg.data[i] = s.getc(i);
								tx_message_mb.put(err_msg);
							end else begin
								emit_monitor_message(mon_payload_accum);
							end

							mon_payload_accum = '0;
							mon_byte_count    = 0;
						end else begin
							mon_byte_count = next_count;
						end
					end
				end
			end

			begin : tx_thread
				while (!done) begin
					if (tx_message_mb.try_get(tx_message)) begin
						pending_tx = tx_message.data;
						while ((pending_tx.size() > 0) && !done) begin
							chunk_sent = 0;
								send_status = board_socket_send(pending_tx, pending_tx.size(), chunk_sent);

							if (send_status < 0) begin
								$error("[TB %0t] board socket send failed/disconnected (ending test)", $time);
								done = 1'b1;
								break;
							end

							if (chunk_sent > 0) begin
								if (chunk_sent >= pending_tx.size()) begin
									pending_tx = new[0];
								end else begin
									byte_array_t remaining_tx;
									remaining_tx = new[pending_tx.size() - chunk_sent];
									for (int i = chunk_sent; i < pending_tx.size(); i++) begin
										remaining_tx[i - chunk_sent] = pending_tx[i];
									end
									pending_tx = remaining_tx;
								end
							end
							@(posedge infra_clk);
						end
					end else begin
							@(posedge infra_clk);
					end
				end
			end
		join_none

		wait (done);
		disable TB_WORKERS;

		board_socket_close();
		#1;
		$finish;
	end

endmodule : board_tb

`endif
