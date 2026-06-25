// example_design.sv

module example_design #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    // Clock / reset
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
    output logic                    s_pslverr,

    // Master interface (outgoing to a target peripheral)
    output logic                    m_pselect,
    output logic                    m_penable,
    output logic                    m_pwrite,
    output logic [ADDR_WIDTH-1:0]   m_paddr,
    output logic [DATA_WIDTH-1:0]   m_pwdata,
    input  logic [DATA_WIDTH-1:0]   m_prdata,
    input  logic                    m_pready,
    input  logic                    m_pslverr
);
    assign m_pselect = s_pselect;
    assign m_penable = s_penable;
    assign m_pwrite = s_pwrite;
    assign m_paddr = s_paddr;
    assign m_pwdata = s_pwdata;
    assign s_prdata = m_prdata;
    assign s_pready = m_pready;
    assign s_pslverr = m_pslverr;

endmodule
