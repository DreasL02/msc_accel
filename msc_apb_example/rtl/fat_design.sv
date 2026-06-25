module fat_design #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int INSTANCES = 1
) (
    input  logic                    PCLK,
    input  logic                    PRESETn,
    // Slave interface (incoming from an APB master)
    input  logic                    s_pselect,
    input  logic                    s_penable,
    input  logic                    s_pwrite,
    input  logic [ADDR_WIDTH-1:0]   s_paddr,
    input  logic [DATA_WIDTH-1:0]   s_pwdata,
    output logic [DATA_WIDTH-1:0]   s_prdata,
    output logic                    s_pready,
    output logic                    s_pslverr
);
  // APB-facing registers
  logic [DATA_WIDTH-1:0] write_reg;
  logic [DATA_WIDTH-1:0] read_reg;
  logic [8:0] cycle_counter;

  // Fold a 32-bit value into 9 bits by XOR-reducing bits spaced by 9.
  function automatic logic [8:0] xor_fold_32_to_9(input logic [31:0] value);
    logic [8:0] folded;
    begin
      for (int b = 0; b < 9; b++) begin
        folded[b] = 1'b0;
        for (int k = b; k < 32; k += 9) begin
          folded[b] ^= value[k];
        end
      end
      xor_fold_32_to_9 = folded;
    end
  endfunction

  // Wires to/from the generated blocks (one per stage)
  logic [8:0] stage_in_bits [0:INSTANCES-1];
  logic        ag_in_ready  [0:INSTANCES-1];
  logic        ag_out_valid [0:INSTANCES-1];
  logic [31:0] ag_out_bits  [0:INSTANCES-1];

  // APB status signals
  assign s_pready = 1'b1; // zero-wait-state slave
  assign s_pslverr = 1'b0;

  // Reads always return the second register regardless of address.
  always_comb begin
    s_prdata = '0;
    if (s_pselect && !s_pwrite) begin
      s_prdata = read_reg;
    end
  end

  // Build the stage chain input: fold to 9 bits, then XOR in the cycle counter.
  always_comb begin
    stage_in_bits[0] = xor_fold_32_to_9(write_reg) ^ cycle_counter;
    for (int i = 1; i < INSTANCES; i++) begin
      stage_in_bits[i] = xor_fold_32_to_9(ag_out_bits[i-1]) ^ cycle_counter;
    end
  end

  // Free-running 9-bit counter and APB write/output register updates.
  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      cycle_counter <= '0;
      write_reg <= '0;
      read_reg  <= '0;
    end else begin
      cycle_counter <= cycle_counter + 9'd1;

      // Any APB write updates the first register regardless of address.
      if (s_pselect && s_penable && s_pwrite) begin
        write_reg <= s_pwdata;
      end

      // Capture output of the last stage into the second register.
      if (ag_out_valid[INSTANCES-1]) begin
        read_reg <= ag_out_bits[INSTANCES-1];
      end
    end
  end

  // Instantiate AutomaticGeneration stages in series.
  generate
    for (genvar gi = 0; gi < INSTANCES; gi++) begin : gen_ag
      AutomaticGeneration automatic_generation_inst (
        .clock(PCLK),
        .reset(~PRESETn),
        .io_inputChannels_0_valid(1'b1),
        .io_inputChannels_0_bits_0_0_0_0(stage_in_bits[gi]),
        .io_outputChannels_0_ready(1'b1),
        .io_inputChannels_0_ready(ag_in_ready[gi]),
        .io_outputChannels_0_valid(ag_out_valid[gi]),
        .io_outputChannels_0_bits_0_0_0_0(ag_out_bits[gi])
      );
    end
  endgenerate

endmodule
