class uart_generator;
    
    typedef enum {
        GEN_RANDOM,         
        GEN_CORNER_CASES,   
        GEN_BURST,          
        GEN_ALL_VALUES     
    } gen_mode_e;
 
    mailbox #(uart_packet) gen2drv_mbox;
    event drv_done;
	
    // Configuration
    gen_mode_e mode;
    int num_packets;
    bit stop_gen;
    
    int packets_generated;
    
    function new(mailbox #(uart_packet) mbox, event done_evt);
        this.gen2drv_mbox = mbox;
        this.mode = GEN_RANDOM;
        this.num_packets = 10;
        this.stop_gen = 0;
        this.packets_generated = 0;
		this.drv_done    = done_evt;
    endfunction
    
    function void set_mode(gen_mode_e m);
        this.mode = m;
        $display("[GENERATOR] Mode set to: %s", m.name());
    endfunction
    
    function void set_num_packets(int n);
        this.num_packets = n;
        $display("[GENERATOR] Number of packets set to: %0d", n);
    endfunction
    
    function void stop();
        this.stop_gen = 1;
        $display("[GENERATOR] Stop requested");
    endfunction
    
    // Main Generation Task
    task run();
        $display("[GENERATOR] Starting generation with mode: %s, num_packets: %0d", mode.name(), num_packets);
        
        case (mode)
            GEN_RANDOM:         generate_random();
            GEN_CORNER_CASES:   generate_corner_cases();
            GEN_BURST:          generate_burst();
            GEN_ALL_VALUES:     generate_all_values();
            default:            generate_random();
        endcase
        
        $display("[GENERATOR] Generation complete. Total packets: %0d", packets_generated);
    endtask
    
    // Generation Methods for Different Modes

    // Random Generation - Fully randomized
    task generate_random();
        uart_packet pkt;
        
        for (int i = 0; i < num_packets && !stop_gen; i++) begin
            pkt = new();
            assert(pkt.randomize()) else $fatal("[GENERATOR] Randomization failed!");
            
            send_packet(pkt);
        end
    endtask
    
    // Corner Cases - 0x00, 0xFF, 0x55, 0xAA
   task generate_corner_cases();
        uart_packet pkt;
        bit [7:0] corner_values[4] = '{8'h00, 8'hFF, 8'h55, 8'hAA};
        int idx = 0;
        
        for (int i = 0; i < num_packets && !stop_gen; i++) begin
            pkt = new();
            assert(pkt.randomize() with {data == corner_values[idx];});
            
            send_packet(pkt);
            
            // Cycle through corner cases
            idx = (idx + 1) % 4;
        end
    endtask

   // Burst Mode - Back-to-back packets with zero delay
    task generate_burst();
        uart_packet pkt;
        
        for (int i = 0; i < num_packets && !stop_gen; i++) begin
            pkt = new();
            assert(pkt.randomize() with {inter_packet_delay == 0;  });
            
            send_packet(pkt);
        end
    endtask
    
    // All Values - Exhaustive 0x00 to 0xFF
    task generate_all_values();
        uart_packet pkt;
        int total = (num_packets < 256) ? num_packets : 256;
        
        for (int i = 0; i < total && !stop_gen; i++) begin
            pkt = new();
            assert(pkt.randomize() with {data == i[7:0];});
            
            send_packet(pkt);
        end
    endtask
  
    // Send packet to driver via mailbox
    task send_packet(uart_packet pkt);
        gen2drv_mbox.put(pkt);
        packets_generated++;
        pkt.display("[GEN] ");
		@(drv_done);
    endtask
    

    function void display_stats();
        $display("========================================");
        $display("GENERATOR STATISTICS");
        $display("========================================");
        $display("Mode              : %s", mode.name());
        $display("Packets Generated : %0d", packets_generated);
        $display("========================================");
    endfunction
    
endclass
