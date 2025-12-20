`timescale 1ns/1ps

module tb_spi_master;

  parameter CLK_PERIOD = 10;       // 100 MHz System Clock
  parameter SPI_MODE = 0;          // Can be 0, 1, 2, 3
  parameter CLKS_PER_HALF_BIT = 2; // 25 MHz SPI Clock (if Sys=100MHz)

  // DUT Interface Signals
  logic       i_Rst_L;
  logic       i_Clk;
  logic [7:0] i_TX_Byte;
  logic       i_TX_DV;
  logic       i_SPI_MISO;

  logic       o_TX_Ready;
  logic       o_RX_DV;
  logic [7:0] o_RX_Byte;
  logic       o_SPI_Clk;
  logic       o_SPI_MOSI;

  // Testbench Variables
  logic [7:0] slave_tx_data = 8'h00; // Data the "Slave" will send back
  int bit_cnt;

  //DUT instantiation
  SPI_Master #(
    .SPI_MODE(SPI_MODE),
    .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
  ) dut (
    .i_Rst_L(i_Rst_L), .i_Clk(i_Clk),
    .i_TX_Byte(i_TX_Byte), .i_TX_DV(i_TX_DV), .o_TX_Ready(o_TX_Ready),
    .o_RX_DV(o_RX_DV), .o_RX_Byte(o_RX_Byte),
    .o_SPI_Clk(o_SPI_Clk), .i_SPI_MISO(i_SPI_MISO), .o_SPI_MOSI(o_SPI_MOSI)
  );



	reg [7:0] shadow_rx_byte;
	reg [2:0] mon_bit_cnt;


    logic transaction_active;
    assign transaction_active = ~o_TX_Ready; 

    initial begin
        // Reset local variables
        shadow_rx_byte = 0;
        mon_bit_cnt = 0;

        forever begin

            mon_bit_cnt = 7;
            
            // --- STEP 2: Sample the bits ---
            repeat(8) begin
                if(SPI_MODE == 0 || SPI_MODE == 3) @(posedge o_SPI_Clk);
                else                               @(negedge o_SPI_Clk);
                
                shadow_rx_byte[mon_bit_cnt] = o_SPI_MOSI;
				$display("[%0t] bit captured %b		o_RX_DV =%b", $time, o_SPI_MOSI, o_RX_DV);
                if(mon_bit_cnt > 0) mon_bit_cnt--;
            end

            // --- STEP 3: Check Result (Wait for Data Valid) ---
            // We use RX_DV because that's when the DUT claims data is valid
            
            if (o_RX_Byte !== shadow_rx_byte) 
                $error("DUT BUG! Wire: 0x%h, DUT: 0x%h", shadow_rx_byte, o_RX_Byte);
            else
                $display("Monitor PASS: 0x%h", o_RX_Byte);

            
        end
    end

  initial i_Clk = 0;
  always #(CLK_PERIOD/2) i_Clk = ~i_Clk; 



  generate
    if (SPI_MODE == 0) begin : SLAVE_MODE_0
        // Async Load MSB when Transaction Starts
        always @(negedge o_TX_Ready) begin
            bit_cnt = 7;
            i_SPI_MISO = slave_tx_data[7]; 
        end

        // Shift remaining bits on Falling Edge
        always @(negedge o_SPI_Clk) begin
            if (transaction_active && bit_cnt > 0) begin
                bit_cnt--;
                i_SPI_MISO <= slave_tx_data[bit_cnt];
            end
        end
    end


    else if (SPI_MODE == 1) begin : SLAVE_MODE_1
        // Reset counter when transaction starts
        always @(negedge o_TX_Ready) bit_cnt = 7;

        // Shift everything (including MSB) on Rising Edge
        always @(posedge o_SPI_Clk) begin
            if (transaction_active) begin
                i_SPI_MISO <= slave_tx_data[bit_cnt];
                if(bit_cnt > 0) bit_cnt--;
            end
        end
    end

    else if (SPI_MODE == 2) begin : SLAVE_MODE_2
        // Async Load MSB when Transaction Starts
        always @(negedge o_TX_Ready) begin
            bit_cnt = 7;
            i_SPI_MISO = slave_tx_data[7]; 
        end

        // Shift remaining bits on Rising Edge
        always @(posedge o_SPI_Clk) begin
            if (transaction_active && bit_cnt > 0) begin
                bit_cnt--;
                i_SPI_MISO <= slave_tx_data[bit_cnt];
            end
        end
    end


    else if (SPI_MODE == 3) begin : SLAVE_MODE_3
        // Reset counter when transaction starts
        always @(negedge o_TX_Ready) bit_cnt = 7;

        // Shift everything (including MSB) on Falling Edge
        always @(negedge o_SPI_Clk) begin
            if (transaction_active) begin
                i_SPI_MISO <= slave_tx_data[bit_cnt];
                if(bit_cnt > 0) bit_cnt--;
            end
        end
    end

  endgenerate

  initial begin
    $dumpfile("spi_hybrid_tb.vcd");
    $dumpvars(0, tb_spi_master);

    // Initialize
    i_Rst_L = 0; i_TX_DV = 0; i_TX_Byte = 0; i_SPI_MISO = 0;

    // Reset Sequence
    #(CLK_PERIOD*5);
    i_Rst_L = 1;
    #(CLK_PERIOD*5);

    $display("\n=== STARTING TEST (MODE %0d) ===", SPI_MODE);

    // --- TEST 1: Simple Pattern ---
    slave_tx_data = 8'h11; 
    send_byte(8'h11); 
    check_response(8'h11);

    // --- TEST 2: Inverse Pattern ---
    #(CLK_PERIOD*10); 
/*    slave_tx_data = 8'h12; 
    send_byte(8'hC3); 
    check_response(8'h12);

    // --- TEST 3: Random Data ---
    #(CLK_PERIOD*10); 
    slave_tx_data = 8'hDB; 
    send_byte(8'h24); 
    check_response(8'hDB);
*/
    $display("\n=== ALL TESTS PASSED ===");
    $finish;
  end

  // --------------------------------------------------------------------------
  // TASKS (My robust driver logic)
  // --------------------------------------------------------------------------
  task send_byte(input [7:0] data);
    begin
      wait(o_TX_Ready);       // Wait for idle
      @(posedge i_Clk);       // Sync
      i_TX_Byte <= data;      // Drive data
      i_TX_DV   <= 1'b1;      // Pulse Valid
      @(posedge i_Clk);
      i_TX_DV   <= 1'b0;      // Release Valid
      $display("[%0t] DRIVER: Sent 0x%h", $time, data);
    end
  endtask

  task check_response(input [7:0] expected);
    begin
      // Wait for the DUT to tell us it has received a full byte
      @(posedge o_RX_DV); 
      
      if (o_RX_Byte === expected)
        $display("[%0t] CHECKER: PASS (Got %b)", $time, o_RX_Byte);
      else
        $error("[%0t] CHECKER: FAIL (Exp: 0x%h, Got: 0x%h)", $time, expected, o_RX_Byte);
    end
  endtask

endmodule