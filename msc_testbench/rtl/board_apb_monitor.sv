`ifndef BOARD_APB_MONITOR_INCLUDED_
`define BOARD_APB_MONITOR_INCLUDED_

module board_apb_monitor #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter logic TRIGGER_ON_REQUEST = 1'b1
) (
  input  logic                  pclk,
  input  logic                  preset_n,

  // Observed APB channel
  input  logic                  psel,
  input  logic                  penable,
  input  logic                  pwrite,
  input  logic [ADDR_WIDTH-1:0] paddr,
  input  logic [DATA_WIDTH-1:0] pwdata,
  input  logic [DATA_WIDTH-1:0] prdata,
  input  logic                  pready,
  input  logic                  pslverr,

  // Monitor item stream
  output logic                  item_valid,
  output logic                  item_write,
  output logic [ADDR_WIDTH-1:0] item_addr,
  output logic [DATA_WIDTH-1:0] item_data,
  output logic                  item_error
);

  typedef enum logic [0:0] {
    ST_IDLE,
    ST_WAIT_ACCESS
  } apb_mon_state_e;

  apb_mon_state_e state_q, state_d;

  logic setup_phase;
  logic access_done;

  logic                  req_write_q;
  logic [ADDR_WIDTH-1:0] req_addr_q;
  logic [DATA_WIDTH-1:0] req_wdata_q;

  assign setup_phase = psel && !penable;
  assign access_done = psel && penable && pready;

  always_comb begin
    state_d = state_q;
    case (state_q)
      ST_IDLE: begin
        if (setup_phase) begin
          state_d = ST_WAIT_ACCESS;
        end
      end

      ST_WAIT_ACCESS: begin
        if (access_done) begin
          state_d = ST_IDLE;
        end
      end

      default: begin
        state_d = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      state_q     <= ST_IDLE;
      item_valid  <= 1'b0;
      item_write  <= 1'b0;
      item_addr   <= '0;
      item_data   <= '0;
      item_error  <= 1'b0;
      req_write_q <= 1'b0;
      req_addr_q  <= '0;
      req_wdata_q <= '0;
    end else begin
      state_q    <= state_d;
      item_valid <= 1'b0;

      case (state_q)
        ST_IDLE: begin
          if (setup_phase && TRIGGER_ON_REQUEST) begin
            item_valid <= 1'b1;
            item_write <= pwrite;
            item_addr  <= paddr;
            item_data  <= pwrite ? pwdata : '0;
            item_error <= 1'b0;
          end
        end

        ST_WAIT_ACCESS: begin
          if (access_done && !TRIGGER_ON_REQUEST) begin
            item_valid <= 1'b1;
            item_write <= pwrite;
            item_addr  <= paddr;
            item_data  <= pwrite ? pwdata : prdata;
            item_error <= pslverr;
          end
        end

        default: begin
          item_valid <= 1'b0;
        end
      endcase
    end
  end

endmodule : board_apb_monitor

`endif