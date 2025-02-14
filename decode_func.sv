`ifndef _decode_func_
`define _decode_func_
`include "system.sv"
`include "register_file.sv" // Used for reg_index_t type

// Translates raw instruction into specific instruction type using opcode
function instr_select_t parse_instruction(rv32i_instruction_t instr);
    instr_type_t instr_type;
    instr_type = decode_opcode(instr.raw[6:0]); // Opcode
    case (instr_type)
        INSTR_R_TYPE: return decode_r_type(instr.r_type);
        INSTR_I_TYPE: return decode_i_type(instr.i_type);
        INSTR_S_TYPE: return decode_s_type(instr.s_type);
        // INSTR_B_TYPE: return decode_b_type(instr.b_type);
        INSTR_U_TYPE: return decode_u_type(instr.u_type);
        // INSTR_J_TYPE: return decode_j_type(instr.j_type);
        default: return X_UNKNOWN;
    endcase
endfunction

// Function returning instr_type_t corrresponding to instruction type of opcode
function instr_type_t decode_opcode(opcode_t opcode);
    case (opcode)
        OPCODE_R_TYPE: return INSTR_R_TYPE; // R-type
        OPCODE_IMM:    return INSTR_I_TYPE; // I-type
        OPCODE_JALR:   return INSTR_I_TYPE; // I-type
        OPCODE_LOAD:   return INSTR_I_TYPE; // I-type
        OPCODE_S_TYPE: return INSTR_S_TYPE; // S-type
        OPCODE_B_TYPE: return INSTR_B_TYPE; // B-type
        OPCODE_LUI:    return INSTR_U_TYPE; // U-type
        OPCODE_AUIPC:  return INSTR_U_TYPE; // U-type
        OPCODE_JAL:    return INSTR_J_TYPE; // J-type
        default: return INSTR_UNKNOWN;
    endcase
endfunction

// Decodes and executes appropriate R-type instruction given r_type_t input
function instr_select_t decode_r_type(r_type_t instr);
    case (instr.funct3)
        FUNCT3_ADD_SUB: begin
            return instr_select_t'((instr.funct7 == FUNCT7_ADD) ? R_ADD : 
                                   (instr.funct7 == FUNCT7_SUB) ? R_SUB : X_UNKNOWN);
        end
        FUNCT3_AND:     return R_AND;
        FUNCT3_OR:      return R_OR;
        FUNCT3_XOR:     return R_XOR;
        FUNCT3_SLL:     return R_SLL;
        FUNCT3_SRL_SRA: begin 
            return instr_select_t'((instr.funct7 == FUNCT7_SRL) ? R_SRL : 
                                   (instr.funct7 == FUNCT7_SRA) ? R_SRA : X_UNKNOWN);
        end
        FUNCT3_SLT:     return R_SLT;
        FUNCT3_SLTU:    return R_SLTU;
        default:        return X_UNKNOWN; // Handle unknown instructions by doing nothing
    endcase
endfunction

// Decodes appropriate I-type instruction given i_type_t input
// FUNCT3 names are not to be taken literally in this case statement since 
// multiple i-type instructions share funct3
function instr_select_t decode_i_type(i_type_t instr);
    case (instr.funct3)
        FUNCT3_ADDI: begin     
            return instr_select_t'((instr.opcode == OPCODE_IMM) ? I_ADDI : 
                                   (instr.opcode == OPCODE_JALR) ? I_JALR : 
                                   (instr.opcode == OPCODE_LOAD) ? I_LB : X_UNKNOWN);
    end
        FUNCT3_SLLI: begin
            return instr_select_t'((instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SLLI) ? I_SLLI : 
                                   (instr.opcode == OPCODE_LOAD) ? I_LH : X_UNKNOWN);
    end
        FUNCT3_SRLI: begin    
            return instr_select_t'((instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SRLI) ? I_SRLI : 
                                   (instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SRAI) ? I_SRAI : 
                                   (instr.opcode == OPCODE_LOAD) ? I_LHU : X_UNKNOWN);

    end
        FUNCT3_SLTI: begin
            return instr_select_t'((instr.opcode == OPCODE_IMM) ? I_SLTI :
                                   (instr.opcode == OPCODE_LOAD) ? I_LW : X_UNKNOWN);
    end
        FUNCT3_XORI: begin
            return instr_select_t'((instr.opcode == OPCODE_IMM) ? I_XORI : 
                                   (instr.opcode == OPCODE_LOAD) ? I_LBU : X_UNKNOWN);
    end
        FUNCT3_ANDI:     return I_ANDI;
        FUNCT3_ORI:      return I_ORI;
        FUNCT3_SLTIU:    return I_SLTIU;
        default:         return X_UNKNOWN; // Handle unsupported instructions
    endcase
endfunction

// Decodes s-type instructon given s_type_t instr input
function instr_select_t decode_s_type(s_type_t instr);
    case (instr.funct3)
        FUNCT3_SB: return S_SB;
        FUNCT3_SH: return S_SH;
        FUNCT3_SW: return S_SW;
        default:   return X_UNKNOWN;
    endcase
endfunction

// Decodes u-type instruction given u_type_t instr input
function instr_select_t decode_u_type(u_type_t instr);
    case (instr.opcode)
        OPCODE_LUI:     return U_LUI;
        OPCODE_AUIPC:   return U_AUIPC;
        default:        return X_UNKNOWN;
    endcase
endfunction

// Given instruction, returns appropriate rs1 register number
function reg_index_t update_rs1_addr(rv32i_instruction_t reg_instr_data);
    // Decides which parts of instruction to use to load registers
    instr_type_t reg_load_type;
    reg_load_type = decode_opcode(reg_instr_data.r_type.opcode); // Opcode same for all instr types
    case (reg_load_type)
        INSTR_R_TYPE: return reg_instr_data.r_type.rs1;
        INSTR_I_TYPE: return reg_instr_data.i_type.rs1;
        INSTR_S_TYPE: return reg_instr_data.s_type.rs1;
        // INSTR_B_TYPE: return decode_b_type(instr.b_type);
        INSTR_U_TYPE: return REG_ZERO;
        // INSTR_J_TYPE: return decode_j_type(instr.j_type);
        default: return REG_ZERO;
    endcase
endfunction

// Given instruction, returns appropriate rs2 register number
function reg_index_t update_rs2_addr(rv32i_instruction_t reg_instr_data);
    // Decides which parts of instruction to use to load registers
    instr_type_t reg_load_type;
    reg_load_type = decode_opcode(reg_instr_data.r_type.opcode); // Opcode same for all instr types
    case (reg_load_type)
        INSTR_R_TYPE: return reg_instr_data.r_type.rs2;
        INSTR_I_TYPE: return REG_ZERO;
        INSTR_S_TYPE: return reg_instr_data.s_type.rs2;
        // INSTR_B_TYPE: return decode_b_type(instr.b_type);
        INSTR_U_TYPE: return REG_ZERO;
        // INSTR_J_TYPE: return decode_j_type(instr.j_type);
        default: return REG_ZERO;
    endcase
endfunction
`endif