`ifndef _core_v
`define _core_v
`include "memory_io.sv"
`include "memory.sv"
`include "Lab1.sv"
`include "execute_func.sv"
`include "decode_func.sv"
`include "mem_func.sv"
`include "register_file.sv"

// TODO: Replace uses of reg_data_t that aren't used in registers to word
// TODO: Add _r prefix to registered values

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

    // High is pc must update to updated_pc_val because of branch/jump
    logic update_pc;
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
    // This means rs1/rs2 data from *these variables* ONLY VALID FOR EXECUTE STAGE
    assign register_io.read_reg_addr_1 = update_rs1_addr(decode_pipe.instr_data);
    assign register_io.read_reg_addr_2 = update_rs2_addr(decode_pipe.instr_data);

    // Comparison signal for mem stage; true if instruction in mem stage is a load
    logic execute_pipe_is_load;
    assign execute_pipe_is_load = execute_pipe.instr_sel >= I_LB && execute_pipe.instr_sel <= I_LHU;

    // Comparison signal for mem stage; true if instruction in mem stage is a store
    logic execute_pipe_is_store;
    assign execute_pipe_is_store = execute_pipe.instr_sel >= S_SB && execute_pipe.instr_sel <= S_SW;

    // Comparison signal for writeback stage; true if instruction in mem stage is a store
    logic mem_pipe_is_load;
    assign mem_pipe_is_load = mem_pipe.instr_sel >= I_LB && mem_pipe.instr_sel <= I_LHU;

    // Represents the current instruction being decoded in DECODE
    // Used for branch prediction, writing to next pipeline stage
    // (I assume combining a function call used in multiple places will (maybe) make synthesis more efficient)
    instr_select_t decoded_instr;
    assign decoded_instr = parse_instruction(fetch_pipe.instr_data);

    // True if branch misprediction occurred, PC must be overwritten, pipeline flushed of bad instr
    logic branch_mispredicted; // TODO: needs 3 states: MISPREDICT, PREDICT, NOT BRANCH
    // New PC if branch was mispredicted
    logic pc_override;

    // True if corresponding processor stage needs to be flushed due to branching
    // flush_instr_mem indicates that the next instr from memory is invalid
    logic flush_instr_mem, flush_fetch, flush_decode;

    // Result from executing instruction in execute stage
    logic alu_result;
    assign alu_result = execute_instr(decode_pipe.instr_data, decode_pipe.pc, decode_pipe.instr_sel, 
                                      register_io.read_data_1, register_io.read_data_2);

    // Program counter control
    // pc represents the master pc, not the pc for each pipeline stage
    // TODO: Basic branch prediction, processor decides whether to flush previous pipes only if wrong pc on branch
    // LAB 5 NOTE: NEEDS RS1 VALUE FOR JALR
    // LAB 5 NOTE: Redo use of execute_instr (reuse/store signal some other way)
    always @(posedge clk) begin
       if (reset)
          pc <= reset_pc;
       if (current_stage == stage_writeback) begin
           if (instr_sel > S_SW && instr_sel < U_LUI) begin
                if (data_to_wb == 32'd1) begin
                    pc <= build_branch_pc(curr_instr_data.b_type, pc);
                end else begin
                    pc <= pc + 4;
                end
           end else if (instr_sel == J_JAL) begin
                pc <= build_jal_pc(curr_instr_data.j_type, pc);
           end else if (instr_sel == I_JALR) begin
                pc <= build_jalr_pc(curr_instr_data.i_type, pc, rs1_data_r);
           end else begin
                pc <= pc + 4;
           end
       end 
    end

    // Main program counter sequential logic
    // Remember that master PC represents what is fetched in the NEXT clock cycle
    always_ff @(posedge clk) begin
        if (reset)
            pc <= reset_pc;
        else if (update_pc) 
            pc <= new_pc_val + 4; // new_pc_val is directly fed to mem in this case to avoid delay, so skip to next instr
        else
            pc <= pc + 4;
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
                new_pc_val = build_branch_pc(fetch_pipe.instr_data.b_type, pc);
            end else begin
                update_pc = FALSE;
                new_pc_val = REG_ZERO_VAL;
            end
        end else if (fetch_pipe.valid && is_jump(decoded_instr)) begin
            update_pc = TRUE;
            new_pc_val = (decoded_instr == J_JAL) ? build_jal_pc(fetch_pipe.instr_data.j_type, fetch_pipe.pc) : 
                                                    build_jalr_pc(fetch_pipe.instr_data.j_type, fetch_pipe.pc);
        end else begin
            update_pc = FALSE;
            new_pc_val = REG_ZERO_VAL;
        end
    end

    // Branch misprediction logic
    // If predict_branch_taken output does not match branch evaluation from ALU, flush pipeline and update PC
    // TODO: Set proper invalid bits
    always_comb begin
        if (is_branch(decode_pipe.instr_sel) && (predict_branch_taken(decode_pipe.instr_data.b_type) != alu_result)) begin
            branch_mispredicted = TRUE;
            pc_override = build_branch_pc(decode_pipe.instr_data.b_type, decode_pipe.pc);
        end else begin
            branch_mispredicted = FALSE;
            pc_override = REG_ZERO_VAL;
        end
    end

    // Instruction memory request logic for fetch stage
    assign instr_mem_req.valid = 1;
    assign instr_mem_req.addr = ()
    assign instr_mem_req.do_read  = 4'b1111;
    assign instr_mem_req.do_write = 4'b0000;

    // Pipelined memory request logic
    // Load and store for a type must be naturally aligned to the respective datatype
    // (i.e. the effective address is not divisible by the size of the access in bytes)
    always_comb begin
        if (execute_pipe_is_load & execute_pipe.valid) begin
            data_mem_req.valid = 1;
            data_mem_req.addr = execute_pipe.wb_data; // Calculated memory addr in EXECUTE
            data_mem_req.data = REG_ZERO_VAL;
            data_mem_req.do_read = create_byte_plane(execute_pipe.instr_sel, execute_pipe.wb_data);
            data_mem_req.do_write = 4'b0000;   
        end else if (execute_pipe_is_store & execute_pipe.valid) begin
            // Check for data_mem_rsp.valid == 0 is required so request only exists while waiting for memory response
            // This ensures false requests are not generated that are read by the simulator as dupe writes to stdout
            data_mem_req.valid = 1;
            data_mem_req.addr = execute_pipe.wb_data;
            data_mem_req.data = write_shift_data_by_offset(execute_pipe.instr_sel, execute_pipe.wb_data, 
                                                           execute_pipe.rs2_data);
            data_mem_req.do_read = 4'b0000;
            data_mem_req.do_write = create_byte_plane(execute_pipe.instr_sel, execute_pipe.wb_data);  
        end else begin
            data_mem_req.valid = 0;
            data_mem_req.addr = 0;
            data_mem_req.data = REG_ZERO_VAL;
            data_mem_req.do_read = 4'b0000;
            data_mem_req.do_write = 4'b0000;
        end
    end

    // Pipeline sequential logic
    // Each pipeline stage has a synchronized reset, pipeline registers between stages

    // Fetch stage sequential logic
    always_ff @(posedge clk) begin
        if (reset) begin
            fetch_pipe <= FETCH_RESET;
        end else begin
            if (instr_mem_rsp.valid) begin
                // If decoded instr is jump, next mem response after is invalid due to memory latency
                if (branch_mispredicted || decoded_instr == J_JAL || decoded_instr == I_JALR) // TODO: IS THIS CORRECT
                    fetch_pipe.valid <= FALSE;
                else
                    fetch_pipe.valid <= TRUE;
                fetch_pipe.instr_data <= instr_mem_rsp.data;
            end else begin
                fetch_pipe.valid <= FALSE;
            end
            fetch_pipe.pc <= pc - 4; // TODO: Update for speculative branch mispred, where this isn't always true
        end
    end

    // Decode stage sequential logic
    always_ff @(posedge clk) begin
        if (reset) begin
            decode_pipe <= DECODE_RESET;
        end else begin
            decode_pipe.valid <= fetch_pipe.valid;
            decode_pipe.instr_data <= fetch_pipe.instr_data;
            decode_pipe.pc <= fetch_pipe.pc;
            decode_pipe.instr_sel <= decoded_instr;
        end
    end

    // Execute stage sequential logic
    // TODO: Review how register file is loading data for execute stage
    always_ff @(posedge clk) begin
        if (reset) begin
            execute_pipe <= EXECUTE_RESET;
        end else begin
            if (decode_pipe.valid) begin
                execute_pipe.valid <= TRUE;
                execute_pipe.instr_data <= decode_pipe.instr_data;
                execute_pipe.pc <= decode_pipe.pc;
                execute_pipe.instr_sel <= decode_pipe.instr_sel;
                execute_pipe.rs1_data <= rs1_data;
                execute_pipe.rs2_data <= rs2_data;
                execute_pipe.wb_data <= alu_result;
                execute_pipe.wb_en <= (instr_sel < S_SB || instr_sel > B_BGEU) ? 1 : 0; // If instr has return value
                end
            end else begin
                execute_pipe.valid <= FALSE;
            end
        end
    end

    // Memory stage sequential logic
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_pipe <= MEM_RESET;
        end else if (execute_pipe.valid) begin
            mem_pipe.valid <= TRUE;
            mem_pipe.instr_data <= execute_pipe.instr_data;
            mem_pipe.pc <= execute_pipe.instr_data;
            mem_pipe.instr_sel <= execute_pipe.instr_sel;
            mem_pipe.rs1_data <= execute_pipe.rs1_data;
            mem_pipe.wb_data <= execute_pipe.wb_data;
            mem_pipe.wb_en <= execute_pipe.wb_en;
            mem_pipe.wb_addr <= execute_pipe.wb_addr;            
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