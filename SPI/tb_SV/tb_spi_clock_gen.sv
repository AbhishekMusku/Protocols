module tb_spi_clock_gen;

    //==========================================================================
    // Testbench Signals
    //==========================================================================
    logic       clk;
    logic       rst_n;
    logic       tx_dv;
    logic       tx_ready;
    logic       spi_clk;
    logic       leading_edge;
    logic       trailing_edge;
    
    //==========================================================================
    // Clock Generation - 100 MHz (10ns period)
    //==========================================================================
    initial clk = 0;
    always #5 clk = ~clk;  // Toggle every 5ns = 10ns period
    
    //==========================================================================
    // DUT Instantiation
    //==========================================================================
    spi_clock_generator #(
        .SPI_MODE(3),           // Mode 0: CPOL=0, CPHA=0
        .CLKS_PER_HALF_BIT(2)   // SPI_CLK = 100MHz / (2*2) = 25 MHz
    ) dut (
        .i_Clk(clk),
        .i_Rst_L(rst_n),
        .i_TX_DV(tx_dv),
        .o_TX_Ready(tx_ready),
        .o_SPI_Clk(spi_clk),
        .o_Leading_Edge(leading_edge),
        .o_Trailing_Edge(trailing_edge)
    );
    
    //==========================================================================
    // Edge Counters - To verify we get exactly 16 edges
    //==========================================================================
    int leading_count = 0;
    int trailing_count = 0;
    
    always @(posedge leading_edge or posedge trailing_edge) begin
        if (leading_edge) begin
            leading_count++;
            $display("Time %0t: Leading Edge #%0d", $time, leading_count);
        end
        
        if (trailing_edge) begin
            trailing_count++;
            $display("Time %0t: Trailing Edge #%0d", $time, trailing_count);
        end
    end
    
    //==========================================================================
    // Main Test Sequence
    //==========================================================================
    initial begin
        // Initialize
        rst_n = 0;
        tx_dv = 0;
        
        $display("=== SPI Clock Generator Test ===");
        $display("Time %0t: Starting test", $time);
        
        // Hold reset for a while
        repeat(5) @(posedge clk);
        $display("Time %0t: Releasing reset", $time);
        
        // Release reset synchronously
        @(posedge clk);
        rst_n = 1;
        
        // Wait one more cycle
        @(posedge clk);
        
        // Check if ready
        if (tx_ready) begin
            $display("Time %0t: Module is READY ✓", $time);
        end else begin
            $display("Time %0t: ERROR - Module not ready!", $time);
        end
        
        // Wait a bit
        repeat(2) @(posedge clk);
        
        //----------------------------------------------------------------------
        // TEST 1: Single Transaction
        //----------------------------------------------------------------------
        $display("\n=== TEST 1: Single Transaction ===");
        leading_count = 0;
        trailing_count = 0;
        
        // Pulse TX_DV
        $display("Time %0t: Starting transaction (pulse TX_DV)", $time);
        tx_dv = 1;
        @(posedge clk);
        tx_dv = 0;
        @(posedge clk);
        // Check that ready went low
        if (!tx_ready) begin
            $display("Time %0t: TX_Ready went LOW ✓", $time);
        end
        
        // Wait for transaction to complete
        wait(tx_ready);
        $display("Time %0t: Transaction complete! TX_Ready is HIGH", $time);
        
        // Verify edge counts
        $display("\nEdge Count Summary:");
        $display("  Leading edges:  %0d (expected 8)", leading_count);
        $display("  Trailing edges: %0d (expected 8)", trailing_count);
        
        if (leading_count == 8 && trailing_count == 8) begin
            $display("  ✓ PASS - Correct number of edges!");
        end else begin
            $display("  ✗ FAIL - Wrong number of edges!");
        end
        
        repeat(5) @(posedge clk);
        
        //----------------------------------------------------------------------
        // TEST 2: Back-to-back Transactions
        //----------------------------------------------------------------------
        $display("\n=== TEST 2: Back-to-Back Transactions ===");
        leading_count = 0;
        trailing_count = 0;
        
        // First transaction
        $display("Time %0t: Starting transaction 1", $time);
        tx_dv = 1;
        @(posedge clk);
        tx_dv = 0;
        
        wait(tx_ready);
        $display("Time %0t: Transaction 1 complete", $time);
        
        // Immediately start second transaction
        @(posedge clk);
        $display("Time %0t: Starting transaction 2 (back-to-back)", $time);
        tx_dv = 1;
        @(posedge clk);
        tx_dv = 0;
        
        wait(tx_ready);
        $display("Time %0t: Transaction 2 complete", $time);
        
        $display("  Total edges: Leading=%0d, Trailing=%0d (expected 16 each)", leading_count, trailing_count);
        
        repeat(10) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test Complete
        //----------------------------------------------------------------------
        $display("\n=== All Tests Complete ===");
        $display("Check waveform for visual verification!");
        $finish;
    end
    
    //==========================================================================
    // Timeout Watchdog
    //==========================================================================
    initial begin
        #10000;  // 10us timeout
        $display("ERROR: Test timed out!");
        $finish;
    end
    
endmodule