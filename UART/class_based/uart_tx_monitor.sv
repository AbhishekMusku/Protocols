class uart_tx_monitor;

    // Interface
    virtual uart_if.MON vif;

    // Mailbox
    mailbox #(uart_packet) mon2scb_mbx;

    // Event
    event packet_captured;

    // Stats
    int packets_captured;
    int baud_ticks_per_bit;

    // Constructor
    function new(
        virtual uart_if.MON vif,
        mailbox #(uart_packet) mbx
    );
        this.vif = vif;
        this.mon2scb_mbx = mbx;
        this.packets_captured = 0;
        this.baud_ticks_per_bit = 16;
    endfunction

    function void set_baud_ticks(int ticks);
        baud_ticks_per_bit = ticks;
    endfunction

    // Main loop
    task run();
        $display("[TX_MON] Monitoring TX...");
        forever begin
            capture_packet();
        end
    endtask
	
	task wait_rx_tickks(int n);
		int cnt = 0;
		while (cnt < n) begin
			@(vif.mon_cb);
			if (vif.mon_cb.rx_tickk)
				cnt++;
		end
	endtask

    // Capture packet from TX serial line
    task capture_packet();
        uart_packet pkt;
        bit [7:0] data;
        bit start_bit, stop_bit;

        // Wait for falling edge (start bit)
        wait_for_start_bit();

        // Sample start bit in middle
 
		wait_rx_tickks(baud_ticks_per_bit/2);
        start_bit = vif.mon_cb.tx;
		$display("[TX_MON] got the start bit = %b @ %0t", vif.mon_cb.tx, $time);

        if (start_bit !== 1'b0)
            $warning("[TX_MON] Invalid start bit");

        // Move to first data bit
        wait_rx_tickks(baud_ticks_per_bit);

        // Sample 8 data bits
        for (int i = 0; i < 8; i++) begin
            data[i] = vif.mon_cb.tx;
		$display("[TX_MON] got the %d bit = %b @ %0t", i, vif.mon_cb.tx, $time);
            if (i < 7)
                wait_rx_tickks(baud_ticks_per_bit);
        end

        // Sample stop bit
        repeat (baud_ticks_per_bit) @(vif.mon_cb);
        stop_bit = vif.mon_cb.tx;

        if (stop_bit !== 1'b1)
            $warning("[TX_MON] Invalid stop bit");

        // Create packet
        pkt = new();
        pkt.data = data;
        pkt.timestamp = $time;

        mon2scb_mbx.put(pkt);
        packets_captured++;

        $display("[TX_MON] Captured 0x%02h @ %0t", data, $time);
        -> packet_captured;
    endtask

    // Start bit detection
    task wait_for_start_bit();
        // Idle high
        while (vif.mon_cb.tx !== 1'b1)
            @(vif.mon_cb);

        // Falling edge
        while (vif.mon_cb.tx !== 1'b0)
            @(vif.mon_cb);
    endtask

    // Display Statistics
    
    function void display_stats();
        $display("========================================");
        $display("TX MONITOR STATISTICS");
        $display("========================================");
        $display("Packets Captured  : %0d", packets_captured);
        $display("Baud Ticks/Bit    : %0d", baud_ticks_per_bit);
        $display("========================================");
    endfunction
    
endclass

// ============================================================================
// Example Usage
// ============================================================================
/*
    // In testbench:
    
    // Create mailbox
    mailbox #(uart_packet) mon2scb_mb = new();
    
    // Create TX monitor
    uart_tx_monitor tx_mon = new(uart_vif, mon2scb_mb);
    
    // Configure baud rate (clock cycles per bit)
    tx_mon.set_baud_ticks(16);  // Example: 16 clocks per bit
    
    // Run monitor in a fork
    fork
        tx_mon.run();
    join_none
    
    // Monitor events
    fork
        forever begin
            @(tx_mon.packet_captured);
            $display("[TB] TX Monitor captured packet at %0t", $time);
        end
    join_none
    
    // At end of test
    tx_mon.display_stats();
*/