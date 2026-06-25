`ifndef EXAMPLE_DESIGN_SMOKE_TEST_INCLUDED_
`define EXAMPLE_DESIGN_SMOKE_TEST_INCLUDED_

class example_design_smoke_test extends example_design_base_test;
  `uvm_component_utils(example_design_smoke_test)

  extern function new(string name = "example_design_smoke_test", uvm_component parent = null);
  extern virtual task run_phase(uvm_phase phase);

endclass : example_design_smoke_test

function example_design_smoke_test::new(string name = "example_design_smoke_test", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

task example_design_smoke_test::run_phase(uvm_phase phase);
  int iterations;
  int fifo_limit;
  super.run_phase(phase);
  fifo_limit  = 500;
  iterations = 100;

  phase.raise_objection(this);
  for (int i = 0; i < iterations; i++) begin
    for (int j = 0; j < fifo_limit; j++) begin
        apb_pkg::apb_write_or_read_seq m_master_seq = apb_pkg::apb_write_or_read_seq::type_id::create("m_master_seq");
        m_master_seq.randomize();
        m_master_seq.start(env_h.apb_master_env_h.m_agent.m_sequencer);
    end
    env_h.scoreboard_h.wait_for_completed(fifo_limit*(i+1));
    disable fork;
  end  

  phase.drop_objection(this);
endtask : run_phase

`endif
