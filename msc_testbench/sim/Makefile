ROOT = ../..
BOARD_DEMO_ROOT = ..
TOP_TB_NAME = board_tb

DPI_DIRECTORY = $(BOARD_DEMO_ROOT)/sim/cpp
DPI_LIB_NAME = libboard_socket.so
DPI_LIB = $(DPI_DIRECTORY)/lib/$(DPI_LIB_NAME)

INCDIRS = \
	+incdir+$(BOARD_DEMO_ROOT)/hvl \
	+incdir+$(BOARD_DEMO_ROOT)/hdl \
	+incdir+$(BOARD_DEMO_ROOT)/rtl \
	+incdir+$(BOARD_DEMO_ROOT)/rtl/general_infrastructure \
	+incdir+$(ROOT)/msc_apb_example/rtl

FILES = \
	$(BOARD_DEMO_ROOT)/hvl/board_dpi_pkg.sv \
	$(BOARD_DEMO_ROOT)/hvl/board_socket_demo_types_pkg.sv \
	$(BOARD_DEMO_ROOT)/rtl/board_apb_master_transactor.sv \
	$(BOARD_DEMO_ROOT)/rtl/board_apb_slave_transactor.sv \
	$(BOARD_DEMO_ROOT)/rtl/board_apb_monitor.sv \
	$(BOARD_DEMO_ROOT)/rtl/general_infrastructure/board_sync_fifo.sv \
	$(BOARD_DEMO_ROOT)/rtl/general_infrastructure/board_fifo_wrapper.sv \
	$(BOARD_DEMO_ROOT)/rtl/general_infrastructure/board_offloader.sv \
	$(BOARD_DEMO_ROOT)/rtl/board_apb_master_cmd_monitor.sv \
	$(BOARD_DEMO_ROOT)/rtl/board_apb_slave_cmd_monitor.sv \
	$(BOARD_DEMO_ROOT)/rtl/general_infrastructure/board_decoder.sv \
	$(BOARD_DEMO_ROOT)/rtl/general_infrastructure/board_arbiter.sv \
	$(BOARD_DEMO_ROOT)/rtl/board_apb_participants.sv \
	$(BOARD_DEMO_ROOT)/rtl/board_apb_assertion_handler.sv \
	$(BOARD_DEMO_ROOT)/rtl/board_test_infrastructure.sv \
	$(ROOT)/msc_apb_example/rtl/example_design.sv \
	$(ROOT)/msc_apb_example/rtl/apb_register_file.sv \
	$(BOARD_DEMO_ROOT)/hdl/board_tb.sv

DATE = $(shell date +%Y-%m-%d_%H-%M-%S)
WAVE ?= 1
GUI ?= 0
SEED ?= 0
ASSERT_ERROR ?= 0
USE_PASS_THROUGH ?= 0


LOGNAME = board_socket_demo_$(SEED)_$(DATE)

DEBUG_ARGS = +vcs+lic+wait

ifeq ($(GUI),1)
	DEBUG_ARGS += -debug_access+all
endif

ifeq ($(WAVE),1)
	DEBUG_ARGS += -debug_access+r
endif

ifeq ($(ASSERT_ERROR),1)
	DEFINES += +define+INJECT_APB_ASSERT_ERROR
endif

ifeq ($(USE_PASS_THROUGH),1)
	DEFINES += +define+PASS_THROUGH
endif


VCS_FLAGS = -full64 -sverilog -override_timescale=1ps/1ps $(DEBUG_ARGS)

VLOGAN_ARGS := $(DEBUG_ARGS) $(DEFINES) $(INCDIRS)

SIMV_ARGS := -licqueue +vcs+flush+all +ntb_random_seed=$(SEED) \
	-vpd_file vpddumps/$(LOGNAME).vpd

ifeq ($(GUI),1)
	SIMV_ARGS += -gui
endif

ifeq ($(WAVE),1)
	SIMV_ARGS += +vcs+vcdpluson
endif

.PHONY: all compile sim clean

all: compile sim

compile:
	@echo "Building board socket DPI library"
	cd $(DPI_DIRECTORY) && make all DPI_LIB_NAME=$(DPI_LIB_NAME)
	@echo "Compiling testbench and RTL"
	vlogan -full64 -sverilog $(VLOGAN_ARGS) $(FILES) -l vcs_compile.log
	vcs $(VCS_FLAGS) $(DPI_LIB) work.$(TOP_TB_NAME) -o simv -l vcs_link.log

sim: compile
	@echo "Running simulation. Final logs in $(LOGNAME).log and waveform in vpddumps/$(LOGNAME).vpd"
	mkdir -p vpddumps
	bash -c "./simv $(SIMV_ARGS) | tee $(LOGNAME).log 2>&1"

clean:
	rm -rf csrc simv simv.daidir ucli.key uvm.log transcript vcs_compile.log vcs_link.log *.vpd *.vcd *.log
	cd $(DPI_DIRECTORY) && make clean
