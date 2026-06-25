`ifndef BOARD_ARBITER_INCLUDED_
`define BOARD_ARBITER_INCLUDED_

module board_arbiter #(
  parameter int NUM_PORTS  = 16,
  parameter int ITEM_WIDTH = 16,
  localparam int ID_WIDTH  = (NUM_PORTS <= 1) ? 1 : $clog2(NUM_PORTS)
) (
  input  logic clk,
  input  logic rst_n,

  // Input ready/valid per port
  input  logic                  in_valid [NUM_PORTS],
  output logic                  in_ready [NUM_PORTS],
  input  logic [ITEM_WIDTH-1:0] in_data  [NUM_PORTS],

  // Output ready/valid: item + source id
  output logic                  out_valid,
  input  logic                  out_ready,
  output logic [ITEM_WIDTH-1:0] out_data,
  output logic [ID_WIDTH-1:0]   out_id
);

  logic [ID_WIDTH-1:0] rr_start_idx_q;
  logic [ID_WIDTH-1:0] selected_idx;
  logic                selected_valid;

  initial begin
    if (NUM_PORTS <= 0) begin
      $fatal(1, "board_arbiter requires NUM_PORTS > 0. Got %0d", NUM_PORTS);
    end
  end

  // Round-robin arbitration
  always_comb begin
    selected_valid = 1'b0;
    selected_idx   = rr_start_idx_q;

    for (int i = 0; i < NUM_PORTS; i++) begin
      int idx;
      idx = rr_start_idx_q + i;
      if (idx >= NUM_PORTS)
        idx -= NUM_PORTS;

      if (in_valid[idx]) begin
        selected_valid = 1'b1;
        selected_idx   = ID_WIDTH'(idx);
        break;
      end
    end
  end

  // Output side: valid must not depend on ready
  always_comb begin
    out_valid = selected_valid;
    out_id    = selected_idx;
    out_data  = '0;

    if (selected_valid)
      out_data = in_data[selected_idx];
  end

  // Input side backpressure: only selected port sees ready,
  // and only when downstream is ready to complete the transfer
  always_comb begin
    for (int j = 0; j < NUM_PORTS; j++) begin
      in_ready[j] = 1'b0;
    end

    if (selected_valid) begin
      in_ready[selected_idx] = out_ready;
    end
  end

  // Advance round-robin pointer on successful transfer
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rr_start_idx_q <= '0;
    end else if (out_valid && out_ready) begin
      if (selected_idx == ID_WIDTH'(NUM_PORTS - 1))
        rr_start_idx_q <= '0;
      else
        rr_start_idx_q <= selected_idx + ID_WIDTH'(1);
    end
  end

endmodule

`endif