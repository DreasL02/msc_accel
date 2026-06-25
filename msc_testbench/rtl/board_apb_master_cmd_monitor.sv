`ifndef BOARD_APB_MASTER_CMD_MONITOR_INCLUDED_
`define BOARD_APB_MASTER_CMD_MONITOR_INCLUDED_
module board_apb_master_cmd_monitor #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  enabled,
  // Command interface (from board control plane)
  input  logic                  cmd_valid,
  input  logic                  cmd_ready,
  input  logic                  cmd_write,
  input  logic [ADDR_WIDTH-1:0] cmd_addr,
  input  logic [DATA_WIDTH-1:0] cmd_wdata,
  // Response interface (to board control plane)
  input  logic                  rsp_valid,
  input  logic [DATA_WIDTH-1:0] rsp_rdata,
  input  logic                  rsp_pslverr,
  output logic                  item_valid,
  input  logic                  item_ready,
  output logic                  item_write,
  output logic [ADDR_WIDTH-1:0] item_addr,
  output logic [DATA_WIDTH-1:0] item_data,
  output logic                  item_error
);

  logic                  pending_cmd_valid_q;
  logic                  pending_cmd_write_q;
  logic [ADDR_WIDTH-1:0] pending_cmd_addr_q;
  logic [DATA_WIDTH-1:0] pending_cmd_wdata_q;

  logic cmd_fire;
  logic rsp_fire;
  logic item_fire;

  assign cmd_fire  = enabled && cmd_valid && cmd_ready;
  assign item_fire = item_valid && item_ready;

  assign rsp_fire = rsp_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pending_cmd_valid_q <= 1'b0;
      pending_cmd_write_q <= 1'b0;
      pending_cmd_addr_q  <= '0;
      pending_cmd_wdata_q <= '0;
      item_valid          <= 1'b0;
      item_write          <= 1'b0;
      item_addr           <= '0;
      item_data           <= '0;
      item_error          <= 1'b0;
    end else begin
      if (item_fire) begin
        item_valid <= 1'b0;
      end

      if (cmd_fire && !pending_cmd_valid_q) begin
        pending_cmd_valid_q <= 1'b1;
        pending_cmd_write_q <= cmd_write;
        pending_cmd_addr_q  <= cmd_addr;
        pending_cmd_wdata_q <= cmd_wdata;
      end

      if (rsp_fire && pending_cmd_valid_q) begin
        item_valid          <= 1'b1;
        item_write          <= pending_cmd_write_q;
        item_addr           <= pending_cmd_addr_q;
        item_data           <= pending_cmd_write_q ? pending_cmd_wdata_q : rsp_rdata;
        item_error          <= rsp_pslverr;
        pending_cmd_valid_q <= 1'b0;
      end
    end
  end

endmodule : board_apb_master_cmd_monitor
`endif