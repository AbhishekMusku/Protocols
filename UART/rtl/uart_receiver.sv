module uart_receiver (
    input wire clk,
    input wire reset,
    input wire rx_tick,                 // 16x Baud rate tick
    input wire rx,                      // Serial input (Raw)
    output reg [7:0] rx_data,           // Received data
    output reg rx_ready                 // Data ready flag (pulse)
);

    // 1. Enum for readable states
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state, next_state;

    // 2. Internal Signals
    reg [3:0] sample_cnt;    // Counter for 16x ticks (0-15)
    reg [2:0] bit_cnt;       // Counter for 8 data bits (0-7)
    reg [7:0] shift_reg;     // Internal shift register

    // --- STATE REGISTER ---
    always @(posedge clk) begin
        if (reset) 
            state <= IDLE;
        else 
            state <= next_state;
    end


    always_comb begin
        next_state = state; // Default: Stay in current state
        
        case (state)
            IDLE: begin
                if (rx == 1'b0) 
                    next_state = START;
            end

            START: begin
                if (rx_tick) begin
                    if (sample_cnt == 7) begin
                        if (rx == 1'b0) 
                            next_state = DATA; 
                        else                  
                            next_state = IDLE; 
                    end
                end
            end

            DATA: begin
                if (rx_tick) begin
                    if (sample_cnt == 15) begin
                        if (bit_cnt == 7)
                            next_state = STOP; 
                    end
                end
            end

            STOP: begin
                if (rx_tick) begin
                    if (sample_cnt == 15) 
                        next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // --- DATAPATH & OUTPUT LOGIC ---
    always @(posedge clk) begin
        if (reset) begin
            sample_cnt <= 4'd0;
            bit_cnt    <= 3'd0;
            shift_reg  <= 8'd0;
            rx_data    <= 8'd0;
            rx_ready   <= 1'b0;
        end 
        else begin
            rx_ready <= 1'b0; 

            case (state)
                IDLE: begin
                    sample_cnt <= 4'd0;
                    bit_cnt    <= 3'd0;
                end

                START: begin
                    if (rx_tick) begin
                        if (sample_cnt == 7) 
                            sample_cnt <= 4'd0; 
                        else 
                            sample_cnt <= sample_cnt + 1;
                    end
                end

                DATA: begin
                    if (rx_tick) begin
                        if (sample_cnt == 15) begin
                            sample_cnt <= 4'd0; 
                            shift_reg <= {rx, shift_reg[7:1]}; 
                            bit_cnt   <= bit_cnt + 1;
                        end 
                        else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end
                end

                STOP: begin
                    if (rx_tick) begin
                        if (sample_cnt == 15) begin
                            sample_cnt <= 4'd0;
                            if (rx == 1'b1) begin
                                rx_data  <= shift_reg; 
                                rx_ready <= 1'b1;
                            end
                        end 
                        else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end
                end
            endcase
        end
    end

endmodule