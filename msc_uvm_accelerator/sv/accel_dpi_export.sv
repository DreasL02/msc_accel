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
 * MODULE:      ACCEL DPI EXPORT
 * PROJECT:     Accelerating UVM testbenches using Co-Emulation in FPGAs
////////////////////////////////////////////////////////////////////////////////
*/
// EXPORTED FUNCTIONS/TASKS CALLED FROM DPI-C
////////////////////////////////////////////////////////////////////////////////
parameter int ACCEL_DPI_BUFFER_SIZE = 16384;

function void queue_received_bytes(
  input byte unsigned bytes[ACCEL_DPI_BUFFER_SIZE],
  input int len
);
  `uvm_info("accel_server_connector",
            $sformatf("queue_received_bytes len=%0d", len),
            UVM_DEBUG)

  if (con == null) begin
    `uvm_error("accel_server_connector",
               "queue_received_bytes called before connector handle was assigned")
    return;
  end

  if ((len < 0) || (len > ACCEL_DPI_BUFFER_SIZE)) begin
    `uvm_error("accel_server_connector",
               $sformatf("queue_received_bytes invalid len=%0d buffer_max=%0d",
                         len, ACCEL_DPI_BUFFER_SIZE))
    return;
  end

  for (int i = 0; i < len; i++) begin
    con.recv_bytes_q.push_back(bytes[i]);
  end

  if (len > 0) begin
    -> con.receive_from_server;
  end
endfunction

function void recv_callback(
  input byte unsigned msg[ACCEL_DPI_BUFFER_SIZE],
  input int len
);
  `uvm_info("accel_server_connector",
            $sformatf("recv_callback len=%0d", len),
            UVM_DEBUG)
  queue_received_bytes(msg, len);
endfunction

task consume_time();
  #1;
endtask