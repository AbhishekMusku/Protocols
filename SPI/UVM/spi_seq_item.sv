`ifndef SPI_SEQ_ITEM_SV
`define SPI_SEQ_ITEM_SV

class spi_seq_item extends uvm_sequence_item;
  `uvm_object_utils(spi_seq_item)
  rand bit [7:0] data_m;    // Master to Slave (MOSI data) 
  bit      [7:0] data_s;    // Slave to Master (MISO data)
  bit      [7:0] parallel_tx;
  bit      [7:0] parallel_rx;

  constraint c_data_patterns {
    soft data_m != 8'h00;
    soft data_m != 8'hFF;
  }

  function new(string name = "spi_seq_item");
    super.new(name);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    spi_seq_item to_copy;
    if (!$cast(to_copy, rhs)) begin 
      `uvm_fatal(get_full_name(), "Non-matching transaction type in do_copy");
    end
    super.do_copy(rhs);
    this.data_m = to_copy.data_m;
    this.data_s = to_copy.data_s;
  endfunction : do_copy

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    spi_seq_item to_compare;
    if (!$cast(to_compare, rhs)) return 0;
    
    return (super.do_compare(rhs, comparer) &&
            this.data_m == to_compare.data_m &&
            this.data_s == to_compare.data_s);
  endfunction : do_compare

  // convert2string: For clean log files and `uvm_info displays
  virtual function string convert2string();
    return $sformatf("MOSI: 0x%h", data_m);
  endfunction : convert2string

endclass

`endif