module apb_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic pclk,
    input logic resetn,
    input logic write,
    input logic [DATA_WIDTH - 1 : 0] data,
    input logic [ADDR_WIDTH - 1 : 0] addr,
    input logic transfer_i,
    
    // Arbiter interface - NEW
    output logic prequest,
    input logic pgrant,
    
    output logic psel,
    output logic penable,
    output logic [ADDR_WIDTH - 1 : 0]paddr,
    output logic pwrite,
    output logic [DATA_WIDTH - 1 : 0] pwdata,
    input logic pready,
    input logic [DATA_WIDTH - 1 : 0] prdata
);
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        WAIT_GRANT = 3'b001,  // NEW STATE
        SETUP      = 3'b010,
        ACCESS     = 3'b011
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge pclk or negedge resetn) begin
        if(!resetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        next_state = state;
        case(state)
            IDLE: begin
                if(transfer_i) 
                    next_state = WAIT_GRANT; 
            end
            
            WAIT_GRANT: begin
                if(pgrant)  
                    next_state = SETUP;
            end
            
            SETUP: begin
                next_state = ACCESS;
            end
            
            ACCESS: begin
                if(pready) begin
                    if(!transfer_i) 
                        next_state = IDLE;
                    else 
                        next_state = WAIT_GRANT;  // Back-to-back transactions
                end
            end
        endcase
    end
    
    // Address/Data capture
    always_ff @(posedge pclk or negedge resetn) begin
        if (!resetn) begin
            paddr  <= '0;
            pwdata <= '0;
            pwrite <= '0;
        end 
        else if ( (state == IDLE && transfer_i) || 
                  (state == ACCESS && pready && transfer_i) ) begin
            paddr  <= addr;
            pwdata <= data;
            pwrite <= write;
        end
    end
    
	// Request signal management - COMBINATIONAL
	always_comb begin
		prequest = 1'b0;  
		
		case(state)
			WAIT_GRANT, SETUP, ACCESS: begin
				prequest = 1'b1;  
			end	
		endcase
		
		if(state == ACCESS && pready && !transfer_i) begin
			prequest = 1'b0;
		end
	end
    
    // Output logic
    always_comb begin
        psel = '0;
        penable = '0;
        case(state)
            IDLE, WAIT_GRANT: begin  
                psel = '0;
                penable = '0;
            end
            SETUP: begin
                psel = '1;
                penable = '0;
            end
            ACCESS: begin
                psel = '1;
                penable = '1;
            end
        endcase
    end
    
endmodule