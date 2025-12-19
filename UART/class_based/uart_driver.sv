class uart_driver;

    // 1. Interface & Mailbox
    virtual uart_if.DRV vif;
    mailbox #(uart_packet) gen2drv_mbx;

    // 2. Events (Handshaking)
    event drv_done;        
    event packet_driven;  

    // 3. Stats
    int packets_driven;

    // 4. Constructor
    function new(
        virtual uart_if.DRV vif,
        mailbox #(uart_packet) mbx,
        event done_evt
    );
        this.vif = vif;
        this.gen2drv_mbx = mbx;
        this.drv_done = done_evt;
        this.packets_driven = 0;
    endfunction

    // 5. Main Lifecycle Task
    task run();
        $display("[DRV] Driver Initialized.");

        forever begin
            // A. Wait for reset deassertion
            while (vif.reset === 1'b1) begin
                reset_signals();
                @(vif.drv_cb);
            end

            // B. Active driving with reset watchdog
            fork : driver_logic
                drive_loop();
                begin
                    wait (vif.reset === 1'b1);
                    $display("[DRV] Reset detected! Aborting current packet.");
					-> drv_done;
                    disable driver_logic;
                end
            join_any
            disable driver_logic;
        end
    endtask

    // 6. Worker Loop
    task drive_loop();
        uart_packet pkt;

        forever begin
            gen2drv_mbx.get(pkt);
            $display("[DRV] Got Packet: 0x%h (Delay: %0d)",
                      pkt.data, pkt.inter_packet_delay);

            drive_item(pkt);
            packets_driven++;
        end
    endtask

    // 7. Protocol Logic
    task drive_item(uart_packet pkt);

        // A. Inter-packet delay
        if (pkt.inter_packet_delay > 0) begin
            repeat (pkt.inter_packet_delay)
                @(vif.drv_cb);
        end

        // B. Busy check
        while (vif.drv_cb.tx_busy === 1'b1) begin
            @(vif.drv_cb);
        end

        // C. Align to baud tick
        wait (vif.drv_cb.tx_tickk);

        // D. Drive start bit + data (1-cycle pulse)
        vif.drv_cb.tx_start <= 1'b1;
        vif.drv_cb.tx_data  <= pkt.data;
        @(vif.drv_cb);
        vif.drv_cb.tx_start <= 1'b0;

        @(vif.drv_cb.tx_done);
        // E. Handshake: transmission started
        $display("[DRV] Packet 0x%h Driven successfully. time =%0t", pkt.data, $time);
		-> drv_done;
    endtask

    // 8. Reset helper
    task reset_signals();
        vif.drv_cb.tx_start <= 1'b0;
        vif.drv_cb.tx_data  <= '0;
    endtask

    // 9. Stats
    function void display_stats();
        $display("[DRV] Total Packets Driven: %0d", packets_driven);
    endfunction

endclass
