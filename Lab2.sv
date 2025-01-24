`ifndef _core_v
`define _core_v
`include "system.sv"
`include "base.sv"
`include "memory_io.sv"
`include "memory.sv"

module core(
    input logic  clk
    ,input logic reset
    ,input logic [`word_address_size-1:0] reset_pc
    ,output memory_io_req   instr_mem_req
    ,input  memory_io_rsp   instr_mem_rsp
    ,output memory_io_req   data_mem_req
    ,input  memory_io_rsp   data_mem_rsp
);

    typedef enum {
        stage_fetch
        ,stage_decode
        ,stage_execute
        ,stage_mem
        ,stage_writeback
    }   stage;

    stage current_stage;

    // Fetch stage
    // Retrives next instruction from memory
    // Valid bit ignored for now
    word pc;
    always_comb begin
        if (current_stage == stage_fetch) begin
        	instr_mem_req.addr = pc;
            instr_mem_req.do_read  = 4'b1111;
            instr_mem_req.valid = true;
    	end
    end

    // Program counter control
    always @(posedge clk) begin
       if (reset)
          pc <= reset_pc;

       if (current_stage == stage_writeback)
          pc <= pc + 4;
    end

    // Input/output driving register file interaction
    reg_file_io_t register_io;

    // Initialize register file, using register_io for in/out
    register_file registers (
        .clk
        ,.reset
        ,.read_reg_addr_1(register_io.read_reg_addr_1)
        ,.read_reg_addr_2(register_io.read_reg_addr_2)
        ,.write_reg_addr(register_io.write_reg_addr)
        ,.write_data(register_io.reg_write_data)
        ,.write_enable(register_io.reg_write_enable)
        ,.read_data_1(register_io.reg_read_data_1)
        ,.read_data_2(register_io.reg_read_data_2)
    );

    // Data for current instruction to be executed
    rv32i_instruction_t curr_instr_data; 

    // Specific instruction data corresponds to
    instr_select_t curr_instr_select; 

    // Decides which parts of instruction to use to load registers
    instr_type_t reg_load_type;

    // Copy of curr_instr_data used to fetch from registers
    rv32i_instruction_t reg_instr_data;
    always reg_instr_data.raw = instr_mem_rsp.data;

    // rs1 data from register file
    reg_data_t rs1_data;
    always rs1_data = register_io.read_data_1;
    
    // rs2 data from register file
    reg_data_t rs2_data;
    always rs2_data = register_io.read_data_2;

    // rd data calculated by execution stage
    reg_data_t rd_data;

    // Address for register to be written back
    reg_index_t rd_writeback_addr;

    // Registered rd data waiting for writeback
    reg_data_t rd_data_to_writeback;

    // if true, rd_data_to_writeback needs to be written to register file
    logic writeback_enable;

    // Decode: Decode instruction, fetch registers, if any

    // I think this logic is okay because this circuit updates the register addresses, which is
    // synchronously used by register file to update read_data, which does not change until after
    // execute, even if read_addr changes
    always_comb begin
        if (current_stage == stage_decode) begin
            reg_load_type = decode_opcode(reg_instr_data.r_type.opcode); // Opcode for instr data
            case (reg_load_type)
                INSTR_R_TYPE: begin
                    register_io.read_reg_addr_1 = reg_instr_data.r_type.rs1;
                    register_io.read_reg_addr_2 = reg_instr_data.r_type.rs2;
                end
                INSTR_I_TYPE: begin
                    register_io.read_reg_addr_1 = reg_instr_data.i_type.rs1;
                end
                // INSTR_S_TYPE: return decode_s_type(instr.s_type);
                // INSTR_B_TYPE: return decode_b_type(instr.b_type);
                // INSTR_U_TYPE: return decode_u_type(instr.u_type);
                // INSTR_J_TYPE: return decode_j_type(instr.j_type);
                default: begin
                    register_io.read_reg_addr_1 = REG_ZERO;
                    register_io.read_reg_addr_2 = REG_ZERO;
                end
            endcase
        end
    end

    // Execute: select and execute instruction
    // Note: In the future, rd_data will have to be stored in temp register to be written back later (for some instructions)
    always_comb begin
        if (current_stage == stage_execute) begin
            case (curr_instr_select)
                R_ADD:  rd_data = execute_add(rs1_data, rs2_data);
                R_SUB:  rd_data = execute_sub(rs1_data, rs2_data);
                R_AND:  rd_data = execute_and(rs1_data, rs2_data);
                R_OR:   rd_data = execute_or(rs1_data, rs2_data);
                R_XOR:  rd_data = execute_xor(rs1_data, rs2_data);
                R_SLL:  rd_data = execute_sll(rs1_data, rs2_data);
                R_SRL:  rd_data = execute_srl(rs1_data, rs2_data);
                R_SRA:  rd_data = execute_sra(rs1_data, rs2_data);
                R_SLT:  rd_data = execute_slt(rs1_data, rs2_data);
                R_SLTU: rd_data = execute_sltu(rs1_data, rs2_data);

                I_ADDI: rd_data = execute_addi(curr_instr_data.i_type, rs1_data);
                I_JALR: rd_data = execute_jalr(curr_instr_data.i_type, rs1_data);
                I_SLLI: rd_data = execute_slli(curr_instr_data.i_type, rs1_data);
                I_SRLI: rd_data = execute_srli(curr_instr_data.i_type, rs1_data);
                I_SRAI: rd_data = execute_srai(curr_instr_data.i_type, rs1_data);
                I_SLTI: rd_data = execute_slti(curr_instr_data.i_type, rs1_data);
                I_XORI: rd_data = execute_xori(curr_instr_data.i_type, rs1_data);
                I_ANDI: rd_data = execute_andi(curr_instr_data.i_type, rs1_data);
                I_ORI:  rd_data = execute_ori(curr_instr_data.i_type, rs1_data);
                I_SLTIU:rd_data = execute_sltiu(curr_instr_data.i_type, rs1_data);
                // I_LB:
                // I_LH:
                // I_LW:
                // I_LBU:
                // I_LHU:

                // S_SB:
                // S_SH:
                // S_SW:

                // B_BEQ:
                // B_BNE:
                // B_BLT:
                // B_BGE:
                // B_BLTU:
                // B_BGEU:

                // U_LUI:
                // U_AUIPC:

                // J_JAL:

                default: rd_data = execute_unknown();
            endcase
        end
    end

    // Write back: register write back
    // If executed instruction is r-type or non_load/jump i-type, immediately write back to register file during execute stage
    // Only always_comb block where register_io.write_enable is written to
    always_comb begin
        if (stage_writeback && writeback_enable) begin
            register_io.write_enable = 1'b1;
            register_io.write_reg_addr = rd_writeback_addr;
            register_io.write_data = rd_data_to_writeback;
        end else begin
            register_io.write_enable = 1'b0;
        end
    end

    // Control flow for stage change
    always @(posedge clk) begin
        if (reset) begin
            current_stage <= stage_fetch;
            curr_instr_data <= REG_ZERO_VAL;
            curr_instr_select <= X_UNKNOWN;
            rd_data_to_writeback <= REG_ZERO_VAL;
            rd_writeback_addr <= REG_ZERO;
            writeback_enable <= 1'b0
        end else begin
            case (current_stage)
                stage_fetch:
                    current_stage <= stage_decode;
                stage_decode:
                    current_stage <= stage_execute;
                    curr_instr_data <= instr_mem_rsp.data;
                    curr_instr_select <= parse_instruction(instr_mem_rsp.data);
                stage_execute:
                    current_stage <= stage_mem;
                    if (curr_instr_select < I_LB && curr_instr_select != J_ALR) begin
                        writeback_enable <= 1'b1;
                        rd_data_to_writeback <= rd_data;
                        rd_writeback_addr <= curr_instr_data.i_type.rd; // Instruction type doesn't matter
                    end else begin
                        writeback_enable <= 1'b0;
                    end
                stage_mem:
                    current_stage <= stage_writeback;
                stage_writeback:
                    current_stage <= stage_fetch;
                default: begin
                    $display("Should never get here");
                    current_stage <= stage_fetch;
                end
            endcase
        end
    end

    // Translates raw instruction into specific instruction type using opcode
    function instr_select_t parse_instruction(rv32i_instruction_t instr);
        instr_type_t instr_type;
        instr_type = decode_opcode(instr.raw[6:0]); // Opcode
        case (instr_type)
            INSTR_R_TYPE: return decode_r_type(instr.r_type);
            INSTR_I_TYPE: return decode_i_type(instr.i_type);
            // INSTR_S_TYPE: return decode_s_type(instr.s_type);
            // INSTR_B_TYPE: return decode_b_type(instr.b_type);
            // INSTR_U_TYPE: return decode_u_type(instr.u_type);
            // INSTR_J_TYPE: return decode_j_type(instr.j_type);
            default: execute_unknown();
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
            FUNCT3_ADD_SUB: (instr.funct7 == FUNCT7_ADD) ? return R_ADD : 
                            (instr.funct7 == FUNCT7_SUB) ? return R_SUB : return X_UNKNOWN;
            FUNCT3_AND:     return R_AND;
            FUNCT3_OR:      return R_OR;
            FUNCT3_XOR:     return R_XOR;
            FUNCT3_SLL:     return R_SLL;
            FUNCT3_SRL_SRA: (instr.funct7 == FUNCT7_SRL) ? return R_SRL : 
                            (instr.funct7 == FUNCT7_SRA) ? return R_SRA : return X_UNKNOWN;
            FUNCT3_SLT:     return R_SLT;
            FUNCT3_SLTU:    return R_SLTU;
            default:        return X_UNKNOWN; // Handle unknown instructions by doing nothing
        endcase
    endfunction

    // Decodes and executes appropriate I-type instruction given i_type_t input
    function instr_select_t decode_i_type(i_type_t instr);
        case (instr.funct3)
            FUNCT3_ADDI:     (instr.opcode == OPCODE_IMM) ? return R_ADDI : 
                             (instr.opcode == OPCODE_JALR) ? return I_JALR : return X_UNKNOWN;
            FUNCT3_SLLI:     (instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SLLI) ? I_SLLI : return X_UNKNOWN;
            FUNCT3_SRLI:     (instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SRLI) ? I_SRLI : 
                             (instr.opcode == OPCODE_IMM && instr.imm[11:5] == SHIFT_TYPE_SRAI) ? I_SRAI : return X_UNKNOWN;
            FUNCT3_SLTI:     (instr.opcode == OPCODE_IMM) ? return I_SLTI : return X_UNKNOWN;
            FUNCT3_XORI:     (instr.opcode == OPCODE_IMM) ? return I_XORI : return X_UNKNOWN;
            FUNCT3_ANDI:     return I_ANDI;
            FUNCT3_ORI:      return I_ORI;
            FUNCT3_SLTIU:    return I_SLTIU;
            default:         return X_UNKNOWN; // Handle unsupported instructions
        endcase
    endfunction

    function void write_reg(reg_index_t reg_addr, reg_data_t data_to_write);
    endfunction

    function reg_data_t execute_unknown();
        return 32'd0;
    endfunction

    function reg_data_t execute_add(reg_data_t rs1, reg_data_t rs2);
        reteurn rs1 + rs2;
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
        return rs1 >>> rs2;
    endfunction

    function reg_data_t execute_slt(reg_data_t rs1, reg_data_t rs2);
        return $signed(rs1) < $signed(rs2) ? 32'd1 : 32'd0;
    endfunction

    function reg_data_t execute_sltu(reg_data_t rs1, reg_data_t rs2);
        return rs1 < rs2 ? 32'd1 : 32'd0;
    endfunction

    function reg_data_t execute_addi(i_type_t instr, reg_data_t rs1);
        return rs1 + {20{instr.imm[11]}, instr.imm[11:0]}; // Sign-extended immediate value
    endfunction

    function reg_data_t execute_andi(i_type_t instr, reg_data_t rs1);
        return rs1 & {20{instr.imm[11]}, instr.imm[11:0]}; // Sign-extended immediate value
    endfunction

    function reg_data_t execute_ori(i_type_t instr, reg_data_t rs1);
        return rs1 | {20{instr.imm[11]}, instr.imm[11:0]}; // Sign-extended immediate value
    endfunction

    function reg_data_t execute_xori(i_type_t instr, reg_data_t rs1);
        return rs1 ^ {20{instr.imm[11]}, instr.imm[11:0]}; // Sign-extended immediate value
    endfunction

    function reg_data_t execute_slti(i_type_t instr, reg_data_t rs1);
        return ($signed(rs1) < $signed({20{instr.imm[11]}, instr.imm[11:0]})) ? 32'd1 : 32'd0;
    endfunction

    function reg_data_t execute_sltiu(i_type_t instr, reg_data_t rs1);
        return (rs1 < {20{instr.imm[11]}, instr.imm[11:0]}) ? 32'd1 : 32'd0;
    endfunction

    function reg_data_t execute_slli(i_type_t instr, reg_data_t rs1);
        return rs1 << instr.imm[4:0]; // [4:0] = shamt
    endfunction

    function reg_data_t execute_srli(i_type_t instr, reg_data_t rs1);
        return rs1 >> instr.imm[4:0]; // [4:0] = shamt
    endfunction

    function reg_data_t execute_srai(i_type_t instr, reg_data_t rs1);
        return rs1 >>> instr.imm[4:0]; // [4:0] shamt
    endfunction

    // function void execute_lb(i_type_t instr);
    // endfunction

    // function void execute_lh(i_type_t instr);
    // endfunction

    // function void execute_lw(i_type_t instr);
    // endfunction

    // function void execute_lbu(i_type_t instr);
    // endfunction

    // function void execute_lhu(i_type_t instr);
    // endfunction

    // function void execute_jalr(i_type_t instr, reg_file_io_t register_io);
    // endfunction

    // function void execute_sb(s_type_t instr);
    // endfunction

    // function void execute_sh(s_type_t instr);
    // endfunction

    // function void execute_sw(s_type_t instr);
    // endfunction

    // function void execute_beq(b_type_t instr);
    // endfunction

    // function void execute_bne(b_type_t instr);
    // endfunction

    // function void execute_blt(b_type_t instr);
    // endfunction

    // function void execute_bge(b_type_t instr);
    // endfunction

    // function void execute_bltu(b_type_t instr);
    // endfunction

    // function void execute_bgeu(b_type_t instr);
    // endfunction

    // function void execute_lui(u_type_t instr);
    // endfunction

    // function void execute_auipc(u_type_t instr);
    // endfunction

    // function void execute_jal(j_type_t instr);
    // endfunction

endmodule : core

// Values for x0 register
localparam logic [31:0] REG_ZERO_VAL = 32'd0;
localparam reg_index_t REG_ZERO = 5'd0;

// 32-bit type for register data operations
localparam logic [31:0] reg_data_t;

// Struct for easier manipulation of register I/O
typedef struct packed {
    reg_index_t read_reg_addr_1;
    reg_index_t read_reg_addr_2;
    reg_index_t write_reg_addr;
    reg_data_t write_data;
    logic write_enable;
    reg_data_t read_data_1;
    reg_data_t read_data_2;
} reg_file_io_t

// Module controlling register file containing 32 registers, including 0 reg
// Read address inputs select the register to be read from (0-31)
// read_reg_addr_1 only used for rs1
// read_reg_addr_2 only used for rs2
// write_reg_addr selects register to be written to by write_data if write_enable is true
module register_file (
    input logic clk
    ,input logic reset
    ,input reg_index_t read_reg_addr_1
    ,input reg_index_t read_reg_addr_2
    ,input reg_index_t write_reg_addr
    ,input reg_data_t write_data
    ,input logic write_enable
    ,output reg_data_t read_data_1
    ,output reg_data_t read_data_2
);
    
    // Register array: 32 registers of 32 bits each
    logic [31:0] reg_file [31:0];

    // Synchronous read & write
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                reg_file[i] <= REG_ZERO_VAL;
            end
        end else begin
            if (write_enable && write_reg_addr != REG_ZERO)
                reg_file[write_reg_addr] <= write_data; // Write
            // Read
            read_data_1 <= (read_reg_addr_1 == REG_ZERO) ? REG_ZERO_VAL : reg_file[read_reg_addr_1];
            read_data_2 <= (read_reg_addr_2 == REG_ZERO) ? REG_ZERO_VAL : reg_filel[read_reg_addr_2];
        
        end
    end

endmodule : register_file

`endif