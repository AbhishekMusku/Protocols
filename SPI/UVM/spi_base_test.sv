`ifndef SPI_TEST_LIB_SV
`define SPI_TEST_LIB_SV

class spi_base_test extends uvm_test;
  `uvm_component_utils(spi_base_test)

  spi_env    m_env;
  spi_config m_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // 1. Build Phase: Configure the "Machine"
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // A. Create the Config Object
    m_cfg = spi_config::type_id::create("m_cfg");

    // B. Get the Virtual Interface (passed from tb_top)
    if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", m_cfg.vif)) begin
      `uvm_fatal("TEST", "Could not get vif from top module! check tb_top.sv")
    end

    // C. Configure SPI Parameters (Must match RTL!)
    m_cfg.spi_mode = 3; // CPOL=0, CPHA=0
    m_cfg.clks_per_half_bit = 4;
    // D. Publish Config to the whole hierarchy (Driver, Monitor, Agent)
    uvm_config_db#(spi_config)::set(this, "*", "spi_cfg", m_cfg);

    // E. Create the Environment
    m_env = spi_env::type_id::create("m_env", this);
  endfunction

  // 2. End of Elaboration: Print the structure (Optional but helpful)
  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

endclass


// -----------------------------------------------------------------------------
// SANITY TEST: sending 10 random packets
// -----------------------------------------------------------------------------
class spi_sanity_test extends spi_base_test;
  `uvm_component_utils(spi_sanity_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

	task run_phase(uvm_phase phase);
	  spi_single_txn_seq seq;

	  phase.raise_objection(this);
	  `uvm_info("TEST", "Raised objection, starting SPI Sanity Test", UVM_LOW)

	  repeat (10) begin
		seq = spi_single_txn_seq::type_id::create("seq");

		if (!seq.randomize())
		  `uvm_error("TEST", "Randomization failed")

		`uvm_info("TEST", "Starting SPI transaction", UVM_MEDIUM)
		seq.start(m_env.m_agent.m_sequencer);
		`uvm_info("TEST", "Completed SPI transaction", UVM_MEDIUM)
	  end

	  #10000ns;
	  `uvm_info("TEST", "Dropping objection, test completed", UVM_LOW)

	  phase.drop_objection(this);
	endtask


endclass

`endif