`ifndef SPI_SEQUENCES_SV
`define SPI_SEQUENCES_SV

class spi_base_sequence extends uvm_sequence#(spi_seq_item);
  `uvm_object_utils(spi_base_sequence)

  rand int unsigned num_transactions;

  constraint reasonable_transactions {
    num_transactions inside {[1:100]};
  }

  function new(string name = "spi_base_sequence");
    super.new(name);
  endfunction

  // Objection handling in pre/post body is standard for "simple" testbenches
/*  virtual task pre_body();
    if (starting_phase != null) begin
      starting_phase.raise_objection(this, get_type_name());
    end
  endtask

  virtual task post_body();
    if (starting_phase != null) begin
      starting_phase.drop_objection(this, get_type_name());
    end
  endtask
*/  
endclass


// -----------------------------------------------------------------------------
// Single Transaction Sequence: Sends one specific byte
// -----------------------------------------------------------------------------
class spi_single_txn_seq extends spi_base_sequence;
  `uvm_object_utils(spi_single_txn_seq)

  // Data to be sent from Master to Slave
  rand bit [7:0] tx_data_val;

  function new(string name = "spi_single_txn_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
              $sformatf("Sequence started. tx_data_val=0x%02h", tx_data_val),
              UVM_LOW)

    // Create request
    req = spi_seq_item::type_id::create("req");

    `uvm_info(get_type_name(),
              "Calling start_item(req)",
              UVM_HIGH)

    start_item(req);

    // Constrain item to sequence data
    if (!req.randomize() with { data_m == local::tx_data_val; }) begin
      `uvm_error(get_type_name(), "Randomization failed")
    end
    else begin
      `uvm_info(get_type_name(),
                $sformatf("Randomized req.data_m = 0x%02h", req.data_m),
                UVM_MEDIUM)
    end

    `uvm_info(get_type_name(),
              "Calling finish_item(req)",
              UVM_HIGH)

    finish_item(req);

    `uvm_info(get_type_name(),
              $sformatf("Transaction sent. %s", req.convert2string()),
              UVM_MEDIUM)

    `uvm_info(get_type_name(),
              "Sequence completed",
              UVM_LOW)
  endtask
endclass


`endif