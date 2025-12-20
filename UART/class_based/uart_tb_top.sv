`include "uart_if.sv"
`include "uart_packet.sv"
`include "uart_generator.sv"
`include "uart_driver.sv"
`include "uart_tx_monitor.sv"
`include "uart_rx_monitor.sv"
`include "uart_scoreboard.sv"
`include "uart_environment.sv"

module uart_tb_top;
    
    logic clk;
    logic reset;
    
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    uart_if uart_vif(clk, reset);
    
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
    
    assign uart_vif.rx = uart_vif.tx;
	
    // RESET GENERATION 
    initial begin
        $display("[TB_TOP] System Reset Asserted");
        reset = 1'b1;          
        #20;                  
        reset = 1'b0;   
        $display("[TB_TOP] System Reset Released");
    end
    
    // Testbench Logic
    
    initial begin
        uart_environment env;
        string test_name;
        $display("========================================================================");
        $display("                    UART VERIFICATION TESTBENCH");
        $display("========================================================================");
        $display("Clock Period      : 10ns (100MHz)");
        $display("Loopback Mode     : Enabled (TX -> RX)");
        $display("========================================================================");
        
        env = new(uart_vif);
        
        env.build();
        
        env.set_baud_ticks(16);         // 16 clock cycles per bit
        env.set_stop_on_mismatch(0);
        
        uart_vif.baud_divisor = 16'd32;
		
        if ($value$plusargs("TESTNAME=%s", test_name)) begin
            $display("[TB_TOP] +TESTNAME argument found: %s", test_name);
        end else begin
            $display("[TB_TOP] No +TESTNAME argument found. Defaulting to comprehensive_test.");
            test_name = "comprehensive_test";
        end

        // SELECT TEST BASED ON ARGUMENT
        case (test_name)
            "smoke_test":        env.run_smoke_test();
            "corner_test":       env.run_corner_test();
            "stress_test":       env.run_stress_test();
            "comprehensive_test": env.run_comprehensive_test();
            default: begin
                $display("[TB_TOP] Error: Unknown test name '%s'. Running comprehensive_test instead.", test_name);
                env.run_comprehensive_test();
            end
        endcase

        $display("\n[TB_TOP] Simulation complete @ %0t", $time);
        $finish;
    end
    
    
    initial begin
        #5_000_000;  // 1ms timeout
        $error("[TB_TOP] Global timeout! Simulation ran too long.");
        $finish;
    end
    
    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb_top);
    end
    
    
endmodule

