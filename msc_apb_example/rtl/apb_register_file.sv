module apb_register_file #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_REGS   = 16
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

    localparam int ADDR_LSB   = (DATA_WIDTH <= 8)  ? 0 :
                                (DATA_WIDTH <= 16) ? 1 :
                                (DATA_WIDTH <= 32) ? 2 :
                                (DATA_WIDTH <= 64) ? 3 : 4;
    localparam int REG_INDEX_W = (NUM_REGS > 1) ? $clog2(NUM_REGS) : 1;

    logic [DATA_WIDTH-1:0] regfile [0:NUM_REGS-1];
    logic [REG_INDEX_W-1:0] reg_index;
    logic                   addr_valid;
    logic                   apb_access;

    assign reg_index  = s_paddr[ADDR_LSB + REG_INDEX_W - 1 : ADDR_LSB];
    assign addr_valid = (reg_index < NUM_REGS);
    assign apb_access = s_pselect && s_penable;

    assign s_pready = 1'b1;

    always_comb begin
        s_prdata  = '0;
        s_pslverr = 1'b0;

        if (apb_access) begin
            if (!addr_valid) begin
                s_pslverr = 1'b1;
            end else if (!s_pwrite) begin
                s_prdata = regfile[reg_index];
            end
        end

`ifdef INJECT_APB_ASSERT_ERROR
        // Intentional APB protocol violation for checker testing:
        // PSLVERR asserted during setup phase instead of completion phase
        if (s_pselect && !s_penable) begin
            s_pslverr = 1'b1;
        end
`endif
    end

    integer i;
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            for (i = 0; i < NUM_REGS; i++) begin
                regfile[i] <= '0;
            end
        end else begin
            if (apb_access && s_pwrite && addr_valid) begin
                regfile[reg_index] <= s_pwdata;
            end
        end
    end

endmodule