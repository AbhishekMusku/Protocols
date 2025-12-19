class uart_environment;

    // Virtual Interface
    virtual uart_if vif;

    // Verification Components
    uart_generator    gen;
    uart_driver       drv;
    uart_tx_monitor   tx_mon;
    uart_rx_monitor   rx_mon;
    uart_scoreboard   scb;

    // Mailboxes
    mailbox #(uart_packet) gen2drv_mbx;
    mailbox #(uart_packet) txmon2scb_mbx;
    mailbox #(uart_packet) rxmon2scb_mbx;

    // Events
    event drv_done;

    // Configuration
    int num_packets;
    uart_generator::gen_mode_e test_mode;
    bit stop_on_mismatch;

    // Constructor
    function new(virtual uart_if vif);
        this.vif = vif;
        this.num_packets = 10;
        this.test_mode = uart_generator::GEN_RANDOM;
        this.stop_on_mismatch = 0;
    endfunction

    // Build Phase
    function void build();
        $display("[ENV] Building environment...");

        gen2drv_mbx   = new(1);
        txmon2scb_mbx = new(1);
        rxmon2scb_mbx = new(1);

        gen = new(gen2drv_mbx, drv_done);
        drv = new(vif, gen2drv_mbx, drv_done);
        tx_mon = new(vif, txmon2scb_mbx);
        rx_mon = new(vif, rxmon2scb_mbx);
        scb = new(txmon2scb_mbx, rxmon2scb_mbx);

        // Apply initial configuration to generator
        gen.num_packets = num_packets;
        gen.mode = test_mode;

        $display("[ENV] Build complete");
    endfunction

    // Configure Test
    function void configure_test(int num_pkts,
                                 uart_generator::gen_mode_e mode);
        this.num_packets = num_pkts;
        this.test_mode = mode;

        gen.num_packets = num_pkts;
        gen.mode = mode;

        $display("[ENV] Test configured: Mode=%s, Packets=%0d", mode.name(), num_pkts);
    endfunction

    function void set_stop_on_mismatch(bit value);
        stop_on_mismatch = value;
        scb.set_stop_on_mismatch(value);
    endfunction

    function void set_baud_ticks(int ticks);
        tx_mon.set_baud_ticks(ticks);
    endfunction

    // Reset
/*    task //reset_dut();
        $display("[ENV] Resetting DUT...");
        vif.reset = 1;
        drv.reset_signals();
        repeat (10) @(posedge vif.clk);
        vif.reset = 0;
        repeat (5) @(posedge vif.clk);
        $display("[ENV] Reset complete");
    endtask
*/
    // Run Phase
    task run();
        $display("[ENV] Starting test...");

        fork
            drv.run();
            tx_mon.run();
            rx_mon.run();
            scb.run();
            gen.run();
        join_none

        // Wait for scoreboard to finish comparisons
        scb.wait_for_completion(num_packets, 50000);

        $display("[ENV] Test complete");
    endtask

    // Run with Timeout
    task run_with_timeout(int timeout_cycles);
        fork
            run();
            begin
                repeat(timeout_cycles) @(posedge vif.clk);
                $error("[ENV] Test timeout!");
            end
        join_any
        disable fork;
    endtask

    // Reporting
    function void report();
        gen.display_stats();
        drv.display_stats();
        tx_mon.display_stats();
        rx_mon.display_stats();
        scb.display_stats();
        scb.display_final_report();
    endfunction

    // Tests
    task run_smoke_test();
        configure_test(10, uart_generator::GEN_RANDOM);
        //reset_dut();
        run_with_timeout(10000);
        report();
    endtask

    task run_corner_test();
        configure_test(20, uart_generator::GEN_CORNER_CASES);
        //reset_dut();
        run_with_timeout(20000);
        report();
    endtask

    task run_stress_test();
        configure_test(100, uart_generator::GEN_BURST);
        //reset_dut();
        run_with_timeout(100000);
        report();
    endtask

    task run_comprehensive_test();
        configure_test(20, uart_generator::GEN_RANDOM);
        //reset_dut();
        run_with_timeout(20000);

        configure_test(20, uart_generator::GEN_CORNER_CASES);
        //reset_dut();
        run_with_timeout(20000);

        configure_test(50, uart_generator::GEN_BURST);
        //reset_dut();
        run_with_timeout(50000);

        configure_test(256, uart_generator::GEN_ALL_VALUES);
        //reset_dut();
        run_with_timeout(30000);

        report();
    endtask

endclass


// ============================================================================
// Example Usage (in testbench top)
// ============================================================================
/*
module tb_top;
    logic clk, reset;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Interface instantiation
    uart_if uart_vif(clk, reset);
    
    // DUT instantiation
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
        .rx_ready(uart_vif.rx_ready)
    );
    
    // Testbench
    initial begin
        uart_environment env;
        
        // Create environment
        env = new(uart_vif);
        
        // Build
        env.build();
        
        // Configure
        env.set_baud_ticks(16);  // 16 clocks per bit
        env.set_stop_on_mismatch(0);
        
        // Set baud divisor
        uart_vif.baud_divisor = 16'd54;  // Example value
        
        // Loopback connection
        assign uart_vif.rx = uart_vif.tx;
        
        // Run test
        env.run_smoke_test();
        // OR: env.run_stress_test();
        // OR: env.run_comprehensive_test();
        // OR: Custom configuration
        //     env.configure_test(50, uart_generator::GEN_RANDOM);
        //     env.//reset_dut();
        //     env.run_with_timeout(50000);
        //     env.report();
        
        $finish;
    end
    
endmodule
*/