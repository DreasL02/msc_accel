`ifndef EXAMPLE_DESIGN_ENV_INCLUDED_
`define EXAMPLE_DESIGN_ENV_INCLUDED_

class example_design_env extends uvm_env;
  `uvm_component_utils(example_design_env)

  apb_pkg::apb_env#() apb_master_env_h;
  apb_pkg::apb_env#() apb_slave_env_h;

  example_design_env_config env_cfg_h;

  example_design_scoreboard scoreboard_h;


  extern function new(string name = "example_design_env", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);

endclass : example_design_env

function example_design_env::new(string name = "example_design_env",uvm_component parent = null);
  super.new(name, parent);
endfunction : new


function void example_design_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if(!uvm_config_db#(example_design_env_config)::get(this, "", "example_design_env_config", env_cfg_h)) begin
    `uvm_fatal(get_type_name(), "example_design_env_config not found in config_db")
  end

  if(env_cfg_h.has_scoreboard) begin
    scoreboard_h = example_design_scoreboard::type_id::create("scoreboard_h", this);
  end

  if(env_cfg_h.apb_master_agent_cfg_h == null) begin
    `uvm_fatal(get_type_name(), "apb_master_agent_cfg_h is null in example_design_env_config")
  end

  if(env_cfg_h.apb_slave_agent_cfg_h == null) begin
    `uvm_fatal(get_type_name(), "apb_slave_agent_cfg_h is null in example_design_env_config")
  end

  // Pass child agent configs through child envs
  uvm_config_db#(apb_config)::set(this, "apb_master_env_h*", "apb_config", env_cfg_h.apb_master_agent_cfg_h);
  uvm_config_db#(apb_config)::set(this, "apb_slave_env_h*", "apb_config", env_cfg_h.apb_slave_agent_cfg_h);

  apb_master_env_h = apb_pkg::apb_env#()::type_id::create("apb_master_env_h", this);
  apb_slave_env_h = apb_pkg::apb_env#()::type_id::create("apb_slave_env_h", this);

  if (env_cfg_h.apb_master_agent_cfg_h.use_accel) begin
    if (env_cfg_h.apb_master_agent_cfg_h.accel_driver_config_h == null) begin
      env_cfg_h.apb_master_agent_cfg_h.accel_driver_config_h = accel_driver_config::type_id::create("example_design_master_accel_driver_config_h");
    end
    if (env_cfg_h.apb_master_agent_cfg_h.accel_monitor_config_h == null) begin
      env_cfg_h.apb_master_agent_cfg_h.accel_monitor_config_h = accel_monitor_config::type_id::create("example_design_master_accel_monitor_config_h");
    end

    uvm_config_db#(accel_server_connector)::set(this, "apb_master_env_h*", "accel_server_connector", con);
    uvm_config_db#(accel_driver_config)::set(this, "apb_master_env_h*", "accel_driver_config", env_cfg_h.apb_master_agent_cfg_h.accel_driver_config_h);
    uvm_config_db#(accel_monitor_config)::set(this, "apb_master_env_h*", "accel_monitor_config", env_cfg_h.apb_master_agent_cfg_h.accel_monitor_config_h);
  end

  if (env_cfg_h.apb_slave_agent_cfg_h.use_accel) begin
    if (env_cfg_h.apb_slave_agent_cfg_h.accel_driver_config_h == null) begin
      env_cfg_h.apb_slave_agent_cfg_h.accel_driver_config_h = accel_driver_config::type_id::create("example_design_slave_accel_driver_config_h");
    end
    if (env_cfg_h.apb_slave_agent_cfg_h.accel_monitor_config_h == null) begin
      env_cfg_h.apb_slave_agent_cfg_h.accel_monitor_config_h = accel_monitor_config::type_id::create("example_design_slave_accel_monitor_config_h");
    end

    uvm_config_db#(accel_server_connector)::set(this, "apb_slave_env_h*", "accel_server_connector", con);
    uvm_config_db#(accel_driver_config)::set(this, "apb_slave_env_h*", "accel_driver_config", env_cfg_h.apb_slave_agent_cfg_h.accel_driver_config_h);
    uvm_config_db#(accel_monitor_config)::set(this, "apb_slave_env_h*", "accel_monitor_config", env_cfg_h.apb_slave_agent_cfg_h.accel_monitor_config_h);
  end
endfunction : build_phase

function void example_design_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  
  if(env_cfg_h.has_scoreboard) begin
    // Connect monitors' analysis ports to the scoreboard
    apb_slave_env_h.req_axp.connect(scoreboard_h.request_export);
    apb_master_env_h.m_axp.connect(scoreboard_h.monitor_export);
  end
  
endfunction : connect_phase

`endif

