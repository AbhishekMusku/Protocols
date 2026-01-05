# Step 1: Create and clean work library
vlib work
vdel -all
vlib work

# Step 2: Compile Verilog files
# Note: Compile independent modules first, then the Top, then the TB.
vlog apb_master1.sv +acc
vlog apb_slave.sv +acc
vlog apb_arbiter.sv +acc
vlog apb_interconnect.sv +acc
vlog apb_soc_top.sv +acc
vlog tb_apb_soc.sv +acc

# Step 3: Load the simulation
# Pointing to the new Testbench
vsim work.tb_apb_soc

# Step 4: Add signals to waveform
# -r * adds all signals recursively (Master, Interconnect, and Slaves)
add wave -r *

# Step 5: Run simulation
run -all