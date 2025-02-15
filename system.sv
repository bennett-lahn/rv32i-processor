`ifndef _system_
`define _system_

`define word_size 32
`define word_address_size 32

`define word_size_bytes (`word_size/8)
`define word_address_size_bytes (`word_address_size/8)

`define user_tag_size 16

// This file contains basic types used by the processor to define/decode instructions
// Specific types for registers are found in register_file.sv

typedef logic[`word_size - 1:0] word_t;

// Opcodes for I-Type instructions
localparam logic [6:0] OPCODE_LOAD  = 7'b0000011; // Load instructions (LB, LH, LW, LBU, LHU)
localparam logic [6:0] OPCODE_IMM   = 7'b0010011; // Arithmetic immediate (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
localparam logic [6:0] OPCODE_JALR  = 7'b1100111; // Jump and Link Register (JALR)

// funct3 values for I-Type instructions
// Load instructions
localparam logic [2:0] FUNCT3_LB   = 3'b000; // Load Byte
localparam logic [2:0] FUNCT3_LH   = 3'b001; // Load Halfword
localparam logic [2:0] FUNCT3_LW   = 3'b010; // Load Word
localparam logic [2:0] FUNCT3_LBU  = 3'b100; // Load Byte Unsigned
localparam logic [2:0] FUNCT3_LHU  = 3'b101; // Load Halfword Unsigned

// Arithmetic immediate instructions
localparam logic [2:0] FUNCT3_ADDI  = 3'b000; // Add Immediate
localparam logic [2:0] FUNCT3_SLTI  = 3'b010; // Set Less Than Immediate (signed)
localparam logic [2:0] FUNCT3_SLTIU = 3'b011; // Set Less Than Immediate Unsigned
localparam logic [2:0] FUNCT3_XORI  = 3'b100; // XOR Immediate
localparam logic [2:0] FUNCT3_ORI   = 3'b110; // OR Immediate
localparam logic [2:0] FUNCT3_ANDI  = 3'b111; // AND Immediate
localparam logic [2:0] FUNCT3_SLLI  = 3'b001; // Shift Left Logical Immediate
localparam logic [2:0] FUNCT3_SRLI  = 3'b101; // Shift Right Logical Immediate
localparam logic [2:0] FUNCT3_SRAI  = 3'b101; // Shift Right Arithmetic Immediate

// Upper imm bit values used to differentiate shift immediate instructions

localparam logic [6:0] SHIFT_TYPE_SLLI = 7'b0000000;
localparam logic [6:0] SHIFT_TYPE_SRLI = 7'b0000000;
localparam logic [6:0] SHIFT_TYPE_SRAI = 7'b0100000;

// Opcode for R-Type instructions
localparam logic [6:0] OPCODE_R_TYPE = 7'b0110011; // R-Type instructions (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)

// funct3 values for R-Type instructions
localparam logic [2:0] FUNCT3_ADD_SUB = 3'b000; // ADD and SUB (differentiated by funct7)
localparam logic [2:0] FUNCT3_SLL     = 3'b001; // Shift Left Logical
localparam logic [2:0] FUNCT3_SLT     = 3'b010; // Set Less Than (signed)
localparam logic [2:0] FUNCT3_SLTU    = 3'b011; // Set Less Than Unsigned
localparam logic [2:0] FUNCT3_XOR     = 3'b100; // XOR
localparam logic [2:0] FUNCT3_SRL_SRA = 3'b101; // SRL and SRA (differentiated by funct7)
localparam logic [2:0] FUNCT3_OR      = 3'b110; // OR
localparam logic [2:0] FUNCT3_AND     = 3'b111; // AND

