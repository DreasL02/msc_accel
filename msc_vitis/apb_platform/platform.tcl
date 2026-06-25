# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\Users\andre\Documents\uvm_acceleration\msc_vitis\apb_platform\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\Users\andre\Documents\uvm_acceleration\msc_vitis\apb_platform\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {apb_platform}\
-hw {C:\Users\andre\Documents\uvm_acceleration\msc_zynq_programming\xsa_apb_example_05_05_26.xsa}\
-proc {psu_cortexa53_0} -os {freertos10_xilinx} -arch {64-bit} -fsbl-target {psu_cortexa53_0} -out {C:/Users/andre/Documents/uvm_acceleration/msc_vitis}

platform write
platform generate -domains 
platform active {apb_platform}
bsp reload
bsp setlib -name lwip213 -ver 1.1
bsp removelib -name lwip213
bsp setlib -name lwip213 -ver 1.1
bsp removelib -name lwip213
bsp setlib -name lwip213 -ver 1.1
bsp config api_mode "SOCKET_API"
bsp write
bsp reload
catch {bsp regenerate}
platform generate
platform generate -domains freertos10_xilinx_domain 
platform active {apb_platform}
bsp reload
platform active {apb_platform}
platform generate
bsp reload
bsp config total_heap_size "65536"
bsp config total_heap_size "262144"
bsp config mem_size "131072"
bsp config memp_n_pbuf "1024"
bsp config memp_n_sys_timeout "8"
bsp config memp_n_tcp_pcb "32"
bsp config memp_n_tcp_seg "1024"
bsp config n_rx_descriptors "256"
bsp config n_tx_descriptors "256"
bsp config pbuf_pool_size "1024"
bsp config tcp_mss "1458"
bsp config tcp_wnd "65000"
bsp config tcp_snd_buf "65000"
bsp write
bsp reload
catch {bsp regenerate}
platform generate -domains freertos10_xilinx_domain 
platform clean
platform generate
platform clean
platform generate
bsp reload
bsp reload
platform active {apb_platform}
platform generate -domains 
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform generate -domains freertos10_xilinx_domain,zynqmp_fsbl,zynqmp_pmufw 
platform active {apb_platform}
bsp reload
bsp reload
platform generate -domains 
bsp config mem_size "524288"
bsp config pbuf_pool_size "8192"
bsp config n_rx_descriptors "512"
bsp config n_tx_descriptors "512"
bsp config n_tx_coalesce "1"
bsp config tcp_snd_buf "65535"
bsp config tcp_synmaxrtx "4"
bsp config tcp_wnd "65535"
bsp config tcp_ttl "255"
bsp write
bsp reload
catch {bsp regenerate}
platform clean
platform generate
platform clean
platform clean
platform generate
bsp config mem_size "524288"
bsp config memp_n_pbuf "16384"
bsp config memp_n_tcp_pcb "8192"
bsp config memp_n_tcp_seg "8192"
bsp config memp_num_api_msg "16"
bsp config pbuf_pool_bufsize "16384"
bsp write
bsp reload
catch {bsp regenerate}
platform clean
platform clean
platform generate
bsp config pbuf_pool_size "1700"
bsp config pbuf_pool_size "256"
bsp config pbuf_pool_bufsize "1700"
bsp config pbuf_pool_size "256"
bsp config tcp_mss "1460"
bsp config tcp_queue_ooseq "1"
bsp config tcp_snd_buf "65535"
bsp config tcp_wnd "65535"
bsp config tcp_snd_buf "65535"
bsp config tcp_snd_buf "373760"
bsp config tcp_wnd "373760"
bsp config tcp_snd_buf "373760"
bsp config mem_size "524288"
bsp config mem_size "524288"
bsp config memp_n_pbuf "16384"
bsp config mem_size "4194304"
bsp config n_rx_descriptors "128"
bsp config n_tx_descriptors "128"
bsp config n_tx_coalesce "16"
bsp config n_rx_coalesce "16"
bsp config emac_number "0"
bsp write
bsp reload
catch {bsp regenerate}
platform clean
platform clean
bsp config tcp_wnd "64240"
bsp config tcp_snd_buf "64240"
bsp write
bsp reload
catch {bsp regenerate}
platform generate
platform clean
platform generate
bsp reload
bsp config memp_num_netbuf "64"
bsp write
bsp reload
catch {bsp regenerate}
platform clean
platform generate
bsp config pbuf_pool_size "1024"
bsp config n_rx_descriptors "256"
bsp config n_tx_descriptors "256"
bsp config n_tx_coalesce "16"
bsp config memp_n_pbuf "16384"
bsp config memp_n_pbuf "1024"
bsp config memp_n_tcp_seg "1024"
bsp config memp_n_tcp_pcb "32"
bsp write
bsp reload
catch {bsp regenerate}
platform clean
platform clean
platform generate
platform active {apb_platform}
platform generate -domains 
platform clean
platform generate
platform clean
platform generate
platform active {apb_platform}
domain active {zynqmp_fsbl}
domain active {freertos10_xilinx_domain}
bsp reload
bsp reload
bsp config phy_link_speed "CONFIG_LINKSPEED_AUTODETECT"
bsp reload
bsp config memp_n_tcp_seg "1024"
bsp config memp_n_pbuf "1024"
bsp reload
bsp reload
platform active {apb_platform}
platform generate
platform active {apb_platform}
domain active {zynqmp_fsbl}
domain active {freertos10_xilinx_domain}
bsp reload
bsp reload
bsp config total_heap_size "262144"
bsp config total_heap_size "524288"
bsp write
bsp reload
catch {bsp regenerate}
platform generate -domains freertos10_xilinx_domain 
