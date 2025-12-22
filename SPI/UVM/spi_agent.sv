`ifndef SPI_AGENT_SV
`define SPI_AGENT_SV

class spi_agent extends uvm_agent;
  `uvm_component_utils(spi_agent)

  spi_sequencer					m_sequencer;  
  spi_driver                    m_driver;
  spi_monitor                   m_monitor;

  // Config Object
  spi_config m_cfg;
  uvm_analysis_port #(spi_seq_item) analysis_port;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // 2. Build Phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
	analysis_port = new("analysis_port", this);
    // Get Config
    if (!uvm_config_db#(spi_config)::get(this, "", "spi_cfg", m_cfg)) begin
      `uvm_fatal("AGENT", "Could not get spi_cfg")
    end

    // The Monitor is ALWAYS created (we always want to see what's happening)
    m_monitor = spi_monitor::type_id::create("m_monitor", this);

    // The Driver & Sequencer are ONLY created if the Agent is ACTIVE
    // (This allows you to turn off the driver for output-only checking if needed)
    if (get_is_active() == UVM_ACTIVE) begin
      m_driver    = spi_driver::type_id::create("m_driver", this);
      m_sequencer = spi_sequencer::type_id::create("m_sequencer", this);
    end
  endfunction

  // 3. Connect Phase
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
	m_monitor.mon_analysis_port.connect(analysis_port);
    // Only connect if Active
    if (get_is_active() == UVM_ACTIVE) begin
      // Connect Driver's request port to Sequencer's export
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end
  endfunction

endclass

`endif