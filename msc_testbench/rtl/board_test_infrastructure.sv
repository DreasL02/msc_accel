`ifndef BOARD_TEST_INFRASTRUCTURE_INCLUDED_
`define BOARD_TEST_INFRASTRUCTURE_INCLUDED_

import board_socket_demo_types_pkg::*;

module board_test_infrastructure #(
  parameter int MASTER_REQ_FIFO_DEPTH = 8,
  parameter int SLAVE_REQ_FIFO_DEPTH = 8,
  parameter int M_CMD_RSP_MON_FIFO_DEPTH = 8,
  parameter int S_CMD_RSP_MON_FIFO_DEPTH = 8,
  parameter int M_ITEM_MON_FIFO_DEPTH = 8,
  parameter int S_ITEM_MON_FIFO_DEPTH = 8,
  parameter int M_ASSERT_MON_FIFO_DEPTH = 8,
  parameter int S_ASSERT_MON_FIFO_DEPTH = 8,
  parameter int M_RSP_MON_FIFO_DEPTH    = 8,
  parameter int S_RSP_MON_FIFO_DEPTH    = 8,
  parameter int AXIS_CMD_TDATA_WIDTH = 64,
  parameter int AXIS_MON_TDATA_WIDTH = 64
) (
  input  logic pclk,
  input  logic infra_clk,
  input  logic preset_n,

  // AXIS command ingress (host/DMA to board).
  input  logic [AXIS_CMD_TDATA_WIDTH-1:0]     s_axis_cmd_tdata,
  input  logic                                s_axis_cmd_tvalid,
  output logic                                s_axis_cmd_tready,

  // AXIS monitor egress (board to host/DMA).
  output logic [AXIS_MON_TDATA_WIDTH-1:0]     m_axis_mon_tdata,
  output logic                                m_axis_mon_tvalid,
  input  logic                                m_axis_mon_tready,

  // Pins for DUT APB slave interface (driven by board-side master transactor).
  output logic s_apb_pselect,
  output logic s_apb_penable,
  output logic s_apb_pwrite,
  output logic [APB_ADDR_WIDTH-1:0] s_apb_paddr,
  output logic [APB_DATA_WIDTH-1:0] s_apb_pwdata,
  input  logic [APB_DATA_WIDTH-1:0] s_apb_prdata,
  input  logic s_apb_pready,
  input  logic s_apb_pslverr,

  // Pins for DUT APB master interface (driven by board-side slave transactor).
  input  logic m_apb_pselect,
  input  logic m_apb_penable,
  input  logic m_apb_pwrite,
  input  logic [APB_ADDR_WIDTH-1:0] m_apb_paddr,
  input  logic [APB_DATA_WIDTH-1:0] m_apb_pwdata,
  output logic [APB_DATA_WIDTH-1:0] m_apb_prdata,
  output logic m_apb_pready,
  output logic m_apb_pslverr,

  // Per-mon-port full item visibility (one 200-bit signal per MON_PORTS)
  output logic [199:0] dbg_mon_item_0,
  output logic [199:0] dbg_mon_item_1,
  output logic [199:0] dbg_mon_item_2,
  output logic [199:0] dbg_mon_item_3,
  output logic [199:0] dbg_mon_item_4,
  output logic [199:0] dbg_mon_item_5,
  output logic [199:0] dbg_mon_item_6,
  output logic [199:0] dbg_mon_item_7,

  // Per-mon-port handshake signals (valid = data available, ready = arbiter read enable)
  output logic dbg_mon_valid_0,
  output logic dbg_mon_valid_1,
  output logic dbg_mon_valid_2,
  output logic dbg_mon_valid_3,
  output logic dbg_mon_valid_4,
  output logic dbg_mon_valid_5,
  output logic dbg_mon_valid_6,
  output logic dbg_mon_valid_7,

  output logic dbg_mon_ready_0,
  output logic dbg_mon_ready_1,
  output logic dbg_mon_ready_2,
  output logic dbg_mon_ready_3,
  output logic dbg_mon_ready_4,
  output logic dbg_mon_ready_5,
  output logic dbg_mon_ready_6,
  output logic dbg_mon_ready_7
);

  localparam int DEC_PORTS = 2;
  localparam int MON_PORTS = 8;

  incoming_req_t axis_dec_struct_item;

  logic in_port_ready [DEC_PORTS];
  logic [INCOMING_APB_ITEM_WIDTH-1:0] in_port_wr_data [DEC_PORTS];
  logic in_port_valid [DEC_PORTS];

  logic out_port_ready [MON_PORTS];
  logic [OUTGOING_APB_ITEM_WIDTH-1:0] out_port_rd_data [MON_PORTS];
  logic out_port_valid [MON_PORTS];
  logic [$clog2(MON_PORTS)-1:0] out_port_rd_id;


  logic [OUTGOING_APB_ITEM_WIDTH-1:0] arb_axis_item_data;
  logic [OUTGOING_ID_WIDTH-1:0] arb_axis_item_id;


  assign axis_dec_struct_item = incoming_req_t'(s_axis_cmd_tdata);

  board_apb_participants #(
    .MASTER_REQ_FIFO_DEPTH(MASTER_REQ_FIFO_DEPTH),
    .SLAVE_REQ_FIFO_DEPTH(SLAVE_REQ_FIFO_DEPTH),
    .M_CMD_RSP_MON_FIFO_DEPTH(M_CMD_RSP_MON_FIFO_DEPTH),
    .S_CMD_RSP_MON_FIFO_DEPTH(S_CMD_RSP_MON_FIFO_DEPTH),
    .M_ITEM_MON_FIFO_DEPTH(M_ITEM_MON_FIFO_DEPTH),
    .S_ITEM_MON_FIFO_DEPTH(S_ITEM_MON_FIFO_DEPTH),
    .M_ASSERT_MON_FIFO_DEPTH(M_ASSERT_MON_FIFO_DEPTH),
    .S_ASSERT_MON_FIFO_DEPTH(S_ASSERT_MON_FIFO_DEPTH),
    .M_RSP_MON_FIFO_DEPTH(M_RSP_MON_FIFO_DEPTH),
    .S_RSP_MON_FIFO_DEPTH(S_RSP_MON_FIFO_DEPTH)
  ) u_board_apb_participants (
    .infra_clk(infra_clk),
    .dut_clk(pclk),
    .preset_n(preset_n),

    .m_req_wr_ready(in_port_ready[0]),
    .m_req_wr_data(in_port_wr_data[0]),
    .m_req_wr_valid(in_port_valid[0]),

    .s_req_wr_ready(in_port_ready[1]),
    .s_req_wr_data(in_port_wr_data[1]),
    .s_req_wr_valid(in_port_valid[1]),

    .m_rsp_to_req_rd_ready(out_port_ready[0]),
    .m_rsp_to_req_rd_data(out_port_rd_data[0]),
    .m_rsp_to_req_rd_valid(out_port_valid[0]),

    .s_rsp_to_req_rd_ready(out_port_ready[1]),
    .s_rsp_to_req_rd_data(out_port_rd_data[1]),
    .s_rsp_to_req_rd_valid(out_port_valid[1]),

    .m_monitor_req_rd_ready(out_port_ready[2]),
    .m_monitor_req_rd_data(out_port_rd_data[2]),
    .m_monitor_req_rd_valid(out_port_valid[2]),

    .m_monitor_rsp_rd_ready(out_port_ready[3]),
    .m_monitor_rsp_rd_data(out_port_rd_data[3]),
    .m_monitor_rsp_rd_valid(out_port_valid[3]),

    .m_assert_rd_ready(out_port_ready[4]),
    .m_assert_rd_data(out_port_rd_data[4]),
    .m_assert_rd_valid(out_port_valid[4]),

    .s_monitor_req_rd_ready(out_port_ready[5]),
    .s_monitor_req_rd_data(out_port_rd_data[5]),
    .s_monitor_req_rd_valid(out_port_valid[5]),
    
    .s_monitor_rsp_rd_ready(out_port_ready[6]),
    .s_monitor_rsp_rd_data(out_port_rd_data[6]),
    .s_monitor_rsp_rd_valid(out_port_valid[6]),
    
    .s_assert_rd_ready(out_port_ready[7]),
    .s_assert_rd_data(out_port_rd_data[7]),
    .s_assert_rd_valid(out_port_valid[7]),

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

  board_decoder #(
    .NUM_PORTS(DEC_PORTS),
    .ITEM_WIDTH(INCOMING_APB_ITEM_WIDTH)
  ) u_board_decoder (
    .clk(infra_clk),
    .rst_n(preset_n),
    .in_valid(s_axis_cmd_tvalid),
    .in_ready(s_axis_cmd_tready),
    .in_data(axis_dec_struct_item.incoming_apb_item),
    .in_id(axis_dec_struct_item.id[$clog2(DEC_PORTS)-1:0]),
    .out_valid(in_port_valid),
    .out_data(in_port_wr_data),
    .out_ready(in_port_ready)
  );

  board_arbiter #(
    .NUM_PORTS(MON_PORTS),
    .ITEM_WIDTH(OUTGOING_APB_ITEM_WIDTH)
  ) u_board_arbiter (
    .clk(infra_clk),
    .rst_n(preset_n),
    .in_valid(out_port_valid),
    .in_ready(out_port_ready),
    .in_data(out_port_rd_data),
    .out_valid(m_axis_mon_tvalid),
    .out_ready(m_axis_mon_tready),
    .out_data(arb_axis_item_data),
    .out_id(out_port_rd_id)
  );

  assign arb_axis_item_id = {{(OUTGOING_ID_WIDTH - $clog2(MON_PORTS)){1'b0}}, out_port_rd_id}; // zero-extend ID to full width
  assign m_axis_mon_tdata = {arb_axis_item_id, arb_axis_item_data};

  // ============================================================================
  // Debug Signal Assignments for ILA Monitoring
  // ============================================================================
  // --------------------------------------------------------------------------
  // Provide one 200-bit debug signal per arbiter input (out_port_rd_data[i])
  // and one 200-bit debug signal for the chosen item (arb_axis_item_data).
  // Also expose per-port valid (data available) and ready (arbiter read enable)
  // as single-bit debug outputs so the ILA can monitor handshakes directly.
  // --------------------------------------------------------------------------
  // Pack out_port_rd_data into 200-bit outputs (LSBs contain payload), and have the id as the upper bits
  assign dbg_mon_item_0[OUTGOING_APB_ITEM_WIDTH-1:0] = out_port_rd_data[0];
  assign dbg_mon_item_0[196:OUTGOING_APB_ITEM_WIDTH] = '0;
  assign dbg_mon_item_0[199:197] = 3'd0;
  assign dbg_mon_item_1[OUTGOING_APB_ITEM_WIDTH-1:0] = out_port_rd_data[1];
  assign dbg_mon_item_1[196:OUTGOING_APB_ITEM_WIDTH] = '0;
  assign dbg_mon_item_1[199:197] = 3'd1;
  assign dbg_mon_item_2[OUTGOING_APB_ITEM_WIDTH-1:0] = out_port_rd_data[2];
  assign dbg_mon_item_2[196:OUTGOING_APB_ITEM_WIDTH] = '0;
  assign dbg_mon_item_2[199:197] = 3'd2;
  assign dbg_mon_item_3[OUTGOING_APB_ITEM_WIDTH-1:0] = out_port_rd_data[3];
  assign dbg_mon_item_3[196:OUTGOING_APB_ITEM_WIDTH] = '0;
  assign dbg_mon_item_3[199:197] = 3'd3;
  assign dbg_mon_item_4[OUTGOING_APB_ITEM_WIDTH-1:0] = out_port_rd_data[4];
  assign dbg_mon_item_4[196:OUTGOING_APB_ITEM_WIDTH] = '0;
  assign dbg_mon_item_4[199:197] = 3'd4;
  assign dbg_mon_item_5[OUTGOING_APB_ITEM_WIDTH-1:0] = out_port_rd_data[5];
  assign dbg_mon_item_5[196:OUTGOING_APB_ITEM_WIDTH] = '0;
  assign dbg_mon_item_5[199:197] = 3'd5;
  assign dbg_mon_item_6[OUTGOING_APB_ITEM_WIDTH-1:0] = out_port_rd_data[6];
  assign dbg_mon_item_6[196:OUTGOING_APB_ITEM_WIDTH] = '0;
  assign dbg_mon_item_6[199:197] = 3'd6;
  assign dbg_mon_item_7[OUTGOING_APB_ITEM_WIDTH-1:0] = arb_axis_item_data;
  assign dbg_mon_item_7[196:OUTGOING_APB_ITEM_WIDTH] = '0;
  assign dbg_mon_item_7[199:197] = out_port_rd_id;

  // Per-port valid = data available (not empty)
  assign dbg_mon_valid_0 = out_port_valid[0];
  assign dbg_mon_valid_1 = out_port_valid[1];
  assign dbg_mon_valid_2 = out_port_valid[2];
  assign dbg_mon_valid_3 = out_port_valid[3];
  assign dbg_mon_valid_4 = out_port_valid[4];
  assign dbg_mon_valid_5 = out_port_valid[5];
  assign dbg_mon_valid_6 = out_port_valid[6];
  assign dbg_mon_valid_7 = m_axis_mon_tvalid;

  // Per-port ready = arbiter read enable
  assign dbg_mon_ready_0 = out_port_ready[0];
  assign dbg_mon_ready_1 = out_port_ready[1];
  assign dbg_mon_ready_2 = out_port_ready[2];
  assign dbg_mon_ready_3 = out_port_ready[3];
  assign dbg_mon_ready_4 = out_port_ready[4];
  assign dbg_mon_ready_5 = out_port_ready[5];
  assign dbg_mon_ready_6 = out_port_ready[6];
  assign dbg_mon_ready_7 = m_axis_mon_tready;

endmodule : board_test_infrastructure

`endif
