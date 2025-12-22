`ifndef SPI_SLAVE_AGENT_SV
`define SPI_SLAVE_AGENT_SV

class spi_slave_agent extends uvm_agent;
  `uvm_component_utils(spi_slave_agent)

  // 1. Components
  // We only need the driver. No Sequencer, No Monitor.
  spi_slave_driver s_driver;
  
  // Config object
  spi_config m_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // 2. Build Phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration
    if (!uvm_config_db#(spi_config)::get(this, "", "spi_cfg", m_cfg)) begin
      `uvm_fatal("SLV_AGT", "Could not get spi_cfg")
    end

    // Create the Driver only if the agent is ACTIVE
    // (If PASSIVE, this agent effectively does nothing, which is valid)
    if (get_is_active() == UVM_ACTIVE) begin
      s_driver = spi_slave_driver::type_id::create("s_driver", this);
    end
  endfunction

  // 3. Connect Phase
  // No connection needed! The driver runs autonomously.
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

endclass

`endif