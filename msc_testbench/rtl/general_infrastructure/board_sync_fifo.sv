module board_sync_fifo #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 1024
) (
  input  logic             clk,
  input  logic             rst_n,

  input  logic             wr_en,
  input  logic [WIDTH-1:0] wr_data,
  output logic             full,

  input  logic             rd_en,
  output logic [WIDTH-1:0] rd_data,
  output logic             rd_valid,
  output logic             empty
);

  localparam int ADDR_WIDTH = $clog2(DEPTH);

  (* ram_style = "block" *) logic [WIDTH-1:0] mem [0:DEPTH-1];

  logic [ADDR_WIDTH-1:0] wr_ptr_q, rd_ptr_q;
  logic [ADDR_WIDTH:0]   count_q;

  logic wr_fire, rd_fire;

  assign full  = (count_q == DEPTH);
  assign empty = (count_q == 0);

  assign wr_fire = wr_en && !full;
  assign rd_fire = rd_en && !empty;

  // BRAM write + synchronous read
  always_ff @(posedge clk) begin
    if (wr_fire)
      mem[wr_ptr_q] <= wr_data;

    if (rd_fire)
      rd_data <= mem[rd_ptr_q];

    rd_valid <= rd_fire;
  end

  // FIFO pointers and occupancy
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr_q <= '0;
      rd_ptr_q <= '0;
      count_q  <= '0;
    end else begin
      if (wr_fire) begin
        if (wr_ptr_q == DEPTH-1)
          wr_ptr_q <= '0;
        else
          wr_ptr_q <= wr_ptr_q + 1'b1;
      end

      if (rd_fire) begin
        if (rd_ptr_q == DEPTH-1)
          rd_ptr_q <= '0;
        else
          rd_ptr_q <= rd_ptr_q + 1'b1;
      end

      case ({wr_fire, rd_fire})
        2'b10: count_q <= count_q + 1'b1;
        2'b01: count_q <= count_q - 1'b1;
        default: count_q <= count_q;
      endcase
    end
  end

endmodule