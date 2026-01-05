module apb_slave_variable_latency #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH  = 256,
    parameter WAIT_CYCLES = 2 
)(
    input  logic                    pclk,
    input  logic                    resetn,
    
    input  logic                    psel,
    input  logic                    penable,
    input  logic                    pwrite,
    input  logic [ADDR_WIDTH-1:0]   paddr,
    input  logic [DATA_WIDTH-1:0]   pwdata,
    
    output logic                    pready,
    output logic [DATA_WIDTH-1:0]   prdata
);

    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];
    logic [$clog2(MEM_DEPTH)-1:0] mem_index;
	
    logic [3:0] wait_counter; 

    assign mem_index = paddr[$clog2(MEM_DEPTH)+1 : 2];

    always_ff @(posedge pclk or negedge resetn) begin
        if (!resetn) begin
            wait_counter <= 0;
        end else begin
            // 1. Setup Phase (PSEL=1, PENABLE=0): Load the counter
            if (psel && !penable) begin
                wait_counter <= WAIT_CYCLES;
            end 
            // 2. Access Phase (PSEL=1, PENABLE=1): Decrement until 0
            else if (psel && penable) begin
                if (wait_counter > 0) begin
                    wait_counter <= wait_counter - 1;
                end
            end
        end
    end


    assign pready = (psel && penable && (wait_counter == 0));
  
    always_ff @(posedge pclk) begin
        if (psel && penable && pwrite && (wait_counter == 0)) begin
            mem[mem_index] <= pwdata;
			
        end
    end

    // READ
    always_comb begin
        if (psel && !pwrite) begin
            prdata = mem[mem_index]; 
        end else begin
            prdata = '0;
        end
    end

endmodule