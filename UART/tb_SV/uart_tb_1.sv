`timescale 1ns/1ps

module uart_tb_1;

    reg  clk, reset;
    reg  [15:0] baud_divisor;
    reg  [7:0]  tx_data;
    reg         tx_start;
    wire        tx, tx_busy, tx_done;
    wire [7:0]  rx_data;
    wire        rx_ready;
    
    int pass_count = 0;
    int fail_count = 0;

    uart_top dut (
        .clk(clk),
        .reset(reset),
        .baud_divisor(baud_divisor),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx(tx),                
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx(tx),           
        .rx_data(rx_data),
        .rx_ready(rx_ready)
    );
	
	initial clk = 0;
	always #10 clk = ~clk;
	
	task verify_byte(input reg [7:0] number);
		begin
			wait(dut.tx_tick);
			
			@(posedge clk);
			tx_start <= 1;
			tx_data  <= number;
			@(posedge clk);
			tx_start <= 0;
			
			fork: wait_for_ready
				begin
					wait(rx_ready);
				end
				begin
					#10000;
					$display("TImeout reached");
				end
			join_any
			disable wait_for_ready;
			
			if(rx_ready) begin
				if(rx_data == number) begin
					$display("Test passed rx_data = 0x%h,	sent_data = 0x%h", rx_data,number);
					pass_count++;
				end
				else begin
					$display("Test failed rx_data = 0x%h,	sent_data = 0x%h", rx_data,number);
					fail_count++;
				end
			end
			#200;
		end
	endtask
			
			
	initial begin
		tx_start = '0;
		tx_data = '0;
		reset = '1;
		baud_divisor = 16'd32; 
		
		#100
		reset = '0;
		
		$display("STARTING THE SIMUALTION");
		
		//Directed testing
		verify_byte(8'hA5);
		verify_byte(8'hC7);
		verify_byte(8'h11);
		verify_byte(8'hFA);
		
		//Randomized testing
		repeat(10) begin
			verify_byte($urandom_range(0, 255));
		end
		
		$display("FINAL REPORT");
		$display("TOTAL PASSES = %d", pass_count);
		$display("TOTAL FAILS = %d", fail_count);
		#1000;
		$finish;
		
	end
	
	initial begin
		#2_500_000;  
		$display("SAFETY TIMEOUT: Simulation stopped.");
		$finish;
	end
	
endmodule
	
		
		
	