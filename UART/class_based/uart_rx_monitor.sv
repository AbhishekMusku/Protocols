class uart_rx_monitor;

    // Interface
    virtual uart_if.MON vif;

    // Mailbox
    mailbox #(uart_packet) mon2scb_mbx;

    // Event
    event packet_captured;

    // Stats
    int packets_captured;
    bit active;

    // Constructor
    function new(virtual uart_if.MON vif, mailbox #(uart_packet) mbx);
        this.vif = vif;
        this.mon2scb_mbx = mbx;
        this.packets_captured = 0;
        this.active = 0;
    endfunction

    // Main task
    task run();
        active = 1;
        $display("[RX_MON] Started monitoring RX output");

        forever begin
            capture_packet();
        end
    endtask

    // Capture RX byte using rx_ready
    task capture_packet();
        uart_packet pkt;
        bit [7:0] captured_data;

        // Wait for reset deassertion
        while (vif.reset === 1'b1)
            @(vif.mon_cb);

        // Wait for rx_ready pulse
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.rx_ready === 1'b1)
                break;
        end

        // Sample data
        captured_data = vif.mon_cb.rx_data;

        $display("[RX_MON] Packet received: 0x%02h @ %0t",
                 captured_data, $time);

        // Create packet
        pkt = new();
        pkt.data = captured_data;
        pkt.timestamp = $time;

        // Send to scoreboard
        mon2scb_mbx.put(pkt);
        packets_captured++;

        pkt.display("[RX_MON] ");

        // Notify
        -> packet_captured;
    endtask

    // Stats
    function void display_stats();
        $display("========================================");
        $display("RX MONITOR STATISTICS");
        $display("========================================");
        $display("Packets Captured : %0d", packets_captured);
        $display("Status           : %s", active ? "ACTIVE" : "IDLE");
        $display("========================================");
    endfunction

endclass



/*
    // In testbench:
   // Create mailbox
    mailbox #(uart_packet) mon2scb_mb = new();
   // Create RX monitor
    uart_rx_monitor rx_mon = new(uart_vif, mon2scb_mb);
   // Run monitor in a fork
    fork
        rx_mon.run();
    join_none
   // Monitor events
    fork
        forever begin
            @(rx_mon.packet_captured);
            $display("[TB] RX Monitor captured packet at %0t", $time);
        end
    join_none
   // At end of test
    rx_mon.display_stats();
*/