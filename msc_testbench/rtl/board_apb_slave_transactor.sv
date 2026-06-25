`ifndef BOARD_APB_SLAVE_TRANSACTOR_INCLUDED_
`define BOARD_APB_SLAVE_TRANSACTOR_INCLUDED_
module board_apb_slave_transactor #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                  pclk,
  input  logic                  preset_n,
  output logic                  rsp_valid,
  input  logic                  rsp_ready,
  output logic                  rsp_write,
  output logic [ADDR_WIDTH-1:0] rsp_addr,
  output logic [DATA_WIDTH-1:0] rsp_wdata,
  output logic [31:0]           rsp_transmit_delay,
  input  logic                  cmd_valid,
  output logic                  cmd_ready,
  input  logic [DATA_WIDTH-1:0] cmd_rdata,
  input  logic                  cmd_pslverr,
  input  logic [31:0]           cmd_response_delay,
  input  logic                  psel,
  input  logic                  penable,
  input  logic                  pwrite,
  input  logic [ADDR_WIDTH-1:0] paddr,
  input  logic [DATA_WIDTH-1:0] pwdata,
  output logic                  pready,
  output logic [DATA_WIDTH-1:0] prdata,
  output logic                  pslverr
);

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_WAIT_CMD,
    ST_DELAY,
    ST_RESP,
    ST_RSP_HS
  } state_t;

  state_t state_q;
  logic [31:0] delay_count_q;

  logic                  req_write_q;
  logic [ADDR_WIDTH-1:0] req_addr_q;
  logic [DATA_WIDTH-1:0] req_wdata_q;

  logic [DATA_WIDTH-1:0] cmd_rdata_q;
  logic                  cmd_pslverr_q;
  logic [31:0]           cmd_response_delay_q;

  logic apb_setup, apb_access;

  assign apb_setup  = psel && !penable;
  assign apb_access = psel && penable;

  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      state_q              <= ST_IDLE;
      rsp_valid            <= 1'b0;
      rsp_write            <= 1'b0;
      rsp_addr             <= '0;
      rsp_wdata            <= '0;
      rsp_transmit_delay   <= '0;
      cmd_ready            <= 1'b0;
      pready               <= 1'b0;
      prdata               <= '0;
      pslverr              <= 1'b0;
      delay_count_q        <= '0;
      req_write_q          <= 1'b0;
      req_addr_q           <= '0;
      req_wdata_q          <= '0;
      cmd_rdata_q          <= '0;
      cmd_pslverr_q        <= 1'b0;
      cmd_response_delay_q <= '0;
    end else begin
      // Default outputs each cycle
      cmd_ready <= 1'b0;
      pready    <= 1'b0;
      pslverr   <= 1'b0;

      case (state_q)
        ST_IDLE: begin
          rsp_valid <= 1'b0;
          prdata    <= '0;

          if (apb_setup) begin
            req_write_q <= pwrite;
            req_addr_q  <= paddr;
            req_wdata_q <= pwdata;
            state_q     <= ST_WAIT_CMD;
          end
        end

        ST_WAIT_CMD: begin
          if (!psel) begin
            state_q <= ST_IDLE;
          end else begin
            if (apb_access && cmd_valid) begin
              cmd_rdata_q          <= cmd_rdata;
              cmd_pslverr_q        <= cmd_pslverr;
              cmd_response_delay_q <= cmd_response_delay;
              delay_count_q        <= cmd_response_delay;
              state_q              <= ST_DELAY;
            end else begin
              cmd_ready <= apb_access;
            end
          end
        end

        ST_DELAY: begin
          if (!psel) begin
            state_q <= ST_IDLE;
          end else if (delay_count_q != 0) begin
            delay_count_q <= delay_count_q - 1'b1;
          end else begin
            prdata            <= pwrite ? 0 : cmd_rdata_q;
            pslverr           <= cmd_pslverr_q;
            pready            <= 1'b1;
            rsp_transmit_delay<= 0; // todo
            state_q           <= ST_RESP;
          end
        end

        ST_RESP: begin
          prdata  <= pwrite ? 0 : cmd_rdata_q;
          pslverr <= cmd_pslverr_q;
          pready  <= 1'b1;

          // APB transaction completes in access phase when ready is high.
          if (apb_access) begin
            rsp_valid <= 1'b1;
            rsp_write <= pwrite;
            rsp_addr  <= paddr;
            rsp_wdata <= pwdata;
            state_q   <= ST_RSP_HS;
          end
        end

        ST_RSP_HS: begin
          if (rsp_valid && rsp_ready) begin
            rsp_valid <= 1'b0;
            state_q   <= ST_IDLE;
          end
        end

        default: begin
          state_q   <= ST_IDLE;
          rsp_valid <= 1'b0;
        end
      endcase
    end
  end

endmodule : board_apb_slave_transactor
`endif