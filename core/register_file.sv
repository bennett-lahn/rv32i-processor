`ifndef _regfile
`define _regfile
`include "system.sv"

// This file contains the register file module

// Struct for easier manipulation of register file I/O
typedef struct packed {
    reg_index_t read_reg_addr_1;
    reg_index_t read_reg_addr_2;
    reg_index_t write_reg_addr;
    reg_data_t write_data;
    logic write_enable;
    reg_data_t read_data_1;
    reg_data_t read_data_2;
} reg_file_io_t;

// Module controlling register file containing 32 registers, including 0 reg
// Read address inputs select the register to be read from (0-31)
// read_reg_addr_1 only used for rs1
// read_reg_addr_2 only used for rs2
// write_reg_addr selects register to be written to by write_data if write_enable is true
// This register file implements register file bypass. If a register being read is the same as
// the register being written, the new data being written is used for the read
module register_file_m (
    input logic clk
    ,input logic reset
    ,input reg_index_t read_reg_addr_1
    ,input reg_index_t read_reg_addr_2
    ,input reg_index_t write_reg_addr
    ,input reg_data_t write_data
    ,input logic write_enable
    ,output reg_data_t read_data_1
    ,output reg_data_t read_data_2
);
    
    // Register array: 32 registers of 32 bits each
    logic [31:0] reg_file [31:0];

    // Synchronous read & write
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                reg_file[i] <= REG_ZERO_VAL;
            end
        end else begin
            if (write_enable && write_reg_addr != REG_ZERO)
                reg_file[write_reg_addr] <= write_data; // Write
            // Read
            read_data_1 <= (read_reg_addr_1 == REG_ZERO) ? REG_ZERO_VAL : ((write_reg_addr == read_reg_addr_1) && write_enable) ? write_data : reg_file[read_reg_addr_1];
            read_data_2 <= (read_reg_addr_2 == REG_ZERO) ? REG_ZERO_VAL : ((write_reg_addr == read_reg_addr_2) && write_enable) ? write_data : reg_file[read_reg_addr_2];
        end
    end
endmodule
`endif