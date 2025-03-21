`ifndef _mem_func_
`define _mem_func_
`include "base.sv"
`include "system.sv"

// This file contains functions used for store/load instructions

// The functions below manipulate memory read/writes by calculating the misalignment between the 4-byte aligned
// main memory and the requested read/write instruction + addr, appropriately shifting data so it is written 
// to the appropriate byte planes (if a write) or moved into the least significant bytes (if a read)
// As the main memory is 4-byte aligned, this is only necessary for halfword/byte instructions
// These instructions work by selecting only the necessary bytes of the 4 bytes available, and shifting them
// into the lowest part of the return

// TODO: These instrs could be made more efficient by using opcode/funct3 instead of instr_sel

// Determines which bytes to access in a 4-byte aligned word based on instruction and address
// Parameters:
//   instr_sel: Instruction type enum indicating the memory operation (LB, LH, LW, etc.)
//   mem_addr: Memory address for the operation
// Returns: 4-bit mask where each bit represents a byte to be accessed
function logic [3:0] create_byte_plane(instr_select_t instr_sel, reg_data_t mem_addr);
    mem_offset_t byte_offset;
    byte_offset = calculate_mem_offset(mem_addr);
    // $display("[MEM] Calculated misalignment for byte plane is %d for addr 0x%h", byte_offset, mem_addr);
    if (instr_sel == I_LW || instr_sel == S_SW) begin
        return 4'b1111;
    end else if (instr_sel == I_LB || instr_sel == I_LBU || instr_sel == S_SB) begin
        case (byte_offset)
            ZERO:    return 4'b0001;
            ONE:     return 4'b0010;
            TWO:     return 4'b0100;
            THREE:   return 4'b1000;
            default: return 4'b0000; // Should never happen
        endcase
    end else if (instr_sel == I_LH || instr_sel == I_LHU || instr_sel == S_SH) begin
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

// Shifts data to the appropriate byte position for memory writes based on address alignment
// Parameters:
//   instr_sel: Instruction type enum indicating the store operation (SB, SH, SW)
//   mem_addr: Target memory address
//   data: Data to be written to memory
// Returns: Shifted data positioned at the correct byte offset
function reg_data_t write_shift_data_by_offset(instr_select_t instr_sel, reg_data_t mem_addr, reg_data_t data);
    logic [3:0] byte_plane;
    byte_plane = create_byte_plane(instr_sel, mem_addr);
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

// Shifts data read from memory to align it to the least significant bytes
// Parameters:
//   instr_sel: Instruction type enum indicating the load operation (LB, LH, LW, etc.)
//   mem_addr: Memory address that was read
//   data: Raw data read from memory
// Returns: Data shifted to position the relevant bytes at LSB position
function reg_data_t read_shift_data_by_offset(instr_select_t instr_sel, reg_data_t mem_addr, reg_data_t data);
    logic [3:0] byte_plane;
    byte_plane = create_byte_plane(instr_sel, mem_addr);
    // $display("Byte plane is: %b", byte_plane);
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

// Calculates the byte offset between a memory address and its 4-byte aligned version
// Parameters:
//   unaligned_addr: Memory address that may not be 4-byte aligned
// Returns: Enum value representing offset (0-3) from aligned address
function mem_offset_t calculate_mem_offset(reg_data_t unaligned_addr);
    logic [31:0] aligned_addr;
    aligned_addr = {unaligned_addr[31:2], 2'd0}; // Drop lowest 2 bits for alignment
    return mem_offset_t'(unaligned_addr - aligned_addr); // Cast may be problematic; should never fall outside of enum
endfunction

// Processes memory read data, applying correct sign/zero extension based on instruction
// Parameters:
//   instr_sel: Instruction type enum indicating the load operation (LB, LH, LW, etc.)
//   data_mem_rsp: Memory response structure containing address and data
// Returns: Properly shifted and sign/zero extended data for 
function reg_data_t interpret_read_memory_rsp(instr_select_t instr_sel, memory_io_rsp32 data_mem_rsp);
    reg_data_t temp;
    // Call shift data to move rsp data into proper LSB(s)
    temp = read_shift_data_by_offset(instr_sel, data_mem_rsp.addr, data_mem_rsp.data);
    // $display("Shifted data: %d Unshifted data: %d, rsp valid: %d", temp, data_mem_rsp.data, data_mem_rsp.valid);
    case (instr_sel)
        I_LB:     return reg_data_t'({{24{temp[7]}}, temp[7:0]});
        I_LH:     return reg_data_t'({{16{temp[15]}}, temp[15:0]});
        I_LW:     return temp;
        I_LBU:    return reg_data_t'({{24{1'b0}}, temp[7:0]});
        I_LHU:    return reg_data_t'({{16{1'b0}}, temp[15:0]});
        default:  return temp; // Should never happen
    endcase
endfunction

`endif