`ifndef SPI_SCOREBOARD_SV
`define SPI_SCOREBOARD_SV

class spi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(spi_scoreboard)

  uvm_analysis_imp #(spi_seq_item, spi_scoreboard) mon_export;

  // Stats
  int m_matches;
  int m_mismatches;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_matches = 0;
    m_mismatches = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Standard creation
    mon_export = new("mon_export", this);
  endfunction

  virtual function void write(spi_seq_item item);
    // Simply pass the item to your integrity checker
    check_integrity(item);
  endfunction

  // 3. THE CHECKER LOGIC
  virtual function void check_integrity(spi_seq_item item);
    bit error_found = 0;

    // A. Serializer Check (TX Path)
    if (item.parallel_tx !== item.data_m) begin
      `uvm_error("SCB_TX", $sformatf("Serializer Fail! Input (i_TX_Byte): 0x%h, Output (MOSI): 0x%h", 
                                     item.parallel_tx, item.data_m))
      error_found = 1;
    end

    // B. Deserializer Check (RX Path)
    if (item.data_s !== item.parallel_rx) begin
      `uvm_error("SCB_RX", $sformatf("Deserializer Fail! Input (MISO): 0x%h, Output (o_RX_Byte): 0x%h", 
                                     item.data_s, item.parallel_rx))
      error_found = 1;
    end

    // C. Stats Update
    if (error_found) begin
      m_mismatches++;
    end else begin
      m_matches++;
      `uvm_info("SCB", $sformatf("PASS: TX(0x%h) RX(0x%h)", item.parallel_tx, item.parallel_rx), UVM_HIGH)
    end
  endfunction

  // 4. CHECK PHASE (Final Report)
  function void check_phase(uvm_phase phase);
    `uvm_info("SCB_SUM", $sformatf("Scoreboard Report: %0d Matches, %0d Mismatches", m_matches, m_mismatches), UVM_LOW)
  endfunction

endclass

`endif