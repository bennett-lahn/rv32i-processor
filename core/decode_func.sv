`ifndef _decode_func_
`define _decode_func_
`include "system.sv"

// Translates raw instruction into specific instruction type (enum value)
// Parameters:
//   instr: Complete RV32I instruction data structure
// Returns: Enumerated instruction type for execution stage
function instr_select_t parse_instruction(instruction_t instr);
    instr_type_t instr_type;
    instr_type = decode_opcode(instr.raw[6:0]); // Opcode
    case (instr_type)
        INSTR_R_TYPE: return decode_r_type(r_type_t'(instr));
        INSTR_I_TYPE: return decode_i_type(i_type_t'(instr));
        INSTR_S_TYPE: return decode_s_type(s_type_t'(instr));
        INSTR_B_TYPE: return decode_b_type(b_type_t'(instr));
        INSTR_U_TYPE: return decode_u_type(u_type_t'(instr));
        INSTR_J_TYPE: return decode_j_type(j_type_t'(instr));
        default: return X_UNKNOWN;
    endcase
endfunction

// Categorizes instruction based on opcode into major instruction type
// Parameters:
//   opcode: 7-bit opcode field from instruction
// Returns: Instruction type enum (R/I/S/B/U/J)
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

// Decodes R-type instruction using funct3 and funct7 fields
// Parameters:
//   instr: R-type instruction structure
// Returns: Specific R-type instruction enum (ADD, SUB, AND, etc.)
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

// Decodes I-type instructions based on opcode, funct3, and immediate fields
// Parameters:
//   instr: I-type instruction structure
// Returns: Specific I-type instruction enum (ADDI, JALR, LB, etc.)
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

// Decodes S-type (store) instructions using funct3 field
// Parameters:
//   instr: S-type instruction structure
// Returns: Specific store instruction enum (SB, SH, SW)
function instr_select_t decode_s_type(s_type_t instr);
    case (instr.funct3)
        FUNCT3_SB: return S_SB;
        FUNCT3_SH: return S_SH;
        FUNCT3_SW: return S_SW;
        default:   return X_UNKNOWN;
    endcase
endfunction

// Decodes U-type instructions based on opcode
// Parameters:
//   instr: U-type instruction structure
// Returns: Either LUI or AUIPC enum value
function instr_select_t decode_u_type(u_type_t instr);
    case (instr.opcode)
        OPCODE_LUI:     return U_LUI;
        OPCODE_AUIPC:   return U_AUIPC;
        default:        return X_UNKNOWN;
    endcase
endfunction

// Decodes B-type (branch) instructions using funct3 field
// Parameters:
//   instr: B-type instruction structure
// Returns: Specific branch instruction enum (BEQ, BNE, etc.)
function instr_select_t decode_b_type(b_type_t instr);
    case (instr.funct3)
        FUNCT3_BEQ:   return B_BEQ;
        FUNCT3_BNE:   return B_BNE;
        FUNCT3_BLT:   return B_BLT;
        FUNCT3_BGE:   return B_BGE;
        FUNCT3_BLTU:  return B_BLTU;
        FUNCT3_BGEU:  return B_BGEU;
        default:      return X_UNKNOWN;
    endcase
endfunction

// Decodes J-type (jump) instructions - only JAL in RV32I
// Parameters:
//   instr: J-type instruction structure
// Returns: J_JAL enum value
function instr_select_t decode_j_type(j_type_t instr);
    return J_JAL;
endfunction

// Extracts rs1 register index from instruction based on type
// Parameters:
//   reg_instr_data: Complete instruction data structure
// Returns: Register index for rs1 field, or REG_ZERO if not used
function reg_index_t update_rs1_addr(instruction_t reg_instr_data);
    // Decides which parts of instruction to use to load registers
    instr_type_t reg_load_type;
    reg_load_type = decode_opcode(reg_instr_data.r_type.opcode); // Opcode same for all instr types
    case (reg_load_type)
        INSTR_R_TYPE: return r_type_t'(reg_instr_data.r_type.rs1);
        INSTR_I_TYPE: return i_type_t'(reg_instr_data.i_type.rs1);
        INSTR_S_TYPE: return s_type_t'(reg_instr_data.s_type.rs1);
        INSTR_B_TYPE: return b_type_t'(reg_instr_data.b_type.rs1);
        INSTR_U_TYPE: return REG_ZERO;
        INSTR_J_TYPE: return REG_ZERO;
        default: return REG_ZERO;
    endcase
endfunction

// Extracts rs2 register index from instruction based on type
// Parameters:
//   reg_instr_data: Complete instruction data structure
// Returns: Register index for rs2 field, or REG_ZERO if not used
function reg_index_t update_rs2_addr(instruction_t reg_instr_data);
    // Decides which parts of instruction to use to load registers
    instr_type_t reg_load_type;
    reg_load_type = decode_opcode(reg_instr_data.r_type.opcode); // Opcode same for all instr types
    case (reg_load_type)
        INSTR_R_TYPE: return r_type_t'(reg_instr_data.r_type.rs2);
        INSTR_I_TYPE: return REG_ZERO;
        INSTR_S_TYPE: return s_type_t'(reg_instr_data.s_type.rs2);
        INSTR_B_TYPE: return b_type_t'(reg_instr_data.b_type.rs2);
        INSTR_U_TYPE: return REG_ZERO;
        INSTR_J_TYPE: return REG_ZERO;
        default: return REG_ZERO;
    endcase
endfunction

`endif