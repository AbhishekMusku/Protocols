interface uart_if(input logic clk, input logic reset);

    logic [15:0] baud_divisor;
    logic        tx_start;
    logic [7:0]  tx_data;
    logic        tx;
    logic        tx_busy;
    logic        tx_done;
    logic        tx_tickk;

    logic        rx;
    logic [7:0]  rx_data;
    logic        rx_ready;
	logic        rx_tickk;

    clocking drv_cb @(posedge clk);
        default input #1step output #1;
        output tx_start;
        output tx_data;
        input  tx_busy;
        input  tx_done;
        input  tx;
        input  tx_tickk;
    endclocking
	
    clocking mon_cb @(posedge clk);
        default input #1step;
        input rx_data;
        input rx_ready;
        input rx;
        input tx;
        input tx_busy;
        input tx_done;
		input rx_tickk;
    endclocking

    modport DRV (
        clocking drv_cb,
        input  reset,
        output baud_divisor
    );

    modport MON (
        clocking mon_cb,
        input reset
    );

    modport TB (
        input  clk, reset,
        output baud_divisor, tx_start, tx_data, rx,
        input  tx, tx_busy, tx_done, rx_data, rx_ready
    );

endinterface