// funct7 values for R-Type instructions
localparam logic [6:0] FUNCT7_ADD    = 7'b0000000; // ADD
localparam logic [6:0] FUNCT7_SUB    = 7'b0100000; // SUB
localparam logic [6:0] FUNCT7_SLL    = 7'b0000000; // Shift Left Logical
localparam logic [6:0] FUNCT7_SLT    = 7'b0000000; // Set Less Than (signed)
localparam logic [6:0] FUNCT7_SLTU   = 7'b0000000; // Set Less Than Unsigned
localparam logic [6:0] FUNCT7_XOR    = 7'b0000000; // XOR
localparam logic [6:0] FUNCT7_SRL    = 7'b0000000; // Shift Right Logical
localparam logic [6:0] FUNCT7_SRA    = 7'b0100000; // Shift Right Arithmetic
localparam logic [6:0] FUNCT7_OR     = 7'b0000000; // OR
localparam logic [6:0] FUNCT7_AND    = 7'b0000000; // AND

// Opcode for S-Type instructions
localparam logic [6:0] OPCODE_S_TYPE = 7'b0100011; // S-Type instructions (SB, SH, SW)

// funct3 values for S-Type instructions
localparam logic [2:0] FUNCT3_SB = 3'b000; // Store Byte
localparam logic [2:0] FUNCT3_SH = 3'b001; // Store Halfword
localparam logic [2:0] FUNCT3_SW = 3'b010; // Store Word

// Opcode for B-Type instructions
localparam logic [6:0] OPCODE_B_TYPE = 7'b1100011; // B-Type instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)

// funct3 values for B-Type instructions
localparam logic [2:0] FUNCT3_BEQ   = 3'b000; // Branch if Equal (beq)
localparam logic [2:0] FUNCT3_BNE   = 3'b001; // Branch if Not Equal (bne)
localparam logic [2:0] FUNCT3_BLT   = 3'b100; // Branch if Less Than (signed) (blt)
localparam logic [2:0] FUNCT3_BGE   = 3'b101; // Branch if Greater Than or Equal (signed) (bge)
localparam logic [2:0] FUNCT3_BLTU  = 3'b110; // Branch if Less Than (unsigned) (bltu)
localparam logic [2:0] FUNCT3_BGEU  = 3'b111; // Branch if Greater Than or Equal (unsigned) (bgeu)

// Opcodes for U-Type instructions
localparam logic [6:0] OPCODE_LUI    = 7'b0110111; // LUI (Load Upper Immediate)
localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111; // AUIPC (Add Upper Immediate to PC)

// U-Type instructions do not have funct3 values
// They only have the opcode and a 20-bit immediate (imm[31:12])

// Opcode for J-Type instructions
localparam logic [6:0] OPCODE_JAL = 7'b1101111; // J-Type instruction (JAL)

// J-Type instructions do not have funct3 or funct7 fields
// They only have a 20-bit immediate (imm[31], imm[19:12], imm[11], imm[10:1])

// Basic definitions used for RV32i encoding
typedef logic [6:0] opcode_t;    // 7-bit opcode field
typedef logic [2:0] funct3_t;    // 3-bit funct3 field
typedef logic [6:0] funct7_t;    // 7-bit funct7 field
typedef logic [4:0] reg_index_t; // 5-bit register index (rd, rs1, rs2)
typedef logic [11:0] imm12_t;    // 12-bit immediate (I-type, S-type, B-type)
typedef logic [19:0] imm20_t;    // 20-bit immediate (U-type, J-type)
typedef logic [31:0] instruction_t; // Full 32-bit instruction

// R-Type Instruction Encoding
typedef struct packed {
    funct7_t funct7;       // Bits 	[31:25]
    reg_index_t rs2;       // Bits [24:20]
    reg_index_t rs1;       // Bits [19:15]
    funct3_t funct3;       // Bits [14:12]
    reg_index_t rd;        // Bits [11:7]
    opcode_t opcode;       // Bits [6:0]
} r_type_t;

// I-Type Instruction Encoding
typedef struct packed {
    imm12_t imm;           // Bits [31:20] (12-bit immediate)
    reg_index_t rs1;       // Bits [19:15]
    funct3_t funct3;       // Bits [14:12]
    reg_index_t rd;        // Bits [11:7]
    opcode_t opcode;       // Bits [6:0]
} i_type_t;

