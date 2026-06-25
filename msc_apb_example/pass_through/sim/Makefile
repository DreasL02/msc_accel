LOCAL_ROOT = ..
RTL_ROOT = ../..
APB_AVIP_ROOT = ../../../i900_01_apb_uvc
ACCEL_ROOT = ../../../msc_uvm_accelerator

TOP_TB_NAMES = hdl_top hvl_top

DPI_DIRECTORY = $(ACCEL_ROOT)/cpp
DPI_LIB_NAME = lib.so
DPI_LIB = $(DPI_DIRECTORY)/lib/$(DPI_LIB_NAME)

INCDIRS = \
	+incdir+$(ACCEL_ROOT)/sv \
	+incdir+$(APB_AVIP_ROOT)/uvc/components/ \
	+incdir+$(APB_AVIP_ROOT)/uvc/coverage/ \
	+incdir+$(APB_AVIP_ROOT)/uvc/interface/ \
	+incdir+$(APB_AVIP_ROOT)/uvc/packages/ \
	+incdir+$(APB_AVIP_ROOT)/uvc/items/ \
	+incdir+$(APB_AVIP_ROOT)/uvc/sequences/ \
	+incdir+$(LOCAL_ROOT)/hvl_top/env \
	+incdir+$(LOCAL_ROOT)/hvl_top/test

FILES = \
	$(ACCEL_ROOT)/sv/accel_pkg.sv \
	$(APB_AVIP_ROOT)/uvc/packages/apb_pkg.sv \
	$(APB_AVIP_ROOT)/uvc/interface/apb_if.sv \
	$(LOCAL_ROOT)/hvl_top/env/example_design_env_pkg.sv \
	$(LOCAL_ROOT)/hvl_top/test/example_design_test_pkg.sv \
	$(RTL_ROOT)/rtl/example_design.sv \
	$(LOCAL_ROOT)/hvl_top/hvl_top.sv \
	$(LOCAL_ROOT)/hdl_top/hdl_top.sv

DATE= $(shell date +%Y-%m-%d_%H-%M-%S)

WAVE ?= 1
GUI ?= 0
SEED ?= 0
ACCEL_MODE ?= 1

DEFINES += +define+EXAMPLE_DESIGN_ACCEL_MODE=$(ACCEL_MODE)

UVM_VERBOSITY ?= UVM_HIGH
UVM_TESTNAME ?= example_design_smoke_test
UVM_VERSION ?= 1.2
UVM_MAX_QUIT_COUNT ?= 1

LOGNAME = $(UVM_TESTNAME)_$(SEED)_$(DATE)

DEBUG_ARGS = +vcs+lic+wait

ifeq ($(GUI),1)
	DEBUG_ARGS += -debug_access+all
endif

ifeq ($(WAVE),1)
	DEBUG_ARGS += -debug_access+r
endif

UVM_ARGS = -ntb_opts uvm-$(UVM_VERSION)

VCS_FLAGS = -full64 -sverilog $(UVM_ARGS) -override_timescale=1ps/1ps $(DEBUG_ARGS)

VLOGAN_ARGS := $(DEBUG_ARGS) $(DEFINES) $(INCDIRS)

SIMV_ARGS := -licqueue +vcs+flush+all +ntb_random_seed=$(SEED) \
 +UVM_TESTNAME=$(UVM_TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) \
 +ENABLE_ACCEL=$(ACCEL_MODE) \
 +UVM_MAX_QUIT_COUNT=$(UVM_MAX_QUIT_COUNT) \
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
	@echo "Building DPI library"
	cd $(DPI_DIRECTORY) && make all DPI_LIB_NAME=$(DPI_LIB_NAME)
	@echo "Compiling uvm"
	vlogan -full64 -sverilog $(UVM_ARGS) -l comp_uvm.log
	@echo "Compiling testbench and DUT"
	vlogan -full64 -licqueue $(UVM_ARGS) $(DPI_LIB) $(VLOGAN_ARGS) $(FILES)  -l vcs_compile.log
	vcs $(VCS_FLAGS) $(DPI_LIB) $(addprefix work.,$(TOP_TB_NAMES)) -o simv -l vcs_link.log

sim: compile
	@echo "Running simulation. Final simulation logs will be in $(LOGNAME).log and waveform in vpddumps/$(LOGNAME).vpd"
	mkdir -p vpddumps
	bash -c "./simv $(SIMV_ARGS) | tee $(LOGNAME).log 2>&1"

clean:
	rm -rf csrc simv simv.daidir ucli.key uvm.log transcript vcs_compile.log waveform.wlf work/ *.vpd *.vcd

