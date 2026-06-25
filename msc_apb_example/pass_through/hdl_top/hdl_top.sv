`default_nettype none

module hdl_top();
    import uvm_pkg::*;
    import apb_pkg::*;

    parameter CLOCK_PERIOD = 10;
    parameter RESET_TIME = 50;
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;


    bit clk   = 1'b0;
    bit rst_n = 1'b0;
    
    apb_if  #(
        .PADDR_WIDTH(ADDR_WIDTH), 
        .PWDATA_WIDTH(DATA_WIDTH), 
        .PRDATA_WIDTH(DATA_WIDTH)
    ) master_apb_interface ( // active requester
        .clk(clk),
        .rst_n(rst_n)
    );

    apb_if  #(
        .PADDR_WIDTH(ADDR_WIDTH), 
        .PWDATA_WIDTH(DATA_WIDTH), 
        .PRDATA_WIDTH(DATA_WIDTH)
    ) slave_apb_interface ( // active responder
        .clk(clk),
        .rst_n(rst_n)
    );

  // DUT
  example_design #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
    .PCLK    (clk),
    .PRESETn (rst_n),

    // Incoming APB side (driven by master BFM)
    .s_pselect (master_apb_interface.psel),
    .s_penable (master_apb_interface.penable),
    .s_pwrite  (master_apb_interface.pwrite),
    .s_paddr   (master_apb_interface.paddr),
    .s_pwdata  (master_apb_interface.pwdata),
    .s_prdata  (master_apb_interface.prdata),
    .s_pready  (master_apb_interface.pready),
    .s_pslverr (master_apb_interface.pslverr),

    // Forwarded APB side (observed/driven by slave BFM)
    .m_pselect (slave_apb_interface.psel),
    .m_penable (slave_apb_interface.penable),
    .m_pwrite  (slave_apb_interface.pwrite),
    .m_paddr   (slave_apb_interface.paddr),
    .m_pwdata  (slave_apb_interface.pwdata),
    .m_prdata  (slave_apb_interface.prdata),
    .m_pready  (slave_apb_interface.pready),
    .m_pslverr (slave_apb_interface.pslverr)
  );


  always #CLOCK_PERIOD clk <= ~clk;
  initial begin
      #RESET_TIME rst_n <= 1'b1;
  end

  initial begin
    uvm_config_db#(virtual apb_if #(ADDR_WIDTH, DATA_WIDTH, DATA_WIDTH))::set(
      null,
      "uvm_test_top.env.apb_master_env_h*",
      "apb_if",
      master_apb_interface
    );
    uvm_config_db#(virtual apb_if #(ADDR_WIDTH, DATA_WIDTH, DATA_WIDTH))::set(
      null,
      "uvm_test_top.env.apb_slave_env_h*",
      "apb_if",
      slave_apb_interface
    );
  end

endmodule
