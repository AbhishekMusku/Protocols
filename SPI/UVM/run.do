vlib work
vdel -all
vlib work

# 1. Compile RTL and Testbench
#    Note: We only compile tb_top.sv because it 'includes' all the agent files.
vlog -sv \
    SPI_Master.v \
    tb_top.sv 

# 2. Load simulation with the Test Name
vsim -voptargs=+acc work.tb_top +UVM_VERBOSITY=UVM_HIGH

# 3. Add Waves (Recursive)
add wave -r sim:/tb_top/*

# 4. Run
run -all