// S-Type Instruction Encoding
typedef struct packed {
    logic [6:0] imm_hi;    // Bits [31:25] (upper 7 bits of immediate)
    reg_index_t rs2;       // Bits [24:20]
    reg_index_t rs1;       // Bits [19:15]
    funct3_t funct3;       // Bits [14:12]
    logic [4:0] imm_lo;    // Bits [11:7] (lower 5 bits of immediate)
    opcode_t opcode;       // Bits [6:0]
} s_type_t;

// B-Type Instruction Encoding
typedef struct packed {
    logic imm11;           // Bit [31] (immediate bit 11)
    logic [5:0] imm10_5;   // Bits [30:25] (immediate bits 10:5)
    reg_index_t rs2;       // Bits [24:20]
    reg_index_t rs1;       // Bits [19:15]
    funct3_t funct3;       // Bits [14:12]
    logic [3:0] imm4_1;    // Bits [11:8] (immediate bits 4:1)
    logic imm12;           // Bit [7] (immediate bit 12)
    opcode_t opcode;       // Bits [6:0]
} b_type_t;

// U-Type Instruction Encoding
typedef struct packed {
    imm20_t imm;           // Bits [31:12] (20-bit immediate)
    reg_index_t rd;        // Bits [11:7]
    opcode_t opcode;       // Bits [6:0]
} u_type_t;

// J-Type Instruction Encoding
typedef struct packed {
    logic imm20;           // Bit [31] (immediate bit 20)
    logic [9:0] imm10_1;   // Bits [30:21] (immediate bits 10:1)
    logic imm11;           // Bit [20] (immediate bit 11)
    logic [7:0] imm19_12;  // Bits [19:12] (immediate bits 19:12)
    reg_index_t rd;        // Bits [11:7]
    opcode_t opcode;       // Bits [6:0]
} j_type_t;

// Generic RV32i Instruction Encoding	
typedef union packed {
    r_type_t r_type;  // R-type instruction
    i_type_t i_type;  // I-type instruction
    s_type_t s_type;  // S-type instruction
    b_type_t b_type;  // B-type instruction
    u_type_t u_type;  // U-type instruction
    j_type_t j_type;  // J-type instruction
    instruction_t raw; // Raw 32-bit instruction, used to modify entire instruction
} rv32i_instruction_t;

// ENUM type used by debug_decode_opcode and debug_parse_instruction to pick appropriate instr type
typedef enum logic [2:0] {
    INSTR_R_TYPE = 3'd0,
    INSTR_I_TYPE = 3'd1,
    INSTR_S_TYPE = 3'd2,
    INSTR_B_TYPE = 3'd3,
    INSTR_U_TYPE = 3'd4,
    INSTR_J_TYPE = 3'd5,
    INSTR_UNKNOWN = 3'd6
} instr_type_t;

// Decoded instructions translated into this type, used to pick right instruction
// in execute stage
typedef enum logic [5:0] {
    R_ADD
    ,R_SUB
    ,R_AND
    ,R_OR
    ,R_XOR
    ,R_SLL
    ,R_SRL
    ,R_SRA
    ,R_SLT
    ,R_SLTU

    ,I_ADDI
    ,I_JALR
    ,I_SLLI
    ,I_SRLI
    ,I_SRAI
    ,I_SLTI
    ,I_XORI
    ,I_ANDI
    ,I_ORI
    ,I_SLTIU
    ,I_LB
    ,I_LH
    ,I_LW
    ,I_LBU
    ,I_LHU

    ,S_SB
    ,S_SH
    ,S_SW

    ,B_BEQ
    ,B_BNE
    ,B_BLT
    ,B_BGE
    ,B_BLTU
    ,B_BGEU

    ,U_LUI
    ,U_AUIPC

    ,J_JAL

    ,X_UNKNOWN
} instr_select_t;

// Used to distinguish between possible memory offsets when aligning halfword/byte read/writes 
typedef enum logic [31:0] {
    ZERO
    ,ONE
    ,TWO
    ,THREE
} mem_offset_t;

`endif
