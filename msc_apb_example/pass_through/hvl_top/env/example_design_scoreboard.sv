
`ifndef APB_UVC_SCOREBOARD_SV
`define APB_UVC_SCOREBOARD_SV

`uvm_analysis_imp_decl(_monitor)
`uvm_analysis_imp_decl(_request)

class example_design_scoreboard extends uvm_component;
  `uvm_component_utils(example_design_scoreboard)
  
  uvm_analysis_imp_monitor#(apb_item, example_design_scoreboard) monitor_export;
  uvm_analysis_imp_request#(apb_item, example_design_scoreboard) request_export;

  int m_matches = 0;
  int m_mismatches = 0;
  protected apb_item m_request_queue[$];
  protected apb_item m_monitor_queue[$];

  // Constructor - Required UVM syntax
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new
    
    // Class Functions or Tasks
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void report_phase(uvm_phase phase);

  virtual function void m_proc_data();
    apb_item request_item = m_request_queue.pop_front();
    apb_item monitor_item = m_monitor_queue.pop_front();
    `uvm_info("Scoreboard", $psprintf("Got master:\n%s",request_item.sprint()), UVM_DEBUG);
    `uvm_info("Scoreboard", $psprintf("Got slave:\n%s",monitor_item.sprint()), UVM_DEBUG);
    
    if (
      request_item.m_addr == monitor_item.m_addr &&
      request_item.m_direction == monitor_item.m_direction &&
      (request_item.m_direction == UVM_READ || (request_item.m_direction == UVM_WRITE && request_item.m_data == monitor_item.m_data)) //if it is a write data can be compared aswell
    ) begin
      m_matches++;
      `uvm_info("Scoreboard", "These two requests are considered matching", UVM_HIGH);
    end else begin
      m_mismatches++;
      //`uvm_info("Scoreboard", $psprintf("The following two items are considered non-matching: \n REQUEST: %s \n \n MONITOR: %s", request_item.sprint(), monitor_item.sprint()), UVM_MEDIUM);
      `uvm_error("Scoreboard", $psprintf("The following two items are considered non-matching: \n REQUEST: %s \n \n MONITOR: %s", request_item.sprint(), monitor_item.sprint()));
    end

  endfunction : m_proc_data
  
  virtual function void write_request(apb_item item);    
    `uvm_info("Scoreboard", $psprintf("Got master :\n%s\nPushing to queue of before size %d (other queue size %d)",item.sprint(), m_request_queue.size(), m_monitor_queue.size()), UVM_HIGH);
    m_request_queue.push_back(item);
    if (m_monitor_queue.size())
      m_proc_data();
  endfunction : write_request
  
  virtual function void write_monitor(apb_item item);  
    `uvm_info("Scoreboard", $psprintf("Got slave :\n%s\nPushing to queue of before size %d (other queue size %d)",item.sprint(), m_monitor_queue.size(), m_request_queue.size()), UVM_HIGH);
    m_monitor_queue.push_back(item);
    if (m_request_queue.size())
      m_proc_data();
  endfunction : write_monitor

  virtual task wait_for_completed(int unsigned target);
    wait(m_matches + m_mismatches >= target);
  endtask
  
endclass : example_design_scoreboard
  
// UVM build_phase
function void example_design_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);
  request_export = new("request_export", this);
  monitor_export = new("monitor_export", this);

  `uvm_info(get_type_name(), $sformatf("Build done"), UVM_LOW)
endfunction : build_phase  

function void example_design_scoreboard::report_phase(uvm_phase phase);
  `uvm_info("Scoreboard", $sformatf("Matches:    %0d", m_matches), UVM_LOW);
  `uvm_info("Scoreboard", $sformatf("Mismatches: %0d", m_mismatches), UVM_LOW);
endfunction : report_phase

`endif 

