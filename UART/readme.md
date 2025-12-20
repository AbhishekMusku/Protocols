# UART Design and Verification (SystemVerilog Class-Based)

## Overview
This repository contains the RTL design of a Universal Asynchronous Receiver-Transmitter (UART) and a complete SystemVerilog class-based verification environment. The testbench follows a layered architecture (Generator, Driver, Monitor, Scoreboard) using mailboxes for transaction passing and events for synchronization.

## Directory Structure
The project is organized into the following directories:

```
Protocols/UART/
├── rtl/                        # Design Under Test (DUT) Source Code
│   ├── uart_top.sv             # Top-level UART module
│   ├── uart_transmitter.sv     # TX logic
│   ├── uart_receiver.sv        # RX logic
│   └── baud_rate_generator.sv  # Baud rate generation logic
│
├── class_based/                # SystemVerilog Verification Environment
│   ├── uart_packet.sv          # Transaction class (Randomization & Constraints)
│   ├── uart_generator.sv       # Stimulus Generator (Random, Corner, Burst modes)
│   ├── uart_driver.sv          # Driver (Protocol implementation)
│   ├── uart_tx_monitor.sv      # TX Monitor (Bus to Transaction)
│   ├── uart_rx_monitor.sv      # RX Monitor (Bus to Transaction)
│   ├── uart_scoreboard.sv      # Scoreboard (Checker & Coverage)
│   ├── uart_environment.sv     # Test Environment container
│   ├── uart_if.sv              # Interface with modport & clocking blocks
│   ├── uart_tb_top.sv          # Top-level Testbench Module
│   └── run.do                  # Simulation script
│
└── tb_SV/                      # (Legacy/Simple Testbench files)
```

## Verification Environment Features
The environment is built using SystemVerilog classes and supports the following verification features:

- **Layered Architecture**: Strict separation of test, environment, and DUT.
- **Mailbox Communication**: Used between Generator → Driver and Monitors → Scoreboard.
- **Configurable Tests**: Supports Random, Corner Case, Burst, and Exhaustive testing modes.
- **Self-Checking**: Scoreboard compares TX and RX packets to ensure data integrity.
- **Loopback Mode**: The testbench connects rx to tx to verify full-duplex functionality.

## Supported Test Modes
The uart_generator and uart_environment support the following test scenarios:

| Test Mode      | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| Smoke Test     | Sends 10 random packets to ensure basic connectivity.                       |
| Corner Cases   | Focuses on specific data patterns: 0x00, 0xFF, 0x55, 0xAA.                  |
| Burst Mode     | Sends packets back-to-back with zero delay (inter_packet_delay == 0).       |
| All Values     | Exhaustive test sending all data values from 0x00 to 0xFF.                  |
| Comprehensive  | Runs all the above tests sequentially in a single simulation.               |

## How to Run Simulations
You can run simulations using the provided run.do script (located in `class_based/run.do`) (requires ModelSim/Questa) or via the command line with any SystemVerilog compliant simulator.

**Syntax:**
```bash
# Using run.do
vsim -do "class_based/run.do <test_name>"

```
**Available Test Names:** smoke_test, corner_test, stress_test, comprehensive_test.

## Simulation Configuration
- **Clock Frequency**: 100 MHz (10ns period).
- **Baud Rate**: Configurable via baud_divisor. Default set to 16'd32 in TB.
- **Oversampling**: 16x baud rate.
- **Timeout**: A global watchdog timer is set to 1ms to prevent infinite loops.