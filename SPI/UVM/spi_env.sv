`ifndef SPI_ENV_SV
`define SPI_ENV_SV

class spi_env extends uvm_env;
  `uvm_component_utils(spi_env)

  spi_agent       m_agent;      
  spi_slave_agent s_agent;      
  spi_scoreboard  m_scb;        

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    m_agent = spi_agent::type_id::create("m_agent", this);

    s_agent = spi_slave_agent::type_id::create("s_agent", this);

    m_scb = spi_scoreboard::type_id::create("m_scb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    m_agent.analysis_port.connect(m_scb.mon_export);
    
  endfunction

endclass

`endif