module board_fifo_wrapper #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 1024
) (
  input  logic             clk,
  input  logic             rst_n,

  // Input ready/valid interface
  input  logic             in_valid,
  output logic             in_ready,
  input  logic [WIDTH-1:0] in_data,

  // Output ready/valid interface
  output logic             out_valid,
  input  logic             out_ready,
  output logic [WIDTH-1:0] out_data
);

  // --------------------------------------------------------------------------
  // FIFO side signals
  // --------------------------------------------------------------------------
  logic             fifo_wr_en;
  logic [WIDTH-1:0] fifo_wr_data;
  logic             fifo_full;

  logic             fifo_rd_en;
  logic [WIDTH-1:0] fifo_rd_data;
  logic             fifo_rd_valid;
  logic             fifo_empty;

  // --------------------------------------------------------------------------
  // Output skid/holding register
  //
  // Since the FIFO read is synchronous, fifo_rd_en requests data and
  // fifo_rd_valid/fifo_rd_data arrive one cycle later. We store that data here
  // and expose it with standard ready/valid semantics.
  // --------------------------------------------------------------------------
  logic             out_valid_q;
  logic [WIDTH-1:0] out_data_q;

  assign out_valid = out_valid_q;
  assign out_data  = out_data_q;

  // --------------------------------------------------------------------------
  // Input interface -> FIFO write side
  // --------------------------------------------------------------------------
  assign in_ready   = !fifo_full;
  assign fifo_wr_en = in_valid && in_ready;
  assign fifo_wr_data = in_data;

  // --------------------------------------------------------------------------
  // Read control
  //
  // We issue a FIFO read when:
  // - FIFO is not empty
  // - no read is already in flight
  // - output holding register is empty, OR it will be consumed this cycle
  //
  // "read_inflight_q" tracks that we have already sent rd_en and are waiting
  // for fifo_rd_valid next cycle.
  // --------------------------------------------------------------------------
  logic read_inflight_q;
  logic out_take;

  assign out_take = out_valid && out_ready;

  always_comb begin
    fifo_rd_en = 1'b0;

    if (!fifo_empty &&
        !read_inflight_q &&
        (!out_valid_q || out_take)) begin
      fifo_rd_en = 1'b1;
    end
  end

  // --------------------------------------------------------------------------
  // Output register + inflight tracking
  // --------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_valid_q     <= 1'b0;
      out_data_q      <= '0;
      read_inflight_q <= 1'b0;
    end else begin
      // Track read request in flight
      if (fifo_rd_en)
        read_inflight_q <= 1'b1;
      else if (fifo_rd_valid)
        read_inflight_q <= 1'b0;

      // Consume output when downstream accepts it
      if (out_take)
        out_valid_q <= 1'b0;

      // Capture FIFO read response
      if (fifo_rd_valid) begin
        out_data_q  <= fifo_rd_data;
        out_valid_q <= 1'b1;
      end
    end
  end

  // --------------------------------------------------------------------------
  // FIFO instance
  // --------------------------------------------------------------------------
  board_sync_fifo #(
    .WIDTH(WIDTH),
    .DEPTH(DEPTH)
  ) u_fifo (
    .clk      (clk),
    .rst_n    (rst_n),
    .wr_en    (fifo_wr_en),
    .wr_data  (fifo_wr_data),
    .full     (fifo_full),
    .rd_en    (fifo_rd_en),
    .rd_data  (fifo_rd_data),
    .rd_valid (fifo_rd_valid),
    .empty    (fifo_empty)
  );

endmodule