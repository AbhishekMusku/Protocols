# SPI Master Design and Verification (UVM)

## Overview

This repository contains the RTL design of a Serial Peripheral Interface (SPI) Master (SOurced from NANDLAND with modifications) and a complete UVM (Universal Verification Methodology) verification environment. The design is a configurable SPI Master that supports all 4 SPI modes (CPOL/CPHA) and variable clock dividers. The testbench follows a layered architecture (Sequencer, Driver, Monitor, Scoreboard) using TLM ports for transaction passing and analysis.

## Directory Structure

The project is organized into the following directories:

```
Protocols/SPI/
├── rtl/                          # Design Under Test (DUT) Source Code
│   └── SPI_Master.v              # SPI Master Logic (Configurable Modes 0-3)
│
├── tb_SV/                        # SystemVerilog Testbench
│
└── UVM/                          # UVM Verification Environment
    ├── run.do                    # Simulation script
    ├── spi_agent.sv              # Master Agent
    ├── SPI_ASSERTIONS_SV.sv      # SVA Assertions
    ├── spi_base_sequence.sv      # Stimulus Sequences (Base & Single Transaction)
    ├── spi_base_test.sv          # Base Test & Sanity Test
    ├── spi_config.sv             # Configuration Object
    ├── spi_driver.sv             # Master Driver (Protocol implementation)
    ├── spi_env.sv                # Test Environment container
    ├── spi_if.sv                 # Interface with clocking blocks
    ├── spi_monitor.sv            # Monitor (Bus to Transaction)
    ├── spi_scoreboard.sv         # Scoreboard (Checker & Coverage)
    ├── spi_seq_item.sv           # Transaction Object (Randomization & Constraints)
    ├── spi_slave_agent.sv        # Slave Agent
    ├── spi_slave_driver.sv       # Slave Driver (Reactive response)
    └── tb_top.sv                 # Top-level Testbench Module
```

## Verification Environment Features

The environment is built using UVM classes and supports the following verification features:

- **Layered Architecture**: Strict separation of test, environment, and DUT.
- **Configurable Master**: Supports SPI Modes 0, 1, 2, 3 via parameters.
- **Configuration Object**: UVM config object for flexible testbench configuration.
- **Reactive Slave**: The testbench includes a slave agent to respond to the master.
- **Self-Checking**: Scoreboard compares transmitted and received packets to ensure data integrity.
- **Assertions**: SVA module bound to the DUT for protocol validation.

## Supported Test Modes

The `spi_base_test.sv` supports the following test scenarios:

| Test Mode    | Description                                              |
|--------------|----------------------------------------------------------|
| Sanity Test  | Sends 10 random packets to ensure basic connectivity.   |
| Single Txn   | Sends a specific byte pattern defined in the sequence.  |

## How to Run Simulations

You can run simulations using the provided `run.do` script (located in `UVM/run.do`) (requires ModelSim/Questa) or via the command line with any UVM compliant simulator.

### Syntax:

```bash
# Using run.do
vsim -do "run.do"
```

### Changing the Test

To run a different test, modify `run.do` by adding `+UVM_TESTNAME=<test_name>`:
```tcl
vsim -voptargs=+acc work.tb_top +UVM_TESTNAME=spi_sanity_test +UVM_VERBOSITY=UVM_HIGH
```

## Simulation Configuration

The testbench can be configured by modifying parameters in `tb_top.sv`:

- **Clock Frequency**: 100 MHz (10ns period)
  
- **SPI Mode**: Configurable via `SPI_MODE` parameter (Default: Mode 3)
  - Supported modes: 0, 1, 2, 3 (CPOL/CPHA combinations)
  
- **Baud Rate**: Configurable via `CLKS_PER_HALF_BIT` parameter (Default: 4)
  - Formula: SPI Clock = System Clock / (CLKS_PER_HALF_BIT × 2)
  - Default: 100 MHz / (4 × 2) = 12.5 MHz
  - Must be ≥ 2

- **Default Test**: `spi_sanity_test`
  - Can be overridden via command line (see "Changing the Test" above)

### Changing Configuration

To modify SPI mode or baud rate, edit the DUT instantiation in `tb_top.sv`:

```systemverilog
SPI_Master #(
  .SPI_MODE(0),           // Change to desired mode (0-3)
  .CLKS_PER_HALF_BIT(2)   // Adjust for different SPI clock speed
) dut (
  // ... port connections
);
```
