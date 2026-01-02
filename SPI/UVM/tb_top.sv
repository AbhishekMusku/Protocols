`ifndef TB_TOP_SV
`define TB_TOP_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "spi_seq_item.sv"
`include "spi_config.sv"
`include "spi_if.sv"    
`include "SPI_ASSERTIONS_SV.sv"
`include "spi_base_sequence.sv"
`include "spi_sequencer.sv"
`include "spi_driver.sv"
`include "spi_slave_driver.sv" 
`include "spi_monitor.sv"
`include "spi_agent.sv"
`include "spi_slave_agent.sv"
`include "spi_scoreboard.sv"
`include "spi_env.sv"
`include "spi_base_test.sv"    

module tb_top;

  bit i_Clk;
  bit i_Rst_L;

  // Clock Generation 
  initial begin
    i_Clk = 0;
    forever #5 i_Clk = ~i_Clk;
  end

  // Reset Generation (Active Low)
  initial begin
    i_Rst_L = 0;      
    #100;             
    i_Rst_L = 1;     
  end


  spi_if vif(i_Clk, i_Rst_L);

  // DUT Instantiation (Device Under Test)
  SPI_Master #(
    .SPI_MODE(3),          
    .CLKS_PER_HALF_BIT(4)  // 25MHz SPI Clock -> System is 100MHz
  ) dut (
    .i_Rst_L    (vif.i_Rst_L),
    .i_Clk      (vif.i_Clk),
    
    // TX Channel (CPU -> DUT)
    .i_TX_Byte  (vif.i_TX_Byte),
    .i_TX_DV    (vif.i_TX_DV),
    .o_TX_Ready (vif.o_TX_Ready),
    
    // RX Channel (DUT -> CPU)
    .o_RX_DV    (vif.o_RX_DV),
    .o_RX_Byte  (vif.o_RX_Byte),
    
    // SPI Physical Interface (DUT -> External)
    .o_SPI_Clk  (vif.o_SPI_Clk),
    .i_SPI_MISO (vif.i_SPI_MISO), 
    .o_SPI_MOSI (vif.o_SPI_MOSI)  
  );
  
  bind SPI_Master spi_assertions #(
    .SPI_MODE(3),          
    .CLKS_PER_HALF_BIT(4)  
  ) u_assertions_inst (
    .clk        (i_Clk),
    .rst_n      (i_Rst_L),
    .i_TX_Byte  (i_TX_Byte),
    .i_TX_DV    (i_TX_DV),
    .o_TX_Ready (o_TX_Ready),
    .o_RX_DV    (o_RX_DV),
    .o_RX_Byte  (o_RX_Byte),
    .o_SPI_Clk  (o_SPI_Clk),
    .o_SPI_MOSI (o_SPI_MOSI),
    .i_SPI_MISO (i_SPI_MISO)
  );

  initial begin
    uvm_config_db#(virtual spi_if)::set(null, "*", "vif", vif);
    
    run_test("spi_sanity_test");
  end

endmodule

`endif