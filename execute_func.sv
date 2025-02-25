`ifndef _execute_func_
`define _execute_func_
`include "base.sv"
`include "system.sv"
`include "register_file.sv" // Used for reg_index_t type

// Uses curr_instr_select and register data to execute appropriate instruction, returning reg_data_t result
function reg_data_t execute_instr(rv32i_instruction_t curr_instr_data, word_t pc, instr_select_t curr_instr_select, 
                                  reg_data_t rs1_data, reg_data_t rs2_data);
    case (curr_instr_select)
        R_ADD:  return execute_add(rs1_data, rs2_data);
        R_SUB:  return execute_sub(rs1_data, rs2_data);
        R_AND:  return execute_and(rs1_data, rs2_data);
        R_OR:   return execute_or(rs1_data, rs2_data);
        R_XOR:  return execute_xor(rs1_data, rs2_data);
        R_SLL:  return execute_sll(rs1_data, rs2_data);
        R_SRL:  return execute_srl(rs1_data, rs2_data);
        R_SRA:  return execute_sra(rs1_data, rs2_data);
        R_SLT:  return execute_slt(rs1_data, rs2_data);
        R_SLTU: return execute_sltu(rs1_data, rs2_data);

        I_ADDI: return execute_addi(curr_instr_data.i_type, rs1_data);
        I_JALR: return execute_jalr(pc);
        I_SLLI: return execute_slli(curr_instr_data.i_type, rs1_data);
        I_SRLI: return execute_srli(curr_instr_data.i_type, rs1_data);
        I_SRAI: return execute_srai(curr_instr_data.i_type, rs1_data);
        I_SLTI: return execute_slti(curr_instr_data.i_type, rs1_data);
        I_XORI: return execute_xori(curr_instr_data.i_type, rs1_data);
        I_ANDI: return execute_andi(curr_instr_data.i_type, rs1_data);
        I_ORI:  return execute_ori(curr_instr_data.i_type, rs1_data);
        I_SLTIU:return execute_sltiu(curr_instr_data.i_type, rs1_data);
        I_LB:   return execute_lb(curr_instr_data.i_type, rs1_data);
        I_LH:   return execute_lh(curr_instr_data.i_type, rs1_data);
        I_LW:   return execute_lw(curr_instr_data.i_type, rs1_data);
        I_LBU:  return execute_lbu(curr_instr_data.i_type, rs1_data);
        I_LHU:  return execute_lhu(curr_instr_data.i_type, rs1_data);

        S_SB:   return execute_sb(curr_instr_data.s_type, rs1_data);
        S_SH:   return execute_sh(curr_instr_data.s_type, rs1_data);
        S_SW:   return execute_sw(curr_instr_data.s_type, rs1_data);

        B_BEQ:  return execute_beq(rs1_data, rs2_data);
        B_BNE:  return execute_bne(rs1_data, rs2_data);
        B_BLT:  return execute_blt(rs1_data, rs2_data);
        B_BGE:  return execute_bge(rs1_data, rs2_data);
        B_BLTU: return execute_bltu(rs1_data, rs2_data);
        B_BGEU: return execute_bgeu(rs1_data, rs2_data);

        U_LUI:  return execute_lui(curr_instr_data.u_type);
        U_AUIPC:return execute_auipc(curr_instr_data.u_type, pc);

        J_JAL:  return execute_jal(pc);

        default:return execute_unknown();
    endcase
endfunction

// Functions implementing rv32i instructions
// Input: register values or immediates needed for instruction
// Output: data to be stored in rd register, if applicable

function reg_data_t execute_unknown();
    return REG_ZERO_VAL;
endfunction

function reg_data_t execute_add(reg_data_t rs1, reg_data_t rs2);
    return rs1 + rs2;
endfunction

function reg_data_t execute_sub(reg_data_t rs1, reg_data_t rs2);
    return rs1 - rs2;
endfunction

function reg_data_t execute_and(reg_data_t rs1, reg_data_t rs2);
    return rs1 & rs2;
endfunction

function reg_data_t execute_or(reg_data_t rs1, reg_data_t rs2);
    return rs1 | rs2;
endfunction

function reg_data_t execute_xor(reg_data_t rs1, reg_data_t rs2);
    return rs1 ^ rs2;
endfunction

function reg_data_t execute_sll(reg_data_t rs1, reg_data_t rs2);
    return rs1 << rs2;
endfunction

function reg_data_t execute_srl(reg_data_t rs1, reg_data_t rs2);
    return rs1 >> rs2;
endfunction

function reg_data_t execute_sra(reg_data_t rs1, reg_data_t rs2);
    return $signed(rs1) >>> $signed(rs2);
endfunction

function reg_data_t execute_slt(reg_data_t rs1, reg_data_t rs2);
    return $signed(rs1) < $signed(rs2) ? REG_ONE_VAL : REG_ZERO_VAL;
endfunction

function reg_data_t execute_sltu(reg_data_t rs1, reg_data_t rs2);
    return rs1 < rs2 ? REG_ONE_VAL : REG_ZERO_VAL;
endfunction

function reg_data_t execute_addi(i_type_t instr, reg_data_t rs1);
    return $signed(rs1) + $signed({{20{instr.imm[11]}}, instr.imm}); // Sign-extended immediate value
endfunction

function reg_data_t execute_andi(i_type_t instr, reg_data_t rs1);
    return rs1 & {{20{instr.imm[11]}}, instr.imm}; // Sign-extended immediate value
endfunction

function reg_data_t execute_ori(i_type_t instr, reg_data_t rs1);
    return rs1 | {{20{instr.imm[11]}}, instr.imm}; // Sign-extended immediate value
endfunction

function reg_data_t execute_xori(i_type_t instr, reg_data_t rs1);
    return rs1 ^ {{20{instr.imm[11]}}, instr.imm}; // Sign-extended immediate value
endfunction

function reg_data_t execute_slti(i_type_t instr, reg_data_t rs1);
    return ($signed(rs1) < $signed({{20{instr.imm[11]}}, instr.imm})) ? REG_ONE_VAL : REG_ZERO_VAL;
endfunction

function reg_data_t execute_sltiu(i_type_t instr, reg_data_t rs1);
    return (rs1 < {{20{instr.imm[11]}}, instr.imm}) ? REG_ONE_VAL : REG_ZERO_VAL;
endfunction

function reg_data_t execute_slli(i_type_t instr, reg_data_t rs1);
    return rs1 << instr.imm[4:0]; // [4:0] = shamt
endfunction

function reg_data_t execute_srli(i_type_t instr, reg_data_t rs1);
    return rs1 >> instr.imm[4:0]; // [4:0] = shamt
endfunction

function reg_data_t execute_srai(i_type_t instr, reg_data_t rs1);
    return $signed(rs1) >>> instr.imm[4:0]; // [4:0] shamt
endfunction

function reg_data_t execute_lb(i_type_t instr, reg_data_t rs1);
    return rs1 + {{20{instr.imm[11]}}, instr.imm};
endfunction

function reg_data_t execute_lh(i_type_t instr, reg_data_t rs1);
    return rs1 + {{20{instr.imm[11]}}, instr.imm};
endfunction

function reg_data_t execute_lw(i_type_t instr, reg_data_t rs1);
    return rs1 + {{20{instr.imm[11]}}, instr.imm};
endfunction

function reg_data_t execute_lbu(i_type_t instr, reg_data_t rs1);
    return rs1 + {{20{instr.imm[11]}}, instr.imm}; 
endfunction

function reg_data_t execute_lhu(i_type_t instr, reg_data_t rs1);
    return rs1 + {{20{instr.imm[11]}}, instr.imm};
endfunction

function reg_data_t execute_jalr(word_t pc);
    return pc + 4;
endfunction

function reg_data_t execute_sb(s_type_t instr, reg_data_t rs1);
    return rs1 + {{20{instr.imm_hi[6]}}, instr.imm_hi, instr.imm_lo};
endfunction

function reg_data_t execute_sh(s_type_t instr, reg_data_t rs1);
    return rs1 + {{20{instr.imm_hi[6]}}, instr.imm_hi, instr.imm_lo};
endfunction

function reg_data_t execute_sw(s_type_t instr, reg_data_t rs1);
    return rs1 + {{20{instr.imm_hi[6]}}, instr.imm_hi, instr.imm_lo};
endfunction

// Functions for branch instructions evaluate branch expression and if true return 1, else return 0

function reg_data_t execute_beq(reg_data_t rs1, reg_data_t rs2);
    logic result;
    result = (rs1 == rs2);
    return {{31{1'b0}}, result};
endfunction

function reg_data_t execute_bne(reg_data_t rs1, reg_data_t rs2);
    logic result;
    result = (rs1 != rs2);
    return {{31{1'b0}}, result};
endfunction

function reg_data_t execute_blt(reg_data_t rs1, reg_data_t rs2);
    logic result;
    result = $signed(rs1) < $signed(rs2);
    return {{31{1'b0}}, result};
endfunction

function reg_data_t execute_bge(reg_data_t rs1, reg_data_t rs2);
    logic result;
    result = $signed(rs1) >= $signed(rs2); 
    return {{31{1'b0}}, result};
endfunction

function reg_data_t execute_bltu(reg_data_t rs1, reg_data_t rs2);
    logic result;
    result = rs1 < rs2;
    return {{31{1'b0}}, result};
endfunction

function reg_data_t execute_bgeu(reg_data_t rs1, reg_data_t rs2);
    logic result;
    result = rs1 >= rs2;
    return {{31{1'b0}}, result};
endfunction

function reg_data_t execute_lui(u_type_t instr); 
    return {instr.imm, {12{1'b0}}};
endfunction

function reg_data_t execute_auipc(u_type_t instr, word_t pc);
    return pc + {instr.imm, {12{1'b0}}}; 
endfunction

function reg_data_t execute_jal(word_t pc);
    return pc + 4;
endfunction

`endif