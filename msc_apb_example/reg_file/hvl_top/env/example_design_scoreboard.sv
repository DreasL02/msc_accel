`ifndef APB_UVC_SCOREBOARD_SV
`define APB_UVC_SCOREBOARD_SV

`uvm_analysis_imp_decl(_monitor)

class example_design_scoreboard extends uvm_component;
  `uvm_component_utils(example_design_scoreboard)
  
  uvm_analysis_imp_monitor#(apb_item, example_design_scoreboard) monitor_export;

  int m_matches = 0;
  int m_mismatches = 0;
  protected apb_item m_monitor_queue[$];

  // Constructor - Required UVM syntax
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new
    
    // Class Functions or Tasks
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

  virtual function void m_proc_data();
    apb_item monitor_item = m_monitor_queue.pop_front();
    m_matches++;
    `uvm_info("Scoreboard", $sformatf("GOT A TRANSACTION: now %d seen", m_matches), UVM_LOW);
  endfunction : m_proc_data
  
  virtual function void write_monitor(apb_item item);  
    m_monitor_queue.push_back(item);
    m_proc_data();
  endfunction : write_monitor

  virtual task wait_for_completed(int unsigned target);
    wait(m_matches + m_mismatches >= target);
  endtask
  
endclass : example_design_scoreboard
  
// UVM build_phase
function void example_design_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
  monitor_export = new("monitor_export", this);

  `uvm_info(get_type_name(), $sformatf("Build done"), UVM_LOW)
endfunction : build_phase  

function void example_design_scoreboard::report_phase(uvm_phase phase);
  `uvm_info("Scoreboard", $sformatf("Matches:    %0d", m_matches), UVM_LOW);
  `uvm_info("Scoreboard", $sformatf("Mismatches: %0d", m_mismatches), UVM_LOW);
endfunction : report_phase

`endif 

