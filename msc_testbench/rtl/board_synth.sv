`ifndef BOARD_SYNTH_INCLUDED_
`define BOARD_SYNTH_INCLUDED_



module board_synth #(
	parameter int ADDR_WIDTH = 32,
	parameter int DATA_WIDTH = 32,
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
	input  logic                                 pclk,
	input logic                                 infra_clk,
	input  logic                                 preset_n,

	input  logic [AXIS_CMD_TDATA_WIDTH-1:0]      s_axis_cmd_tdata,
	input  logic [(AXIS_CMD_TDATA_WIDTH/8)-1:0]  s_axis_cmd_tkeep,
	input  logic                                 s_axis_cmd_tvalid,
	output logic                                 s_axis_cmd_tready,
	input  logic                                 s_axis_cmd_tlast,

	output logic [AXIS_MON_TDATA_WIDTH-1:0]      m_axis_mon_tdata,
	output logic [(AXIS_MON_TDATA_WIDTH/8)-1:0]  m_axis_mon_tkeep,
	output logic                                 m_axis_mon_tvalid,
	input  logic                                 m_axis_mon_tready,
	output logic                                 m_axis_mon_tlast,

	output logic                                 s_apb_pselect,
	output logic                                 s_apb_penable,
	output logic                                 s_apb_pwrite,
	output logic [ADDR_WIDTH-1:0]                s_apb_paddr,
	output logic [DATA_WIDTH-1:0]                s_apb_pwdata,
	output logic [DATA_WIDTH-1:0]                s_apb_prdata,
	output logic                                 s_apb_pready,
	output logic                                 s_apb_pslverr,

	output logic                                 m_apb_pselect,
	output logic                                 m_apb_penable,
	output logic                                 m_apb_pwrite,
	output logic [ADDR_WIDTH-1:0]                m_apb_paddr,
	output logic [DATA_WIDTH-1:0]                m_apb_pwdata,
	output logic [DATA_WIDTH-1:0]                m_apb_prdata,
	output logic                                 m_apb_pready,
	output logic                                 m_apb_pslverr,

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

	board_test_infrastructure #(
		.AXIS_CMD_TDATA_WIDTH(AXIS_CMD_TDATA_WIDTH),
		.AXIS_MON_TDATA_WIDTH(AXIS_MON_TDATA_WIDTH),
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
	) u_board_test_infrastructure (
		.pclk(pclk),
		.infra_clk(infra_clk),
		.preset_n(preset_n),
		.s_axis_cmd_tdata(s_axis_cmd_tdata),
		.s_axis_cmd_tready(s_axis_cmd_tready),
		.s_axis_cmd_tvalid(s_axis_cmd_tvalid),

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
		.m_apb_pslverr(m_apb_pslverr),

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

/*
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
*/
	fat_design #(
		.ADDR_WIDTH(APB_ADDR_WIDTH),
		.DATA_WIDTH(APB_DATA_WIDTH),
		.INSTANCES(1)
	) u_fat_design (
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

/*
	example_design #(
		.ADDR_WIDTH(ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
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
*/
endmodule : board_synth

`endif
