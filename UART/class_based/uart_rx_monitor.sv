class uart_rx_monitor;

    virtual uart_if.MON vif;

    mailbox #(uart_packet) mon2scb_mbx;

    event packet_captured;

    int packets_captured;
    bit active;

    function new(virtual uart_if.MON vif, mailbox #(uart_packet) mbx);
        this.vif = vif;
        this.mon2scb_mbx = mbx;
        this.packets_captured = 0;
        this.active = 0;
    endfunction

    task run();
        active = 1;
        $display("[RX_MON] Started monitoring RX output");

        forever begin
            capture_packet();
        end
    endtask

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

        -> packet_captured;
    endtask

    function void display_stats();
        $display("========================================");
        $display("RX MONITOR STATISTICS");
        $display("========================================");
        $display("Packets Captured : %0d", packets_captured);
        $display("Status           : %s", active ? "ACTIVE" : "IDLE");
        $display("========================================");
    endfunction

endclass


