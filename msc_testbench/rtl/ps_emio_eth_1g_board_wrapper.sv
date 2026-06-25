`timescale 1 ps / 1 ps

module ps_emio_eth_1g_board_wrapper (
  input  logic        gtrefclk_in_clk_n,
  input  logic        gtrefclk_in_clk_p,
  input  logic        sfp_rxn,
  input  logic        sfp_rxp,

  output logic [0:0]  gmii_rx_clk_led,
  output logic [0:0]  link_status_led,
  output logic [0:0]  link_sync_led,
  output logic [0:0]  mdc_clk_led,
  output logic [0:0]  pcs_clk_led,
  output logic [0:0]  pl_reset_led,
  output logic [0:0]  sfp_tx_dis,
  output logic        sfp_txn,
  output logic        sfp_txp,
  output logic [0:0]  xcvr_rst_done_led
);

  logic [184-1:0] ps_m_axis_tdata;
  logic [23-1:0]  ps_m_axis_tkeep;
  logic        ps_m_axis_tlast;
  logic        ps_m_axis_tready;
  logic        ps_m_axis_tvalid;

  logic [184-1:0] ps_s_axis_tdata;
  logic [23-1:0]  ps_s_axis_tkeep;
  logic        ps_s_axis_tlast;
  logic        ps_s_axis_tready;
  logic        ps_s_axis_tvalid;

  logic        resetn;
  logic        out_clk;

  logic [199:0]probe0_0;
  logic [199:0]probe1_0;
  logic [199:0]probe2_0;
  logic [199:0]probe3_0;
  logic [199:0]probe4_0;
  logic [199:0]probe5_0;
  logic [199:0]probe6_0;
  logic [199:0]probe7_0;
  logic [31:0]probe8_0;
  logic [31:0]probe9_0;
  logic [31:0]probe10_0;
  logic [31:0]probe11_0;
  logic [31:0]probe12_0;
  logic [31:0]probe13_0;
  logic [31:0]probe14_0;
  logic [31:0]probe15_0;
  logic [0:0]probe16_0;
  logic [0:0]probe17_0;
  logic [0:0]probe18_0;
  logic [0:0]probe19_0;
  logic [0:0]probe20_0;
  logic [0:0]probe21_0;
  logic [0:0]probe22_0;
  logic [0:0]probe23_0;
  logic [0:0]probe24_0;
  logic [0:0]probe25_0;
  logic [0:0]probe26_0;
  logic [0:0]probe27_0;
  logic [0:0]probe28_0;
  logic [0:0]probe29_0;
  logic [0:0]probe30_0;
  logic [0:0]probe31_0;
  
  ps_emio_eth_1g_wrapper u_ps_emio_eth_1g_wrapper (
    .M_AXIS_0_tdata(ps_m_axis_tdata), // 184
    .M_AXIS_0_tkeep(ps_m_axis_tkeep),
    .M_AXIS_0_tlast(ps_m_axis_tlast),
    .M_AXIS_0_tready(ps_m_axis_tready),
    .M_AXIS_0_tvalid(ps_m_axis_tvalid),
    .S_AXIS_0_tdata(ps_s_axis_tdata), //184 
    .S_AXIS_0_tkeep(ps_s_axis_tkeep),
    .S_AXIS_0_tlast(ps_s_axis_tlast),
    .S_AXIS_0_tready(ps_s_axis_tready),
    .S_AXIS_0_tvalid(ps_s_axis_tvalid),
    .gmii_rx_clk_led(gmii_rx_clk_led),
    .gtrefclk_in_clk_n(gtrefclk_in_clk_n),
    .gtrefclk_in_clk_p(gtrefclk_in_clk_p),
    .link_status_led(link_status_led),
    .link_sync_led(link_sync_led),
    .mdc_clk_led(mdc_clk_led),
    .pcs_clk_led(pcs_clk_led),
    .pl_reset_led(pl_reset_led),
    .sfp_rxn(sfp_rxn),
    .sfp_rxp(sfp_rxp),
    .sfp_tx_dis(sfp_tx_dis),
    .sfp_txn(sfp_txn),
    .sfp_txp(sfp_txp),
    .xcvr_rst_done_led(xcvr_rst_done_led),
    .pl_resetn(resetn),
    .pl_clk(out_clk),
    .probe0_0(probe0_0),
    .probe1_0(probe1_0),
    .probe2_0(probe2_0),
    .probe3_0(probe3_0),
    .probe4_0(probe4_0),
    .probe5_0(probe5_0),
    .probe6_0(probe6_0),
    .probe7_0(probe7_0),
    .probe8_0(probe8_0),
    .probe9_0(probe9_0),
    .probe10_0(probe10_0),
    .probe11_0(probe11_0),
    .probe12_0(probe12_0),
    .probe13_0(probe13_0),
    .probe14_0(probe14_0),
    .probe15_0(probe15_0),
    .probe16_0(probe16_0),
    .probe17_0(probe17_0),
    .probe18_0(probe18_0),
    .probe19_0(probe19_0),
    .probe20_0(probe20_0),
    .probe21_0(probe21_0),
    .probe22_0(probe22_0),
    .probe23_0(probe23_0),
    .probe24_0(probe24_0),
    .probe25_0(probe25_0),
    .probe26_0(probe26_0),
    .probe27_0(probe27_0),
    .probe28_0(probe28_0),
    .probe29_0(probe29_0),
    .probe30_0(probe30_0),
    .probe31_0(probe31_0)
  );

  logic [184-1:0] board_m_axis_tdata;
  logic        board_m_axis_tready;
  logic        board_m_axis_tvalid;

  logic dbg_reading;
  logic dbg_write_fire;
  logic dbg_read_fire;
  logic dbg_read_start;
  logic [199:0]                      dbg_read_ptr;
  logic [199:0]                      dbg_write_ptr;
  
  board_offloader #(
    .DATA_WIDTH(184),
    .DEPTH(40)
  ) u_board_offloader (
    .clk(out_clk),
    .rst_n(resetn),
    .s_tdata(board_m_axis_tdata),
    .s_tvalid(board_m_axis_tvalid),
    .s_tready(board_m_axis_tready),
    .m_axis_tdata(ps_s_axis_tdata),
    .m_axis_tvalid(ps_s_axis_tvalid),
    .m_axis_tready(ps_s_axis_tready),
    .m_axis_tlast(ps_s_axis_tlast),
    .dbg_read_ptr(dbg_read_ptr),
    .dbg_write_ptr(dbg_write_ptr),
    .dbg_reading(dbg_reading),
    .dbg_write_fire(dbg_write_fire),
    .dbg_read_fire(dbg_read_fire),
    .dbg_read_start(dbg_read_start)
  );
  assign ps_s_axis_tkeep = {23{1'b1}};

  // Internal APB and AXIS signals from board_synth for probe monitoring
  logic                                 apb_s_pselect;
  logic                                 apb_s_penable;
  logic                                 apb_s_pwrite;
  logic [31:0]                          apb_s_paddr;
  logic [31:0]                          apb_s_pwdata;
  logic [31:0]                          apb_s_prdata;
  logic                                 apb_s_pready;
  logic                                 apb_s_pslverr;

  logic                                 apb_m_pselect;
  logic                                 apb_m_penable;
  logic                                 apb_m_pwrite;
  logic [31:0]                          apb_m_paddr;
  logic [31:0]                          apb_m_pwdata;
  logic [31:0]                          apb_m_prdata;
  logic                                 apb_m_pready;
  logic                                 apb_m_pslverr;


  logic                                dbg_mon_valid_0;
  logic                                dbg_mon_valid_1;
  logic                                dbg_mon_valid_2;
  logic                                dbg_mon_valid_3;
  logic                                dbg_mon_valid_4;
  logic                                dbg_mon_valid_5;
  logic                                dbg_mon_valid_6;
  logic                                dbg_mon_valid_7;

  logic                                dbg_mon_ready_0;
  logic                                dbg_mon_ready_1;
  logic                                dbg_mon_ready_2;
  logic                                dbg_mon_ready_3;
  logic                                dbg_mon_ready_4;
  logic                                dbg_mon_ready_5;
  logic                                dbg_mon_ready_6;
  logic                                dbg_mon_ready_7;

  logic [199:0]                       dbg_mon_item_0;
  logic [199:0]                       dbg_mon_item_1;
  logic [199:0]                       dbg_mon_item_2;
  logic [199:0]                       dbg_mon_item_3;
  logic [199:0]                       dbg_mon_item_4;
  logic [199:0]                       dbg_mon_item_5;
  logic [199:0]                       dbg_mon_item_6;
  logic [199:0]                       dbg_mon_item_7;

  board_synth #(
    .AXIS_CMD_TDATA_WIDTH(184),
    .AXIS_MON_TDATA_WIDTH(184),
    .MASTER_REQ_FIFO_DEPTH(512*4),
    .SLAVE_REQ_FIFO_DEPTH(512*4),
    .M_CMD_RSP_MON_FIFO_DEPTH(512*4),
    .S_CMD_RSP_MON_FIFO_DEPTH(512*4),
    .M_ITEM_MON_FIFO_DEPTH(512*4),
    .S_ITEM_MON_FIFO_DEPTH(512*4),
    .M_ASSERT_MON_FIFO_DEPTH(512*4),
    .S_ASSERT_MON_FIFO_DEPTH(512*4),
    .M_RSP_MON_FIFO_DEPTH(512*4),
    .S_RSP_MON_FIFO_DEPTH(512*4)
  ) u_board_synth (
    .pclk(out_clk),
    .infra_clk(out_clk),
    .preset_n(resetn),
    .s_axis_cmd_tdata(ps_m_axis_tdata),
    .s_axis_cmd_tvalid(ps_m_axis_tvalid),
    .s_axis_cmd_tready(ps_m_axis_tready),
    .m_axis_mon_tdata(board_m_axis_tdata),
    .m_axis_mon_tvalid(board_m_axis_tvalid),
    .m_axis_mon_tready(board_m_axis_tready),
    .s_apb_pselect(apb_s_pselect),
    .s_apb_penable(apb_s_penable),
    .s_apb_pwrite(apb_s_pwrite),
    .s_apb_paddr(apb_s_paddr),
    .s_apb_pwdata(apb_s_pwdata),
    .s_apb_prdata(apb_s_prdata),
    .s_apb_pready(apb_s_pready),
    .s_apb_pslverr(apb_s_pslverr),
    .m_apb_pselect(apb_m_pselect),
    .m_apb_penable(apb_m_penable),
    .m_apb_pwrite(apb_m_pwrite),
    .m_apb_paddr(apb_m_paddr),
    .m_apb_pwdata(apb_m_pwdata),
    .m_apb_prdata(apb_m_prdata),
    .m_apb_pready(apb_m_pready),
    .m_apb_pslverr(apb_m_pslverr),
    .dbg_mon_item_0(dbg_mon_item_0),
    .dbg_mon_item_1(dbg_mon_item_1),
    .dbg_mon_item_2(dbg_mon_item_2),
    .dbg_mon_item_3(dbg_mon_item_3),
    .dbg_mon_item_4(dbg_mon_item_4),
    .dbg_mon_item_5(dbg_mon_item_5),
    .dbg_mon_item_6(dbg_mon_item_6),
    .dbg_mon_item_7(dbg_mon_item_7),
    .dbg_mon_valid_0(dbg_mon_valid_0),
    .dbg_mon_valid_1(dbg_mon_valid_1),
    .dbg_mon_valid_2(dbg_mon_valid_2),
    .dbg_mon_valid_3(dbg_mon_valid_3),
    .dbg_mon_valid_4(dbg_mon_valid_4),
    .dbg_mon_valid_5(dbg_mon_valid_5),
    .dbg_mon_valid_6(dbg_mon_valid_6),
    .dbg_mon_valid_7(dbg_mon_valid_7),
    .dbg_mon_ready_0(dbg_mon_ready_0),
    .dbg_mon_ready_1(dbg_mon_ready_1),
    .dbg_mon_ready_2(dbg_mon_ready_2),
    .dbg_mon_ready_3(dbg_mon_ready_3),
    .dbg_mon_ready_4(dbg_mon_ready_4),
    .dbg_mon_ready_5(dbg_mon_ready_5),
    .dbg_mon_ready_6(dbg_mon_ready_6),
    .dbg_mon_ready_7(dbg_mon_ready_7)
  );

  // ============================================================================
  // ILA Probe Assignments
  // ============================================================================
  
  // 200-bit probes: one full 200-bit probe per arbiter input item
  assign probe0_0 = board_m_axis_tdata;
  assign probe1_0 = dbg_read_ptr;
  assign probe2_0 = dbg_write_ptr;
  assign probe3_0 = dbg_mon_item_3;
  assign probe4_0 = dbg_mon_item_4;
  assign probe5_0 = dbg_mon_item_5;
  assign probe6_0 = dbg_mon_item_6;
  assign probe7_0 = dbg_mon_item_7;

  // 32-bit probes: Individual APB signals (one per probe), packing the APB handshake signals into the 1-bit probes below
  assign probe8_0  = apb_s_paddr;        // Slave APB Address
  assign probe9_0  = apb_s_pwdata;       // Slave APB Write Data
  assign probe10_0 = apb_s_prdata;       // Slave APB Read Data
  assign probe11_0 = apb_m_paddr;        // Master APB Address
  assign probe12_0 = apb_m_pwdata;       // Master APB Write Data
  assign probe13_0 = apb_m_prdata;       // Master APB Read Data 
  assign probe14_0 = {'0, apb_s_pwrite, apb_s_penable, apb_s_pready, apb_s_pslverr}; // Slave APB Ready and Slave Error
  assign probe15_0 = {'0, apb_m_pwrite, apb_m_penable, apb_m_pready, apb_m_pslverr}; // Master APB Ready and Master Error

  // 1-bit probes: APB and AXIS control/handshake signals
  
  // Slave APB control signals
  // Map per-mon-port handshake signals to the 1-bit probes
  assign probe16_0 = board_m_axis_tready;
  assign probe17_0 = board_m_axis_tvalid;
  assign probe18_0 = dbg_reading;
  assign probe19_0 = dbg_write_fire;
  assign probe20_0 = dbg_read_fire;
  assign probe21_0 = dbg_read_start;
  assign probe22_0 = dbg_mon_valid_3;
  assign probe23_0 = dbg_mon_ready_3;
  assign probe24_0 = dbg_mon_valid_4;
  assign probe25_0 = dbg_mon_ready_4;
  assign probe26_0 = dbg_mon_valid_5;
  assign probe27_0 = dbg_mon_ready_5;
  assign probe28_0 = dbg_mon_valid_6;
  assign probe29_0 = dbg_mon_ready_6;
  assign probe30_0 = dbg_mon_valid_7;
  assign probe31_0 = dbg_mon_ready_7;


endmodule
