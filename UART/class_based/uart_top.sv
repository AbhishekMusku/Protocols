module uart_top (
    input wire clk,
    input wire reset,
    
    // Configuration
    input wire [15:0] baud_divisor,    // For 16x oversampling: clk_freq/(baud_rate*16)
    
    // Transmitter Interface
    input wire [7:0] tx_data,
    input wire tx_start,
    output wire tx,
    output wire tx_busy,
    output wire tx_done,
    
    // Receiver Interface
    input wire rx,
    output wire [7:0] rx_data,
    output wire rx_ready,
	output wire tx_tickk,
	output wire rx_tickk
);

    // Internal signals
    wire tx_tick, rx_tick;
    assign tx_tickk = tx_tick;
    assign rx_tickk = rx_tick;
	
    // Instantiate Baud Rate Generator
    baud_rate_generator baud_gen (
        .clk(clk),
        .reset(reset),
        .baud_divisor(baud_divisor),
        .tx_tick(tx_tick),
        .rx_tick(rx_tick)
    );
    
    // Instantiate Transmitter
    uart_transmitter transmitter (
        .clk(clk),
        .reset(reset),
        .tx_tick(tx_tick),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );
    
    // Instantiate Receiver
    uart_receiver receiver (
        .clk(clk),
        .reset(reset),
        .rx_tick(rx_tick),
        .rx(rx),
        .rx_data(rx_data),
        .rx_ready(rx_ready)
    );

endmodule