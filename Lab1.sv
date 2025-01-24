`ifndef _debug
`define _debug
`include "system.sv"
`include "base.sv"

// Function returning instr_type_t corrresponding to instruction type of opcode
function instr_type_t debug_decode_opcode(opcode_t opcode);
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

// Returns string representation of inputted reg_index from instruction
function string debug_decode_register(reg_index_t reg_index);
    return $sformatf("x%0d", reg_index);
endfunction

// Returns string representation of R-Type instruction
function string debug_decode_r_type(r_type_t instr);
    string mnemonic;
    case (instr.funct3)
        FUNCT3_ADD_SUB: mnemonic = (instr.funct7 == FUNCT7_ADD) ? "add" : (instr.funct7 == FUNCT7_SUB) ? "sub" : "unknown";
        FUNCT3_AND:     mnemonic = "and";
        FUNCT3_OR:      mnemonic = "or";
        FUNCT3_XOR:     mnemonic = "xor";
        FUNCT3_SLL:     mnemonic = "sll";
        FUNCT3_SRL_SRA: mnemonic = (instr.funct7 == FUNCT7_SRL) ? "srl" : (instr.funct7 == FUNCT7_SRA) ? "sra" : "unknown";
        FUNCT3_SLT:     mnemonic = "slt";
        FUNCT3_SLTU:    mnemonic = "sltu";
        default:        mnemonic = "unknown";
    endcase
    return $sformatf("%-5s %-4s %-4s %-10s", mnemonic, debug_decode_register(instr.rd), debug_decode_register(instr.rs1), debug_decode_register(instr.rs2));
endfunction

// Localparam for shift amount field size
localparam int SHIFT_AMOUNT_WIDTH = 5;

// Returns string representation of I-Type instruction
function string debug_decode_i_type(i_type_t instr);
    string mnemonic;
    case (instr.funct3)
        FUNCT3_ADDI:     mnemonic = (instr.opcode == OPCODE_IMM) ? "addi" : (instr.opcode == OPCODE_LOAD) ? "lb" : "jalr";
        FUNCT3_SLLI:     mnemonic = (instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SLLI) ? "slli" : "lh";
        FUNCT3_SRLI:     mnemonic = (instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SRLI) ? "srli" : 
                                    (instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SRAI) ? "srai" : "lhu";
        FUNCT3_SLTI:     mnemonic = (instr.opcode == OPCODE_IMM) ? "slti" : "lw";
        FUNCT3_XORI:     mnemonic = (instr.opcode == OPCODE_IMM) ? "xori" : "lbu";
        FUNCT3_ANDI:     mnemonic = "andi";
        FUNCT3_ORI:      mnemonic = "ori";
        FUNCT3_SLTIU:    mnemonic = "sltiu";
        default:         mnemonic = "unknown";
    endcase
    if (instr.opcode == OPCODE_IMM && (instr.funct3 == FUNCT3_SLLI || instr.funct3 == FUNCT3_SRLI))
        return $sformatf("%-5s %-4s %-4s %-10d", mnemonic, debug_decode_register(instr.rd), debug_decode_register(instr.rs1), instr.imm[SHIFT_AMOUNT_WIDTH-1:0]);
    else if (instr.opcode == OPCODE_IMM)
        return $sformatf("%-5s %-4s %-4s %-10s", mnemonic, debug_decode_register(instr.rd), debug_decode_register(instr.rs1), $sformatf("%0d", $signed(instr.imm)));
    else
        return $sformatf("%-5s %-4s %0d(%s)", mnemonic, debug_decode_register(instr.rd), $signed({instr.imm}), debug_decode_register(instr.rs1));  
endfunction

// Returns string representation of S-Type instruction
function string debug_decode_s_type(s_type_t instr);
    string mnemonic;
    case (instr.funct3)
        FUNCT3_SB:       mnemonic = "sb";
        FUNCT3_SH:       mnemonic = "sh";
        FUNCT3_SW:       mnemonic = "sw";
        default:         mnemonic = "unknown";
    endcase
    // Combine immediate fields for memory offset
    return $sformatf("%-5s %-4s %0d(%s)", mnemonic, debug_decode_register(instr.rs2), $signed({instr.imm_hi, instr.imm_lo}), debug_decode_register(instr.rs1));
    
endfunction

// Returns string representation of B-Type instruction
function string debug_decode_b_type(b_type_t instr);
    string mnemonic;
    case (instr.funct3)
        FUNCT3_BEQ:      mnemonic = "beq";
        FUNCT3_BNE:      mnemonic = "bne";
        FUNCT3_BLT:      mnemonic = "blt";
        FUNCT3_BGE:      mnemonic = "bge";
        FUNCT3_BLTU:     mnemonic = "bltu";
        FUNCT3_BGEU:     mnemonic = "bgeu";
        default:         mnemonic = "unknown";
    endcase
    // Combine immediate fields into a signed offset
    return $sformatf("%-5s %-4s %-4s %-10s", mnemonic, debug_decode_register(instr.rs1), debug_decode_register(instr.rs2), $sformatf("%0d", $signed({instr.imm12, instr.imm11, instr.imm10_5, instr.imm4_1, 1'b0})));
endfunction

// Returns string representation of U-Type instruction
function string debug_decode_u_type(u_type_t instr);
    string mnemonic;
    case (instr.opcode)
        OPCODE_LUI:     mnemonic = "lui";
        OPCODE_AUIPC:   mnemonic = "auipc";
        default:        mnemonic = "unknown";
    endcase
    return $sformatf("%-5s %-4s 0x%-5x", mnemonic, debug_decode_register(instr.rd), instr.imm);
endfunction


// Returns string representation of J-Type instruction
function string debug_decode_j_type(j_type_t instr);
    string mnemonic;
    mnemonic = "jal";
    // Combine immediate fields into a signed offset
    return $sformatf("%-5s %-4s 0x%-5x", mnemonic, debug_decode_register(instr.rd), $signed({instr.imm20, instr.imm19_12, instr.imm11, instr.imm10_1, 1'b0}));
endfunction

// Returns string representation of inputted function
function string debug_parse_instruction(rv32i_instruction_t instr);
    instr_type_t instr_type;
    instr_type = debug_decode_opcode(instr.raw[6:0]); // Opcode
    case (instr_type)
        INSTR_R_TYPE: return debug_decode_r_type(instr.r_type);
        INSTR_I_TYPE: return debug_decode_i_type(instr.i_type);
        INSTR_S_TYPE: return debug_decode_s_type(instr.s_type);
        INSTR_B_TYPE: return debug_decode_b_type(instr.b_type);
        INSTR_U_TYPE: return debug_decode_u_type(instr.u_type);
        INSTR_J_TYPE: return debug_decode_j_type(instr.j_type);
        default: return "Unsupported instruction";
    endcase
endfunction

function void print_instruction(logic [31:0] pc, logic [31:0] instruction);
	rv32i_instruction_t instr_new_type;
	instr_new_type.raw = instruction;
    $write("%x: ", pc);
    $write("%x   ", instruction);
    $write("%s", debug_parse_instruction(instr_new_type));
    $write("\n");
endfunction	

`endif