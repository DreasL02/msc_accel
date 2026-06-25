[DPI-C] Configuring with localhost:9095
[DPI-C] State of connection set, creating socket
[DPI-C] Socket created. Assigning port
[DPI-C] Trying to connect
[DPI-C] Connected to localhost:9095
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(194) @ 0: con [uvm_component] connection setup
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_monitor.sv(140) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_monitor [uvm_monitor] APB monitor data new transfer
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_monitor.sv(147) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_monitor [uvm_monitor] APB monitor data Request waiting :
[DPI-C] recv_thread started[DPI-C] do_recv_forever started
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 0: con [uvm_component] starting recv_from_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : 17e12435
 m_direction      : UVM_READ
 m_data           : 4b7fcaab
 m_transmit_delay :         10
 m_response_delay :          6
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=000017e12435000000004b7fcaab0000000a0000000600, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=000017e12435000000004b7fcaab0000000a0000000600
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'h17e12435, write_data = 'h4b7fcaab
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : b9287934
 m_direction      : UVM_WRITE
 m_data           : d0e4e0cb
 m_transmit_delay :          8
 m_response_delay :          7
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=0000b928793400000001d0e4e0cb000000080000000700, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=0000b928793400000001d0e4e0cb000000080000000700
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'hb9287934, write_data = 'hd0e4e0cb
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : 88561459
 m_direction      : UVM_READ
 m_data           : 4dd67cd1
 m_transmit_delay :          4
 m_response_delay :          1
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=000088561459000000004dd67cd1000000040000000100, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=000088561459000000004dd67cd1000000040000000100
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'h88561459, write_data = 'h4dd67cd1
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : ed11367b
 m_direction      : UVM_WRITE
 m_data           : cb8dd587
 m_transmit_delay :          4
 m_response_delay :          4
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=0000ed11367b00000001cb8dd587000000040000000400, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=0000ed11367b00000001cb8dd587000000040000000400
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'hed11367b, write_data = 'hcb8dd587
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : 80ab7f20
 m_direction      : UVM_WRITE
 m_data           : e103d0f7
 m_transmit_delay :          8
 m_response_delay :          7
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=000080ab7f2000000001e103d0f7000000080000000700, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=000080ab7f2000000001e103d0f7000000080000000700
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'h80ab7f20, write_data = 'he103d0f7
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : 5495aed2
 m_direction      : UVM_READ
 m_data           : 53b0d10b
 m_transmit_delay :          9
 m_response_delay :          2
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=00005495aed20000000053b0d10b000000090000000200, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=00005495aed20000000053b0d10b000000090000000200
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'h5495aed2, write_data = 'h53b0d10b
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : b010edc3
 m_direction      : UVM_WRITE
 m_data           : 1eb0e54a
 m_transmit_delay :          1
 m_response_delay :          0
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=0000b010edc3000000011eb0e54a000000010000000000, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=0000b010edc3000000011eb0e54a000000010000000000
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'hb010edc3, write_data = 'h1eb0e54a
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : a76c6b93
 m_direction      : UVM_WRITE
 m_data           : 79c516fc
 m_transmit_delay :          3
 m_response_delay :          0
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=0000a76c6b930000000179c516fc000000030000000000, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=0000a76c6b930000000179c516fc000000030000000000
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'ha76c6b93, write_data = 'h79c516fc
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : a9c892ef
 m_direction      : UVM_READ
 m_data           : 1bfd0a64
 m_transmit_delay :          5
 m_response_delay :          5
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=0000a9c892ef000000001bfd0a64000000050000000500, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=0000a9c892ef000000001bfd0a64000000050000000500
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'ha9c892ef, write_data = 'h1bfd0a64
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(110) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] Starting...
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../components/apb_accel_driver.sv(124) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_accel_driver [uvm_driver #(REQ,RSP)] ACCELERATING PROTOCOL 0 DRIVE ITEM: 
 m_addr           : 06abbab4
 m_direction      : UVM_READ
 m_data           : f835d367
 m_transmit_delay :         10
 m_response_delay :          5
 m_error          : 0
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(236) @ 0: con [uvm_component] send_to_remote payload=000006abbab400000000f835d3670000000a0000000500, len          23
[DPI-C] [SOCKET SEND] len=23 payload_hex=000006abbab400000000f835d3670000000a0000000500
[DPI-C] [SOCKET SEND RESULT] requested=23 sent=23
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(213) @ 0: con [uvm_component] starting send_to_remote
UVM_INFO ../../../i900_01_apb_uvc/uvc/components/../sequences/apb_sequences.sv(118) @ 0: uvm_test_top.env.apb_master_env_h.m_agent.m_sequencer@@m_master_seq [apb_base_seq] addr = 'h6abbab4, write_data = 'hf835d367
[DPI-C] [SOCKET RECV] len=230 payload_hex=060017e124350000000000000000000000000000000000020017e124350000000000000000000000000000000000040017e1243500000000060000000000000000000000000600b928793400000001d0e4e0cb0000000000000000000200b928793400000001d0e4e0cb0000000000000000000400b928793400000000060000000000000000000000000600885614590000000000000000000000000000000000020088561459000000000000000000000000000000000004008856145900000000060000000000000000000000000600ed11367b00000001cb8dd587000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 1: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=115 payload_hex=0200ed11367b00000001cb8dd5870000000000000000000400ed11367b0000000006000000000000000000000000060080ab7f2000000001e103d0f7000000000000000000020080ab7f2000000001e103d0f7000000000000000000040080ab7f200000000006000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 4: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=06005495aed20000000000000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 5: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=02005495aed20000000000000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 6: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=04005495aed20000000006000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 7: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0600b010edc3000000011eb0e54a000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 9: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0200b010edc3000000011eb0e54a000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 10: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0400b010edc30000000006000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 11: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0600a76c6b930000000179c516fc000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 13: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0200a76c6b930000000179c516fc000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 14: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0400a76c6b930000000006000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 15: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0600a9c892ef0000000000000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 17: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0200a9c892ef0000000000000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 18: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=0400a9c892ef0000000006000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 19: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=060006abbab40000000000000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 21: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=020006abbab400000000d0e4e0cb000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 22: con [uvm_component] starting recv_from_remote
[DPI-C] [SOCKET RECV] len=23 payload_hex=040006abbab40000000006000000000000000000000000
UVM_INFO ../../../msc_uvm_accelerator/sv/accel_server_connector.sv(403) @ 23: con [uvm_component] starting recv_from_remote

