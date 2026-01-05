`timescale 1ns/1ps
module tb_apb_soc;

    // ---------------------------------------------------------
    // 1. Parameters & Signals
    // ---------------------------------------------------------
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam N_SLAVES   = 4;
	parameter NUM_MASTERS = 4; 
    localparam SLAVE_ADDR_BITS = 10; // 1KB slot per slave

    logic pclk;
    logic resetn;

    // Inputs to SoC 
    logic [NUM_MASTERS-1:0]		ext_transfer_i;
    logic [NUM_MASTERS-1:0]		ext_write_i;
    logic [ADDR_WIDTH-1:0]		ext_addr_i [NUM_MASTERS-1:0];
    logic [DATA_WIDTH-1:0]		ext_data_i [NUM_MASTERS-1:0];

    // Outputs from SoC 
    logic                    soc_ready_o;
    logic [DATA_WIDTH-1:0]   soc_rdata_o;

    int error_count = 0;

    int burst_len = 4;
    // ---------------------------------------------------------
    // 2. Instantiate the Top Level (DUT)
    // ---------------------------------------------------------
    apb_soc_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .N_SLAVES(N_SLAVES),
		.NUM_MASTERS(NUM_MASTERS),
        .SLAVE_ADDR_BITS(SLAVE_ADDR_BITS)
    ) dut (
        .pclk           (pclk),
        .resetn         (resetn),
        .ext_transfer_i (ext_transfer_i),
        .ext_write_i    (ext_write_i),
        .ext_addr_i     (ext_addr_i),
        .ext_data_i     (ext_data_i),
        .soc_ready_o    (soc_ready_o),
        .soc_rdata_o    (soc_rdata_o)
    );

    // ---------------------------------------------------------
    // 3. Clock Generation
    // ---------------------------------------------------------
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk; // 100MHz (10ns period)
    end

    // ---------------------------------------------------------
    // 4. Tasks (Driver Methods)
    // ---------------------------------------------------------
    
    // Task: Reset the system
    task apply_reset(input int master_id);
        begin
            $display("[TB] System Reset Asserted");
            resetn = 0;
            ext_transfer_i[master_id] = 0;
            ext_write_i[master_id]    = 0;
            ext_addr_i[master_id]     = 0;
            ext_data_i [master_id]    = 0;
            repeat(5) @(posedge pclk);
            resetn = 1;
            $display("[TB] System Reset Released");
            @(posedge pclk);
        end
    endtask

	// ---------------------------------------------------------
    //Write Task
    // ---------------------------------------------------------
    task automatic master_write(input int id, input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            // 1. Fire the Request (Pulse transfer_i)
            // We do this immediately so both masters request at the same time
			$display("WRITE being done @ %0t", $time);
            @(posedge pclk);
            ext_addr_i[id]      <= addr;
            ext_data_i[id]      <= data;
            ext_write_i[id]     <= 1'b1;
            ext_transfer_i[id]  <= 1'b1; 
            
            @(posedge pclk);
            ext_transfer_i[id]  <= 1'b0; // Pulse ends
            ext_write_i[id]     <= 1'b0;

            wait(dut.u_interconnect.pgrant[id] == 1'b1);

            do begin
                @(posedge pclk);
            end while (soc_ready_o == 0);

            $display("[TB] Master %0d Concurrent Write DONE | Addr: 0x%h | Data: 0x%h", id, addr, data);
        end
    endtask

	// ---------------------------------------------------------
    // Read Task
    // ---------------------------------------------------------
    task automatic master_read(input int id, input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] exp_data);
        begin
			$display("READ being done @ %0t", $time);
            @(posedge pclk);
            ext_addr_i[id]      <= addr;
            ext_write_i[id]     <= 1'b0; // READ
            ext_transfer_i[id]  <= 1'b1;
            
            @(posedge pclk);
            ext_transfer_i[id]  <= 1'b0; 

            wait(dut.u_interconnect.pgrant[id] == 1'b1);

            do begin
                @(posedge pclk);
            end while (soc_ready_o == 0);

            if (soc_rdata_o !== exp_data) begin
                $error("[TB] Master %0d READ FAIL! Addr: 0x%h | Exp: 0x%h | Got: 0x%h", id, addr, exp_data, soc_rdata_o);
                error_count++;
            end else begin
                $display("[TB] Master %0d Concurrent Read PASS | Addr: 0x%h | Data: 0x%h", id, addr, soc_rdata_o);
            end
        end
    endtask



	// ---------------------------------------------------------
    // Burst Write Task
    // ---------------------------------------------------------
    task automatic master_burst_write(input int id, input [ADDR_WIDTH-1:0] start_addr, input int length, input [DATA_WIDTH-1:0] start_data);
        begin
            $display("[TB] Master %0d Starting BURST WRITE (Len: %0d) @ %0t", id, length, $time);
            
            @(posedge pclk);
            ext_write_i[id]     <= 1'b1;
            ext_transfer_i[id]  <= 1'b1;
			ext_addr_i[id] <= start_addr;
			ext_data_i[id] <= start_data;
            wait(dut.u_interconnect.pgrant[id] == 1'b1);
			do begin
				@(posedge pclk);
			end while (soc_ready_o == 0);

            for (int k = 1; k < length; k++) begin
				ext_addr_i[id] <= start_addr + (k * 4);
                ext_data_i[id] <= start_data + k;
				$display("WRITE  Addr: 0x%h Data: 0x%h @ %0t", start_addr + ((k - 1) * 4), start_data + k - 1, $time);    
                do begin
                    @(posedge pclk);
                end while (soc_ready_o == 0);
            end
			
			ext_addr_i[id] <= start_addr + (7 * 4);
			ext_data_i[id] <= start_data + 7;
			$display("WRITE  Addr: 0x%h Data: 0x%h @ %0t", start_addr + (7 * 4), start_data + 7, $time); 
            @(posedge pclk);
            ext_transfer_i[id]  <= 1'b0; 		

			do begin
				@(posedge pclk);
			end while (soc_ready_o == 0);
            
            $display("[TB] Master %0d BURST WRITE DONE @ %0t", id, $time);
        end
    endtask

    // ---------------------------------------------------------
    // Burst Read Task 
    // ---------------------------------------------------------
    task automatic master_burst_read(input int id, input [ADDR_WIDTH-1:0] start_addr, input int length, input [DATA_WIDTH-1:0] start_exp_data);
        begin
            $display("[TB] Master %0d Starting BURST READ (Len: %0d) @ %0t", id, length, $time);

            @(posedge pclk);
            ext_write_i[id]     <= 1'b0; // Read
            ext_transfer_i[id]  <= 1'b1; // Lock the bus
			ext_addr_i[id] <= start_addr;
            wait(dut.u_interconnect.pgrant[id] == 1'b1);
			do begin
			   @(posedge pclk);
			end while (soc_ready_o == 0);			
			
            for (int k = 1; k < length; k++) begin

				ext_addr_i[id] <= start_addr + (k * 4);
				do begin
                    @(posedge pclk);
                end while (soc_ready_o == 0);
                if (soc_rdata_o !== (start_exp_data + k - 1)) begin
                    $error("[TB] Burst Read Fail! Idx: %0d | Addr: 0x%h Exp: 0x%h | Got: 0x%h  @ %0t", k, start_addr + ((k-1) * 4), (start_exp_data + k - 1), soc_rdata_o, $time);
                    error_count++;
                end
				else begin
                    $display("[TB] Burst Read PASS Idx: %0d | Addr: 0x%h Exp: 0x%h | Got: 0x%h  @ %0t", k, start_addr + ((k-1) * 4), (start_exp_data + k - 1), soc_rdata_o, $time);				
				end
            end

            ext_transfer_i[id] <= 1'b0;
            
            $display("[TB] Master %0d BURST READ DONE @ %0t", id, $time);
        end
    endtask


    initial begin
        // --- Setup ---
		for (int i = 0; i < NUM_MASTERS; i++) begin
			apply_reset(i);
		end
        
        $display("---------------------------------------------------");
        $display("Test 1: Basic R/W to Slave 0 (Fast Slave, 0 wait)");
        $display("---------------------------------------------------");
        // Slave 0 base is 0x0000_0000. 
        master_write(2, 32'h0000_0010, 32'hDEAD_BEEF);
        master_read (0, 32'h0000_0010, 32'hDEAD_BEEF);


        $display("\n---------------------------------------------------");
        $display("Test 2: R/W to Slave 3 (Slow Slave, 3 wait cycles)");
        $display("---------------------------------------------------");
        // Slave 3 base is 0x0000_3000 (Bits 13:12 = 2'b11 = 3)
        master_write(0, 32'h0000_3000, 32'hCAFE_BABE);
        master_read (0, 32'h0000_3000, 32'hCAFE_BABE);


        $display("\n---------------------------------------------------");
        $display("Test 3: Verify Address Aliasing on Slave 0");
        $display("---------------------------------------------------");
        // Slave depth is 256 (1KB or 0x400 bytes).
        // 0x0410 should shadow 0x0010 because bits [11:10] are ignored by slave.
        $display("[TB] Reading from Aliased Address 0x0000_0410...");
        master_read (1,32'h0000_0410, 32'hDEAD_BEEF);


        $display("\n---------------------------------------------------");
        $display("Test 4: Cross-Slave Integrity");
        $display("---------------------------------------------------");
        master_write(2,32'h0000_1000, 32'h1234_5678);
        
        master_read (1,32'h0000_0010, 32'hDEAD_BEEF);
        
        master_read (1,32'h0000_1000, 32'h1234_5678);


		$display("\n---------------------------------------------------");
        $display("Test 5: Concurrent Burst (Master 0 & Master 1 at same time)");
        $display("---------------------------------------------------");
       
        fork
            // Thread A: Master 0 writes to Slave 0 (Fast)
            begin
                $display("[TB] @%0t: Master 0 Requesting...", $time);
                master_write(0, 32'h0000_0020, 32'hAAAA_AAAA);
            end

            // Thread B: Master 1 writes to Slave 1 (Wait cycles = 1)
            begin
                $display("[TB] @%0t: Master 1 Requesting...", $time);
                master_write(1, 32'h0000_1020, 32'hBBBB_BBBB);
            end
			begin
                $display("[TB] @%0t: Master 2 Requesting...", $time);
                master_write(2, 32'h0000_3020, 32'hCCCC_CCCC);
            end
        join

        $display("[TB] Verifying Data Integrity...");
        master_read(1, 32'h0000_0020, 32'hAAAA_AAAA); // Check M0's work
        master_read(0, 32'h0000_1020, 32'hBBBB_BBBB); // Check M1's work
		
		$display("\n---------------------------------------------------");
        $display("Test 7: Concurrent Bursts (Interleaved Transactions)");
        $display("---------------------------------------------------");
        
        
        $display("[TB] Starting Concurrent Write Burst...");

        fork
            // --- THREAD A: Master 0 (Priority High) ---
            // Writing pattern 0xA0, 0xA1, 0xA2... to Slave 0
            begin
                for (int k = 0; k < burst_len; k++) begin
                    master_write(0, 32'h0000_0000 + (k*4), 32'hA000_0000 + k);
                    
                    // Small delay to allow Arbiter to give bus to Master 1
                    // If we remove this, Master 0 might hog the bus 100% of the time.
                    repeat($urandom_range(1,3)) @(posedge pclk);
                end
                $display("[TB] Master 0 Write Burst Complete");
            end

            // --- THREAD B: Master 1 (Priority Low) ---
            // Writing pattern 0xB0, 0xB1, 0xB2... to Slave 1
            begin
                for (int k = 0; k < burst_len; k++) begin
                    // Addr: Base 0x1000 + offset
                    // Data: 0xB000 + index
                    master_write(1, 32'h0000_1000 + (k*4), 32'hB000_0000 + k);
                    
                    repeat($urandom_range(1,3)) @(posedge pclk);
                end
                 $display("[TB] Master 1 Write Burst Complete");
            end
        join

        // ---------------------------------------------------------
        // Verify Data with Concurrent Read Burst
        // ---------------------------------------------------------
        $display("\n[TB] Verifying Data with Concurrent Read Burst...");
        
        fork
            // --- THREAD A: Master 0 Reading Back ---
            begin
                for (int k = 0; k < burst_len; k++) begin
                    master_read(0, 32'h0000_0000 + (k*4), 32'hA000_0000 + k);
                    repeat($urandom_range(1,3)) @(posedge pclk);
                end
            end

            // --- THREAD B: Master 1 Reading Back ---
            begin
                for (int k = 0; k < burst_len; k++) begin
                    master_read(1, 32'h0000_1000 + (k*4), 32'hB000_0000 + k);
                    repeat($urandom_range(1,3)) @(posedge pclk);
                end
            end
        join
				
		$display("\n---------------------------------------------------");
        $display("Test 10: Locked Burst (High Priority M0 holds bus vs M1)");
        $display("---------------------------------------------------");

        fork
            // --- THREAD A: Master 0 ---
            begin
                // Writing 0x1000, 0x1001... to 0x0000_0000
                master_burst_write(0, 32'h0000_0000, 8, 32'hDEAD_BEE1);
            end

            // --- THREAD B: Master 1 (The Interrupter) ---
            begin
                //repeat(4) @(posedge pclk);
                
                $display("[TB] @%0t: Master 1 attempting to interrupt...", $time);
                
                // This call should BLOCK until M0 is totally done
                master_burst_write(1, 32'h0000_0020, 8, 32'hDEAD_DEAD);
                
                $display("[TB] @%0t: Master 1 finally finished!", $time);
            end
			
			            begin
                //Wait 2 cycles so M0 is definitely running
                //repeat(4) @(posedge pclk);
                
                $display("[TB] @%0t: Master 1 attempting to interrupt...", $time);
                
                // This call should BLOCK until M0 is totally done
                master_burst_write(2, 32'h0000_0820, 8, 32'hDEAD_FAAB);
                
                $display("[TB] @%0t: Master 1 finally finished!", $time);
            end
        join

        // Verify Data

        $display("[TB] Verifying Burst Data...");
		//master_read(0, 32'h0000_0000, 32'hDEAD_BEE1);
        master_burst_read(0, 32'h0000_0000, 8, 32'hDEAD_BEE1);
		master_burst_read(1, 32'h0000_0020, 8, 32'hDEAD_DEAD);
		master_burst_read(0, 32'h0000_0000, 8, 32'hDEAD_BEE1);
		master_burst_read(2, 32'h0000_0820, 8, 32'hDEAD_FAAB);
		//master_read(0, 32'h0000_0008, 32'hDEAD_BEE1);

        // --- Summary ---
        $display("\n---------------------------------------------------");
        if (error_count == 0) begin
            $display(" [SUCCESS] All Tests Passed!");
        end else begin
            $display(" [FAILURE] Found %0d mismatches.", error_count);
        end
        $display("---------------------------------------------------");
        
        #100 $finish;
    end
endmodule