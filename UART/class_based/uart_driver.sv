class uart_driver;

    virtual uart_if.DRV vif;
    mailbox #(uart_packet) gen2drv_mbx;

    event drv_done;        
    event packet_driven;  

    int packets_driven;

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

    task run();
        $display("[DRV] Driver Initialized.");

        forever begin
            while (vif.reset === 1'b1) begin
                reset_signals();
                @(vif.drv_cb);
            end

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

    task drive_item(uart_packet pkt);

        if (pkt.inter_packet_delay > 0) begin
            repeat (pkt.inter_packet_delay)
                @(vif.drv_cb);
        end

        while (vif.drv_cb.tx_busy === 1'b1) begin
            @(vif.drv_cb);
        end

        wait (vif.drv_cb.tx_tickk);

        vif.drv_cb.tx_start <= 1'b1;
        vif.drv_cb.tx_data  <= pkt.data;
        @(vif.drv_cb);
        vif.drv_cb.tx_start <= 1'b0;

        @(vif.drv_cb.tx_done);
        $display("[DRV] Packet 0x%h Driven successfully. time =%0t", pkt.data, $time);
		-> drv_done;
    endtask
	
    task reset_signals();
        vif.drv_cb.tx_start <= 1'b0;
        vif.drv_cb.tx_data  <= '0;
    endtask

    function void display_stats();
        $display("[DRV] Total Packets Driven: %0d", packets_driven);
    endfunction

endclass
