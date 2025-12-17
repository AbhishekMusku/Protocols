# Step 1: Create and clean work library
vlib work
vdel -all
vlib work

# Step 2: Compile Verilog files
vlog baud_rate_generator.sv +acc
vlog uart_transmitter.sv +acc
vlog uart_receiver.sv +acc
vlog uart_top.sv +acc
vlog uart_tb_1.sv +acc

# Step 3: Load the simulation
vsim work.uart_tb_1

# Step 4: Add signals to waveform
add wave -r *
#add wave sim:/tb/clk
#add wave sim:/tb/cnt

# Step 5: Run simulation
run -all