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
`include "sys_func.sv"

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

// Represents the current instruction being decoded in DECODE
// Used for branch prediction, writing to next pipeline stage
// (I assume combining a function call used in multiple places will (maybe) make synthesis more efficient)
instr_select_t decoded_instr;
assign decoded_instr = parse_instruction(fetch_pipe.instr_data);

// True if branch misprediction occurred, PC must be overwritten, pipeline flushed of bad instr
logic branch_mispredicted;
// New PC if branch was mispredicted
word_t pc_override;

// True if corresponding processor stage needs to be flushed due to branching
// flush_instr_mem indicates that the next instr from memory is invalid
// flush_instr_mem_latched is used to execuute flush_instr_mem in the fetch stage, since instr can't be flushed before mem returns it
logic flush_instr_mem, flush_instr_mem_latched, flush_fetch, flush_decode;

// Used by forwarding unit to select which forwarding networks the instr in decode should use in the execute stage
fwd_src_t rs1_fwd_network;
fwd_src_t rs2_fwd_network;

// Opcode value of current instr being decoded (in decode stage)
opcode_t decode_opcode 
assign decode_opcode = fetch_pipe.instr_data.r_type.opcode;

// rs1 and rs2 index values of current instr being decoded (in decode stage)
reg_index_t decode_rs1_index;
reg_index_t decode_rs2_index;
assign decode_rs1_index = fetch_pipe.instr_data.r_type.rs1;
assign decode_rs2_index = fetch_pipe.instr_data.r_type.rs2;

// rd index values of current instructions in execute and memory stages
reg_index_t execute_rd_index;
reg_index_t mem_rd_index;
assign execute_rd_index = decode_pipe.instr_data.r_type.rd;
assign mem_rd_index = execute_pipe.instr_data.r_type.rd



// Result from executing instruction in execute stage
reg_data_t alu_result;
assign alu_result = execute_instr(decode_pipe.instr_data, decode_pipe.pc, decode_pipe.instr_sel, 
                                  rs1_data_from_reg, rs2_data_from_reg);

// Main program counter sequential logic
// Remember that main pc represents what is fetched in the NEXT clock cycle
always_ff @(posedge clk) begin
    if (reset) begin
        pc <= reset_pc;
        pc_was_reset <= TRUE;
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
    end else if (fetch_pipe.valid && is_branch(fetch_pipe.instr_data.r_type.opcode)) begin
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
    if (decode_pipe.valid & is_branch(decode_pipe.instr_data.r_type.opcode)) begin
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
            flush_instr_mem = FALSE;
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
        flush_instr_mem = FALSE;
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
// Functions used to interact with memory detailed in mem_func.sv
always_comb begin
    if (execute_pipe.valid & is_load(execute_pipe.instr_sel)) begin
        data_mem_req.valid = TRUE;
        data_mem_req.addr = execute_pipe.wb_data; // Calculated memory addr in EXECUTE
        data_mem_req.data = REG_ZERO_VAL;
        data_mem_req.do_read = create_byte_plane(execute_pipe.instr_sel, execute_pipe.wb_data);
        data_mem_req.do_write = 4'b0000;
        data_mem_req.user_tag = execute_pipe.user_tag;
    end else if (execute_pipe.valid & is_store(execute_pipe.instr_sel)) begin
        data_mem_req.valid = TRUE;
        data_mem_req.addr = execute_pipe.wb_data;
        data_mem_req.data = write_shift_data_by_offset(execute_pipe.instr_sel, execute_pipe.wb_data, execute_pipe.rs2_data);
        data_mem_req.do_read = 4'b0000;
        data_mem_req.do_write = create_byte_plane(execute_pipe.instr_sel, execute_pipe.wb_data);  
        data_mem_req.user_tag = execute_pipe.user_tag;
    end else begin
        data_mem_req.valid = FALSE;
        data_mem_req.addr = REG_ZERO_VAL;
        data_mem_req.data = REG_ZERO_VAL;
        data_mem_req.do_read = 4'b0000;
        data_mem_req.do_write = 4'b0000;
        data_mem_req.user_tag = TAG_ZERO;
    end
end

// Register Forwarding Unit
// Compares instr in decode to instrs downstream, looking for data hazards
// Updates pipeline data to activate the necessary forwarding channels in execute
// Move down pipe, checking if instr update dependent registers, priority for recently executed instr
always_comb begin
    // rs1, opcode in same place for all instr types
    if (uses_rs1(fetch_opcode) & ~(is_load(fetch_opcode) | is_store(fetch_opcode))) begin
        
    end else begin
        rs1_fwd_network = FWD_NONE;
    end
    // rs2, opcode in same place for all instr types
    if (uses_rs1(fetch_opcode) & ~(is_load(fetch_opcode) | is_store(fetch_opcode))) begin
        
    end else begin
        rs2_fwd_network = FWD_NONE;
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
            // If instr in decode is jump, next mem response after is invalid due to memory latency
            if (flush_instr_mem_latched || flush_fetch)
                fetch_pipe.valid <= FALSE;
            else
                fetch_pipe.valid <= TRUE;
            fetch_pipe.instr_data <= inst_mem_rsp.data;
        end else begin
            fetch_pipe.valid <= FALSE;
        end
        fetch_pipe.pc <= inst_mem_rsp.addr; 
    end
end

// Decode stage sequential logic
always_ff @(posedge clk) begin
    if (reset) begin
        decode_pipe.valid <= FALSE;
        decode_pipe.instr_data <= REG_ZERO_VAL;
        decode_pipe.pc <= REG_ZERO_VAL;
        decode_pipe.instr_sel <= X_UNKNOWN;
        decode_pipe.fwd_rs1 <= FWD_NONE;
        decode_pipe.fwd_rs2 <= FWD_NONE;
    end else begin
        decode_pipe.valid <= (flush_decode) ? FALSE : fetch_pipe.valid;
        decode_pipe.instr_data <= fetch_pipe.instr_data;
        decode_pipe.pc <= fetch_pipe.pc;
        decode_pipe.instr_sel <= decoded_instr;
    end
end

// Execute stage sequential logic
// TODO: Review how register file is loading data for execute stage
always_ff @(posedge clk) begin
    if (reset) begin
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
        execute_pipe.valid <= TRUE;
        execute_pipe.instr_data <= decode_pipe.instr_data;
        print_instruction(decode_pipe.pc, decode_pipe.instr_data);
        execute_pipe.pc <= decode_pipe.pc;
        execute_pipe.instr_sel <= decode_pipe.instr_sel;
        execute_pipe.rs1_data <= rs1_data_from_reg;
        execute_pipe.rs2_data <= rs2_data_from_reg;
        execute_pipe.user_tag <= TAG_ZERO; // Not used for this lab
        execute_pipe.wb_data <= alu_result;
        $display("%h ALU result %d for instr %d", decode_pipe.pc, $signed(alu_result), decode_pipe.instr_sel);
        execute_pipe.wb_addr <= decode_pipe.instr_data.r_type.rd; // All instruction types use the same rd bits
        execute_pipe.wb_en <= ((decode_pipe.instr_sel < S_SB || decode_pipe.instr_sel > B_BGEU) 
                             && decode_pipe.instr_sel != X_UNKNOWN) ? TRUE : FALSE; // If instr has return value
    end else begin
        execute_pipe.valid <= FALSE;
    end
end

// Memory stage sequential logic
always_ff @(posedge clk) begin
    if (reset) begin
        mem_pipe.valid <= FALSE;
        mem_pipe.instr_data <= REG_ZERO_VAL;
        mem_pipe.pc <= REG_ZERO_VAL;
        mem_pipe.instr_sel <= X_UNKNOWN;
        mem_pipe.rs1_data <= REG_ZERO_VAL;
        mem_pipe.wb_data <= REG_ZERO_VAL;
        mem_pipe.wb_en <= FALSE;
        mem_pipe.wb_addr <= REG_ZERO;
    end else if (execute_pipe.valid) begin
        mem_pipe.valid <= TRUE;
        mem_pipe.instr_data <= execute_pipe.instr_data;
        mem_pipe.pc <= execute_pipe.pc;
        mem_pipe.instr_sel <= execute_pipe.instr_sel;
        mem_pipe.rs1_data <= execute_pipe.rs1_data;
        mem_pipe.wb_en <= execute_pipe.wb_en;
        mem_pipe.wb_addr <= execute_pipe.wb_addr;
        mem_pipe.wb_data <= execute_pipe.wb_data; 
    end else begin
        mem_pipe.valid <= FALSE;
    end
end

// No sequential logic needed after writeback stage

// Writeback register file I/O logic

assign register_io.write_reg_addr = mem_pipe.wb_addr;
assign register_io.write_data = (mem_pipe.valid & is_load(mem_pipe.instr_sel)) ? interpret_read_memory_rsp(mem_pipe.instr_sel, data_mem_rsp) : mem_pipe.wb_data;
assign register_io.write_enable = (mem_pipe.valid & mem_pipe.wb_en) ? TRUE : FALSE;

endmodule

`endif
