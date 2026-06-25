`ifndef BOARD_APB_SLAVE_CMD_MONITOR_INCLUDED_
`define BOARD_APB_SLAVE_CMD_MONITOR_INCLUDED_
module board_apb_slave_cmd_monitor #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  enabled,
  // Completion interface from board control plane:
  // "Here is the APB response to return"
  input  logic                  rsp_valid,
  output logic                  rsp_ready,
  input  logic                  rsp_write,
  input  logic [ADDR_WIDTH-1:0] rsp_addr,
  input  logic [DATA_WIDTH-1:0] rsp_wdata,
  // Request interface to board control plane:
  // "An APB transaction arrived"
  input  logic                  cmd_valid,
  input  logic                  cmd_ready,
  input  logic [DATA_WIDTH-1:0] cmd_rdata,
  input  logic                  cmd_pslverr,

  output logic                  item_valid,
  input  logic                  item_ready,
  output logic                  item_write,
  output logic [ADDR_WIDTH-1:0] item_addr,
  output logic [DATA_WIDTH-1:0] item_data,
  output logic                  item_error
);

  logic                  have_cmd_q;
  logic [DATA_WIDTH-1:0] cmd_rdata_q;
  logic                  cmd_pslverr_q;

  logic cmd_fire, rsp_fire, item_fire;

  assign cmd_fire  = enabled && cmd_valid && cmd_ready;
  assign item_fire = item_valid && item_ready;

  // Only accept a response when a previously captured command exists
  // and the output item register is free (or being freed this cycle).
  assign rsp_ready = have_cmd_q &&
                    (!item_valid || item_ready);

  assign rsp_fire = rsp_valid && rsp_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      have_cmd_q    <= 1'b0;
      cmd_rdata_q   <= '0;
      cmd_pslverr_q <= 1'b0;
      item_valid    <= 1'b0;
      item_write    <= 1'b0;
      item_addr     <= '0;
      item_data     <= '0;
      item_error    <= 1'b0;
    end else begin
      // Consume output item if accepted
      if (item_fire) begin
        item_valid <= 1'b0;
      end

      // Capture command first. Only one outstanding command is supported.
      if (cmd_fire && !have_cmd_q) begin
        have_cmd_q    <= 1'b1;
        cmd_rdata_q   <= cmd_rdata;
        cmd_pslverr_q <= cmd_pslverr;
      end

      // When the matching response is accepted, emit the combined item.
      if (rsp_fire) begin
        item_valid    <= 1'b1;
        item_write    <= rsp_write;
        item_addr     <= rsp_addr;
        item_data     <= rsp_write ? rsp_wdata : cmd_rdata_q;
        item_error    <= cmd_pslverr_q;
        have_cmd_q    <= 1'b0;
      end
    end
  end

endmodule
`endif