`ifndef BOARD_APB_PARTICIPANTS_INCLUDED_
`define BOARD_APB_PARTICIPANTS_INCLUDED_
import board_socket_demo_types_pkg::*;
module board_apb_participants #(
  parameter int MASTER_REQ_FIFO_DEPTH      = 8,
  parameter int SLAVE_REQ_FIFO_DEPTH       = 8,
  parameter int M_CMD_RSP_MON_FIFO_DEPTH   = 8,
  parameter int S_CMD_RSP_MON_FIFO_DEPTH   = 8,
  parameter int M_ITEM_MON_FIFO_DEPTH      = 8,
  parameter int S_ITEM_MON_FIFO_DEPTH      = 8,
  parameter int M_ASSERT_MON_FIFO_DEPTH    = 8,
  parameter int S_ASSERT_MON_FIFO_DEPTH    = 8,
  parameter int M_RSP_MON_FIFO_DEPTH    = 8,
  parameter int S_RSP_MON_FIFO_DEPTH    = 8
) (
  input  logic                               infra_clk,
  input  logic                               dut_clk,
  input  logic                               preset_n,
  // Request FIFOs exported as FIFO interfaces (consumer is internal).
  input  logic                               m_req_wr_valid,
  input  logic [INCOMING_APB_ITEM_WIDTH-1:0] m_req_wr_data,
  output logic                               m_req_wr_ready,
  
  input  logic                               s_req_wr_valid,
  input  logic [INCOMING_APB_ITEM_WIDTH-1:0] s_req_wr_data,
  output logic                               s_req_wr_ready,

  // Monitor FIFOs exported as FIFO interfaces (producer is internal).
  input  logic                               m_rsp_to_req_rd_ready,
  output logic [OUTGOING_APB_ITEM_WIDTH-1:0] m_rsp_to_req_rd_data,
  output logic                               m_rsp_to_req_rd_valid,

  input  logic                               s_rsp_to_req_rd_ready,
  output logic [OUTGOING_APB_ITEM_WIDTH-1:0] s_rsp_to_req_rd_data,
  output logic                               s_rsp_to_req_rd_valid,

  input  logic                               s_monitor_req_rd_ready,
  output logic [OUTGOING_APB_ITEM_WIDTH-1:0] s_monitor_req_rd_data,
  output logic                               s_monitor_req_rd_valid,


  input  logic                               m_monitor_req_rd_ready,
  output logic [OUTGOING_APB_ITEM_WIDTH-1:0] m_monitor_req_rd_data,
  output logic                               m_monitor_req_rd_valid,


  input  logic                               s_assert_rd_ready,
  output logic [OUTGOING_APB_ITEM_WIDTH-1:0] s_assert_rd_data,
  output logic                               s_assert_rd_valid,


  input  logic                               m_assert_rd_ready,
  output logic [OUTGOING_APB_ITEM_WIDTH-1:0] m_assert_rd_data,
  output logic                               m_assert_rd_valid,


  input  logic                               s_monitor_rsp_rd_ready,
  output logic [OUTGOING_APB_ITEM_WIDTH-1:0] s_monitor_rsp_rd_data,
  output logic                               s_monitor_rsp_rd_valid,

  input  logic                               m_monitor_rsp_rd_ready,
  output logic [OUTGOING_APB_ITEM_WIDTH-1:0] m_monitor_rsp_rd_data,
  output logic                               m_monitor_rsp_rd_valid,




  // Pins for DUT APB slave interface (driven by master transactor).
  output logic                               s_apb_pselect,
  output logic                               s_apb_penable,
  output logic                               s_apb_pwrite,
  output logic [APB_ADDR_WIDTH-1:0]          s_apb_paddr,
  output logic [APB_DATA_WIDTH-1:0]          s_apb_pwdata,
  input  logic [APB_DATA_WIDTH-1:0]          s_apb_prdata,
  input  logic                               s_apb_pready,
  input  logic                               s_apb_pslverr,
  // Pins for DUT APB master interface (driven by slave transactor).
  input  logic                               m_apb_pselect,
  input  logic                               m_apb_penable,
  input  logic                               m_apb_pwrite,
  input  logic [APB_ADDR_WIDTH-1:0]          m_apb_paddr,
  input  logic [APB_DATA_WIDTH-1:0]          m_apb_pwdata,
  output logic [APB_DATA_WIDTH-1:0]          m_apb_prdata,
  output logic                               m_apb_pready,
  output logic                               m_apb_pslverr
);

  //--------------------------------------------------------------------------
  // Internal handshake/data signals
  //--------------------------------------------------------------------------
  logic                               m_rsp_valid;
  logic [APB_DATA_WIDTH-1:0]          m_rsp_rdata;
  logic                               m_rsp_pslverr;
  logic [31:0]                        m_rsp_response_delay;

  logic                               s_rsp_valid;
  logic                               s_rsp_write;
  logic [APB_ADDR_WIDTH-1:0]          s_rsp_addr;
  logic [APB_DATA_WIDTH-1:0]          s_rsp_wdata;
  logic [31:0]                        s_rsp_transmit_delay;

  logic [INCOMING_APB_ITEM_WIDTH-1:0] m_req_rd_data;
  logic                               m_req_rd_ready;
  logic                               m_req_rd_valid;
  apb_incoming_item_t                 m_req_head;

  logic [INCOMING_APB_ITEM_WIDTH-1:0] s_req_rd_data;
  logic                               s_req_rd_ready;
  logic                               s_req_rd_valid;
  apb_incoming_item_t                 s_req_head;

  apb_outgoing_item_t                 s_rsp_to_req;
  logic                               s_rsp_to_req_valid;
  logic                               s_rsp_to_req_ready;

  apb_outgoing_item_t                 m_rsp_to_req;
  logic                               m_rsp_to_req_valid;
  logic                               m_rsp_to_req_ready;

  apb_outgoing_item_t                 s_monitor_req;
  logic                               s_monitor_req_valid;
  logic                               s_monitor_req_ready;

  apb_outgoing_item_t                 m_monitor_req;
  logic                               m_monitor_req_valid;
  logic                               m_monitor_req_ready;

  apb_outgoing_item_t                 s_assert_item;
  logic                               s_assert_valid;
  logic                               s_assert_ready;

  apb_outgoing_item_t                 m_assert_item;
  logic                               m_assert_valid;
  logic                               m_assert_ready;

  apb_outgoing_item_t                 s_monitor_rsp;
  logic                               s_monitor_rsp_valid;
  logic                               s_monitor_rsp_ready;

  apb_outgoing_item_t                 m_monitor_rsp;
  logic                               m_monitor_rsp_valid;
  logic                               m_monitor_rsp_ready;
  //--------------------------------------------------------------------------
  // Cast FIFO words to structs and vice versa
  //--------------------------------------------------------------------------
  // unpacker
  assign m_req_head = apb_incoming_item_t'(m_req_rd_data);
  assign s_req_head = apb_incoming_item_t'(s_req_rd_data);

  // packer (for unassigned fields, rest is done by modules)
  assign s_rsp_to_req.header = {OUTGOING_HEADER_WIDTH{1'b0}};
  assign m_rsp_to_req.header = {OUTGOING_HEADER_WIDTH{1'b0}};
  assign s_rsp_to_req.m_transmit_delay = {32{1'b0}};
  assign m_rsp_to_req.m_transmit_delay = {32{1'b0}};
  assign s_rsp_to_req.m_response_delay = {32{1'b0}};
  assign m_rsp_to_req.m_response_delay = {32{1'b0}};
  assign s_rsp_to_req.m_error[7:1] = 7'b0;
  assign m_rsp_to_req.m_error[7:1] = 7'b0;
  assign s_rsp_to_req.m_direction[31:1] = 31'b0;
  assign m_rsp_to_req.m_direction[31:1] = 31'b0;

  assign s_monitor_req.header     = {OUTGOING_HEADER_WIDTH{1'b0}};
  assign m_monitor_req.header     = {OUTGOING_HEADER_WIDTH{1'b0}};
  assign s_monitor_req.m_transmit_delay     = {32{1'b0}};
  assign m_monitor_req.m_transmit_delay     = {32{1'b0}};
  assign s_monitor_req.m_response_delay     = {32{1'b0}};
  assign m_monitor_req.m_response_delay     = {32{1'b0}};
  assign s_monitor_req.m_error[7:1] = 7'b0;
  assign m_monitor_req.m_error[7:1] = 7'b0;
  assign s_monitor_req.m_direction[31:1] = 31'b0;
  assign m_monitor_req.m_direction[31:1] = 31'b0;

  assign s_monitor_rsp.header      = {OUTGOING_HEADER_WIDTH{1'b0}};
  assign m_monitor_rsp.header      = {OUTGOING_HEADER_WIDTH{1'b0}};
  assign s_monitor_rsp.m_transmit_delay      = {32{1'b0}};
  assign m_monitor_rsp.m_transmit_delay      = {32{1'b0}};
  assign s_monitor_rsp.m_response_delay      = {32{1'b0}};
  assign m_monitor_rsp.m_response_delay      = {32{1'b0}};
  assign s_monitor_rsp.m_error[7:1] = 7'b0;
  assign m_monitor_rsp.m_error[7:1] = 7'b0;
  assign s_monitor_rsp.m_direction[31:1] = 31'b0;
  assign m_monitor_rsp.m_direction[31:1] = 31'b0;

  assign s_assert_item.header      = {OUTGOING_HEADER_WIDTH{1'b0}};
  assign m_assert_item.header      = {OUTGOING_HEADER_WIDTH{1'b0}};
  assign s_assert_item.m_response_delay      = {32{1'b0}};
  assign m_assert_item.m_response_delay      = {32{1'b0}};
  assign s_assert_item.m_error      = {8{1'b0}};
  assign m_assert_item.m_error      = {8{1'b0}};
  assign s_assert_item.m_direction  = {32{1'b0}};
  assign m_assert_item.m_direction  = {32{1'b0}};
  assign s_assert_item.m_transmit_delay      = {32{1'b0}};
  assign m_assert_item.m_transmit_delay      = {32{1'b0}};

  //--------------------------------------------------------------------------
  // Transactors / monitors
  //--------------------------------------------------------------------------
  board_apb_master_transactor #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH)
  ) u_board_apb_master_transactor (
    .pclk               (dut_clk),
    .preset_n           (preset_n),
    // incoming
    .cmd_valid          (m_req_rd_valid),
    .cmd_ready          (m_req_rd_ready),
    .cmd_write          (m_req_head.m_direction[0]),
    .cmd_addr           (m_req_head.m_addr),
    .cmd_wdata          (m_req_head.m_data),
    .cmd_transmit_delay (m_req_head.m_transmit_delay),
    // outgoing
    .rsp_valid          (m_rsp_valid),
    .rsp_ready          ('1),
    .rsp_rdata          (m_rsp_rdata),
    .rsp_pslverr        (m_rsp_pslverr),
    .rsp_response_delay (m_rsp_response_delay),
    // DUT
    .penable            (s_apb_penable),
    .psel               (s_apb_pselect),
    .pwrite             (s_apb_pwrite),
    .paddr              (s_apb_paddr),
    .pwdata             (s_apb_pwdata),
    .pready             (s_apb_pready),
    .prdata             (s_apb_prdata),
    .pslverr            (s_apb_pslverr)
  );

  board_apb_master_cmd_monitor #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH)
  ) u_master_cmd_rsp_monitor (
    .clk         (dut_clk),
    .rst_n       (preset_n),
    .enabled     (m_req_head.header[0]),
    // incoming
    .cmd_valid   (m_req_rd_valid),
    .cmd_ready   (m_req_rd_ready),
    .cmd_write   (m_req_head.m_direction[0]),
    .cmd_addr    (m_req_head.m_addr),
    .cmd_wdata   (m_req_head.m_data),
    // incoming
    .rsp_valid   (m_rsp_valid),
    .rsp_rdata   (m_rsp_rdata),
    .rsp_pslverr (m_rsp_pslverr),
    // outgoing
    .item_valid  (m_rsp_to_req_valid),
    .item_ready  (m_rsp_to_req_ready),
    .item_write  (m_rsp_to_req.m_direction[0]),
    .item_addr   (m_rsp_to_req.m_addr),
    .item_data   (m_rsp_to_req.m_data),
    .item_error  (m_rsp_to_req.m_error[0])
  );

  board_apb_slave_transactor #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH)
  ) u_board_apb_slave_transactor (
    .pclk               (dut_clk),
    .preset_n           (preset_n),
    // incoming
    .cmd_valid          (s_req_rd_valid),
    .cmd_ready          (s_req_rd_ready),
    .cmd_rdata          (s_req_head.m_data),
    .cmd_pslverr        (s_req_head.m_error[0]),
    .cmd_response_delay (s_req_head.m_response_delay),
    // outgoing
    .rsp_valid          (s_rsp_valid),
    .rsp_ready          ('1),
    .rsp_write          (s_rsp_write),
    .rsp_addr           (s_rsp_addr),
    .rsp_wdata          (s_rsp_wdata),
    .rsp_transmit_delay (s_rsp_transmit_delay),
    // DUT
    .psel               (m_apb_pselect),
    .penable            (m_apb_penable),
    .pwrite             (m_apb_pwrite),
    .paddr              (m_apb_paddr),
    .pwdata             (m_apb_pwdata),
    .prdata             (m_apb_prdata),
    .pready             (m_apb_pready),
    .pslverr            (m_apb_pslverr)
  );

  board_apb_slave_cmd_monitor #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH)
  ) u_slave_cmd_rsp_monitor (
    .clk         (dut_clk),
    .rst_n       (preset_n),
    .enabled     (s_req_head.header[0]),
    // incoming
    .cmd_valid   (s_req_rd_valid),
    .cmd_ready   (s_req_rd_ready),
    .cmd_rdata   (s_req_head.m_data),
    .cmd_pslverr (s_req_head.m_error[0]),
    // incoming
    .rsp_valid   (s_rsp_valid),
    .rsp_write   (s_rsp_write),
    .rsp_addr    (s_rsp_addr),
    .rsp_wdata   (s_rsp_wdata),
    // outgoing
    .item_valid  (s_rsp_to_req_valid),
    .item_ready  (s_rsp_to_req_ready),
    .item_write  (s_rsp_to_req.m_direction[0]),
    .item_addr   (s_rsp_to_req.m_addr),
    .item_data   (s_rsp_to_req.m_data),
    .item_error  (s_rsp_to_req.m_error[0])
  );

  board_apb_monitor #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH),
    .TRIGGER_ON_REQUEST(1'b0)
  ) u_board_apb_monitor_rsp_s_xtor (
    .pclk       (dut_clk),
    .preset_n   (preset_n),
    .psel       (s_apb_pselect),
    .penable    (s_apb_penable),
    .pwrite     (s_apb_pwrite),
    .paddr      (s_apb_paddr),
    .pwdata     (s_apb_pwdata),
    .prdata     (s_apb_prdata),
    .pready     (s_apb_pready),
    .pslverr    (s_apb_pslverr),
    .item_valid (s_monitor_req_valid),
    .item_write (s_monitor_req.m_direction[0]),
    .item_addr  (s_monitor_req.m_addr),
    .item_data  (s_monitor_req.m_data),
    .item_error (s_monitor_req.m_error[0])
  );

  board_apb_monitor #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH),
    .TRIGGER_ON_REQUEST(1'b1)
  ) u_board_apb_monitor_s_xtor (
    .pclk       (dut_clk),
    .preset_n   (preset_n),
    .psel       (s_apb_pselect),
    .penable    (s_apb_penable),
    .pwrite     (s_apb_pwrite),
    .paddr      (s_apb_paddr),
    .pwdata     (s_apb_pwdata),
    .prdata     (s_apb_prdata),
    .pready     (s_apb_pready),
    .pslverr    (s_apb_pslverr),
    .item_valid (s_monitor_rsp_valid),
    .item_write (s_monitor_rsp.m_direction[0]),
    .item_addr  (s_monitor_rsp.m_addr),
    .item_data  (s_monitor_rsp.m_data),
    .item_error (s_monitor_rsp.m_error[0])
  );

  board_apb_monitor #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH),
    .TRIGGER_ON_REQUEST(1'b0)
  ) u_board_apb_monitor_m_xtor (
    .pclk       (dut_clk),
    .preset_n   (preset_n),
    .psel       (m_apb_pselect),
    .penable    (m_apb_penable),
    .pwrite     (m_apb_pwrite),
    .paddr      (m_apb_paddr),
    .pwdata     (m_apb_pwdata),
    .prdata     (m_apb_prdata),
    .pready     (m_apb_pready),
    .pslverr    (m_apb_pslverr),
    .item_valid (m_monitor_req_valid),
    .item_write (m_monitor_req.m_direction[0]),
    .item_addr  (m_monitor_req.m_addr),
    .item_data  (m_monitor_req.m_data),
    .item_error (m_monitor_req.m_error[0])
  );

  board_apb_monitor #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH),
    .TRIGGER_ON_REQUEST(1'b1)
  ) u_board_apb_monitor_rsp_m_xtor (
    .pclk       (dut_clk),
    .preset_n   (preset_n),
    .psel       (m_apb_pselect),
    .penable    (m_apb_penable),
    .pwrite     (m_apb_pwrite),
    .paddr      (m_apb_paddr),
    .pwdata     (m_apb_pwdata),
    .prdata     (m_apb_prdata),
    .pready     (m_apb_pready),
    .pslverr    (m_apb_pslverr),
    .item_valid (m_monitor_rsp_valid),
    .item_write (m_monitor_rsp.m_direction[0]),
    .item_addr  (m_monitor_rsp.m_addr),
    .item_data  (m_monitor_rsp.m_data),
    .item_error (m_monitor_rsp.m_error[0])
  );

  board_apb_assertion_handler #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH)
  ) u_board_apb_slave_assertion_handler (
    .pclk        (dut_clk),
    .preset_n    (preset_n),
    .psel        (s_apb_pselect),
    .penable     (s_apb_penable),
    .pwrite      (s_apb_pwrite),
    .paddr       (s_apb_paddr),
    .pwdata      (s_apb_pwdata),
    .prdata      (s_apb_prdata),
    .pready      (s_apb_pready),
    .pslverr     (s_apb_pslverr),
    .assert_valid(s_assert_valid),
    .assert_ready(s_assert_ready),
    .assert_info (s_assert_item.m_data),
    .assert_addr (s_assert_item.m_addr)
  );

  board_apb_assertion_handler #(
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH)
  ) u_board_apb_master_assertion_handler (
    .pclk        (dut_clk),
    .preset_n    (preset_n),
    .psel        (m_apb_pselect),
    .penable     (m_apb_penable),
    .pwrite      (m_apb_pwrite),
    .paddr       (m_apb_paddr),
    .pwdata      (m_apb_pwdata),
    .prdata      (m_apb_prdata),
    .pready      (m_apb_pready),
    .pslverr     (m_apb_pslverr),
    .assert_valid(m_assert_valid),
    .assert_ready(m_assert_ready),
    .assert_info (m_assert_item.m_data),
    .assert_addr (m_assert_item.m_addr)
  );


  //--------------------------------------------------------------------------
  // FIFOs
  //--------------------------------------------------------------------------
  board_fifo_wrapper #(
    .WIDTH(INCOMING_APB_ITEM_WIDTH),
    .DEPTH(MASTER_REQ_FIFO_DEPTH)
  ) u_master_req_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (m_req_wr_valid),
    .in_ready  (m_req_wr_ready),
    .in_data   (m_req_wr_data),
    .out_valid (m_req_rd_valid),
    .out_ready (m_req_rd_ready),
    .out_data  (m_req_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(INCOMING_APB_ITEM_WIDTH),
    .DEPTH(SLAVE_REQ_FIFO_DEPTH)
  ) u_slave_req_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (s_req_wr_valid),
    .in_ready  (s_req_wr_ready),
    .in_data   (s_req_wr_data),
    .out_valid (s_req_rd_valid),
    .out_ready (s_req_rd_ready),
    .out_data  (s_req_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(OUTGOING_APB_ITEM_WIDTH),
    .DEPTH(M_CMD_RSP_MON_FIFO_DEPTH)
  ) u_m_cmd_rsp_mon_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (m_rsp_to_req_valid),
    .in_ready  (m_rsp_to_req_ready),
    .in_data   (m_rsp_to_req),
    .out_valid (m_rsp_to_req_rd_valid),
    .out_ready (m_rsp_to_req_rd_ready),
    .out_data  (m_rsp_to_req_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(OUTGOING_APB_ITEM_WIDTH),
    .DEPTH(S_CMD_RSP_MON_FIFO_DEPTH)
  ) u_s_cmd_rsp_mon_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (s_rsp_to_req_valid),
    .in_ready  (s_rsp_to_req_ready),
    .in_data   (s_rsp_to_req),
    .out_valid (s_rsp_to_req_rd_valid),
    .out_ready (s_rsp_to_req_rd_ready),
    .out_data  (s_rsp_to_req_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(OUTGOING_APB_ITEM_WIDTH),
    .DEPTH(S_ITEM_MON_FIFO_DEPTH)
  ) u_s_item_mon_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (s_monitor_req_valid),
    .in_ready  (s_monitor_req_ready),
    .in_data   (s_monitor_req),
    .out_valid (s_monitor_req_rd_valid),
    .out_ready (s_monitor_req_rd_ready),
    .out_data  (s_monitor_req_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(OUTGOING_APB_ITEM_WIDTH),
    .DEPTH(M_ITEM_MON_FIFO_DEPTH)
  ) u_m_item_mon_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (m_monitor_req_valid),
    .in_ready  (m_monitor_req_ready),
    .in_data   (m_monitor_req),
    .out_valid (m_monitor_req_rd_valid),
    .out_ready (m_monitor_req_rd_ready),
    .out_data  (m_monitor_req_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(OUTGOING_APB_ITEM_WIDTH),
    .DEPTH(S_ASSERT_MON_FIFO_DEPTH)
  ) u_s_assert_mon_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (s_assert_valid),
    .in_ready  (s_assert_ready),
    .in_data   (s_assert_item),
    .out_valid (s_assert_rd_valid),
    .out_ready (s_assert_rd_ready),
    .out_data  (s_assert_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(OUTGOING_APB_ITEM_WIDTH),
    .DEPTH(M_ASSERT_MON_FIFO_DEPTH)
  ) u_m_assert_mon_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (m_assert_valid),
    .in_ready  (m_assert_ready),
    .in_data   (m_assert_item),
    .out_valid (m_assert_rd_valid),
    .out_ready (m_assert_rd_ready),
    .out_data  (m_assert_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(OUTGOING_APB_ITEM_WIDTH),
    .DEPTH(S_RSP_MON_FIFO_DEPTH)
  ) u_s_rsp_item_mon_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (s_monitor_rsp_valid),
    .in_ready  (s_monitor_rsp_ready),
    .in_data   (s_monitor_rsp),
    .out_valid (s_monitor_rsp_rd_valid),
    .out_ready (s_monitor_rsp_rd_ready),
    .out_data  (s_monitor_rsp_rd_data)
  );

  board_fifo_wrapper #(
    .WIDTH(OUTGOING_APB_ITEM_WIDTH),
    .DEPTH(M_RSP_MON_FIFO_DEPTH)
  ) u_m_rsp_item_mon_fifo (
    .clk       (dut_clk),
    .rst_n     (preset_n),
    .in_valid  (m_monitor_rsp_valid),
    .in_ready  (m_monitor_rsp_ready),
    .in_data   (m_monitor_rsp),
    .out_valid (m_monitor_rsp_rd_valid),
    .out_ready (m_monitor_rsp_rd_ready),
    .out_data  (m_monitor_rsp_rd_data)
  );
endmodule : board_apb_participants
`endif



