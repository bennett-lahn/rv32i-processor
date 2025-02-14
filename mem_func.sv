`ifndef _mem_func_
`define _mem_func_
`define BYTE 8
`include "system.sv"
`include "register_file.sv" // Used for reg_index_t type

// The functions below manipulate memory read/writes by calculating the misalignment between the 4-byte aligned
// main memory and the requested read/write instruction + addr, appropriately shifting data so it is written to the appropriate byte
// planes (if a write) or moved into the least significant bytes (if a read)
// As the main memory is 4-byte aligned, this is only necessary for halfword/byte instructions

localparam int BYTE = 8;

// Return which bytes should be read from memory after 4-byte aligning memory address request
function logic [3:0] create_byte_plane(instr_select_t curr_instr_select, reg_data_t mem_addr);
    mem_offset_t byte_offset;
    byte_offset = calculate_mem_offset(mem_addr);
    // $display("[MEM] Calculated misalignment for byte plane is %d for addr 0x%h", byte_offset, data_mem_req.addr);
    if (curr_instr_select == I_LW || curr_instr_select == S_SW) begin
        return 4'b1111;
    end else if (curr_instr_select == I_LB || curr_instr_select == I_LBU || curr_instr_select == S_SB) begin
        case (byte_offset)
            ZERO:    return 4'b0001;
            ONE:     return 4'b0010;
            TWO:     return 4'b0100;
            THREE:   return 4'b1000;
            default: return 4'b0000; // Should never happen
        endcase
    end else if (curr_instr_select == I_LH || curr_instr_select == I_LHU || curr_instr_select == S_SH) begin
        case (byte_offset)
            ZERO:    return 4'b0011;
            ONE:     return 4'b0110;
            TWO:     return 4'b1100;
            default: return 4'b0000; // Should never happen
        endcase
    end else begin
        return 4'b0000; // Should never happen
    end
endfunction

// Shift data into appropriate bytes depending on which byte planes are going to be written to
function reg_data_t write_shift_data_by_offset(instr_select_t curr_instr_select, reg_data_t mem_addr, reg_data_t data);
    logic [3:0] byte_plane;
    byte_plane = create_byte_plane(curr_instr_select, mem_addr);
    case (byte_plane)
        4'b0001: return data;
        4'b0010: return data << BYTE;
        4'b0100: return data << 2*BYTE;
        4'b1000: return data << 3*BYTE;
        4'b0011: return data;
        4'b0110: return data << BYTE;
        4'b1100: return data << 2*BYTE;
        default: return data;
    endcase
endfunction

// Shift data into lowest bytes depending on which byte planes were read by memory, return shifted value
function reg_data_t read_shift_data_by_offset(instr_select_t curr_instr_select, reg_data_t mem_addr, reg_data_t data);
    logic [3:0] byte_plane;
    byte_plane = create_byte_plane(curr_instr_select, mem_addr);
    case (byte_plane)
        4'b0001: return data;
        4'b0010: return data >> BYTE;
        4'b0100: return data >> 2*BYTE; 
        4'b1000: return data >> 3*BYTE;
        4'b0011: return data;
        4'b0110: return data >> BYTE;
        4'b1100: return data >> 2*BYTE;
        default: return data;
    endcase
endfunction

// Helper function that compares memory address to 4-byte aligned version and returns numerical difference between the two
// Subtract true address from aligned address to get offset to select byte plane
function mem_offset_t calculate_mem_offset(reg_data_t unaligned_addr);
    logic [31:0] aligned_addr;
    aligned_addr = {unaligned_addr[31:2], 2'd0}; // Drop lowest 2 bits for alignment
    return mem_offset_t'(unaligned_addr - aligned_addr); // Cast may be problematic; should never fall outside of enum
endfunction

// Given current load instruction memory rsp, return sign/zero extended memory response according to instruction
function reg_data_t interpret_read_memory_rsp(instr_select_t curr_instr_select, memory_io_rsp32 data_mem_rsp);
    reg_data_t temp;
    // Call shift data to move rsp data into proper LSB(s)
    temp = read_shift_data_by_offset(curr_instr_select, data_mem_rsp.addr, data_mem_rsp.data);
    case (curr_instr_select)
        I_LB:     return reg_data_t'({{24{temp[7]}}, temp[7:0]});
        I_LH:     return reg_data_t'({{16{temp[15]}}, temp[15:0]});
        I_LW:     return temp;
        I_LBU:    return reg_data_t'({{24{1'b0}}, temp[7:0]});
        I_LHU:    return reg_data_t'({{16{1'b0}}, temp[15:0]});
        default:  return temp; // Should never happen
    endcase
endfunction

`endif