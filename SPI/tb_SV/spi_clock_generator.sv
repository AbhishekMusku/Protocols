module spi_clock_generator #(
    parameter SPI_MODE = 0,
    parameter CLKS_PER_HALF_BIT = 2
)(
    // System signals
    input  logic       i_Clk,
    input  logic       i_Rst_L,      // Active low reset
    
    // Control signals
    input  logic       i_TX_DV,      // Start transaction (data valid pulse)
    output logic       o_TX_Ready,   // Ready to accept new transaction
    
    // SPI Clock outputs (for other modules to use)
    output logic       o_SPI_Clk,         // The actual SPI clock
    output logic       o_Leading_Edge,    // Pulse on leading edge
    output logic       o_Trailing_Edge    // Pulse on trailing edge
);

    //==========================================================================
    // Internal Signals - Already declared for you
    //==========================================================================
    
    // CPOL and CPHA decode
    logic w_CPOL;
    logic w_CPHA;
    
    // Clock generation signals
    logic [$clog2(CLKS_PER_HALF_BIT*2)-1:0] r_SPI_Clk_Count;
    logic r_SPI_Clk;
    logic [4:0] r_SPI_Clk_Edges;
    logic r_Leading_Edge;
    logic r_Trailing_Edge;
    
    //==========================================================================
    // TODO 1: Decode SPI_MODE into CPOL and CPHA
    //==========================================================================
    // Hint: 
    // Mode 0: CPOL=0, CPHA=0
    // Mode 1: CPOL=0, CPHA=1
    // Mode 2: CPOL=1, CPHA=0
    // Mode 3: CPOL=1, CPHA=1
    
    assign w_CPOL = (SPI_MODE == 2) || (SPI_MODE == 3);
    assign w_CPHA = (SPI_MODE == 1) || (SPI_MODE == 3);
    
    //==========================================================================
    // TODO 2: Main Clock Generation Logic
    //==========================================================================
    // Your task: Implement the always block that:
    // 1. Handles reset
    // 2. Generates edge pulses (r_Leading_Edge, r_Trailing_Edge)
    // 3. Toggles r_SPI_Clk
    // 4. Counts edges (r_SPI_Clk_Edges)
    // 5. Manages o_TX_Ready
    
	always @(posedge i_Clk or negedge i_Rst_L) begin
		if(~i_Rst_L) begin
			o_TX_Ready <= '1;
			o_SPI_Clk <= w_CPOL;          // ✓ Output
			o_Leading_Edge <= '0;          // ✓ Output
			o_Trailing_Edge <= '0;         // ✓ Output
			r_SPI_Clk_Count <= '0;
			r_SPI_Clk_Edges <= '0;
		end
		else begin
			o_Leading_Edge  <= 1'b0;       
			o_Trailing_Edge <= 1'b0;       
			
			if(i_TX_DV) begin
				o_TX_Ready <= '0;
				r_SPI_Clk_Edges <= 16;
			end
			else if(r_SPI_Clk_Edges > 0) begin
				o_TX_Ready <= '0;
				
				if(r_SPI_Clk_Count == CLKS_PER_HALF_BIT*2 - 1) begin
					r_SPI_Clk_Count <= 0;
					o_SPI_Clk <= ~o_SPI_Clk;    
					r_SPI_Clk_Edges <= r_SPI_Clk_Edges - 1'b1;
					o_Trailing_Edge <= '1;       
				end
				else if(r_SPI_Clk_Count == CLKS_PER_HALF_BIT - 1) begin
					r_SPI_Clk_Edges <= r_SPI_Clk_Edges - 1'b1;
					r_SPI_Clk_Count <= r_SPI_Clk_Count + 1;
					o_SPI_Clk <= ~o_SPI_Clk;     
					o_Leading_Edge <= '1;         
				end
				else begin
					r_SPI_Clk_Count <= r_SPI_Clk_Count + 1;
				end
			end
			else begin
				o_TX_Ready <= 1'b1;
			end
		end
	end
		

endmodule