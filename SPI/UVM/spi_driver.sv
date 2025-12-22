`ifndef SPI_DRIVER_SV
`define SPI_DRIVER_SV

class spi_driver extends uvm_driver #(spi_seq_item);
  
  `uvm_component_utils(spi_driver)

  virtual spi_if.DRV vif;
  spi_config     m_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Get the config object (Make sure your Test creates 'spi_cfg'!)
    if (!uvm_config_db#(spi_config)::get(this, "", "spi_cfg", m_cfg)) begin
      `uvm_fatal("DRV", "Could not get spi_cfg from config_db")
    end
    
    // Assign local vif handle from the config
    vif = m_cfg.vif;
  endfunction


  virtual task run_phase(uvm_phase phase);
    // 1. Initialize Signals to Idle
    vif.drv_cb.i_TX_DV   <= 1'b0;
    vif.drv_cb.i_TX_Byte <= 8'h00;

    // 2. Wait for Reset to lift (Passive wait)
    wait(vif.i_Rst_L === 1'b1);
    `uvm_info("DRV", "Reset lifted. Starting driver loop...", UVM_MEDIUM)
    
    // 3. Process Transactions
    forever begin
      seq_item_port.get_next_item(req); 
	  `uvm_info("DRV", "Driving transaction ...", UVM_MEDIUM)
      drive_transfer(req); 
		`uvm_info("DRV", "Drove the transaction...", UVM_MEDIUM)
      seq_item_port.item_done();  
    end
  endtask


  virtual task drive_transfer(spi_seq_item item);
    `uvm_info("DRV", $sformatf("Driving Item: %s", item.convert2string()), UVM_HIGH)

    while (vif.drv_cb.o_TX_Ready !== 1'b1) begin
      @(vif.drv_cb);
    end

    vif.drv_cb.i_TX_Byte <= item.data_m;
    vif.drv_cb.i_TX_DV   <= 1'b1;


    @(vif.drv_cb);
    vif.drv_cb.i_TX_DV   <= 1'b0; // Release Valid


    @(vif.drv_cb); 
    
  endtask

endclass

`endif