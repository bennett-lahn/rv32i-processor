`ifndef _sys_func_
`define _sys_func_
`include "system.sv"
`include "register_file.sv"

// Returns TRUE if the given instr_sel indicates a store instruction.
function logic is_load(opcode_t opcode);
    return (opcode == OPCODE_LOAD); // Load instructions (LB, LH, LW, LBU, LHU)
endfunction

// Returns TRUE if the given instr_sel indicates a load instruction.
function logic is_store(opcode_t opcode);
    return (opcode == OPCODE_S_TYPE); // Store instructions (SB, SH, SW)
endfunction


// Returns TRUE if instruction corresponding to opcode uses rs1
function logic uses_rs1(opcode_t opcode);
    case (opcode)
        OPCODE_R_TYPE,  // R-type (ADD, SUB, AND, OR, XOR, etc.)
        OPCODE_IMM,     // I-type ALU (ADDI, ANDI, ORI, etc.)
        OPCODE_LOAD,    // I-type Load (LB, LH, LW, etc.)
        OPCODE_S_TYPE,  // S-type Store (SB, SH, SW)
        OPCODE_B_TYPE,  // B-type Branch (BEQ, BNE, BLT, etc.)
        OPCODE_JALR:    // JALR (I-type Jump)
            return TRUE;
        default:
            return FALSE;
    endcase
endfunction

// Returns TRUE if instruction corresponding to opcode uses rs2
function logic uses_rs2(opcode_t opcode);
    case (opcode)
        OPCODE_R_TYPE,  // R-type ALU (ADD, SUB, AND, OR, XOR, etc.)
        OPCODE_S_TYPE,  // S-type Store (SB, SH, SW)
        OPCODE_B_TYPE:  // B-type Branch (BEQ, BNE, BLT, etc.)
            return TRUE;
        default:
            return FALSE;
    endcase
endfunction

// Returns TRUE if instruction corresponding to opcode uses rd
function logic uses_rd(opcode_t opcode);
    case (opcode)
        OPCODE_R_TYPE,   // R-Type instructions (ADD, SUB, AND, OR, etc.)
        OPCODE_IMM,      // I-Type ALU instructions (ADDI, ANDI, ORI, etc.)
        OPCODE_LUI,      // LUI (Load Upper Immediate)
        OPCODE_AUIPC,    // AUIPC (Add Upper Immediate to PC)
        OPCODE_JAL,      // JAL (Jump and Link)
        OPCODE_JALR,     // JALR (Jump and Link Register)
        OPCODE_LOAD:     // Load instructions (LB, LH, LW, LBU, LHU)
            return TRUE; // These instructions write to rd
        default:
            return FALSE; // Other instructions do not write to rd
    endcase
endfunction

`endif