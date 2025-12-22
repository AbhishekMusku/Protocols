`ifndef SPI_SLAVE_DRIVER_SV
`define SPI_SLAVE_DRIVER_SV

class spi_slave_driver extends uvm_driver #(spi_seq_item);
  `uvm_component_utils(spi_slave_driver)

  virtual spi_if.RES vif;
  spi_config     m_cfg;

  bit [7:0] internal_data_s;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(spi_config)::get(this, "", "spi_cfg", m_cfg))
      `uvm_fatal("SLV_DRV", "No spi_cfg found")
    vif = m_cfg.vif;
  endfunction

  virtual task run_phase(uvm_phase phase);
    // 1. Init MISO to 0
    vif.res_cb.i_SPI_MISO <= 1'b0;

    // 2. Wait for Reset
    wait (vif.i_Rst_L === 1'b1);
    `uvm_info("SLV_DRV", "Reset released, slave driver active", UVM_LOW)

    forever begin
      void'(std::randomize(internal_data_s));

      `uvm_info("SLV_RSP",
                $sformatf("Prepared slave response: 0x%02h", internal_data_s),
                UVM_MEDIUM)

      wait (vif.res_cb.o_TX_Ready === 1'b0);
      drive_slave_response(internal_data_s);

      wait (vif.res_cb.o_TX_Ready === 1'b1);
      vif.res_cb.i_SPI_MISO <= 1'b0;

      `uvm_info("SLV_RSP",
                "Completed slave response transaction",
                UVM_LOW)
    end
  endtask

  task drive_slave_response(bit [7:0] data_to_send);
    int bit_idx;
    bit cpha_zero_mode;

    cpha_zero_mode = (m_cfg.spi_mode == 0 || m_cfg.spi_mode == 2);

    if (cpha_zero_mode) begin
      // CPHA=0: Drive MSB immediately when Ready goes Low
      vif.res_cb.i_SPI_MISO <= data_to_send[7];

      for (bit_idx = 6; bit_idx >= 0; bit_idx--) begin
        wait_for_shift_edge();
        vif.res_cb.i_SPI_MISO <= data_to_send[bit_idx];
      end
    end
    else begin
      // CPHA=1: Wait for first edge before driving MSB
      for (bit_idx = 7; bit_idx >= 0; bit_idx--) begin
        wait_for_shift_edge();
        vif.res_cb.i_SPI_MISO <= data_to_send[bit_idx];
      end
    end
  endtask

  task wait_for_shift_edge();
    if (m_cfg.spi_mode == 0 || m_cfg.spi_mode == 3)
      @(negedge vif.res_cb.o_SPI_Clk);
    else
      @(posedge vif.res_cb.o_SPI_Clk);
  endtask

endclass


`endif