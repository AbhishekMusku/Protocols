// ============================================================================
// UART Driver Class
// ============================================================================
// Drives UART packets from generator to the DUT transmitter
// ============================================================================

class uart_driver;
    
    // ========================================================================
    // Virtual Interface & Connections
    // ========================================================================
    
    virtual uart_if vif;  // Virtual interface to DUT
    
    // Mailbox from generator
    mailbox #(uart_packet) gen2drv_mbx;
    
    // Events for synchronization
    event drv_done;       // Signal to generator that packet transmission started
    event packet_driven;  // Signal when packet is fully driven
    
    // ========================================================================
    // Configuration & Statistics
    // ========================================================================
    
    int packets_driven;
    bit active;           // Driver active flag
    
    // ========================================================================
    // Constructor
    // ========================================================================
    
    function new(virtual uart_if vif, mailbox #(uart_packet) mbx, event done_evt);
        this.vif = vif;
        this.gen2drv_mbx = mbx;
        this.drv_done = done_evt;
        this.packets_driven = 0;
        this.active = 0;
    endfunction
    
    // ========================================================================
    // Reset Task
    // ========================================================================
    
    task reset_signals();
        $display("[DRIVER] Resetting signals");
        vif.tx_start <= 0;
        vif.tx_data  <= 8'h00;
    endtask
    
    // ========================================================================
    // Main Driver Task
    // ========================================================================
    
    task run();
        uart_packet pkt;
        
        active = 1;
        reset_signals();
        
        $display("[DRIVER] Started and waiting for packets...");
        
        forever begin
            // Get packet from generator
            gen2drv_mbx.get(pkt);
            
            // Drive the packet
            drive_packet(pkt);
            
            packets_driven++;
        end
    endtask
    
    // ========================================================================
    // Drive Single Packet
    // ========================================================================
    
    task drive_packet(uart_packet pkt);
        $display("[DRIVER] Driving packet: Data=0x%02h, Delay=%0d @ %0t", 
                 pkt.data, pkt.delay, $time);
        
        // Apply inter-packet delay (wait before driving this packet)
        if (pkt.delay > 0) begin
            repeat(pkt.delay) @(posedge vif.clk);
        end
        
        // Wait for transmitter to be ready (not busy)
        wait_for_ready();
        
        // Drive tx_start and tx_data
        @(posedge vif.clk);
        vif.tx_start <= 1;
        vif.tx_data  <= pkt.data;
        
        // Hold for one clock cycle
        @(posedge vif.clk);
        vif.tx_start <= 0;
        
        // Signal generator that we've started transmission
        -> drv_done;
        
        // Wait for transmission to complete
        wait_for_done();
        
        // Signal that packet is fully driven
        -> packet_driven;
        
        $display("[DRIVER] Packet driven complete @ %0t", $time);
    endtask
    
    // ========================================================================
    // Wait for Transmitter Ready
    // ========================================================================
    
    task wait_for_ready();
        // Wait until tx_busy is low (transmitter is idle)
        while (vif.tx_busy) begin
            @(posedge vif.clk);
        end
    endtask
    
    // ========================================================================
    // Wait for Transmission Done
    // ========================================================================
    
    task wait_for_done();
        // Wait for tx_done pulse (transmission complete)
        @(posedge vif.tx_done);
        $display("[DRIVER] Transmission complete signal received @ %0t", $time);
    endtask
    
    // ========================================================================
    // Alternative: Wait using tx_busy
    // ========================================================================
    
    task wait_for_done_busy();
        // Alternative method: wait for tx_busy to go low
        wait(vif.tx_busy);     // First wait for it to go high
        wait(!vif.tx_busy);    // Then wait for it to go low
        @(posedge vif.clk);    // One extra clock for safety
    endtask
    
    // ========================================================================
    // Display Statistics
    // ========================================================================
    
    function void display_stats();
        $display("========================================");
        $display("DRIVER STATISTICS");
        $display("========================================");
        $display("Packets Driven    : %0d", packets_driven);
        $display("Status            : %s", active ? "ACTIVE" : "IDLE");
        $display("========================================");
    endfunction
    
endclass

// ============================================================================
// Example Usage
// ============================================================================
/*
    // In testbench:
    
    // Create mailbox and events
    mailbox #(uart_packet) gen2drv_mb = new();
    event drv_done_evt;
    
    // Create driver
    uart_driver drv = new(uart_vif, gen2drv_mb, drv_done_evt);
    
    // Run driver in a fork
    fork
        drv.run();
    join_none
    
    // Monitor driver events
    fork
        forever begin
            @(drv.packet_driven);
            $display("[TB] Driver completed packet at %0t", $time);
        end
    join_none
    
    // At end of test
    drv.display_stats();
*/