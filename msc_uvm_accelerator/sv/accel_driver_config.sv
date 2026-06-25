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
 * MODULE:      amiq_ofc_driver_config
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
 * MODULE:      ACCEL DRIVER CONFIG
 * PROJECT:     Accelerating UVM testbenches using Co-Emulation in FPGAs
////////////////////////////////////////////////////////////////////////////////
*/

class accel_driver_config extends uvm_object;
	`uvm_object_utils(accel_driver_config)

	function new(string name = "accel_driver_config");
		super.new(name);
	endfunction

	byte unsigned protocol_identifier = 0;

	bit wait_for_response = 1;

endclass
