# ==============================================================================
# Industry-Standard Verilog Makefile
# ==============================================================================

# Toolchain Definitions
VERILOG = iverilog -g2012
SIM     = vvp
WAVES   = gtkwave

# Directory Structure (Relative Paths Only)
RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim

# Exact Source Files (Order matters: lowest level modules first)
SRC = $(RTL_DIR)/i2c_prescaler.v \
      $(RTL_DIR)/i2c_protocol.v \
      $(RTL_DIR)/i2c_top.v

# Exact Testbench File
TB  = $(TB_DIR)/i2c_tb.v

# Output Binaries (Quarantined in the sim folder)
OUT = $(SIM_DIR)/sim_out.vvp
VCD = $(SIM_DIR)/i2c_top.vcd

# ==============================================================================
# Execution Targets
# ==============================================================================

.PHONY: all clean compile run wave

# Default target when you just type 'make'
all: clean compile run

# 1. Create the quarantine folder and compile the silicon
compile:
	@echo "--------------------------------------------------"
	@echo " Compiling RTL and Testbench..."
	@echo "--------------------------------------------------"
	mkdir -p $(SIM_DIR)
	$(VERILOG) -o $(OUT) $(SRC) $(TB)

# 2. Run the actual simulation matrix
run: compile
	@echo "--------------------------------------------------"
	@echo " Running Verification Matrix..."
	@echo "--------------------------------------------------"
	$(SIM) $(OUT)

# 3. Boot up GTKWave to look at the physical timing
wave:
	@echo "Opening waveforms..."
	$(WAVES) $(VCD) &

# 4. Nuke the generated files to keep the repo clean
clean:
	@echo "Cleaning simulation artifacts..."
	rm -rf $(SIM_DIR)
