# Step 1: Create and clean work library
vlib work
vdel -all
vlib work

# Step 2: Compile Verilog files
vlog SPI_Master.v +acc
vlog tb_spi_master.sv +acc

# Step 3: Load the simulation
vsim work.tb_spi_master

# Step 4: Add signals to waveform
add wave -r *
#add wave sim:/tb/clk
#add wave sim:/tb/cnt

# Step 5: Run simulation
run -all