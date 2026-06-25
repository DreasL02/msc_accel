`ifndef HVL_TOP_INCLUDED_
`define HVL_TOP_INCLUDED_

//--------------------------------------------------------------------------------------------
// Module : hvl_top
//  Starts the testbench components
//--------------------------------------------------------------------------------------------
module hvl_top;

  //-------------------------------------------------------
  // Importing UVM Package and test Package
  //-------------------------------------------------------
  import uvm_pkg::*;
  import example_design_test_pkg::*;
  
  //-------------------------------------------------------
  // Calling run_test for simulation
  //-------------------------------------------------------
  initial begin
    run_test("example_design_smoke_test");
  end

endmodule : hvl_top

`endif

