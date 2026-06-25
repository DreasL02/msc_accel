set CABLE_SERIAL "210308B0A957"

set BITFILE "/home/ci-ali/Documents/msc/msc_vivado/ps_emio_eth_1g/Hardware/ps_emio_eth_1g_hw/ps_emio_eth_1g.runs/impl_1/ps_emio_eth_1g_board_wrapper.bit"
set FSBL_ELF "/home/ci-ali/Documents/msc/apb_revision/msc_zynq_programming/fsbl_a53.elf"
set APP_ELF "/home/ci-ali/Documents/msc/apb_revision/msc_zynq_programming/apb_tcp.elf"

proc log {msg} {
    puts ">>> $msg"
}

proc select_target {filter desc} {
    log "Selecting $desc"
    targets -set -filter $filter
}

select_target "jtag_cable_serial == \"$CABLE_SERIAL\" && name == \"PSU\"" "system reset target (PSU)"

log "Issuing system reset"
rst -system

log "Waiting 1000 ms"
after 1000

log "Selecting Cortex-A53 #0"
select_target "jtag_cable_serial == \"$CABLE_SERIAL\" && name =~ \"Cortex-A53*#0\"" "Cortex-A53 #0"

log "Resetting processor"
rst -processor

log "Waiting 1000 ms"
after 1000

log "Selecting FPGA programming target"
select_target "jtag_cable_serial == \"$CABLE_SERIAL\" && name == \"PS TAP\"" "FPGA programming target PS TAP"

log "Programming FPGA bitstream"
fpga -file $BITFILE

log "Waiting 2000 ms"
after 2000

log "Re-selecting Cortex-A53 #0"
select_target "jtag_cable_serial == \"$CABLE_SERIAL\" && name =~ \"Cortex-A53*#0\"" "Cortex-A53 #0"

log "Resetting processor"
rst -processor

log "Downloading FSBL"
dow $FSBL_ELF

log "Running FSBL"
con

log "Waiting 5000 ms"
after 5000

log "Stopping processor"
stop

log "Downloading application ELF"
dow $APP_ELF

log "Running application"
con

log "Script complete"