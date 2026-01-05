module apb_arbiter #(
    parameter NUM_MASTERS = 4
) (
    input  logic                    pclk,
    input  logic                    presetn,
    
    input  logic [NUM_MASTERS-1:0]  prequest,
    
    input  logic                    pready,
    input  logic  					penable, 
    
    output logic [NUM_MASTERS-1:0]  pgrant,
    
    output logic [$clog2(NUM_MASTERS)-1:0] master_id
);

    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        GRANTED = 2'b01
    } state_t;
    
    state_t current_state, next_state;
    
    logic [$clog2(NUM_MASTERS)-1:0] granted_master_id;
    logic [$clog2(NUM_MASTERS)-1:0] next_master_id;
    
    logic transaction_done;
    assign transaction_done = penable && pready;
    

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            current_state <= IDLE;
            granted_master_id <= '0;
        end else begin
            current_state <= next_state;
            granted_master_id <= next_master_id;
        end
    end
    

    function automatic logic [$clog2(NUM_MASTERS)-1:0] get_highest_priority;
        input logic [NUM_MASTERS-1:0] requests;
        integer i;
        begin
            get_highest_priority = '0;
            for (i = NUM_MASTERS-1; i >= 0; i--) begin
                if (requests[i]) begin
                    get_highest_priority = i;
                end
            end
        end
    endfunction
    

    always_comb begin
        next_state = current_state;
        next_master_id = granted_master_id;
        
        case (current_state)
            IDLE: begin
                if (|prequest) begin  // Any request active
                    next_state = GRANTED;
                    next_master_id = get_highest_priority(prequest);
                end
            end
            
            GRANTED: begin
                if (transaction_done) begin
                    if (|prequest) begin
                        next_master_id = get_highest_priority(prequest);
                        next_state = GRANTED;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    

    always_comb begin
        pgrant = '0;
        master_id = granted_master_id;
        
        if (current_state == GRANTED) begin
            pgrant[granted_master_id] = 1'b1;
        end
    end

endmodule