`ifndef BOARD_DECODER_INCLUDED_
`define BOARD_DECODER_INCLUDED_

module board_decoder #(
  parameter int NUM_PORTS  = 16,
  parameter int ITEM_WIDTH = 16,
  localparam int ID_WIDTH  = (NUM_PORTS <= 1) ? 1 : $clog2(NUM_PORTS)
) (
  input  logic clk,
  input  logic rst_n,

  input  logic                  in_valid,
  output logic                  in_ready,
  input  logic [ITEM_WIDTH-1:0] in_data,
  input  logic [ID_WIDTH-1:0]   in_id,

  output logic                  out_valid [NUM_PORTS],
  output logic [ITEM_WIDTH-1:0] out_data  [NUM_PORTS],
  input  logic                  out_ready [NUM_PORTS]
);

  integer j;

  initial begin
    if (NUM_PORTS <= 0) begin
      $fatal(1, "board_decoder requires NUM_PORTS > 0. Got %0d", NUM_PORTS);
    end
  end

  always_comb begin
    in_ready = out_ready[in_id];

    for (j = 0; j < NUM_PORTS; j++) begin
      out_valid[j] = in_valid && (in_id == ID_WIDTH'(j));
      out_data[j]  = in_data;
    end
  end

endmodule

`endif