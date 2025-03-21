`ifndef _branch_func_
`define _branch_func_
`include "system.sv"

// This file contains functions related to branching, jumping, branch prediction, and the program counter

// Calculates target address for JAL (Jump And Link) instruction
// Parameters:
//   instr: J-type instruction containing immediate fields
//   pc: Current program counter value
// Returns: New program counter value after adding sign-extended immediate
function word_t build_jal_pc(j_type_t instr, word_t pc);
    word_t offset, sum;
    // Add 0 lowest bit to align address
    offset = {{11{instr.imm20}}, instr.imm20, instr.imm19_12, instr.imm11, instr.imm10_1, 1'b0}; 
    sum = pc + $signed(offset);
    return {sum[31:1], 1'b0}; // Set lowest bit to 0 to align address
endfunction

// Calculates target address for JALR (Jump And Link Register) instruction
// Parameters:
//   instr: I-type instruction containing immediate field
//   pc: Current program counter (not used in calculation but included in 
function word_t build_jalr_pc(i_type_t instr, word_t pc, reg_data_t rs1_data);
    word_t sign_extended_imm, sum;
    sign_extended_imm = {{20{instr.imm[11]}}, instr.imm};
    sum = (rs1_data + $signed(sign_extended_imm)) & $signed(-2);
    return sum;
endfunction

// Calculates target address for branch instructions (BEQ, BNE, etc.)
// Parameters:
//   instr: B-type instruction containing immediate fields
//   pc: Current program counter value
// Returns: Target program counter value if branch is taken
function word_t build_branch_pc(b_type_t instr, word_t pc);
    word_t sign_extended_imm;
    // Add 0 lowest bit to align address
    sign_extended_imm = {{19{instr.imm12}}, instr.imm12, instr.imm11, instr.imm10_5, instr.imm4_1, 1'b0};
    return pc + $signed(sign_extended_imm);
endfunction

// Implements BTFNT (Backward Taken, Forward Not Taken) branch prediction strategy
// Parameters:
//   b_instr: B-type instruction to predict
// Returns: Boolean indicating whether the branch is predicted to be taken (HIGH = TAKEN)
function logic predict_branch_taken(b_type_t b_instr);
    return (b_instr.imm12 == 1'b1);
endfunction

// Determines if an instruction is a branch based on opcode
// Parameters:
//   opcode: 7-bit instruction opcode field
// Returns: Boolean indicating whether instruction is a branch (HIGH = is branch)
function logic is_branch(opcode_t opcode);
    return (opcode == OPCODE_B_TYPE); // B-Type instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
endfunction

// Determines if an instruction is a jump (JAL or JALR)
// Parameters:
//   instr_sel: Instruction type enum from decode stage
// Returns: Boolean indicating whether instruction is a jump
function logic is_jump(instr_select_t instr_sel);
    return instr_sel == J_JAL || instr_sel == I_JALR;
endfunction

`endif