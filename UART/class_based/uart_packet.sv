class uart_packet;
    
    rand bit [7:0] data;
    rand int inter_packet_delay;  
    
    time timestamp;
    int packet_id;
    static int packet_count = 0;
    
    constraint c_inter_packet_delay {
        inter_packet_delay inside {[0:100]};
        inter_packet_delay dist {0 := 40, [1:10] := 40, [11:50] := 15, [51:100] := 5};
    }
    
    constraint c_data_distribution {
        data dist {
            8'h00       := 5,  // NULL
            8'h0A       := 5,  // LF
            8'h0D       := 5,  // CR
            8'h20       := 5,  // SPACE
            [8'h41:8'h5A] := 15, // A-Z
            [8'h61:8'h7A] := 15, // a-z
            [8'h30:8'h39] := 10, // 0-9
            8'hFF       := 5,  // All 1's
            [8'h00:8'hFF] := 35  // Rest
        };
    }
    
    function new();
        this.packet_id = packet_count++;
        this.timestamp = $time;
        this.inter_packet_delay = 0;
    endfunction
    
    function uart_packet copy();
        uart_packet pkt;
        pkt = new();
        pkt.data = this.data;
        pkt.inter_packet_delay = this.inter_packet_delay;
        pkt.timestamp = this.timestamp;
        return pkt;
    endfunction
    
    function bit compare(uart_packet pkt, output string mismatch_msg);
        mismatch_msg = "";
        
        if (this.data !== pkt.data) begin
            $sformat(mismatch_msg, "Data mismatch: Expected=0x%0h, Got=0x%0h", this.data, pkt.data);
            return 0;
        end
        
        return 1;
    endfunction
    
    function bit [10:0] pack_to_bits();
        bit [10:0] packedd;
        packedd[0] = 0;              // Start bit
        packedd[8:1] = data;         // Data bits (LSB first in transmission)
        packedd[9] = 1;              // Stop bit
        packedd[10] = 1;             // Idle
        return packedd;
    endfunction
    
    function void unpack_from_bits(bit [10:0] packedd);
        data = packedd[8:1];
    endfunction
    
    function void display(string prefix = "");
        $display("%s[PKT#%0d @ %0t] Data=0x%02h (%c) | Delay=%0d", prefix, packet_id, timestamp, data, (data >= 32 && data <= 126) ? data : ".", inter_packet_delay);
    endfunction
    
    function void print(string prefix = "");
        $display("====================================================================");
        $display("%sUART Packet #%0d", prefix, packet_id);
        $display("  Timestamp        : %0t", timestamp);
        $display("  Data (Hex)       : 0x%02h", data);
        $display("  Data (Dec)       : %0d", data);
        $display("  Data (Bin)       : 0b%08b", data);
        $display("  Data (Char)      : %c", (data >= 32 && data <= 126) ? data : ".");
        $display("  Inter-pkt Delay  : %0d cycles", inter_packet_delay);
        $display("====================================================================");
    endfunction
    

    function string to_string();
        string s;
        $sformat(s, "[PKT#%0d] Data=0x%02h Delay=%0d", 
                 packet_id, data, inter_packet_delay);
        return s;
    endfunction
    
endclass
