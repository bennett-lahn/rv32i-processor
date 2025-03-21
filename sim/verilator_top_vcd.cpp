#include <verilated.h>          // Defines common routines
#include <iostream>             // Need std::cout
#include "Vtop.h"               // From Verilating "top.v"
#include "verilated_vcd_c.h"    // For VCD tracing

Vtop *top;                      // Instantiation of module
VerilatedVcdC* tfp;             // Trace file pointer

vluint64_t main_time = 0;       // Current simulation time
// This is a 64-bit integer to reduce wrap over issues and
// allow modulus.  This is in units of the timeprecision
// used in Verilog (or from --timescale-override)

double sc_time_stamp () {       // Called by $time in Verilog
    return main_time;           // converts to double, to match
                               // what SystemC does
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);   // Remember args
    
    // Enable VCD tracing
    Verilated::traceEverOn(true);
    
    top = new Vtop;             // Create instance
    
    // Initialize VCD trace file
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);        // Trace 99 levels of hierarchy
    tfp->open("dump.vcd");      // Open the VCD file
    
    top->reset = 1;           // Set some inputs

    while (!Verilated::gotFinish()) {
        if (main_time > 10)
            top->reset = 0;   // Deassert reset
        
        top->clk = 1;
        top->eval();
        tfp->dump(main_time);   // Dump values at current time
        
        top->clk = 0;
        top->eval();
        tfp->dump(main_time+1); // Dump values after clock edge
        
        if (top->halt == 1)
            break;
            
        main_time += 2;         // Advance time by 2 units for full clock cycle
    }

    // Clean up
    tfp->close();               // Close the trace file
    top->final();               // Done simulating
    delete top;
    delete tfp;                 // Free the trace file
    
    return 0;
}
