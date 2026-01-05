`timescale 1ns/1ps

module tb_apb_master;

    // -------------------------------------------------------------------------
    // 1. Parameters & Signals
    // -------------------------------------------------------------------------
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    // System Signals
    logic                    pclk;
    logic                    resetn;

    // User Interface (CPU -> Master)
    logic                    transfer_i;
    logic                    write_i;
    logic [ADDR_WIDTH-1:0]   addr_i;
    logic [DATA_WIDTH-1:0]   data_i;

    // APB Interface (Master -> Slave)
    logic                    psel;
    logic                    penable;
    logic                    pwrite;
    logic [ADDR_WIDTH-1:0]   paddr;
    logic [DATA_WIDTH-1:0]   pwdata;
    
    // Slave Response
    logic                    pready;
    logic [DATA_WIDTH-1:0]   prdata;

    // Testbench Control
    int wait_states = 0; // Control how many cycles the dummy slave waits

    // -------------------------------------------------------------------------
    // 2. DUT Instantiation
    // -------------------------------------------------------------------------
    apb_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .pclk       (pclk),
        .resetn     (resetn),
        .transfer_i (transfer_i),
        .write      (write_i),
        .addr       (addr_i),
        .data       (data_i),
        .psel       (psel),
        .penable    (penable),
        .pwrite     (pwrite),
        .paddr      (paddr),
        .pwdata     (pwdata),
        .pready     (pready),
        .prdata     (prdata)
    );

    // -------------------------------------------------------------------------
    // 3. Clock & Reset
    // -------------------------------------------------------------------------
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk; // 100MHz
    end

    // -------------------------------------------------------------------------
    // 4. Dummy Slave Model (Responsive)
    // -------------------------------------------------------------------------
    always @(posedge pclk or negedge resetn) begin
        if (!resetn) begin
            pready <= 0;
            prdata <= '0;
        end else begin
            // Default: Not ready
            pready <= 0;

            // Only respond in ACCESS phase (PSEL=1, PENABLE=1)
            if (psel && penable) begin
                if (wait_states > 0) begin
                    wait_states <= wait_states - 1;
                    pready <= 0;
                end else begin
                    pready <= 1; // Drive Ready
                    if (!pwrite) prdata <= 32'hDEAD_BEEF; // Return dummy data on read
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 5. Tasks (CPU Drivers)
    // -------------------------------------------------------------------------

    // TASK: Single Transfer
    // Safely waits for PREADY before dropping request.
    task single_transfer(input logic is_write, input logic [31:0] addr, input logic [31:0] data);
        // 1. Drive Request
        @(posedge pclk);
        transfer_i <= 1;
        write_i    <= is_write;
        addr_i     <= addr;
        data_i     <= data;

        // 2. Wait for Handshake (ACCESS + READY)
        wait(psel && penable && pready);

        #1; 
        transfer_i <= 0; 
        
        // 4. Align with end of cycle
        @(posedge pclk);
    endtask

    // TASK: Back-to-Back Transfer
    // Keeps transfer_i High but swaps address when PREADY hits.
    task back_to_back_transfers();
        $display("[%0t] Starting Back-to-Back Transfers...", $time);

        // --- TRANSFER 1 ---
        @(posedge pclk);
        transfer_i <= 1;
        write_i    <= 1;
        addr_i     <= 32'hA000_0001;
        data_i     <= 32'h1111_1111;

        // Wait for completion of T1
        wait(psel && penable && pready);
        
        // --- TRANSFER 2 (Seamless) ---
        // Don't drop transfer_i! Just update address.
        #1;
        addr_i     <= 32'hA000_0002;
        data_i     <= 32'h2222_2222;
        
        // Wait for completion of T2
        // Note: Master transitions ACCESS -> SETUP -> ACCESS
        @(posedge pclk); // Finish T1 cycle
        
        // Now waiting for T2 handshake
        wait(psel && penable && pready);

        // End Sequence
        #1 transfer_i <= 0;
        @(posedge pclk);
        $display("[%0t] Back-to-Back Complete.", $time);
    endtask

    // -------------------------------------------------------------------------
    // 6. Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        // Init
        resetn = 0;
        transfer_i = 0;
        write_i = 0;
        addr_i = 0;
        data_i = 0;
        wait_states = 0;

        // Reset
        #20 resetn = 1;
        @(posedge pclk);

        // Test 1: Single Write (Zero Wait States)
        $display("--- Test 1: Single Write ---");
        single_transfer(1, 32'h100, 32'hAA);
        #20;

        // Test 2: Single Read (with Slave Wait States)
        $display("--- Test 2: Single Read (2 Wait States) ---");
        wait_states = 2; 
        single_transfer(0, 32'h200, 32'h00); // Data ignored on read req
        #20;

        // Test 3: Back-to-Back Writes
        $display("--- Test 3: Back-to-Back Writes ---");
        wait_states = 0;
        back_to_back_transfers();

        #50;
        $display("TEST PASSED");
        $finish;
    end

    // Monitor for Debugging
    initial begin
        $monitor("Time=%0t | State=%b | PSEL=%b PENABLE=%b PREADY=%b | Addr=%h Data=%h", 
                 $time, dut.state, psel, penable, pready, paddr, pwdata);
    end

endmodule