`include "uart_if.sv"
`include "uart_packet.sv"
`include "uart_generator.sv"
`include "uart_driver.sv"
`include "uart_tx_monitor.sv"
`include "uart_rx_monitor.sv"
`include "uart_scoreboard.sv"
`include "uart_environment.sv"

module uart_tb_top;
    
    // Clock and Reset Generation
    
    logic clk;
    logic reset;
    
    // Clock generation - 100MHz (10ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    // Interface Instantiation
    
    uart_if uart_vif(clk, reset);
    
    // DUT Instantiation
    
    uart_top dut (
        .clk(clk),
        .reset(reset),
        .baud_divisor(uart_vif.baud_divisor),
        .tx_data(uart_vif.tx_data),
        .tx_start(uart_vif.tx_start),
        .tx(uart_vif.tx),
        .tx_busy(uart_vif.tx_busy),
        .tx_done(uart_vif.tx_done),
        .rx(uart_vif.rx),
        .rx_data(uart_vif.rx_data),
        .rx_ready(uart_vif.rx_ready),
		.tx_tickk(uart_vif.tx_tickk),
		.rx_tickk(uart_vif.rx_tickk)
    );
    
    // Loopback Connection (TX -> RX)
    
    assign uart_vif.rx = uart_vif.tx;
	
    // RESET GENERATION (ADD THIS BLOCK)
    // This simulates the physical "Power-On Reset" button
    initial begin
        $display("[TB_TOP] System Reset Asserted");
        reset = 1'b1;   // Force Reset High (Active)
        
        #20;           // Hold it for 200ns (20 clocks) to clear the DUT
        
        reset = 1'b0;   // Release Reset (System goes Live)
        $display("[TB_TOP] System Reset Released");
    end
    // ---------------------------------------------------------
    
    // Testbench Logic
    
    initial begin
        uart_environment env;
        
        // Display test information
        $display("========================================================================");
        $display("                    UART VERIFICATION TESTBENCH");
        $display("========================================================================");
        $display("Clock Period      : 10ns (100MHz)");
        $display("Loopback Mode     : Enabled (TX -> RX)");
        $display("========================================================================");
        
        // Create environment
        env = new(uart_vif);
        
        // Build environment
        env.build();
        
        // Configure environment
        env.set_baud_ticks(16);         // 16 clock cycles per bit
        env.set_stop_on_mismatch(0);    // Continue on mismatch for full report
        
        // Configure baud rate divisor
        // For 100MHz clock and 115200 baud: divisor = 100MHz/(115200*16) ≈ 54
        uart_vif.baud_divisor = 16'd32;
        
        // ====================================================================
        // Select Test to Run
        // ====================================================================
        
        // Uncomment ONE of the following test options:
        
        // Option 1: Smoke Test (Quick - 10 packets)
        //env.run_smoke_test();
		//env.run_corner_test();
		//env.run_stress_test();
		env.run_comprehensive_test();
        
        // Option 2: Corner Case Test (20 pattern packets)
        // env.run_corner_test();
        
        // Option 3: Stress Test (100 burst packets)
        // env.run_stress_test();
        
        // Option 4: Comprehensive Test (All modes)
        // env.run_comprehensive_test();
        
        // Option 5: Custom Test
        // env.configure_test(50, uart_generator::MODE_RANDOM);
        // env.reset_dut();
        // env.run_with_timeout(50000);
        // env.report();
        
        // ====================================================================
        
        // End simulation
        $display("\n[TB_TOP] Simulation complete @ %0t", $time);
        $finish;
    end
    
    // Timeout Watchdog (Global Safety)
    
    initial begin
        #5_000_000;  // 1ms timeout
        $error("[TB_TOP] Global timeout! Simulation ran too long.");
        $finish;
    end
    
    // Waveform Dump (for debugging)
    
    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb_top);
    end
    
    // Optional: Monitor Key Signals
    
    // Uncomment to display key signal changes
    /*
    always @(posedge uart_vif.tx_start) begin
        $display("[TB_TOP] TX Start asserted: data=0x%02h @ %0t", uart_vif.tx_data, $time);
    end
    
    always @(posedge uart_vif.tx_done) begin
        $display("[TB_TOP] TX Done @ %0t", $time);
    end
    
    always @(posedge uart_vif.rx_ready) begin
        $display("[TB_TOP] RX Ready: data=0x%02h @ %0t", uart_vif.rx_data, $time);
    end
    */
    
endmodule

// ============================================================================
// Compilation Order (for reference)
// ============================================================================
/*
    1. uart_packet.sv
    2. uart_generator.sv
    3. uart_if.sv
    4. uart_driver.sv
    5. uart_tx_monitor.sv
    6. uart_rx_monitor.sv
    7. uart_scoreboard.sv
    8. uart_environment.sv
    9. uart_tb_top.sv
    
    DUT files:
    - baud_rate_generator.sv
    - uart_transmitter.sv
    - uart_receiver.sv
    - uart_top.sv
*/