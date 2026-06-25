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
 * MODULE:      amiq_ofc_pkg
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
 * MODULE:      ACCEL PKG
 * PROJECT:     Accelerating UVM testbenches using Co-Emulation in FPGAs
////////////////////////////////////////////////////////////////////////////////
*/

`ifndef ACCEL_PKG
`define ACCEL_PKG

package accel_pkg;

	// integrate UVM
	`include "uvm_macros.svh"
	 import uvm_pkg::*;

	import "DPI-C" context function int  configure(input string hostname, input int port);
	import "DPI-C" context function void set_timeout(input int milliseconds);
	import "DPI-C" context task send_data(input byte unsigned data[], input int len, output int result);
	import "DPI-C" context task         recv_thread();
	import "DPI-C" context task         print_metric_statistics();

	export "DPI-C" function recv_callback;
	export "DPI-C" task     consume_time;

	`include "accel_codec.sv"
	`include "accel_server_connector_config.sv"
	`include "accel_server_connector.sv"
	`include "accel_driver_config.sv"
	`include "accel_monitor_config.sv"

	// Create the accel_server_connector
	accel_server_connector con = new("con", null);
	`include "accel_dpi_export.sv"

endpackage

`endif
