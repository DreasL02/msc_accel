`ifndef EXAMPLE_DESIGN_ENV_CONFIG_INCLUDED_
`define EXAMPLE_DESIGN_ENV_CONFIG_INCLUDED_

class example_design_env_config extends uvm_object;
  `uvm_object_utils(example_design_env_config)
  
  //Enables the scoreboard. 
  bit has_scoreboard;
  bit enable_accel;

  //Handle for master agent configuration
  apb_config apb_master_agent_cfg_h;

  extern function new(string name = "example_design_env_config");
  extern function void do_print(uvm_printer printer);

endclass : example_design_env_config

function example_design_env_config::new(string name = "example_design_env_config");
  super.new(name);
endfunction : new

function void example_design_env_config::do_print(uvm_printer printer);
  super.do_print(printer);
  
  printer.print_field ("has_scoreboard",   has_scoreboard,   $bits(has_scoreboard),   UVM_DEC);
  printer.print_field ("enable_accel",       enable_accel,       $bits(enable_accel),       UVM_DEC);

endfunction : do_print

`endif

