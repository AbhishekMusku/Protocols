class uart_scoreboard;
    
    mailbox #(uart_packet) tx_mon_mbx;  
    mailbox #(uart_packet) rx_mon_mbx; 
    
    event comparison_done;     

    int packets_compared;
    int packets_matched;
    int packets_mismatched;
    int tx_packets_received;
    int rx_packets_received;
    
    bit active;
    
    bit stop_on_mismatch;      
    
    uart_packet tx_queue[$];
    uart_packet rx_queue[$];
    
    function new(mailbox #(uart_packet) tx_mbx, mailbox #(uart_packet) rx_mbx);
        this.tx_mon_mbx = tx_mbx;
        this.rx_mon_mbx = rx_mbx;
        
        this.packets_compared = 0;
        this.packets_matched = 0;
        this.packets_mismatched = 0;
        this.tx_packets_received = 0;
        this.rx_packets_received = 0;
        
        this.active = 0;
        this.stop_on_mismatch = 0;
    endfunction
    
    function void set_stop_on_mismatch(bit value);
        this.stop_on_mismatch = value;
        $display("[SCOREBOARD] Stop on mismatch: %s", value ? "ENABLED" : "DISABLED");
    endfunction
    
    task run();
        active = 1;
        $display("[SCOREBOARD] Started...");
        
        fork
            collect_tx_packets();
            collect_rx_packets();
            compare_packets();
        join
    endtask
    
    task collect_tx_packets();
        uart_packet pkt;
        
        forever begin
            tx_mon_mbx.get(pkt);
            tx_packets_received++;
            
            $display("[SCOREBOARD] TX packet received: Data=0x%02h @ %0t", pkt.data, $time);
            tx_queue.push_back(pkt);
        end
    endtask
    
    task collect_rx_packets();
        uart_packet pkt;
        
        forever begin
            rx_mon_mbx.get(pkt);
            rx_packets_received++;
            
            $display("[SCOREBOARD] RX packet received: Data=0x%02h @ %0t", pkt.data, $time);
            rx_queue.push_back(pkt);
        end
    endtask
    
    task compare_packets();
        uart_packet tx_pkt, rx_pkt;
        string mismatch_msg;
        
        forever begin
            wait(tx_queue.size() > 0 && rx_queue.size() > 0);
            
            tx_pkt = tx_queue.pop_front();
            rx_pkt = rx_queue.pop_front();
            
            if (tx_pkt.compare(rx_pkt, mismatch_msg)) begin
                // Match!
                packets_matched++;
                $display("[SCOREBOARD] ✓ MATCH: TX=0x%02h, RX=0x%02h @ %0t", tx_pkt.data, rx_pkt.data, $time);
            end 
			else begin
                packets_mismatched++;
                $error("[SCOREBOARD] ✗ MISMATCH: %s @ %0t", mismatch_msg, $time);
                $display("[SCOREBOARD]   TX Packet:");
                tx_pkt.print("      ");
                $display("[SCOREBOARD]   RX Packet:");
                rx_pkt.print("      ");
                
                if (stop_on_mismatch) begin
                    $display("[SCOREBOARD] Stopping simulation due to mismatch!");
                    display_final_report();
                    $finish;
                end
            end
            
            packets_compared++;
            -> comparison_done;
            #1;
        end
    endtask
    
    function bit queues_empty();
        return (tx_queue.size() == 0 && rx_queue.size() == 0);
    endfunction
    
    task wait_for_completion(int expected_packets, int timeout_cycles = 10000);
        int start_time = $time;
        
        $display("[SCOREBOARD] Waiting for %0d packet comparisons...", expected_packets);
        
        while (packets_compared < expected_packets) begin
            @(posedge comparison_done);
            
            // Check for timeout
            if (($time - start_time) > timeout_cycles) begin
                $warning("[SCOREBOARD] Timeout waiting for comparisons!");
                $display("[SCOREBOARD] Expected: %0d, Got: %0d", expected_packets, packets_compared);
                break;
            end
        end
        
        // Check for pending packets
        if (!queues_empty()) begin
            $warning("[SCOREBOARD] Pending packets in queues:");
            $display("  TX Queue: %0d packets", tx_queue.size());
            $display("  RX Queue: %0d packets", rx_queue.size());
        end
        
        $display("[SCOREBOARD] Comparison complete.");
    endtask
    
    function void display_stats();
        real pass_rate;
        
        if (packets_compared > 0)
            pass_rate = (real'(packets_matched) / real'(packets_compared)) * 100.0;
        else
            pass_rate = 0.0;
        
        $display("========================================");
        $display("SCOREBOARD STATISTICS");
        $display("========================================");
        $display("TX Packets Received   : %0d", tx_packets_received);
        $display("RX Packets Received   : %0d", rx_packets_received);
        $display("Packets Compared      : %0d", packets_compared);
        $display("Packets Matched       : %0d", packets_matched);
        $display("Packets Mismatched    : %0d", packets_mismatched);
        $display("Pass Rate             : %.2f%%", pass_rate);
        $display("Pending TX Packets    : %0d", tx_queue.size());
        $display("Pending RX Packets    : %0d", rx_queue.size());
        $display("Status                : %s", active ? "ACTIVE" : "IDLE");
        $display("========================================");
    endfunction
    
    function void display_final_report();
        real pass_rate;
        
        if (packets_compared > 0)
            pass_rate = (real'(packets_matched) / real'(packets_compared)) * 100.0;
        else
            pass_rate = 0.0;
        
        $display("");
        $display("========================================================================");
        $display("                    UART VERIFICATION FINAL REPORT");
        $display("========================================================================");
        $display("");
        $display("  Packets Compared      : %0d", packets_compared);
        $display("  Packets Matched       : %0d", packets_matched);
        $display("  Packets Mismatched    : %0d", packets_mismatched);
        $display("  Pass Rate             : %.2f%%", pass_rate);
        $display("");
        
        if (packets_mismatched == 0 && packets_compared > 0) begin
            $display("  *** TEST PASSED ***");
        end else if (packets_compared == 0) begin
            $display("  *** NO COMPARISONS PERFORMED ***");
        end else begin
            $display("  *** TEST FAILED ***");
        end
        
        $display("");
        $display("========================================================================");
        $display("");
    endfunction
    
endclass

