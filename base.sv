`ifndef _base_
`define _base_

`ifdef verilator
typedef logic bool;
`endif
// Useful macros to make the code more readable
localparam TRUE = 1'b1;
localparam FALSE = 1'b0;
localparam ONE = 1'b1;
localparam ZERO = 1'b0;
localparam BYTE = 8;

`endif
