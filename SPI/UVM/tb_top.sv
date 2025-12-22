`ifndef TB_TOP_SV
`define TB_TOP_SV

// 1. UVM Standard Imports
import uvm_pkg::*;
`include "uvm_macros.svh"

// 2. Include all UVM Class Files
// (Order matters: items -> components -> env -> tests)
`include "spi_seq_item.sv"
`include "spi_config.sv"
`include "spi_if.sv"    // The Interface definition
`include "SPI_ASSERTIONS_SV.sv"
`include "spi_base_sequence.sv"
`include "spi_sequencer.sv"
`include "spi_driver.sv"
`include "spi_slave_driver.sv" // The Slave Responder
`include "spi_monitor.sv"
`include "spi_agent.sv"
`include "spi_slave_agent.sv"
`include "spi_scoreboard.sv"
`include "spi_env.sv"
`include "spi_base_test.sv"     // The Test Selection

module tb_top;

  // ---------------------------------------------------------------------------
  // 3. Clock & Reset Generation
  // ---------------------------------------------------------------------------
  bit i_Clk;
  bit i_Rst_L;

  // Clock Generation (e.g., 100MHz -> 10ns period)
  initial begin
    i_Clk = 0;
    forever #5 i_Clk = ~i_Clk;
  end

  // Reset Generation (Active Low)
  initial begin
    i_Rst_L = 0;      // Hold Reset
    #100;             // Wait 100ns
    i_Rst_L = 1;      // Release Reset
  end

  // ---------------------------------------------------------------------------
  // 4. Interface Instantiation
  // ---------------------------------------------------------------------------
  // This is the physical bundle of wires that connects UVM to RTL
  spi_if vif(i_Clk, i_Rst_L);

  // ---------------------------------------------------------------------------
  // 5. DUT Instantiation (Device Under Test)
  // ---------------------------------------------------------------------------
  SPI_Master #(
    .SPI_MODE(3),          // MUST match the configuration in spi_test_lib
    .CLKS_PER_HALF_BIT(4)  // Example: 25MHz SPI Clock if System is 100MHz
  ) dut (
    // System Signals
    .i_Rst_L    (vif.i_Rst_L),
    .i_Clk      (vif.i_Clk),
    
    // TX Channel (CPU -> DUT)
    .i_TX_Byte  (vif.i_TX_Byte),
    .i_TX_DV    (vif.i_TX_DV),
    .o_TX_Ready (vif.o_TX_Ready),
    
    // RX Channel (DUT -> CPU)
    .o_RX_DV    (vif.o_RX_DV),
    .o_RX_Byte  (vif.o_RX_Byte),
    
    // SPI Physical Interface (DUT -> Outside World)
    .o_SPI_Clk  (vif.o_SPI_Clk),
    .i_SPI_MISO (vif.i_SPI_MISO), // Driven by our Slave Agent!
    .o_SPI_MOSI (vif.o_SPI_MOSI)  // Monitored by our Monitor!
  );
  
  bind SPI_Master spi_assertions #(
    .SPI_MODE(3),          // MUST MATCH DUT!
    .CLKS_PER_HALF_BIT(4)  // MUST MATCH DUT!
  ) u_assertions_inst (
    // connect assertion_port (RTL_signal_name)
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

  // ---------------------------------------------------------------------------
  // 6. UVM Startup Block
  // ---------------------------------------------------------------------------
  initial begin
    // A. Pass the Virtual Interface to the UVM Config DB
    //    "*" means all components can see it. "vif" is the key.
    uvm_config_db#(virtual spi_if)::set(null, "*", "vif", vif);
    
    run_test("spi_sanity_test");
  end

endmodule

`endif