`ifndef SPI_AGENT_SV
`define SPI_AGENT_SV

class spi_agent extends uvm_agent;
  `uvm_component_utils(spi_agent)

  spi_sequencer					m_sequencer;  
  spi_driver                    m_driver;
  spi_monitor                   m_monitor;

  spi_config m_cfg;
  uvm_analysis_port #(spi_seq_item) analysis_port;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
	analysis_port = new("analysis_port", this);

    if (!uvm_config_db#(spi_config)::get(this, "", "spi_cfg", m_cfg)) begin
      `uvm_fatal("AGENT", "Could not get spi_cfg")
    end

    m_monitor = spi_monitor::type_id::create("m_monitor", this);

    if (get_is_active() == UVM_ACTIVE) begin
      m_driver    = spi_driver::type_id::create("m_driver", this);
      m_sequencer = spi_sequencer::type_id::create("m_sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
	m_monitor.mon_analysis_port.connect(analysis_port);
    if (get_is_active() == UVM_ACTIVE) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end
  endfunction

endclass

`endif