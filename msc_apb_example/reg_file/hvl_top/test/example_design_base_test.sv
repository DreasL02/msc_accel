`ifndef EXAMPLE_DESIGN_BASE_TEST_INCLUDED_
`define EXAMPLE_DESIGN_BASE_TEST_INCLUDED_

`ifndef SCOREBOARD_DRAIN_TIMEOUT_NS
`define SCOREBOARD_DRAIN_TIMEOUT_NS 2000000
`endif

class example_design_base_test extends uvm_test;
  `uvm_component_utils(example_design_base_test)

  example_design_env env_h;
  example_design_env_config env_cfg_h;

  extern function new(string name = "example_design_base_test", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void setup_example_design_env_config();
  extern virtual function void setup_apb_master_agent_config();
  extern virtual function void end_of_elaboration_phase(uvm_phase phase);
  extern virtual task run_phase(uvm_phase phase);
endclass : example_design_base_test

function example_design_base_test::new(string name = "example_design_base_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new


function void example_design_base_test::build_phase(uvm_phase phase);
  super.build_phase(phase);

  setup_example_design_env_config();

  uvm_config_db#(example_design_env_config)::set(this, "*", "example_design_env_config", env_cfg_h);

  env_h = example_design_env::type_id::create("env", this);
endfunction : build_phase

function void example_design_base_test::setup_example_design_env_config();
  env_cfg_h = example_design_env_config::type_id::create("example_design_env_config");
  env_cfg_h.has_scoreboard = 1;

`ifdef EXAMPLE_DESIGN_ACCEL_MODE
  env_cfg_h.enable_accel = (`EXAMPLE_DESIGN_ACCEL_MODE != 0);
`else
  env_cfg_h.enable_accel = 1;
`endif

  // Prevent ACCEL connector from opening socket threads when ACCEL is disabled.
  con.server_connector_config.toggle = env_cfg_h.enable_accel;

  setup_apb_master_agent_config();

  `uvm_info(get_type_name(), $sformatf("\nEXAMPLE_DESIGN_ENV_CONFIG\n%s", env_cfg_h.sprint()), UVM_LOW)
endfunction : setup_example_design_env_config

function void example_design_base_test::setup_apb_master_agent_config();
  env_cfg_h.apb_master_agent_cfg_h = apb_config::type_id::create("apb_master_agent_config");

  env_cfg_h.apb_master_agent_cfg_h                   = apb_pkg::apb_config::type_id::create(.name("apb_config"), .parent(this));
  env_cfg_h.apb_master_agent_cfg_h.c_type_id         = 0;
  env_cfg_h.apb_master_agent_cfg_h.c_id              = 1;
  env_cfg_h.apb_master_agent_cfg_h.c_name            = "MASTER";
  env_cfg_h.apb_master_agent_cfg_h.c_is_active       = UVM_ACTIVE;
  env_cfg_h.apb_master_agent_cfg_h.c_is_tx           = 1'b1;
  env_cfg_h.apb_master_agent_cfg_h.c_coverage_enable = 1'b0;
  env_cfg_h.apb_master_agent_cfg_h.c_error_is_ignored = 1'b1;
  env_cfg_h.apb_master_agent_cfg_h.c_expect_errors    = 1'b0;

  env_cfg_h.apb_master_agent_cfg_h.use_accel = env_cfg_h.enable_accel;
  env_cfg_h.apb_master_agent_cfg_h.accel_driver_config_h = accel_driver_config::type_id::create("example_design_master_accel_driver_config_h");
  env_cfg_h.apb_master_agent_cfg_h.accel_driver_config_h.protocol_identifier = 0;
  env_cfg_h.apb_master_agent_cfg_h.accel_driver_config_h.wait_for_response = 0; 
  env_cfg_h.apb_master_agent_cfg_h.accel_monitor_config_h = accel_monitor_config::type_id::create("example_design_master_accel_monitor_config_h");
  env_cfg_h.apb_master_agent_cfg_h.accel_monitor_config_h.request_protocol_identifier = 6; 
  env_cfg_h.apb_master_agent_cfg_h.accel_monitor_config_h.response_protocol_identifier = 5;
endfunction : setup_apb_master_agent_config


function void example_design_base_test::end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  uvm_top.print_topology();
endfunction : end_of_elaboration_phase

task example_design_base_test::run_phase(uvm_phase phase);
  phase.raise_objection(this);
  super.run_phase(phase);
  phase.drop_objection(this);
endtask : run_phase

`endif
