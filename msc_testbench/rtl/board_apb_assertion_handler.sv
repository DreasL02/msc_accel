module board_apb_assertion_handler #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                  pclk,
  input  logic                  preset_n,
  input  logic                  psel,
  input  logic                  penable,
  input  logic                  pwrite,
  input  logic [ADDR_WIDTH-1:0] paddr,
  input  logic [DATA_WIDTH-1:0] pwdata,
  input  logic                  pready,
  input  logic [DATA_WIDTH-1:0] prdata,
  input  logic                  pslverr,
  output logic                  assert_valid,
  input  logic                  assert_ready,
  output logic [ADDR_WIDTH-1:0] assert_addr,
  output logic [DATA_WIDTH-1:0] assert_info
);

  localparam logic [7:0] ERR_PENABLE_WITHOUT_PSEL     = 8'h01;
  localparam logic [7:0] ERR_ACCESS_WITHOUT_SETUP     = 8'h02;
  localparam logic [7:0] ERR_SETUP_NOT_FOLLOWED       = 8'h03;
  localparam logic [7:0] ERR_CTRL_CHANGED_IN_WAIT     = 8'h04;
  localparam logic [7:0] ERR_PSLVERR_OUTSIDE_COMPLETE = 8'h05;
  localparam logic [7:0] ERR_ACCESS_DROPPED_EARLY     = 8'h06;

  logic prev_setup_q;
  logic prev_wait_q;

  logic [ADDR_WIDTH-1:0] access_addr_q;
  logic [DATA_WIDTH-1:0] access_wdata_q;
  logic                  access_write_q;

  logic                  violation;
  logic [7:0]            violation_code;
  logic [ADDR_WIDTH-1:0] violation_addr;
  logic                  can_post;

  assign can_post = (!assert_valid || assert_ready);

  always_comb begin
    violation      = 1'b0;
    violation_code = 8'h00;
    violation_addr = paddr;

    // PENABLE must not be high without PSEL
    if (penable && !psel) begin
      violation      = 1'b1;
      violation_code = ERR_PENABLE_WITHOUT_PSEL;
    end

    // Access must be preceded by setup in previous cycle
    else if (psel && penable && !prev_setup_q && !prev_wait_q) begin
      violation      = 1'b1;
      violation_code = ERR_ACCESS_WITHOUT_SETUP;
    end

    // Setup must be followed by access
    else if (prev_setup_q && !(psel && penable)) begin
      violation      = 1'b1;
      violation_code = ERR_SETUP_NOT_FOLLOWED;
    end

    // During wait states, controls must remain stable
    else if (prev_wait_q) begin
      if (!psel || !penable) begin
        violation      = 1'b1;
        violation_code = ERR_ACCESS_DROPPED_EARLY;
      end
      else if ((paddr != access_addr_q) ||
               (pwrite != access_write_q) ||
               (pwrite && (pwdata != access_wdata_q))) begin
        violation      = 1'b1;
        violation_code = ERR_CTRL_CHANGED_IN_WAIT;
      end
    end

    // PSLVERR only valid on completion
    if (!violation && pslverr && !(psel && penable && pready)) begin
      violation      = 1'b1;
      violation_code = ERR_PSLVERR_OUTSIDE_COMPLETE;
    end
  end

  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      prev_setup_q   <= 1'b0;
      prev_wait_q    <= 1'b0;
      assert_valid   <= 1'b0;
      assert_addr    <= '0;
      assert_info    <= '0;
      access_addr_q  <= '0;
      access_wdata_q <= '0;
      access_write_q <= 1'b0;
    end
    else begin
      // Track setup phase
      prev_setup_q <= (psel && !penable);

      // Track whether current cycle is an unfinished access
      prev_wait_q <= (psel && penable && !pready);

      // Capture transfer attributes at setup
      if (psel && !penable) begin
        access_addr_q  <= paddr;
        access_wdata_q <= pwdata;
        access_write_q <= pwrite;
      end

      if (assert_valid && assert_ready)
        assert_valid <= 1'b0;

      if (can_post && violation) begin
        assert_valid <= 1'b1;
        assert_addr  <= violation_addr;
        assert_info  <= '0;
        assert_info[DATA_WIDTH-1 -: 8] <= violation_code;
      end
    end
  end

endmodule