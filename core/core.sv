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

// High if pc must update to updated_pc_val because of branch/jump
logic update_pc;
// Value pc should be updated to when update_pc is HIGH
word_t new_pc_val;
// Value for pc of the previous instr, used when stalling
word_t prev_pc_val;

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

// Casted instruction data variables
// All versions of casted pipeline instruction fields, used to make interfacing with the instr structs easier
r_type_t casted_fetch_instr;
r_type_t casted_decode_instr;
r_type_t casted_execute_instr;
r_type_t casted_mem_instr;
assign casted_fetch_instr = r_type_t'(fetch_pipe.instr_data);
assign casted_decode_instr = r_type_t'(decode_pipe.instr_data);
assign casted_execute_instr = r_type_t'(execute_pipe.instr_data);
assign casted_mem_instr = r_type_t'(mem_pipe.instr_data);

// Register reads
// Continuously update register read based on current instruction rs1/rs2
// This means rs1/rs2 data logic variables ONLY VALID FOR EXECUTE and completely unknown before EXECUTE
// Valid bit for instr is not checked since register values don't matter if instr is valid
assign register_io.read_reg_addr_1 = update_rs1_addr(fetch_pipe.instr_data);
assign register_io.read_reg_addr_2 = update_rs2_addr(fetch_pipe.instr_data);

// rs1 data from register file
// Should not be used directly outside rs1_data_for_alu assign
// Use rs1_data_for_alu, which includes forwarding
reg_data_t rs1_data_from_regfile;
assign rs1_data_from_regfile = register_io.read_data_1;

// rs2 data from register file
// Should not be used directly outside rs2_data_for_alu assign
// Use rs2_data_for_alu, which includes forwarding
reg_data_t rs2_data_from_regfile;
assign rs2_data_from_regfile = register_io.read_data_2;

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
logic flush_fetch, flush_decode;

// Used by forwarding unit to select which forwarding networks the instr in decode should use in the execute stage
fwd_src_t rs1_fwd_network;
fwd_src_t rs2_fwd_network;

// True if bubble/nop should be inserted in front of instr in decode, stalling processor
logic insert_bubble_execute;

// Opcode value of current instr being decoded (in decode stage)
opcode_t decode_opcode;
assign decode_opcode = casted_fetch_instr.opcode;

// rs1 and rs2 index values of current instr being decoded (in decode stage)
reg_index_t decode_rs1_index;
reg_index_t decode_rs2_index;
assign decode_rs1_index = casted_fetch_instr.rs1;
assign decode_rs2_index = casted_fetch_instr.rs2;

// rd index values of current instructions in execute and memory stages
// If instruction does not use rd, passes x0 value (never forwarded by fwd unit)
reg_index_t execute_rd_index;
reg_index_t mem_rd_index;
assign execute_rd_index = (uses_rd(casted_decode_instr.opcode)) ? casted_decode_instr.rd : REG_ZERO;
assign mem_rd_index =     (uses_rd(casted_execute_instr.opcode)) ? casted_execute_instr.rd : REG_ZERO;

// Result from executing instruction in execute stage
reg_data_t alu_result;
// rs1 and rs2 values used by alu, either forwarded from later pipeline stages or from reg file
// Possibly room to shrink critical path here by moving MUXing of fwd_path to decode
// However, would still have to MUX data_from_regfile because it's not ready until execute
reg_data_t rs1_data_for_alu;
reg_data_t rs2_data_for_alu;
assign rs1_data_for_alu = (decode_pipe.fwd_rs1 == FWD_EXEC)     ? execute_pipe.wb_data  :
                          (decode_pipe.fwd_rs1 == FWD_MEM)      ? mem_pipe.wb_data      :
                          (decode_pipe.fwd_rs1 == FWD_MEM_READ) ? register_io.write_data : 
                                                                  rs1_data_from_regfile;

assign rs2_data_for_alu = (decode_pipe.fwd_rs2 == FWD_EXEC)     ? execute_pipe.wb_data  :
                          (decode_pipe.fwd_rs2 == FWD_MEM)      ? mem_pipe.wb_data      :
                          (decode_pipe.fwd_rs2 == FWD_MEM_READ) ? register_io.write_data : 
                                                                  rs2_data_from_regfile;

assign alu_result = execute_instr(decode_pipe.instr_data, decode_pipe.pc, decode_pipe.instr_sel, 
                                  rs1_data_for_alu, rs2_data_for_alu);

// ------------------------------------------------------------------------------------------------
// Combinational Logic
// ------------------------------------------------------------------------------------------------

