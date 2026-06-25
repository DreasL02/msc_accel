`ifndef EXAMPLE_DESIGN_ENV_PKG_INCLUDED_
`define EXAMPLE_DESIGN_ENV_PKG_INCLUDED_


package example_design_env_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import apb_pkg::*;

  import accel_pkg::*;


  `include "example_design_env_config.sv"
  `include "example_design_scoreboard.sv"
  `include "example_design_env.sv"

endpackage : example_design_env_pkg

`endif

