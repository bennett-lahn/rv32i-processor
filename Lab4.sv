`ifndef _core_v
`define _core_v
`include "base.sv"
`include "memory_io.sv"
`include "memory.sv"
`include "Lab1.sv"
`include "execute_func.sv"
`include "decode_func.sv"
`include "mem_func.sv"
`include "register_file.sv"

// TODO: Replace uses of reg_data_t that aren't used in registers to word

// MEGA TODO: Test JALR seperately / finish JALR test

module core (
    input logic  clk
    ,input logic reset
    ,input logic [`word_address_size-1:0] reset_pc
    ,output memory_io_req   instr_mem_req
    ,input  memory_io_rsp   instr_mem_rsp
    ,output memory_io_req   data_mem_req
    ,input  memory_io_rsp   data_mem_rsp
);

    // Program counter
    word_t pc;

    // Enum for processor cycle stages
    typedef enum {
        stage_fetch
        ,stage_decode
        ,stage_execute
        ,stage_mem
        ,stage_writeback
    }   stage;

    stage current_stage;

    // Data for current instruction to be executed
    rv32i_instruction_t curr_instr_data; 

    // Specific instruction data corresponds to
    instr_select_t curr_instr_select; 

    // Copy of curr_instr_data used to fetch from registers
    rv32i_instruction_t reg_instr_data;
    assign reg_instr_data.raw = instr_mem_rsp.data;

    // Input/output driving register file interaction
    reg_file_io_t register_io;

    // rs1 data from register file
    reg_data_t rs1_data;
    // Registered rs1 value used by JALR instructions
    reg_data_t rs1_data_r;
    assign rs1_data = register_io.read_data_1;
    
    // rs2 data from register file
    reg_data_t rs2_data;
    assign rs2_data = register_io.read_data_2;

    // Address for register to be written back, stored for writeback
    reg_index_t rd_writeback_addr;

    // Registered rd data waiting for writeback
    reg_data_t rd_data_to_writeback;

    // if true, rd_data_to_writeback needs to be written to register file
    logic writeback_enable;

    // Register used for store instructions
    // Stores rs2 value to be sent to memory
    reg_data_t store_data_reg;

    // Continuously update register read based on current instruction rs1/rs2
    // This means rs1/rs2 addresses ONLY VALID FOR EXECUTE STAGE
    assign register_io.read_reg_addr_1 = update_rs1_addr(reg_instr_data);
    assign register_io.read_reg_addr_2 = update_rs2_addr(reg_instr_data);
    assign register_io.write_reg_addr = rd_writeback_addr;
    assign register_io.write_data = rd_data_to_writeback;
    assign register_io.write_enable = check_writeback(current_stage, writeback_enable);

    // Initialize register file, using register_io for in/out
    register_file_m registers (
        .clk
        ,.reset
        ,.read_reg_addr_1(register_io.read_reg_addr_1)
        ,.read_reg_addr_2(register_io.read_reg_addr_2)
        ,.write_reg_addr(register_io.write_reg_addr)
        ,.write_data(register_io.write_data)
        ,.write_enable(register_io.write_enable)
        ,.read_data_1(register_io.read_data_1)
        ,.read_data_2(register_io.read_data_2)
    );

    // Program counter control
    // LAB 5 NOTE: NEEDS RS1 VALUE FOR JALR
    // LAB 5 NOTE: Redo use of execute_instr (reuse/store signal some other way)
    always @(posedge clk) begin
       if (reset)
          pc <= reset_pc;
       if (current_stage == stage_writeback) begin
           if (curr_instr_select > S_SW && curr_instr_select < U_LUI) begin
                if (rd_data_to_writeback == 32'd1) begin
                    $display("Take branch, result %-0d", rd_data_to_writeback);
                    $display("New PC %-0h", build_branch_pc(curr_instr_data.b_type, pc));
                    pc <= build_branch_pc(curr_instr_data.b_type, pc);
                end else begin
                    $display("Do not take branch, result %-0d", rd_data_to_writeback);
                    pc <= pc + 4;
                end
           end else if (curr_instr_select == J_JAL) begin
                $display("Doing JAL things.");
                pc <= build_jal_pc(curr_instr_data.j_type, pc);
           end else if (curr_instr_select == I_JALR) begin
                $display("Doing JALR things.");
               pc <= build_jalr_pc(curr_instr_data.i_type, pc, rs1_data_r);
           end else begin
               pc <= pc + 4;
           end
       end
          
    end

    // Instruction memory request logic for fetch stage
    // Instruction memory response ONLY VALID FOR DECODE STAGE
    always_comb begin
        if (current_stage == stage_fetch) begin
            instr_mem_req.valid = 1;
            instr_mem_req.addr = pc;
            instr_mem_req.do_read  = 4'b1111;
            instr_mem_req.do_write = 4'b0000;
        end else begin
            instr_mem_req.valid = 0;
            instr_mem_req.addr = pc;
            instr_mem_req.do_read  = 4'b0000;
            instr_mem_req.do_write = 4'b0000;
        end
    end

    // Data memory request logic for execute, mem stage
    // Load and store for a type must be naturally aligned to the respective datatype
    // (i.e. the effective address is not divisible by the size of the access in bytes)
    always_comb begin
        if (current_stage == stage_mem && curr_instr_select >= I_LB && curr_instr_select <= I_LHU) begin
            data_mem_req.valid = 1;
            data_mem_req.addr = rd_data_to_writeback; // Calculated memory addr in EXECUTE
            data_mem_req.data = REG_ZERO_VAL;
            data_mem_req.do_read = create_byte_plane(curr_instr_select, rd_data_to_writeback);
            data_mem_req.do_write = 4'b0000;
        end else if (current_stage == stage_mem && curr_instr_select >= S_SB && curr_instr_select <= S_SW) begin
            data_mem_req.valid = 1;
            data_mem_req.addr = rd_data_to_writeback;
            data_mem_req.data = write_shift_data_by_offset(curr_instr_select, rd_data_to_writeback, store_data_reg);
            data_mem_req.do_read = 4'b0000;
            data_mem_req.do_write = create_byte_plane(curr_instr_select, rd_data_to_writeback);
        end else begin
            data_mem_req.valid = 0;
            data_mem_req.addr = 0;
            data_mem_req.data = REG_ZERO_VAL;
            data_mem_req.do_read = 4'b0000;
            data_mem_req.do_write = 4'b0000;
        end
    end

    // Processor control flow for stage change, data path
    always @(posedge clk) begin
        if (reset) begin
            current_stage <= stage_fetch;
            curr_instr_data <= REG_ZERO_VAL;
            curr_instr_select <= X_UNKNOWN;
            rd_data_to_writeback <= REG_ZERO_VAL;
            rd_writeback_addr <= REG_ZERO;
            writeback_enable <= 1'b0;
            store_data_reg <= REG_ZERO_VAL;
        end else begin
            case (current_stage)
                stage_fetch: begin
                    // $display("[FETCH] Fetching instruction at PC: %h", pc);
                    if (instr_mem_rsp.valid) begin
                        // $display("[STAGE] Transitioning to DECODE");
                        current_stage <= stage_decode;
                        curr_instr_data <= instr_mem_rsp.data;
                    end else begin
                        current_stage <= stage_fetch;
                    end
                end
                stage_decode: begin
                    // $display("[DECODE] Decoding instruction, should be:");
                    print_instruction(pc, curr_instr_data.raw);
                    current_stage <= stage_execute;
                    curr_instr_select <= parse_instruction(instr_mem_rsp.data);
                    // $display("[STAGE] Transitioning to EXECUTE");
                end
                stage_execute: begin
                    current_stage <= stage_mem;

                    // $display("[EXECUTE] Executing instruction %s", curr_instr_select.name());
                    // $display("[EXECUTE] If valid: rs1 val %d, rs2 val %d, imm val %d", curr_instr_data.r_type.rs1, curr_instr_data.r_type.rs2, $signed(curr_instr_data.i_type.imm));

                    // Only writeback for appropriate instructions
                    writeback_enable <= (curr_instr_select < S_SB || curr_instr_select > B_BGEU) ? 1 : 0;
                    rd_data_to_writeback <= execute_instr(curr_instr_data, pc, curr_instr_select, rs1_data, rs2_data);
                    rd_writeback_addr <= curr_instr_data.r_type.rd; // All types use same rd bit location in instr

                    // If store instruction, store data of rs2 for memory write
                    if (curr_instr_select >= S_SB && curr_instr_select <= S_SW)
                        store_data_reg <= rs2_data;
                    if (curr_instr_select == I_JALR)
                        rs1_data_r <= rs1_data; // If JALR instruction, store rs1_data for pc update
                    // $display("[STAGE] Transitioning to MEM");
                end
                stage_mem: begin
                    // If instruction is load, we need to update rd_data_to_writeback using data read from memory
                    if (curr_instr_select < I_LB || curr_instr_select > S_SW)
                        // $display("[EXECUTE] Got result %d to return to reg %d", $signed(rd_data_to_writeback), rd_writeback_addr);

                    // Handle memory read or write, otherwise continue to writeback
                    if (curr_instr_select >= I_LB && curr_instr_select <= I_LHU) begin // If reading
                        if (data_mem_rsp.valid == 1) begin
                            // $display("[MEM] Got successful read from address 0x%h", data_mem_rsp.addr);
                            // $display("[STAGE] Transitioning to WRITEBACK");
                            current_stage <= stage_writeback;
                            rd_data_to_writeback <= interpret_read_memory_rsp(curr_instr_select, data_mem_rsp);
                        end else begin
                            current_stage <= stage_mem;
                        end
                    end else if (curr_instr_select >= S_SB && curr_instr_select <= S_SW) begin // If writing
                        if (data_mem_rsp.valid == 1) begin
                            // $display("[MEM] Successfully wrote to address 0x%h", data_mem_rsp.addr);
                            current_stage <= stage_writeback;
                        end else begin
                            current_stage <= stage_mem;
                            // $display("[MEM] Waiting on write to 0x%h, byte plane %b", data_mem_req.addr, data_mem_req.do_write);
                        end
                    end else begin
                        current_stage <= stage_writeback;
                        // $display("[STAGE] Transitioning to WRITEBACK");
                    end
                end
                stage_writeback: begin
                    current_stage <= stage_fetch;
                    // $display("[WRITEBACK] State: Writeback to reg %d with reg value %d, writeback_enable: %d", rd_writeback_addr, $signed(rd_data_to_writeback), writeback_enable);
                    // $display("[STAGE] Transitiong to FETCH");
                end
                default: begin
                    $display("Should never get here");
                    current_stage <= stage_fetch;
                end
            endcase
        end
    end

    // Returns 1 if stage is writeback and writeback enabled by execute stage, otherwise 0
    function logic check_writeback(stage current_stage, logic writeback_enable);
        if (current_stage == stage_writeback && writeback_enable) begin
            return 1;
        end else begin
            return 0;
        end
    endfunction

    // Returns new program counter value by adding sign-extended j-type immediate to current program counter value
    function word_t build_jal_pc(j_type_t instr, word_t pc);
        word_t offset, sum;
        offset = {{11{instr.imm20}}, instr.imm20, instr.imm19_12, instr.imm11, instr.imm10_1, 1'b0}; // Add 0 lowest bit to align address
        sum = pc + $signed(offset);
        return {sum[31:1], 1'b0}; // Set lowest bit to 0 to align address
    endfunction

    // Returns new program counter value by adding rs1 value + sign-extended immediate
    // Problem: rs1_data is only valid during execute stage
    function word_t build_jalr_pc(i_type_t instr, word_t pc, reg_data_t rs1_data);
        word_t sign_extended_imm, sum;
        sign_extended_imm = {{20{instr.imm[11]}}, instr.imm};
        sum = (rs1_data + $signed(sign_extended_imm)) & $signed(-2); // Does this correctly force the LSB to 0?
        $display("Immediate: %-0h Sum: %-0h RS1: %-0h", sign_extended_imm, sum, rs1_data);
        return sum;
    endfunction

    // Returns new program counter value by adding branch offset to current program counter value
    function word_t build_branch_pc(b_type_t instr, word_t pc);
        word_t sign_extended_imm;
        sign_extended_imm = {{19{instr.imm12}}, instr.imm12, instr.imm11, instr.imm10_5, instr.imm4_1, 1'b0}; // Add 0 lowest bit to align address
        $display("Immediate: %-0h", sign_extended_imm);
        return pc + $signed(sign_extended_imm);
    endfunction
    
endmodule

`endif