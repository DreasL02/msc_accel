// Original work license:
/******************************************************************************
 * (C) Copyright 2021 AMIQ Consulting
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * MODULE:      amiq_ofc_server_connector
 * PROJECT:     Amiq Open-Source Framework for Co-Emulation
 *******************************************************************************/

// Changed by Andreas Lildballe for Master Thesis, 2026:
/******************************************************************************
 * (C) Copyright 2026 Andreas Lildballe
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * MODULE:      ACCEL SERVER CONNECTOR
 * PROJECT:     Accelerating UVM testbenches using Co-Emulation in FPGAs
////////////////////////////////////////////////////////////////////////////////
*/

typedef byte unsigned byte_array_t[];

localparam int FAN_OUT = 0;
static bit metric_summary_printed = 0;
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// HELPER TYPES
////////////////////////////////////////////////////////////////////////////////

class byte_packet;
  byte unsigned data[];
  int len;

  function new();
    data = new[0];
    len  = 0;
  endfunction

  function void from_array(input byte_array_t arr);
    len = arr.size();
    data = new[len];
    for (int i = 0; i < len; i++) begin
      data[i] = arr[i];
    end
  endfunction

  function void to_array(output byte_array_t arr);
    arr = new[len];
    for (int i = 0; i < len; i++) begin
      arr[i] = data[i];
    end
  endfunction
endclass



////////////////////////////////////////////////////////////////////////////////
// CONNECTOR CLASS
////////////////////////////////////////////////////////////////////////////////

