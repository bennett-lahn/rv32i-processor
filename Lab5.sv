`ifndef _core_v
`define _core_v
`include "memory_io.sv"
`include "memory.sv"
`include "Lab1.sv"
`include "execute_func.sv"
`include "decode_func.sv"
`include "mem_func.sv"
`include "branch_func.sv"
`include "register_file.sv"

// TODO: Fix memory read/writes w/o hazards; need to stall for memory requests (reads and writes or just reads?)
// If there are two loads back to back, need some way to differentiate them

module core (
    input logic  clk
    ,input logic reset
    ,input logic [`word_address_size-1:0] reset_pc
    ,output memory_io_req   inst_mem_req
    ,input  memory_io_rsp   inst_mem_rsp
    ,output memory_io_req   data_mem_req
    ,input  memory_io_rsp   data_mem_rsp
);

    // Main program counter
    // Decides what instruction is read from memory, each pipeline stage has its own pc too
    word_t pc;
    // HIGH if PC was just reset, so fetch pc should not be offset by -4
    logic pc_was_reset;

    // High if pc must update to updated_pc_val because of branch/jump
    logic update_pc;
    // Value pc should be updated to when update_pc is HIGH
    word_t new_pc_val;

    // Pipeline registers
    fetch_pipe_t fetch_pipe;
    decode_pipe_t decode_pipe;
    execute_pipe_t execute_pipe;
    mem_pipe_t mem_pipe;

    // Input/output driving register file interaction
    reg_file_io_t register_io;

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

    // Register reads
    // Continuously update register read based on current instruction rs1/rs2
    // This means rs1/rs2 data logic variables ONLY VALID FOR EXECUTE and completely unknown before EXECUTE
    // Valid bit for instr is not checked since register values don't matter if instr is valid
    assign register_io.read_reg_addr_1 = update_rs1_addr(fetch_pipe.instr_data);
    assign register_io.read_reg_addr_2 = update_rs2_addr(fetch_pipe.instr_data);

    // rs1 data from register file
    reg_data_t rs1_data_from_reg;
    assign rs1_data_from_reg = register_io.read_data_1;
    
    // rs2 data from register file
    reg_data_t rs2_data_from_reg;
    assign rs2_data_from_reg = register_io.read_data_2;

    // Comparison signal for execute stage; true if instruction in execute stage is a load
    logic decode_pipe_is_load;
    assign decode_pipe_is_load = decode_pipe.instr_sel >= I_LB && decode_pipe.instr_sel <= I_LHU;

    // Comparison signal for decode stage; true if instruction in decode stage is a store
    logic decode_pipe_is_store;
    assign decode_pipe_is_store = decode_pipe.instr_sel >= S_SB && decode_pipe.instr_sel <= S_SW;

    // Comparison signal for mem stage; true if instruction in mem stage is a load
    logic execute_pipe_is_load;
    assign execute_pipe_is_load = execute_pipe.instr_sel >= I_LB && execute_pipe.instr_sel <= I_LHU;

    // Comparison signal for mem stage; true if instruction in mem stage is a store
    logic execute_pipe_is_store;
    assign execute_pipe_is_store = execute_pipe.instr_sel >= S_SB && execute_pipe.instr_sel <= S_SW;

    // Comparison signal for writeback stage; true if instruction in mem stage is a store
    logic mem_pipe_is_load;
    assign mem_pipe_is_load = mem_pipe.instr_sel >= I_LB && mem_pipe.instr_sel <= I_LHU;

    // Incremented registered value that stores the last tag valued used by a data memory request
    // Tags are used to differentiate between back-to-back memory accesses
    mem_tag_t mem_tag_val;

    // If HIGH, processor should stall; used for memory accesses
    logic stall_core;

    // Represents the current instruction being decoded in DECODE
    // Used for branch prediction, writing to next pipeline stage
    // (I assume combining a function call used in multiple places will (maybe) make synthesis more efficient)
    instr_select_t decoded_instr;
    assign decoded_instr = parse_instruction(fetch_pipe.instr_data);

    // True if branch misprediction occurred, PC must be overwritten, pipeline flushed of bad instr
    logic branch_mispredicted; // TODO: needs 3 states: MISPREDICT, PREDICT, NOT BRANCH
    // New PC if branch was mispredicted
    word_t pc_override;

    // True if corresponding processor stage needs to be flushed due to branching
    // flush_instr_mem indicates that the next instr from memory is invalid
    // flush_instr_mem_latched is used to execuute flush_instr_mem in the fetch stage, since instr can't be flushed before mem returns it
    logic flush_instr_mem, flush_instr_mem_latched, flush_fetch, flush_decode;

    // Result from executing instruction in execute stage
    reg_data_t alu_result;
    assign alu_result = execute_instr(decode_pipe.instr_data, decode_pipe.pc, decode_pipe.instr_sel, 
                                      register_io.read_data_1, register_io.read_data_2);

    // Main program counter sequential logic
    // Remember that main pc represents what is fetched in the NEXT clock cycle
    always_ff @(posedge clk) begin
        if (reset) begin
            pc <= reset_pc;
            pc_was_reset <= TRUE;
        end else if (stall_core) begin
            pc <= pc;
            pc_was_reset <= TRUE; // If core stalls, instr mem will catch up to pc; this ensures instr pc stays accurate
        end else if (update_pc) begin
            pc <= new_pc_val + 4; // new_pc_val is directly fed to mem in this case to avoid delay, so skip to next instr
            pc_was_reset <= FALSE;
        end else begin
            pc <= pc + 4;
            pc_was_reset <= FALSE;
        end
    end

    // Program counter logic
    // Update master program counter if jump/branch instruction triggers
    // Branch prediction: "backwards taken, fowards not taken"
    // Prefers updating pc to correct mispredict to predicting more branches as fetched instruction would be invalid
    always_comb begin
        if (branch_mispredicted) begin
            update_pc = TRUE;
            new_pc_val = pc_override;
        end else if (fetch_pipe.valid && is_branch(decoded_instr)) begin
            if (predict_branch_taken(fetch_pipe.instr_data.b_type)) begin
                update_pc = TRUE;
                new_pc_val = build_branch_pc(fetch_pipe.instr_data.b_type, fetch_pipe.pc);
            end else begin
                update_pc = FALSE;
                new_pc_val = REG_ZERO_VAL;
            end
        end else begin
            update_pc = FALSE;
            new_pc_val = REG_ZERO_VAL;
        end
    end

    // Branch misprediction (and jump flush) logic, operating in EXECUTE stage
    // If predict_branch_taken output does not match branch evaluation from ALU, flush pipeline and update PC
    always_comb begin
        if (decode_pipe.valid & is_branch(decode_pipe.instr_sel)) begin
            // Case 1: Predict branch taken (correct); only flush decode
            if (predict_branch_taken(decode_pipe.instr_data.b_type) && alu_result == REG_TRUE) begin 
                branch_mispredicted = FALSE;
                pc_override = REG_ZERO_VAL;
                flush_decode = TRUE;
                flush_fetch = FALSE;
                flush_instr_mem = FALSE;
            // Case 2: Predict branch taken (incorrect); flush fetch and next instr from memory
            end else if (predict_branch_taken(decode_pipe.instr_data.b_type) && alu_result != REG_TRUE) begin
                branch_mispredicted = TRUE;
                pc_override = build_branch_pc(decode_pipe.instr_data.b_type, decode_pipe.pc);
                flush_decode = FALSE;
                flush_fetch = TRUE;
                flush_instr_mem = TRUE;
            // Case 3: Predict branch not taken (incorrect); flush decode, fetch, and next instr from memory
            end else if (!predict_branch_taken(decode_pipe.instr_data.b_type) && alu_result == REG_TRUE) begin
                branch_mispredicted = TRUE;
                pc_override = build_branch_pc(decode_pipe.instr_data.b_type, decode_pipe.pc);
                flush_decode = TRUE;
                flush_fetch = TRUE;
                flush_instr_mem = TRUE;
            // Case 4: Predict branch not taken (correct); do not flush anything, as PC is not modified by predictor or branch    
            end else begin
                branch_mispredicted = FALSE;
                pc_override = REG_ZERO_VAL;
                flush_decode = FALSE;
                flush_fetch = FALSE;
                flush_instr_mem = FALSE;
            end
        end else if (decode_pipe.valid & is_jump(decode_pipe.instr_sel)) begin 
            branch_mispredicted = TRUE; // Misnomer because not a branch, but equivalent to Case 3 in effect
            pc_override = (decode_pipe.instr_sel == J_JAL) ? build_jal_pc(decode_pipe.instr_data.j_type, decode_pipe.pc) : 
                                                             build_jalr_pc(decode_pipe.instr_data.i_type, decode_pipe.pc, rs1_data_from_reg);
            flush_decode = TRUE;
            flush_fetch = TRUE;
            flush_instr_mem = TRUE;
        end else begin
            branch_mispredicted = FALSE;
            pc_override = REG_ZERO_VAL;
            flush_decode = FALSE;
            flush_fetch = FALSE;
            flush_instr_mem = FALSE;
        end
    end

    // Instruction memory request logic for fetch stage
    assign inst_mem_req.valid = (reset) ? FALSE : TRUE;
    assign inst_mem_req.addr = (update_pc) ? new_pc_val : pc;
    assign inst_mem_req.do_read  = 4'b1111;
    assign inst_mem_req.do_write = 4'b0000;

    // Pipelined memory request logic
    // Load and store for a type must be naturally aligned to the respective datatype
    // (i.e. the effective address is not divisible by the size of the access in bytes)
    always_comb begin
        if (execute_pipe_is_load & execute_pipe.valid) begin
            data_mem_req.valid = TRUE;
            data_mem_req.addr = execute_pipe.wb_data; // Calculated memory addr in EXECUTE
            data_mem_req.data = REG_ZERO_VAL;
            data_mem_req.do_read = create_byte_plane(execute_pipe.instr_sel, execute_pipe.wb_data);
            data_mem_req.do_write = 4'b0000;
            data_mem_req.user_tag = execute_pipe.user_tag;
        end else if (execute_pipe_is_store & execute_pipe.valid) begin
            // Check for data_mem_rsp.valid == 0 is required so request only exists while waiting for memory response
            // This ensures false requests are not generated that are read by the simulator as dupe writes to stdout
            data_mem_req.valid = TRUE;
            data_mem_req.addr = execute_pipe.wb_data;
            data_mem_req.data = write_shift_data_by_offset(execute_pipe.instr_sel, execute_pipe.wb_data, 
                                                           execute_pipe.rs2_data);
            data_mem_req.do_read = 4'b0000;
            data_mem_req.do_write = create_byte_plane(execute_pipe.instr_sel, execute_pipe.wb_data);  
            data_mem_req.user_tag = execute_pipe.user_tag;
        end else begin
            data_mem_req.valid = FALSE;
            data_mem_req.addr = REG_ZERO;
            data_mem_req.data = REG_ZERO_VAL;
            data_mem_req.do_read = 4'b0000;
            data_mem_req.do_write = 4'b0000;
            data_mem_req.user_tag = TAG_ZERO;
        end
    end

    // Processor stall control
    // Sets stall to HIGH if processor needs to stall for memory access
    always_comb begin
       // Stall if processor is waiting for valid mem response or if tag does not match tag of instr in mem stage
       if ((execute_pipe_is_load || execute_pipe_is_store) && 
           (!data_mem_rsp.valid || (data_mem_rsp.valid && data_mem_rsp.user_tag != execute_pipe.user_tag))) begin
           stall_core = TRUE;
       end else begin
           stall_core = FALSE;
       end
    end

    // Pipeline sequential logic
    // Each pipeline stage has a synchronized reset, pipeline registers between stages

    // Sequential logic for flush_instr_mem
    // Used to perform the flush when the instr comes into fetch, since it can't be flushed before memory returns it
    always_ff @(posedge clk) begin
        if (reset)
            flush_instr_mem_latched <= FALSE;
        else if (flush_instr_mem)
            flush_instr_mem_latched <= TRUE;
        else
            flush_instr_mem_latched <= FALSE;
    end

    // Fetch stage sequential logic
    always_ff @(posedge clk) begin
        if (reset) begin
            fetch_pipe.valid <= FALSE;
            fetch_pipe.instr_data <= REG_ZERO_VAL;
            fetch_pipe.pc <= REG_ZERO_VAL;
        end else begin
            if (inst_mem_rsp.valid) begin
                if (stall_core) begin
                    fetch_pipe <= fetch_pipe;
                end else begin
                    // If instr in decode is jump, next mem response after is invalid due to memory latency
                    if (flush_instr_mem_latched || flush_fetch)
                        fetch_pipe.valid <= FALSE;
                    else
                        fetch_pipe.valid <= TRUE;
                    fetch_pipe.instr_data <= inst_mem_rsp.data;
                end
            end else begin
                fetch_pipe.valid <= FALSE;
            end
            fetch_pipe.pc <= (pc_was_reset) ? pc : pc - 4; 
        end
    end

    // Decode stage sequential logic
    always_ff @(posedge clk) begin
        if (reset) begin
            decode_pipe.valid <= FALSE;
            decode_pipe.instr_data <= REG_ZERO_VAL;
            decode_pipe.pc <= REG_ZERO_VAL;
            decode_pipe.instr_sel <= X_UNKNOWN;
        end else begin
            if (stall_core)
                decode_pipe <= decode_pipe;
            else begin
                decode_pipe.valid <= (flush_decode) ? FALSE : fetch_pipe.valid;
                decode_pipe.instr_data <= fetch_pipe.instr_data;
                decode_pipe.pc <= fetch_pipe.pc;
                decode_pipe.instr_sel <= decoded_instr;
            end
        end
    end

    // Execute stage sequential logic
    // TODO: Review how register file is loading data for execute stage
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_tag_val <= TAG_ZERO;
            execute_pipe.valid <= FALSE;
            execute_pipe.instr_data <= REG_ZERO_VAL;
            execute_pipe.pc <= REG_ZERO_VAL;
            execute_pipe.instr_sel <= X_UNKNOWN;
            execute_pipe.rs1_data <= REG_ZERO_VAL;
            execute_pipe.rs2_data <= REG_ZERO_VAL;
            execute_pipe.user_tag <= TAG_ZERO;
            execute_pipe.wb_data <= REG_ZERO_VAL;
            execute_pipe.wb_en <= FALSE;
            execute_pipe.wb_addr <= REG_ZERO;
        end else if (decode_pipe.valid) begin
            if (stall_core)
                execute_pipe <= execute_pipe;
            else begin 
                mem_tag_val <= (decode_pipe_is_load || decode_pipe_is_store) ? mem_tag_val + 1 : mem_tag_val;
                execute_pipe.valid <= TRUE;
                execute_pipe.instr_data <= decode_pipe.instr_data;
                print_instruction(decode_pipe.pc, decode_pipe.instr_data);
                execute_pipe.pc <= decode_pipe.pc;
                execute_pipe.instr_sel <= decode_pipe.instr_sel;
                execute_pipe.rs1_data <= rs1_data_from_reg;
                execute_pipe.rs2_data <= rs2_data_from_reg;
                execute_pipe.user_tag <= mem_tag_val; // Only used if instr happens to be memory access
                execute_pipe.wb_data <= alu_result;
                execute_pipe.wb_addr <= decode_pipe.instr_data.r_type.rd; // All instruction types use the same rd location
                execute_pipe.wb_en <= (decode_pipe.instr_sel < S_SB || decode_pipe.instr_sel > B_BGEU) ? TRUE : FALSE; // If instr has return value
            end
        end else begin
            execute_pipe.valid <= FALSE;
        end
    end

    // Memory stage sequential logic
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_tag_val <= TAG_ZERO;
            mem_pipe.valid <= FALSE;
            mem_pipe.instr_data <= REG_ZERO_VAL;
            mem_pipe.pc <= REG_ZERO_VAL;
            mem_pipe.instr_sel <= X_UNKNOWN;
            mem_pipe.rs1_data <= REG_ZERO_VAL;
            mem_pipe.wb_data <= REG_ZERO_VAL;
            mem_pipe.wb_en <= FALSE;
            mem_pipe.wb_addr <= REG_ZERO;
        end else if (execute_pipe.valid) begin
            if (stall_core) begin
                mem_pipe <= mem_pipe;
                $display("Stalling, instr tag: %-0d, mem tag: %-0d, mem valid: %-0d", execute_pipe.user_tag, data_mem_rsp.user_tag, data_mem_rsp.valid);
            end else begin
                mem_pipe.valid <= TRUE;
                mem_pipe.instr_data <= execute_pipe.instr_data;
                mem_pipe.pc <= execute_pipe.pc;
                mem_pipe.instr_sel <= execute_pipe.instr_sel;
                mem_pipe.rs1_data <= execute_pipe.rs1_data;
                mem_pipe.wb_en <= execute_pipe.wb_en;
                mem_pipe.wb_addr <= execute_pipe.wb_addr;
                $display("Writing back %d to x%d", execute_pipe.wb_data, execute_pipe.wb_addr);
                if (execute_pipe_is_load) begin
                    mem_pipe.wb_data <= interpret_read_memory_rsp(execute_pipe.instr_sel, data_mem_rsp);
                end else begin
                    mem_pipe.wb_data <= execute_pipe.wb_data;
                end
            end       
        end else begin
            mem_pipe.valid <= FALSE;
        end
    end

    // No sequential logic needed after writeback stage

    // Writeback register file I/O logic

    assign register_io.write_reg_addr = mem_pipe.wb_addr;
    assign register_io.write_data = (mem_pipe_is_load) ? interpret_read_memory_rsp(mem_pipe.instr_sel, data_mem_rsp) : mem_pipe.wb_data;
    assign register_io.write_enable = (mem_pipe.valid && (mem_pipe.wb_en || mem_pipe_is_load)) ? TRUE : FALSE;
    // TODO: What to do if memory response isn't valid when mem_pipe_is_load is valid? Ans: have to stall somehow

endmodule

`endif