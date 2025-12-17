module uart_transmitter (
    input wire clk,
    input wire reset,
    input wire tx_tick,                 // Baud rate tick
    input wire tx_start,                // Start transmission
    input wire [7:0] tx_data,           // Data to transmit
    output reg tx,                      // Serial output
    output reg tx_busy,                 // Transmitter busy flag
    output reg tx_done                  // Transmission complete (pulse)
);

    // 1. Enum for readable states
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state, next_state;

    // 2. Internal Signals
    reg [2:0] cnt;       // Bit counter (0-7)
    reg [7:0] shift_reg; // Shift register

    // --- STATE REGISTER ---
    always @(posedge clk) begin
        if (reset) 
            state <= IDLE;
        else 
            state <= next_state;
    end

    // --- NEXT STATE LOGIC ---
    always_comb begin
        next_state = state; 
        case (state)
            IDLE: begin
                if (tx_start) next_state = START; 
            end
            START: begin
                if (tx_tick) next_state = DATA;
            end
            DATA: begin
                if (tx_tick && cnt == 7) next_state = STOP;
            end
            STOP: begin
                if (tx_tick) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // --- DATAPATH & OUTPUT LOGIC ---
    always @(posedge clk) begin
        if (reset) begin
            tx <= 1'b1;          // Idle High
            shift_reg <= 8'd0;
            cnt <= 3'd0;
            tx_busy <= 1'b0;
            tx_done <= 1'b0;
        end 
        else begin
            tx_done <= 1'b0; // Default pulse low

            case (state)
                IDLE: begin
                    tx <= 1'b1;         // Drive High
                    tx_busy <= 1'b0;    // Not busy
                    // Load data immediately when start requested
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy <= 1'b1;
                    end
                end

                START: begin
                    tx_busy <= 1'b1;
                    tx <= 1'b0;         // *** CRITICAL FIX: Drive Start Bit (Low) ***
                    cnt <= 3'd0;        // Reset bit counter
                end

                DATA: begin
                    tx_busy <= 1'b1;
                    tx <= shift_reg[0]; // Drive LSB

                    if (tx_tick) begin
                        shift_reg <= {1'b0, shift_reg[7:1]}; // Shift Right
                        cnt <= cnt + 1;
                    end
                end

                STOP: begin
                    tx_busy <= 1'b1;
                    tx <= 1'b1;         // Drive Stop Bit (High)
                    
                    if (tx_tick) begin
                        tx_done <= 1'b1; // Pulse Done signal
                    end
                end
            endcase
        end
    end

endmodule


	
