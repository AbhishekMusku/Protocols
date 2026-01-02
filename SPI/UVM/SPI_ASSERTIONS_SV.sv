`ifndef SPI_ASSERTIONS_SV
`define SPI_ASSERTIONS_SV

interface spi_assertions #(
  parameter SPI_MODE = 0,
  parameter CLKS_PER_HALF_BIT = 2
) (
  input logic        clk,
  input logic        rst_n,
  input logic [7:0]  i_TX_Byte,
  input logic        i_TX_DV,
  input logic        o_TX_Ready,
  input logic        o_RX_DV,
  input logic [7:0]  o_RX_Byte,
  input logic        o_SPI_Clk,
  input logic        o_SPI_MOSI,
  input logic        i_SPI_MISO
);

  // Modes 0,1 idle Low (0). Modes 2,3 idle High (1).
  bit w_CPOL;
  assign w_CPOL = (SPI_MODE == 2) || (SPI_MODE == 3);

  //============================================================================
  // CATEGORY 1: PROTOCOL HANDSHAKE
  //============================================================================
  
  // "If we request a TX, the core must go Busy (Ready=0) in the next cycle"
  property p_handshake_start;
    @(posedge clk) disable iff (!rst_n)
    ($rose(i_TX_DV) && o_TX_Ready) |=> !o_TX_Ready;
  endproperty
  ast_handshake_start: assert property(p_handshake_start)
    else $error("TX_Ready did not drop after TX_DV!");

  //Can't request if not ready.
  property p_tx_dv_when_ready;
    @(posedge clk) disable iff (!rst_n)
    i_TX_DV |-> o_TX_Ready;
  endproperty
  ast_p_tx_dv_when_ready: assert property(p_tx_dv_when_ready)
    else $error("Can't request if not ready.");


  //============================================================================
  // CATEGORY 2: SPI PROTOCOL ACCURACY (The Missing Piece!)
  //============================================================================

  // Idle state must match CPOL parameter.
  property p_spi_clk_idle_state;
    @(posedge clk) disable iff (!rst_n)
    o_TX_Ready |-> (o_SPI_Clk == w_CPOL);
  endproperty
  ast_spi_clk_idle_state: assert property(p_spi_clk_idle_state)
    else $error("SPI_Clk not in correct CPOL Idle state!");

  // Mode 0,3: Sample on Rising -> Data must be stable/valid on Rising
  property p_mosi_valid_rising;
    @(posedge o_SPI_Clk) disable iff (!rst_n)
    (SPI_MODE == 0 || SPI_MODE == 3) |-> !$isunknown(o_SPI_MOSI);
  endproperty
  ast_mosi_valid_rising: assert property(p_mosi_valid_rising)
    else $error("MOSI X/Z during Rising Edge Capture!");

  // Mode 1,2: Sample on Falling -> Data must be stable/valid on Falling
  property p_mosi_valid_falling;
    @(negedge o_SPI_Clk) disable iff (!rst_n)
    (SPI_MODE == 1 || SPI_MODE == 2) |-> !$isunknown(o_SPI_MOSI);
  endproperty
  ast_mosi_valid_falling: assert property(p_mosi_valid_falling)
    else $error("MOSI X/Z during Falling Edge Capture!");

  //============================================================================
  // CATEGORY 3: LIVENESS & TIMING
  //============================================================================

  //"Eventually returns high" (Liveness)
  property p_tx_ready_returns_high;
    @(posedge clk) disable iff (!rst_n)
    $fell(o_TX_Ready) |-> ##[1:1000] o_TX_Ready;
  endproperty
  ast_tx_ready_returns_high: assert property(p_tx_ready_returns_high)
    else $error("Deadlock: TX_Ready stuck low!");

  // RX_DV Pulse Width (Crucial for Monitor)
  property p_rx_dv_single_cycle;
    @(posedge clk) disable iff (!rst_n)
    o_RX_DV |=> !o_RX_DV;
  endproperty
  ast_rx_dv_single_cycle: assert property(p_rx_dv_single_cycle)
    else $error("RX_DV pulse > 1 cycle (Double-read risk)!");

  //============================================================================
  // CATEGORY 4: SIGNAL INTEGRITY (Your Excellent Additions)
  //============================================================================

  // No X checks (Keep all of them)
  ast_no_x_ready: assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(o_TX_Ready));
  ast_no_x_rx_dv: assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(o_RX_DV));
  ast_no_x_mosi:  assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(o_SPI_MOSI));

  //============================================================================
  // CATEGORY 5: COVERAGE
  //============================================================================
  cover_transaction: cover property (@(posedge clk) disable iff (!rst_n) $rose(o_RX_DV));
  cover_back_to_back: cover property (
    @(posedge clk) disable iff (!rst_n) 
    o_RX_DV ##[1:20] $fell(o_TX_Ready) 
  );

endinterface : spi_assertions
`endif