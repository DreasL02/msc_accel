`ifndef EXAMPLE_DESIGN_TEST_PKG_INCLUDED_
`define EXAMPLE_DESIGN_TEST_PKG_INCLUDED_

package example_design_test_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;

  import example_design_env_pkg::*;
  import apb_pkg::*;
  import accel_pkg::*;

  `include "example_design_base_test.sv"
  `include "example_design_smoke_test.sv"

endpackage : example_design_test_pkg

`endif
