`ifndef BOARD_APB_MASTER_TRANSACTOR_INCLUDED_
`define BOARD_APB_MASTER_TRANSACTOR_INCLUDED_

module board_apb_master_transactor #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                  pclk,
  input  logic                  preset_n,

  // Command interface (from board control plane)
  input  logic                  cmd_valid,
  output logic                  cmd_ready,
  input  logic                  cmd_write,
  input  logic [ADDR_WIDTH-1:0] cmd_addr,
  input  logic [DATA_WIDTH-1:0] cmd_wdata,
  input  logic [31:0]           cmd_transmit_delay,

  // Response interface (to board control plane)
  output logic                  rsp_valid,
  input  logic                  rsp_ready,
  output logic [DATA_WIDTH-1:0] rsp_rdata,
  output logic                  rsp_pslverr,
  output logic [31:0]           rsp_response_delay,

  // APB pins driven by this transactor
  output logic                  penable,
  output logic                  psel,
  output logic                  pwrite,
  output logic [ADDR_WIDTH-1:0] paddr,
  output logic [DATA_WIDTH-1:0] pwdata,
  input  logic                  pready,
  input  logic [DATA_WIDTH-1:0] prdata,
  input  logic                  pslverr
);

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_SETUP,
    ST_ACCESS,
    ST_RSP
  } state_t;

  state_t       state_q;
  logic [31:0]  response_delay_q;

  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      state_q             <= ST_IDLE;
      cmd_ready           <= 1'b1;
      rsp_valid           <= 1'b0;
      rsp_rdata           <= '0;
      rsp_pslverr         <= 1'b0;
      rsp_response_delay  <= '0;
      psel                <= 1'b0;
      penable             <= 1'b0;
      pwrite              <= 1'b0;
      paddr               <= '0;
      pwdata              <= '0;
      response_delay_q    <= '0;
    end else begin
      case (state_q)

        ST_IDLE: begin
          cmd_ready <= 1'b1;
          rsp_valid <= 1'b0;

          if (cmd_valid && cmd_ready) begin
            // Latch command and start APB setup phase.
            psel             <= 1'b1;
            penable          <= 1'b0;
            pwrite           <= cmd_write;
            paddr            <= cmd_addr;
            pwdata           <= cmd_wdata;
            cmd_ready        <= 1'b0;

            // Load programmed delay and clear measured response delay.
            response_delay_q <= 32'd0;

            state_q          <= ST_SETUP;
          end
        end

        ST_SETUP: begin
          // Move to APB access phase.
          penable <= 1'b1;
          state_q <= ST_ACCESS;
        end

        ST_ACCESS: begin
          // Count cycles spent in access phase waiting for completion.
          response_delay_q <= response_delay_q + 32'd1;


          // Complete only when APB slave is ready
          if (pready) begin
            rsp_rdata          <= prdata;
            rsp_pslverr        <= pslverr;
            rsp_response_delay <= response_delay_q + 32'd1;
            rsp_valid          <= 1'b1;

            psel               <= 1'b0;
            penable            <= 1'b0;

            state_q            <= ST_RSP;
          end
        end

        ST_RSP: begin
          if (rsp_ready) begin
            rsp_valid <= 1'b0;
            cmd_ready <= 1'b1;
            state_q   <= ST_IDLE;
          end
        end

        default: begin
          state_q <= ST_IDLE;
        end

      endcase
    end
  end

endmodule : board_apb_master_transactor

`endif