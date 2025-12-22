`ifndef SPI_MONITOR_SV
`define SPI_MONITOR_SV

class spi_monitor extends uvm_monitor;
  
  `uvm_component_utils(spi_monitor)

  uvm_analysis_port #(spi_seq_item) mon_analysis_port;

  virtual spi_if.MON vif;
  spi_config     m_cfg;

  // Internal Variables
  bit [7:0] m_mosi_byte; // Reconstructed byte from MOSI
  bit [7:0] m_miso_byte; // Reconstructed byte from MISO

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mon_analysis_port = new("mon_analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(spi_config)::get(this, "", "spi_cfg", m_cfg)) begin
      `uvm_fatal("MON", "Could not get spi_cfg from config_db")
    end
    vif = m_cfg.vif;
  endfunction

  // ---------------------------------------------------------------------------
  // Run Phase: The "Smart" Decoder
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    spi_seq_item item;

    forever begin
      // A. Wait for Transaction Start
      wait(vif.mon_cb.o_TX_Ready === 1'b0);
      `uvm_info("MON_MOSI", $sformatf("TX READY SET TO %d", vif.mon_cb.o_TX_Ready), UVM_MEDIUM)
      // Create new item to store results
      item = spi_seq_item::type_id::create("item");
	  
      // B. Decode the 8 Bits (Serial to Parallel)
      // We fork this to capture both MOSI (TX) and MISO (RX) simultaneously
      fork
        collect_mosi(item);
        collect_miso(item);
		collect_parallel_rx(item);
		collect_parallel_tx(item);
		//mochi(item);
      join

      // D. Broadcast to Scoreboard
      `uvm_info("MON", $sformatf("Observed: %s", item.convert2string()), UVM_HIGH)
      mon_analysis_port.write(item);

      // E. Wait for Transaction End (Ready goes High)
      wait(vif.mon_cb.o_TX_Ready === 1'b1);
    end
  endtask

  task collect_mosi(spi_seq_item item);
    int bit_idx;
    // According to RTL [Source: 47], MSB (Bit 7) is sent first.
    for (bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      // 1. Wait for the correct Sampling Edge
      wait_for_sample_edge();
      
      // 2. Sample the bit
      m_mosi_byte[bit_idx] = vif.mon_cb.o_SPI_MOSI;
	 `uvm_info("MON_MOSI", $sformatf("Completed bit_idx = %d	MOSI byte = 0x%02h (%08b)", bit_idx, m_mosi_byte, m_mosi_byte), UVM_MEDIUM)
	  
    end
    item.data_m = m_mosi_byte; // Store result in item
  endtask

  task collect_miso(spi_seq_item item);
    int bit_idx;
    for (bit_idx = 7; bit_idx >= 0; bit_idx--) begin
      wait_for_sample_edge();
      m_miso_byte[bit_idx] = vif.mon_cb.i_SPI_MISO;
    end
    item.data_s = m_miso_byte;
  endtask
  
	task mochi(spi_seq_item item);
	forever begin
	@(vif.mon_cb.o_SPI_MOSI)
		`uvm_info("MOCHI", $sformatf("o_SPI_MOSI %d", vif.mon_cb.o_SPI_MOSI), UVM_MEDIUM)
	end
  endtask
  
    task collect_parallel_tx(spi_seq_item item);

      wait_for_sample_edge();
	  item.parallel_tx = vif.mon_cb.i_TX_Byte;

    endtask
  
    task collect_parallel_rx(spi_seq_item item);
	
	  wait(vif.mon_cb.o_RX_DV === 1'b1);
	  item.parallel_rx = vif.mon_cb.o_RX_Byte;

    endtask

  // ---------------------------------------------------------------------------
  // Key Logic: Determine Sampling Edge based on CPOL/CPHA
  // ---------------------------------------------------------------------------
  // Logic derived from standard SPI Protocol:
  // Mode 0 (0,0) & Mode 3 (1,1) -> Sample on Rising Edge
  // Mode 1 (0,1) & Mode 2 (1,0) -> Sample on Falling Edge
  // ---------------------------------------------------------------------------
  task wait_for_sample_edge();
    if (m_cfg.spi_mode == 0 || m_cfg.spi_mode == 3) begin
      @(posedge vif.mon_cb.o_SPI_Clk);
    end
    else begin
      @(negedge vif.mon_cb.o_SPI_Clk);
    end
  endtask

endclass

`endif