// Branch prediction and program counter logic
// Minor TODO: Currently branch prediction requires calculating the target address twice: in fetch when updating the PC,
// (if decode is branch) and in execute (if the branch is mispredicted). It would be better to avoid this using BTB etc.
always_comb begin
    // Default inputs for combinational logic; defaults also set in every if/else case
    update_pc = FALSE;
    new_pc_val = REG_ZERO_VAL;
    branch_mispredicted = FALSE;
    pc_override = REG_ZERO_VAL;
    flush_decode = FALSE;
    flush_fetch = FALSE;
    insert_bubble_execute = FALSE; // Default to no stall
    rs1_fwd_network = FWD_NONE;
    rs2_fwd_network = FWD_NONE;

    // Forwarding Unit
    // Compares instr in decode to instrs downstream, looking for data hazards
    // Updates pipeline data to activate the necessary forwarding channels in execute
    // Move down pipe, checking if instr update dependent registers, priority for recently executed instr
    // Forwarding ignored for zero register, instrs that do not use rd pass in x0 for rd_index, are not forwarded
    if (uses_rs1(decode_opcode)) begin
        if (decode_rs1_index == REG_ZERO) // Ignore forwarding for zero register
            rs1_fwd_network = FWD_NONE;
        else if ((decode_rs1_index == execute_rd_index) & decode_pipe.valid) begin
            // If the immediate next instr is a load, use FWD_MEM instead due to stalling
            // Set other signals to stall appropriately (assumes 1 cycle memory response)
            if (is_load(casted_decode_instr.opcode)) begin
                rs1_fwd_network = FWD_MEM; // This value doesn't matter since processor 
                                           // stalls and load moves ahead a cycle while decode instr doesn't
                insert_bubble_execute = TRUE;
            end else
                rs1_fwd_network = FWD_EXEC;
        end else if ((decode_rs1_index == mem_rd_index) & execute_pipe.valid) begin
            if (is_load(casted_execute_instr.opcode))
                rs1_fwd_network = FWD_MEM_READ;
            else
                rs1_fwd_network = FWD_MEM;
        end else
            rs1_fwd_network = FWD_NONE;
    end else begin
        rs1_fwd_network = FWD_NONE;
    end
    
    // Forwarding for rs2, should be identical to rs1 but for rs2
    if (uses_rs2(decode_opcode)) begin
        if (decode_rs2_index == REG_ZERO) // Ignore forwarding for zero register
            rs2_fwd_network = FWD_NONE;
        else if ((decode_rs2_index == execute_rd_index) & decode_pipe.valid) begin
            // If the immediate next instr is a load, use FWD_MEM instead due to stalling
            // Set other signals to stall appropriately (assumes 1 cycle memory response)
            if (is_load(casted_decode_instr.opcode)) begin
                rs2_fwd_network = FWD_MEM;
                insert_bubble_execute = TRUE;
            end else begin
                rs2_fwd_network = FWD_EXEC;
            end
        end else if ((decode_rs2_index == mem_rd_index) & execute_pipe.valid) begin
            if (is_load(casted_execute_instr.opcode))
                rs2_fwd_network = FWD_MEM_READ;
            else
                rs2_fwd_network = FWD_MEM;
        end else
            rs2_fwd_network = FWD_NONE;
    end else begin
        rs2_fwd_network = FWD_NONE;
    end

    // Branch misprediction (and jump flush) logic, operating in EXECUTE stage
    // If predict_branch_taken output does not match branch evaluation from ALU, flush pipeline and update PC
    // TODO: Update branch prediction so jumps don't require flushing (low priority)
    if (decode_pipe.valid & is_branch(casted_decode_instr.opcode)) begin
        // Case 1: Predict branch taken (correct); only flush decode
        if (predict_branch_taken(b_type_t'(decode_pipe.instr_data)) && alu_result == REG_TRUE) begin 
            branch_mispredicted = FALSE;
            pc_override = REG_ZERO_VAL;
            flush_decode = TRUE;
            flush_fetch = FALSE;
        // Case 2: Predict branch taken (incorrect); flush fetch, but not decode which contains pc + 4
        end else if (predict_branch_taken(b_type_t'(decode_pipe.instr_data)) && alu_result != REG_TRUE) begin
            branch_mispredicted = TRUE;
            pc_override = decode_pipe.pc + 8;
            flush_decode = FALSE;
            flush_fetch = TRUE;
        // Case 3: Predict branch not taken (incorrect); flush decode, fetch
        end else if (!predict_branch_taken(b_type_t'(decode_pipe.instr_data)) && alu_result == REG_TRUE) begin
            branch_mispredicted = TRUE;
            pc_override = build_branch_pc(b_type_t'(decode_pipe.instr_data), decode_pipe.pc);
            flush_decode = TRUE;
            flush_fetch = TRUE;
        // Case 4: Predict branch not taken (correct); do not flush anything, as PC is not modified by predictor or branch    
        end else begin
            branch_mispredicted = FALSE;
            pc_override = REG_ZERO_VAL;
            flush_decode = FALSE;
            flush_fetch = FALSE;
        end
    end else if (decode_pipe.valid & is_jump(decode_pipe.instr_sel)) begin 
        branch_mispredicted = TRUE; // Misnomer because not a branch, but equivalent to Case 3 in effect
        pc_override = (decode_pipe.instr_sel == J_JAL) ? build_jal_pc(j_type_t'(decode_pipe.instr_data), decode_pipe.pc) : 
                                                         build_jalr_pc(i_type_t'(decode_pipe.instr_data), decode_pipe.pc, rs1_data_for_alu);
        flush_decode = TRUE;
        flush_fetch = TRUE;
    end else begin
        branch_mispredicted = FALSE;
        pc_override = REG_ZERO_VAL;
        flush_decode = FALSE;
        flush_fetch = FALSE;
    end

    // Program counter logic
    // Update master program counter if jump/branch instruction triggers
    // Branch prediction: "backwards taken, fowards not taken"
    // Prefers updating pc to correct mispredict to predicting more branches as fetched instruction would be invalid
    if (insert_bubble_execute) begin
        update_pc = FALSE;
        new_pc_val = REG_ZERO_VAL;
    end else if (branch_mispredicted) begin
        update_pc = TRUE;
        new_pc_val = pc_override;
    end else if (fetch_pipe.valid && is_branch(casted_fetch_instr.opcode)) begin
        if (predict_branch_taken(b_type_t'(fetch_pipe.instr_data))) begin
            update_pc = TRUE;
            new_pc_val = build_branch_pc(b_type_t'(fetch_pipe.instr_data), fetch_pipe.pc);
        end else begin
            update_pc = FALSE;
            new_pc_val = REG_ZERO_VAL;
        end
    end else begin
        update_pc = FALSE;
        new_pc_val = REG_ZERO_VAL;
    end
end

// Instruction memory request logic for fetch stage
assign inst_mem_req.valid = (reset) ? FALSE : TRUE;
assign inst_mem_req.addr = (insert_bubble_execute) ? prev_pc_val : (update_pc) ? new_pc_val : pc;
assign inst_mem_req.do_read  = 4'b1111;
assign inst_mem_req.do_write = 4'b0000;

assign inst_mem_req.data = 32'b0;
assign inst_mem_req.dummy = 3'b0;
assign inst_mem_req.user_tag = TAG_ZERO;

// Pipelined memory request logic
// Load and store for a type must be naturally aligned to the respective datatype
// (i.e. the effective address is not divisible by the size of the access in bytes)
// Functions used to interact with memory detailed in mem_func.sv
always_comb begin
    data_mem_req.valid = FALSE;
    data_mem_req.addr = REG_ZERO_VAL;
    data_mem_req.data = REG_ZERO_VAL;
    data_mem_req.do_read = 4'b0000;
    data_mem_req.do_write = 4'b0000;
    data_mem_req.user_tag = TAG_ZERO;
    data_mem_req.dummy = 3'b0;
    if (execute_pipe.valid & is_load(casted_execute_instr.opcode)) begin
        data_mem_req.valid = TRUE;
        data_mem_req.addr = execute_pipe.wb_data; // Calculated memory addr in EXECUTE
        data_mem_req.data = REG_ZERO_VAL;
        data_mem_req.do_read = create_byte_plane(execute_pipe.instr_sel, execute_pipe.wb_data);
        data_mem_req.do_write = 4'b0000;
        data_mem_req.user_tag = execute_pipe.user_tag;
    end else if (execute_pipe.valid & is_store(casted_execute_instr.opcode)) begin
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

// ------------------------------------------------------------------------------------------------
// Sequential Logic
// ------------------------------------------------------------------------------------------------

// Main program counter sequential logic
// Remember that main pc represents what is fetched in the NEXT clock cycle
always_ff @(posedge clk) begin
    if (reset) begin
        pc <= reset_pc;
        prev_pc_val <= REG_ZERO_VAL;
    end else if (insert_bubble_execute) begin
        pc <= pc;
        prev_pc_val <= pc; // Only correct for 1-cycle bubble, otherwise need new mechanism to hold prev_pc_val longer
    end else if (update_pc) begin
        pc <= new_pc_val + 4; // new_pc_val is directly fed to mem in this case to avoid delay, so skip to next instr
        prev_pc_val <= new_pc_val;
    end else begin
        pc <= pc + 4;
        prev_pc_val <= pc;
    end
end

// Pipeline sequential logic
// Each pipeline stage has a synchronized reset, pipeline registers between stages 
// (fetch, decode, execute, memory, writeback)

// Fetch/decode stage sequential logic
// Do not modify pipeline register if inserting bubble
always_ff @(posedge clk) begin
    if (reset) begin
        fetch_pipe.valid <= FALSE;
        fetch_pipe.instr_data <= REG_ZERO_VAL;
        fetch_pipe.pc <= REG_ZERO_VAL;
    end else if (~insert_bubble_execute) begin
        if (inst_mem_rsp.valid) begin
            // If instr in decode is jump, next mem response after is invalid due to memory latency
            if (flush_fetch) begin
                fetch_pipe.valid <= FALSE;
                // $display("Flushed fetch.");
            end else
                fetch_pipe.valid <= TRUE;
            fetch_pipe.instr_data <= inst_mem_rsp.data;
            fetch_pipe.pc <= inst_mem_rsp.addr;
        end else begin
            fetch_pipe.valid <= FALSE;
        end 
    end
end

// Decode/execute stage sequential logic
always_ff @(posedge clk) begin
    if (reset) begin
        decode_pipe.valid <= FALSE;
        decode_pipe.instr_data <= REG_ZERO_VAL;
        decode_pipe.pc <= REG_ZERO_VAL;
        decode_pipe.instr_sel <= X_UNKNOWN;
        decode_pipe.fwd_rs1 <= FWD_NONE;
        decode_pipe.fwd_rs2 <= FWD_NONE;
    end else if (insert_bubble_execute) begin
        decode_pipe.valid <= FALSE;
    end else begin
        if (flush_decode) begin
            decode_pipe.valid <= FALSE;
            // $display("Flushed decode");
        end else begin
            decode_pipe.valid <= fetch_pipe.valid;
        end
        // decode_pipe.valid <= (flush_decode) ? FALSE : fetch_pipe.valid;
        decode_pipe.instr_data <= fetch_pipe.instr_data;
        decode_pipe.pc <= fetch_pipe.pc;
        decode_pipe.instr_sel <= decoded_instr;
        decode_pipe.fwd_rs1 <= rs1_fwd_network;
        decode_pipe.fwd_rs2 <= rs2_fwd_network;
    end
end

// Execute/mem stage sequential logic
always_ff @(posedge clk) begin
    if (reset) begin
        execute_pipe.valid <= FALSE;
        execute_pipe.instr_data <= REG_ZERO_VAL;
        execute_pipe.pc <= REG_ZERO_VAL;
        execute_pipe.instr_sel <= X_UNKNOWN;
        execute_pipe.rs1_data <= REG_ZERO_VAL;
        execute_pipe.rs2_data <= REG_ZERO_VAL;
        execute_pipe.user_tag <= TAG_ZERO; // Not used for this lab
        execute_pipe.wb_data <= REG_ZERO_VAL;
        execute_pipe.wb_en <= FALSE;
        execute_pipe.wb_addr <= REG_ZERO;
    end else if (decode_pipe.valid) begin
        execute_pipe.valid <= TRUE;
        execute_pipe.instr_data <= decode_pipe.instr_data;
        // print_instruction(decode_pipe.pc, decode_pipe.instr_data);
        execute_pipe.pc <= decode_pipe.pc;
        execute_pipe.instr_sel <= decode_pipe.instr_sel;
        execute_pipe.rs1_data <= rs1_data_for_alu; // Includes data that may be forwarded instead of coming from reg file
        execute_pipe.rs2_data <= rs2_data_for_alu;
        execute_pipe.wb_data <= alu_result;
        // $display("%h:  ALU result %d for instr %d", decode_pipe.pc, $signed(alu_result), decode_pipe.instr_sel);
        // $display("%h: FWD RS1: %d FWD RS2 %d", decode_pipe.pc, decode_pipe.fwd_rs1, decode_pipe.fwd_rs2);
        // $display("%h: ALU RS1 val: %d ALU RS2 val: %d", decode_pipe.pc, rs1_data_for_alu, rs2_data_for_alu);
        execute_pipe.wb_addr <= casted_decode_instr.rd; // All instruction types use the same rd bits
        execute_pipe.wb_en <= ((decode_pipe.instr_sel < S_SB || decode_pipe.instr_sel > B_BGEU) 
                             && decode_pipe.instr_sel != X_UNKNOWN) ? TRUE : FALSE; // If instr has return value
    end else begin
        execute_pipe.valid <= FALSE;
    end
end

// Memory/writeback stage sequential logic
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

// Writeback register file I/O logic

assign register_io.write_reg_addr = mem_pipe.wb_addr;
assign register_io.write_data = (is_load(casted_mem_instr.opcode)) ? interpret_read_memory_rsp(mem_pipe.instr_sel, data_mem_rsp) : mem_pipe.wb_data;
assign register_io.write_enable = (mem_pipe.valid & mem_pipe.wb_en) ? TRUE : FALSE;

endmodule

`endif
