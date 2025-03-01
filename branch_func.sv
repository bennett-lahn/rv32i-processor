`ifndef _branch_func_
`define _branch_func_
`include "system.sv"

// Returns new program counter value by adding sign-extended j-type immediate to current program counter value
function word_t build_jal_pc(j_type_t instr, word_t pc);
    word_t offset, sum;
    // Add 0 lowest bit to align address
    offset = {{11{instr.imm20}}, instr.imm20, instr.imm19_12, instr.imm11, instr.imm10_1, 1'b0}; 
    sum = pc + $signed(offset);
    return {sum[31:1], 1'b0}; // Set lowest bit to 0 to align address
endfunction

// Returns new program counter value by adding rs1 value + sign-extended immediate
// Problem: rs1_data is only valid during execute stage
function word_t build_jalr_pc(i_type_t instr, word_t pc, reg_data_t rs1_data);
    word_t sign_extended_imm, sum;
    sign_extended_imm = {{20{instr.imm[11]}}, instr.imm};
    sum = (rs1_data + $signed(sign_extended_imm)) & $signed(-2);
    return sum;
endfunction

// Returns new program counter value by adding branch offset to current program counter value
function word_t build_branch_pc(b_type_t instr, word_t pc);
    word_t sign_extended_imm;
    // Add 0 lowest bit to align address
    sign_extended_imm = {{19{instr.imm12}}, instr.imm12, instr.imm11, instr.imm10_5, instr.imm4_1, 1'b0};
    return pc + $signed(sign_extended_imm);
endfunction

// Returns HIGH if pc should be speculatively updated to take the decoded branch or not
// BTFNT strategy: If the branch offset is negative based on sign bit (i.e., branch target is behind PC),
// then predict that the branch will be taken
function logic predict_branch_taken(b_type_t b_instr);
    return (b_instr.imm12 == 1'b1);
endfunction

// Returns HIGH if inputted instr_select_t is a branch instr
function logic is_branch(instr_select_t instr_sel);
    return instr_sel >= B_BEQ && instr_sel <= B_BGEU;
endfunction

// Returns HIGH if inputted instr_select_t is a jump instr
function logic is_jump(instr_select_t instr_sel);
    return instr_sel == J_JAL || instr_sel == I_JALR;
endfunction

`endif