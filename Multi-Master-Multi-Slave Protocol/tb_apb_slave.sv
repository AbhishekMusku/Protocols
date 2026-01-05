`timescale 1ns/1ps

module tb_apb_slave;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter MEM_DEPTH  = 256;
    parameter WAIT_CYCLES = 2; // Testing logic with 2 wait states

    logic                    pclk;
    logic                    resetn;
    logic                    psel;
    logic                    penable;
    logic                    pwrite;
    logic [ADDR_WIDTH-1:0]   paddr;
    logic [DATA_WIDTH-1:0]   pwdata;
    logic                    pready;
    logic [DATA_WIDTH-1:0]   prdata;

    apb_slave_variable_latency #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEM_DEPTH(MEM_DEPTH),
        .WAIT_CYCLES(WAIT_CYCLES)
    ) dut (
        .pclk(pclk),
        .resetn(resetn),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .pready(pready),
        .prdata(prdata)
    );


    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk; // 10ns Clock Period
    end


    // Task: Write Data
    task apb_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            // A. SETUP PHASE
            @(posedge pclk);
            paddr   <= addr;
            pwdata  <= data;
            pwrite  <= 1'b1;
            psel    <= 1'b1;
            penable <= 1'b0; // Setup means Enable is LOW

            // B. ACCESS PHASE
            @(posedge pclk);
            penable <= 1'b1; // Enable goes HIGH

            // C. WAIT FOR READY
            // We sample pready at the clock edge. 
            // If it's 0, we stay in this loop (Wait States).
            wait(pready == 1'b1);
            
            // D. FINISH
            // Standard allows us to go to IDLE or Keep PSEL high.
            // For safety, let's go to IDLE.
            @(posedge pclk);
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            
            $display("[WRITE] Addr: 0x%h, Data: 0x%h, Time: %0t", addr, data, $time);
        end
    endtask

    // Task: Read Data & Verify
    task apb_read(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] expected_data);
        begin
            // A. SETUP PHASE
            @(posedge pclk);
            paddr   <= addr;
            pwrite  <= 1'b0; // Read
            psel    <= 1'b1;
            penable <= 1'b0;

            // B. ACCESS PHASE
            @(posedge pclk);
            penable <= 1'b1;

            // C. WAIT FOR READY
			while (pready === 1'b0) begin
				@(posedge pclk); // Wait for next cycle and check again
			end

            // D. SAMPLE & CHECK
            // We must sample prdata *at the edge* where pready is high
            // Note: Since we are in the procedural block after `wait`, 
            // we are strictly at the moment the condition became true? 
            // Ideally, we check values right before the next clock edge.
            // For simplicity in TB, we check now.
            if (prdata !== expected_data) begin
                $error("[READ FAIL] Addr: 0x%h | Exp: 0x%h | Got: 0x%h", addr, expected_data, prdata);
            end else begin
                $display("[READ PASS] Addr: 0x%h | Data: 0x%h", addr, prdata);
            end

            psel    <= 1'b0;
            penable <= 1'b0;
        end
    endtask

    // ------------------------------------------------
    // 5. Main Test Sequence
    // ------------------------------------------------
    initial begin
        // Initialize Signals
        psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
        resetn = 0;
        
        // Reset Pulse
        repeat(5) @(posedge pclk);
        resetn = 1;
        $display("--- Reset Released ---");

        // TEST 1: Basic Write and Read back
        // Address 0x10 -> Word Index 4 (because 0x10 / 4 = 4)
        $display("\n--- Test 1: Write to 0x10 ---");
        apb_write(32'h0000_0010, 32'hDEAD_BEEF);
        apb_read (32'h0000_0010, 32'hDEAD_BEEF);

        // TEST 2: Check Aliasing (Wait Cycle Logic)
        // Address 0x14 -> Word Index 5
        // We expect PREADY to take some time.
        $display("\n--- Test 2: Write to 0x14 with Latency ---");
        apb_write(32'h0000_0014, 32'hCAFE_F00D);
        apb_read (32'h0000_0014, 32'hCAFE_F00D);

        // TEST 3: Back-to-Back Writes (Stress Test)
        // Check if slave recovers fast enough
        $display("\n--- Test 3: Back-to-Back Writes ---");
        apb_write(32'h0000_0020, 32'hAAAA_AAAA); // Addr 0x20
        apb_write(32'h0000_0024, 32'h5555_5555); // Addr 0x24 (Next word)
        
        // Verify both
        apb_read(32'h0000_0020, 32'hAAAA_AAAA);
        apb_read(32'h0000_0024, 32'h5555_5555);

        // End Simulation
        #100;
        $display("\n--- All Tests Passed ---");
        $finish;
    end

endmodule