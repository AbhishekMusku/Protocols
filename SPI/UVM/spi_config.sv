`ifndef SPI_CONFIG_SV
`define SPI_CONFIG_SV

class spi_config extends uvm_object;
  `uvm_object_utils(spi_config)

  // These match your RTL Parameters
  int spi_mode          = 0;
  int clks_per_half_bit = 2;

  // Virtual interface handle
  virtual spi_if vif;

  function new(string name = "spi_config");
    super.new(name);
  endfunction
endclass

`endif