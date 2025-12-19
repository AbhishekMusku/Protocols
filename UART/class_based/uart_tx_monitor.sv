class uart_tx_monitor;

    virtual uart_if.MON vif;

    mailbox #(uart_packet) mon2scb_mbx;

    event packet_captured;

    int packets_captured;
    int baud_ticks_per_bit;

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

    task capture_packet();
        uart_packet pkt;
        bit [7:0] data;
        bit start_bit, stop_bit;

        wait_for_start_bit();
 
		wait_rx_tickks(baud_ticks_per_bit/2);
        start_bit = vif.mon_cb.tx;
		$display("[TX_MON] got the start bit = %b @ %0t", vif.mon_cb.tx, $time);

        if (start_bit !== 1'b0)
            $warning("[TX_MON] Invalid start bit");
			
        wait_rx_tickks(baud_ticks_per_bit);

        for (int i = 0; i < 8; i++) begin
            data[i] = vif.mon_cb.tx;
		$display("[TX_MON] got the %d bit = %b @ %0t", i, vif.mon_cb.tx, $time);
            if (i < 7)
                wait_rx_tickks(baud_ticks_per_bit);
        end

        repeat (baud_ticks_per_bit) @(vif.mon_cb);
        stop_bit = vif.mon_cb.tx;

        if (stop_bit !== 1'b1)
            $warning("[TX_MON] Invalid stop bit");
        pkt = new();
        pkt.data = data;
        pkt.timestamp = $time;

        mon2scb_mbx.put(pkt);
        packets_captured++;

        $display("[TX_MON] Captured 0x%02h @ %0t", data, $time);
        -> packet_captured;
    endtask

    task wait_for_start_bit();
        while (vif.mon_cb.tx !== 1'b1)
            @(vif.mon_cb);

        while (vif.mon_cb.tx !== 1'b0)
            @(vif.mon_cb);
    endtask
    
    function void display_stats();
        $display("========================================");
        $display("TX MONITOR STATISTICS");
        $display("========================================");
        $display("Packets Captured  : %0d", packets_captured);
        $display("Baud Ticks/Bit    : %0d", baud_ticks_per_bit);
        $display("========================================");
    endfunction
    
endclass

