# RV32I Processor

This repository contains the source code and test benches for a pipelined, in-order, single-issue RV32I processor. My processor supports the full RV32I instruction set (with additional extensions planned) and includes custom implementations for interfacing with memory and standard C functions for simulation and debugging.

## Purpose
The goal of this project is to build a functional RV32I processor that can execute arbitrary C code. My design is implemented in SystemVerilog and includes modules for the core datapath, control logic, branch prediction, and hazard detection/forwarding. My processor is simulated using both Verilator and Icarus Verilog to verify correct behavior and performance.

## Repository Structure

.
├── core/                  # Processor core implementation (SystemVerilog)
│   ├── top.sv             # Top-level module
│   ├── execute_func.sv    # Execute stage functions
│   ├── decode_func.sv     # Decode stage functions
│   ├── mem_func.sv        # Memory interface functions
│   ├── branch_func.sv     # Branch prediction and control logic
│   ├── register_file.sv   # Register file implementation
│   └── sys_func.sv        # System-level helper functions
├── tests/                 # Assembly and C test programs
│   ├── test_asm.s         # Assembly test cases
│   └── test_c.c           # C test program to run on the processor
├── sim/                   # Simulation top files and scripts
│   ├── verilator_top.cpp  # Verilator simulation top-level
│   └── run_iverilog.sh    # Script to run Icarus Verilog simulation
├── libmc/                 # Custom C library for simulator I/O and utility functions
│   ├── libmc.a            # Precompiled library archive
│   ├── libmc.h            # Header file for the custom C functions
│   └── (source files)     # Source for functions such as printf, strtok, etc.
├── ld.script              # Linker script used for building the test programs
└── Makefile               # Top-level makefile for building the project and running simulations

## Testing Methodology

- **Simulation Environments:**
The processor is simulated using both Verilator and Icarus Verilog.

	- **Verilator:** Used for fast simulation, debugging, and more helpful warnings/errors; treats unknown values as zeros.
	- **Icarus Verilog:** Used for more rigorous testing since it strictly propagates X values, exposing subtle bugs.
- **Test Programs:**

	- **Assembly Tests:** Custom RV32I assembly test files exercise various control-flow, branch prediction, and hazard scenarios.
	- **C Tests:** A set of C programs using custom library functions (e.g., printf, strtok, memset) test arithmetic, recursion, and control flow.
- **Waveform Analysis:**
VCD files are generated during simulation to analyze signal propagation and debug timing/hazard issues using tools like GTKWave and Surfer.

- **Debug Statements:**
Debug prints are included in the pipeline stages (fetch, decode, execute, memory) to monitor PC updates, branch predictions, and stall conditions.

# Planned Improvements

- **Synthesizeability on Altera FPGAs:** My design uses a pretty unconvential style of SystemVerilog, including heavy utilization of functions. I plan on massaging my design to make it synthesizeable on Altera FPGAs. This may involve some pretty extensive redesigning, as my processor utilizes unions (not supported by Quartus Prime) to interpret instruction data. 
- **Enhanced Branch Prediction:** My processor currently implements a backwards taken, forwards not taken static predictor. This is better than nothing, but my implementation calculates the branch address in two places (very inefficient). I plan on implementing a **branch target buffer** to rectify this, as well as a more advanced predictor if I more deeply pipeline my procesor.
- **Constrained Random Verification Testbench:** My main future goal for this project. Although my processor can run arbitrary C code, there are several known and certainly many more unknown bugs in my design because I lack a thorough testing system. Hopefully, this testbench will be a good introduction to verification on using a project I am already intimately familiar with.

# **Potential Future Improvements**
- **ASIC-conscious design:** As it stands, my design is mostly designed to run in simulation and (in time) on FPGAs. 
- **Precise Interrupt Support:** Work in progress. The first-step in a  goal of creating a processor that could run code in the "real world".
- **Support for RISC-V extensions:** I hope to add support for the RV32M and RV32F/RV32D extensions. I want more experiencing interfacing with pre-made modules (I do not plan on making my own multiplier/floating point unit), especially as my design is currently not very modularized.
