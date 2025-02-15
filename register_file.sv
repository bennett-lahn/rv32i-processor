`ifndef _regfile
`define _regfile

// This file contains the register file module and related register types

// 32-bit type representing data to/from registers
// Also used as a generic 32-bit data type
typedef logic [31:0] reg_data_t;

// Values for x0 register; data and address
// REG_ZERO_VAL also used by some instructions to zero output
localparam reg_data_t REG_ZERO_VAL = 32'd0;
localparam reg_index_t REG_ZERO = 5'd0;

// Used by certain instructions to set register output to one
localparam reg_data_t REG_ONE_VAL = 32'd1;

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
            read_data_1 <= (read_reg_addr_1 == REG_ZERO) ? REG_ZERO_VAL : reg_file[read_reg_addr_1];
            read_data_2 <= (read_reg_addr_2 == REG_ZERO) ? REG_ZERO_VAL : reg_file[read_reg_addr_2];
        end
    end
endmodule
`endif