class accel_server_connector extends uvm_component;

  // Used for sending items from testbench to server.
  local mailbox #(byte_packet) send_mbox;

  // Demultiplexed receive mailboxes by protocol identifier.
  local mailbox #(byte_packet) recv_mbox_by_protocol[byte unsigned];

  // Configuration object.
  accel_server_connector_config server_connector_config;

  // Event and byte queue used by DPI callback -> SV receive path.
  event receive_from_server;
  byte unsigned recv_bytes_q[$];

  function new(string name = "accel_server_connector", uvm_component parent);
    super.new(name, parent);

    `uvm_info(get_type_name(), "new called", UVM_MEDIUM)

    server_connector_config =
      accel_server_connector_config::type_id::create("server_connector_config");

    `uvm_info(get_type_name(), "created config", UVM_MEDIUM)

    uvm_config_db #(accel_server_connector)::set(null, "*", "accel_server_connector", this);

    send_mbox = new();

    con = this;
  endfunction

  ////////////////////////////////////////////////////////////////////////////
  // Public API
  ////////////////////////////////////////////////////////////////////////////

  task send_item(input byte_array_t item);
    byte_packet pkt;

    `uvm_info(get_type_name(),
              $sformatf("send_item bytes=%0d", item.size()),
              UVM_DEBUG)

    if ((server_connector_config.outgoing_item_width > 0) &&
        (item.size() != server_connector_config.outgoing_item_width)) begin
      `uvm_warning(get_type_name(),
                   $sformatf("send width mismatch: expected=%0d got=%0d",
                             server_connector_config.outgoing_item_width,
                             item.size()))
    end

    pkt = new();
    pkt.from_array(item);
    send_mbox.put(pkt);
  endtask
  
  function void register_rx_protocol(byte unsigned protocol_identifier);
    if (!recv_mbox_by_protocol.exists(protocol_identifier)) begin
      `uvm_info(get_type_name(),
                $sformatf("register_rx_protocol id=0x%02h", protocol_identifier),
                UVM_DEBUG)
      recv_mbox_by_protocol[protocol_identifier] = new();
    end
  endfunction

  task recv_item_by_protocol(
    input  byte unsigned protocol_identifier,
    output byte_array_t item
  );
    byte_packet pkt;

    `uvm_info(get_type_name(),
              $sformatf("recv_item_by_protocol id=0x%02h waiting",
                        protocol_identifier),
              UVM_DEBUG)

    register_rx_protocol(protocol_identifier);
    recv_mbox_by_protocol[protocol_identifier].get(pkt);
    pkt.to_array(item);

    `uvm_info(get_type_name(),
              $sformatf("recv_item_by_protocol id=0x%02h bytes=%0d header=0x%02h",
                        protocol_identifier, item.size(), (item.size() > 0 ? item[0] : 8'h00)),
              UVM_DEBUG)
  endtask


  ////////////////////////////////////////////////////////////////////////////
  // UVM run phase
  ////////////////////////////////////////////////////////////////////////////

  virtual task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
              $sformatf("run_phase toggle=%0d outgoing_width=%0d incoming_width=%0d",
                        server_connector_config.toggle,
                        server_connector_config.outgoing_item_width,
                        server_connector_config.incoming_item_width),
              UVM_DEBUG)

    `uvm_info(get_type_name(), "run phase started", UVM_MEDIUM)

    if (server_connector_config.toggle) begin
      setup_connection();

      fork
        recv_thread();
      join_none

      fork
        forever send_to_remote();
        forever recv_from_remote();
      join
    end
  endtask

  ////////////////////////////////////////////////////////////////////////////
  // Connection setup
  ////////////////////////////////////////////////////////////////////////////

  function void setup_connection();
    `uvm_info(get_type_name(),
              $sformatf("setup_connection host=%s port=%0d timeout=%0d",
                        server_connector_config.hostname,
                        server_connector_config.port,
                        server_connector_config.timeout),
              UVM_DEBUG)

    `uvm_info(get_type_name(), "setting up connection", UVM_MEDIUM)

    if (configure(server_connector_config.hostname,
                  server_connector_config.port) != 0) begin
      $error("Could not establish connection!");
    end

    set_timeout(server_connector_config.timeout);

    `uvm_info(get_type_name(), "connection setup", UVM_MEDIUM)
  endfunction : setup_connection

  ////////////////////////////////////////////////////////////////////////////
  // Send path
  ////////////////////////////////////////////////////////////////////////////

  task send_to_remote();
    int send_rsp = 0;
    int retry_count = 0;
    int not_connected_count = 0;
    int would_block_count = 0;
    int socket_error_count = 0;
    int unknown_stall_count = 0;
	string s;

    byte_packet pkt;
    byte_array_t item_bytes;

    `uvm_info(get_type_name(), "starting send_to_remote", UVM_MEDIUM)

    send_mbox.get(pkt);
    pkt.to_array(item_bytes);

      `uvm_info(get_type_name(),
                $sformatf("send_to_remote len=%0d id=0x%02h header=0x%02h", item_bytes.size(),
                          (item_bytes.size() > 0 ? item_bytes[0] : 8'h00), (item_bytes.size() > 1 ? item_bytes[1] : 8'h00)),
                UVM_DEBUG)

    if ((server_connector_config.outgoing_item_width > 0) &&
        (item_bytes.size() != server_connector_config.outgoing_item_width)) begin
      `uvm_warning(get_type_name(),
                   $sformatf("send width mismatch: expected=%0d got=%0d",
                             server_connector_config.outgoing_item_width,
                             item_bytes.size()))
    end

    while (item_bytes.size() > 0) begin
      s = "";
      for (int i = 0; i < item_bytes.size(); i++) begin
        s = {s, $sformatf("%02x", item_bytes[i])};
      end
      `uvm_info(get_type_name(), $sformatf("send_to_remote payload=%s, len %d", s, item_bytes.size()), UVM_HIGH)
      send_data(item_bytes, item_bytes.size(), send_rsp);

      if (send_rsp <= 0) begin
        retry_count++;

        if (send_rsp == -2) begin
          not_connected_count++;
          if ((not_connected_count % 200) == 1) begin
            `uvm_warning(get_type_name(),
                         $sformatf("send stalled: socket not connected. pending_len=%0d retry_count=%0d",
                                   item_bytes.size(), retry_count))
          end
          if ((not_connected_count % 50) == 0) begin
            `uvm_info(get_type_name(), "Attempting reconnection (not connected)", UVM_LOW)
            setup_connection();
          end
        end
        else if (send_rsp == -3) begin
          would_block_count++;
          if ((would_block_count % 500) == 1) begin
            `uvm_warning(get_type_name(),
                         $sformatf("send stalled: socket would block (backpressure). pending_len=%0d retry_count=%0d",
                                   item_bytes.size(), retry_count))
          end
        end
        else if (send_rsp == -4) begin
          socket_error_count++;
          if ((socket_error_count % 100) == 1) begin
            `uvm_warning(get_type_name(),
                         $sformatf("send stalled: socket error from DPI-C. pending_len=%0d retry_count=%0d",
                                   item_bytes.size(), retry_count))
          end
          if ((socket_error_count % 20) == 0) begin
            `uvm_info(get_type_name(), "Attempting reconnection (socket error)", UVM_LOW)
            setup_connection();
          end
        end
        else begin
          unknown_stall_count++;
          if ((unknown_stall_count % 200) == 1) begin
            `uvm_warning(get_type_name(),
                         $sformatf("send stalled: unexpected send_rsp=%0d. pending_len=%0d retry_count=%0d",
                                   send_rsp, item_bytes.size(), retry_count))
          end
          if ((unknown_stall_count % 50) == 0) begin
            `uvm_info(get_type_name(), "Attempting reconnection (unexpected stall)", UVM_LOW)
            setup_connection();
          end
        end

        #1;
        continue;
      end

      retry_count = 0;
      not_connected_count = 0;
      would_block_count = 0;
      socket_error_count = 0;
      unknown_stall_count = 0;

      if (send_rsp >= item_bytes.size()) begin
        item_bytes = new[0];
      end
      else begin
        byte_array_t remaining_bytes;
        remaining_bytes = new[item_bytes.size() - send_rsp];
        for (int i = send_rsp; i < item_bytes.size(); i++) begin
          remaining_bytes[i - send_rsp] = item_bytes[i];
        end
        item_bytes = remaining_bytes;
      end
    end
  endtask

  ////////////////////////////////////////////////////////////////////////////
  // Receive routing
  ////////////////////////////////////////////////////////////////////////////

  function void route_received_item(input byte_array_t item);
    byte unsigned protocol_identifier;
    byte_packet pkt;
    bit ok;

    if (item.size() == 0) begin
      `uvm_info(get_type_name(), "route_received_item empty packet", UVM_DEBUG)
      return;
    end

    `uvm_info(get_type_name(),
          $sformatf("route_received_item bytes=%0d id=0x%02h header=0x%02h",
              item.size(), item[0], (item.size() > 1 ? item[1] : 8'h00)),
          UVM_DEBUG)

    if (FAN_OUT) begin
      // Also route to all protocol-specific mailboxes (if any) for monitoring purposes
      byte unsigned pid;
      foreach (recv_mbox_by_protocol[pid]) begin
        // Create a fresh packet and copy bytes once, then adjust header for this pid
        pkt = new();
        pkt.data = new[item.size()];
        pkt.len = item.size();
        for (int j = 0; j < item.size(); j++) begin
          pkt.data[j] = item[j];
        end
        pkt.data[0] = pid;
        ok = recv_mbox_by_protocol[pid].try_put(pkt);
        if (!ok) begin
          `uvm_warning(get_type_name(),
                $sformatf("route_received_item failed to enqueue protocol item for id=0x%02h",
                      pid))
        end
      end
    end else begin
      // Route full item (with id and header intact) to protocol-specific mailbox
      protocol_identifier = item[0];
      if (recv_mbox_by_protocol.exists(protocol_identifier)) begin
        pkt = new();
        pkt.data = new[item.size()];
        pkt.len = item.size();
        for (int j = 0; j < item.size(); j++) begin
          pkt.data[j] = item[j];
        end
        ok = recv_mbox_by_protocol[protocol_identifier].try_put(pkt);
        if (!ok) begin
          `uvm_warning(get_type_name(),
                $sformatf("route_received_item failed to enqueue protocol item for id=0x%02h",
                      protocol_identifier))
        end
      end else begin
        `uvm_warning(get_type_name(),
              $sformatf("route_received_item no mailbox for protocol id=0x%02h. Current mailboxes: %p",
                    protocol_identifier, recv_mbox_by_protocol))
      end
    end

  endfunction

  ////////////////////////////////////////////////////////////////////////////
  // Receive packet extraction from raw byte queue
  ////////////////////////////////////////////////////////////////////////////

  function bit pop_received_packet(output byte_array_t item);
    int incoming_width;

    if (recv_bytes_q.size() == 0) begin
      `uvm_info(get_type_name(), "pop_received_packet queue empty", UVM_DEBUG)
      return 0;
    end

    incoming_width = server_connector_config.incoming_item_width;
    if (incoming_width <= 0) begin
      incoming_width = recv_bytes_q.size();
    end

    if (recv_bytes_q.size() < incoming_width) begin
      `uvm_info(get_type_name(),
                $sformatf("pop_received_packet partial packet queued=%0d expected=%0d",
                          recv_bytes_q.size(), incoming_width),
                UVM_DEBUG)
      return 0;
    end

    item = new[incoming_width];
    for (int i = 0; i < incoming_width; i++) begin
      item[i] = recv_bytes_q.pop_front();
    end

    return 1;
  endfunction

  ////////////////////////////////////////////////////////////////////////////
  // Receive path from raw bytes to mailboxes
  ////////////////////////////////////////////////////////////////////////////

  task recv_from_remote();
    byte_array_t received_item;

    `uvm_info(get_type_name(), "starting recv_from_remote", UVM_MEDIUM)
    `uvm_info(get_type_name(), $sformatf("recv_from_remote incoming_width=%0d", server_connector_config.incoming_item_width), UVM_DEBUG)

    @receive_from_server;

    while (pop_received_packet(received_item)) begin
      `uvm_info(get_type_name(), $sformatf("recv_from_remote routing packet bytes=%0d", received_item.size()), UVM_DEBUG)
      route_received_item(received_item);
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    if (server_connector_config.toggle && !metric_summary_printed) begin
      metric_summary_printed = 1;
      `uvm_info(get_type_name(), "Printing DPI-C metric statistics summary", UVM_LOW)
      print_metric_statistics();
    end
  endfunction

endclass

