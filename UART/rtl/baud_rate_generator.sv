module baud_rate_generator (
    input wire clk,
    input wire reset,
    input wire [15:0] baud_divisor,
    output reg tx_tick,
    output reg rx_tick
);

    reg [15:0] count;
    reg [3:0]  t_count;
    
    // 1. Create a "Control Signal" (Combinational Logic)
    // This resolves instantly before the clock edge
    wire tick_enable = (count == (baud_divisor >> 4) - 1);

    // 2. Block 1 uses the wire
    always @(posedge clk) begin
        if (reset) begin
            rx_tick <= 1'b0;
            count   <= 16'd0;
        end else begin
            rx_tick <= 1'b0; 
            if (tick_enable) begin     // Uses the wire
                count   <= 16'd0;
                rx_tick <= 1'b1;       // Fires on next edge
            end else begin
                count   <= count + 1'b1;
            end
        end
    end

    // 3. Block 2 uses the SAME wire
    always @(posedge clk) begin
        if (reset) begin
            tx_tick <= 1'b0;
            t_count <= 4'd0;
        end else begin
            tx_tick <= 1'b0;
            if (tick_enable) begin     // Uses the wire (NO DELAY!)
                if (t_count == 4'd15) begin
                    t_count <= 4'd0;
                    tx_tick <= 1'b1;   // Fires on SAME edge as rx_tick
                end else begin
                    t_count <= t_count + 1'b1;
                end
            end
        end
    end

endmodule

