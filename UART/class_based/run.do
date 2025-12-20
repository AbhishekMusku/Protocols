vlib work
vdel -all
vlib work


# Compile ALL files (order does not matter)
vlog -sv \
    baud_rate_generator.sv \
    uart_transmitter.sv \
    uart_receiver.sv \
    uart_top.sv \
    uart_tb_top.sv

# Load simulation
vsim -voptargs=+acc work.uart_tb_top +TESTNAME=$test_name

# Basic waves (optional)
add wave -r sim:/uart_tb_top/uart_vif/*

# Run
run -all
