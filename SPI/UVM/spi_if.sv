interface spi_if (input logic i_Clk, input logic i_Rst_L);

  // TX (MOSI) Signals
  logic [7:0] i_TX_Byte;    
  logic       i_TX_DV;      
  logic       o_TX_Ready;   
   
  // RX (MISO) Signals
  logic       o_RX_DV;      
  logic [7:0] o_RX_Byte;   

  // SPI Physical Pins
  logic       o_SPI_Clk;    
  logic       i_SPI_MISO;   
  logic       o_SPI_MOSI;     

  clocking drv_cb @(posedge i_Clk);
    default input #1ns output #1ns;
    output i_TX_Byte;
    output i_TX_DV;
    input  o_TX_Ready;
    input  o_RX_DV;
    input  o_RX_Byte;
  endclocking


  clocking mon_cb @(posedge i_Clk);
    default input #1ns output #1ns;
    input i_TX_Byte;
    input i_TX_DV;
    input o_TX_Ready;
    input o_RX_DV;
    input o_RX_Byte;
    input o_SPI_Clk;
    input i_SPI_MISO;
    input o_SPI_MOSI;
  endclocking
  
  clocking res_cb @(posedge i_Clk);
    default input #1ns output #1ns;
    input i_TX_Byte;
    input i_TX_DV;
    input o_TX_Ready;
    input o_RX_DV;
    input o_RX_Byte;
    input o_SPI_Clk;
    output i_SPI_MISO;
    input o_SPI_MOSI;
  endclocking

  modport DRV (clocking drv_cb, input i_Rst_L);
  modport MON (clocking mon_cb, input i_Rst_L);
  modport RES (clocking res_cb, input i_Rst_L);

endinterface