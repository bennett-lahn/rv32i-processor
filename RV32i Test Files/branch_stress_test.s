.section .text
.global _start

_start:
    ####################################################
    # Test A: Two Back-to-Back Branches (No intervening instr)
    # Using real registers for branch conditions.
    addi   x1, x0, 5         # x1 = 5
    addi   x2, x0, 10        # x2 = 10
    # First branch: bge x1, x2, branch_target_A
    # Condition: 5 >= 10 is false, so branch not taken.
    bge    x1, x2, branch_target_A  # Fall through.
    # Second branch: bge x2, x1, branch_target_A
    # Condition: 10 >= 5 is true, so branch is taken.
    bge    x2, x1, branch_target_A  # Should branch; the next instruction is flushed.
    addi   x1, x0, 999       # This instruction should be flushed.
branch_target_A:
    addi   x1, x0, 111       # x1 = 111, branch target executed.

    ####################################################
    # Test 1: Backward Branch Loop (Correct Prediction)
    addi   x1, x0, 5         # x1 = 5 (loop counter initialization)
    addi   x2, x0, 10        # x2 = 10 (loop limit)
back_loop:
    addi   x1, x1, 1         # Increment counter
    blt    x1, x2, back_loop # Loop until x1 equals 10
    # Expected: x1 becomes 10.

    ####################################################
    # Test 2: Forward Branch (Mispredicted)
    addi   x3, x0, 10        # x3 = 10
    addi   x4, x0, 5         # x4 = 5
    bge    x3, x4, forward_target  # Branch if 10 >= 5 is true; predicted not taken.
    addi   x5, x0, 999       # x5 should be flushed.
forward_target:
    addi   x6, x0, 2         # x6 = 2, branch target executed.

    ####################################################
    # Test 3: Back-to-Back Jumps
    addi   x7, x0, 100       # x7 = 100 (dummy value)
    addi   x8, x0, 200       # x8 = 200 (dummy target value)
    jal    x9, jump_target1  # Jump and link; x9 gets return address.
    addi   x10, x0, 999      # Should be flushed.
jump_target1:
    addi   x11, x0, 300      # x11 = 300, executed at jump_target1.
    jal    x12, jump_target2 # Second jump.
    addi   x13, x0, 888      # Should be flushed.
jump_target2:
    addi   x14, x0, 400      # x14 = 400, executed at jump_target2.

    ####################################################
    # Test 4: Branch Chain (Back-to-Back Branches)
    addi   x15, x0, 0        # x15 = 0, initialize counter.
branch_chain:
    addi   x15, x15, 1       # Increment counter.
    bne    x15, x2, branch_chain  # Loop until x15 equals x2 (10)
    # Expected: x15 becomes 10.

    ####################################################
    # Test 5: JALR Function Call/Return Test with Load-Use Dependencies
    # In this test, we simulate a function call using JALR:
    #  1. We load the function target address into x20.
    #  2. We call the function using "jalr x21, x20, 0", which stores the return address (PC+4) in x21.
    #  3. Immediately after the call, an instruction (addi x22, x0, 999) is present which should be flushed.
    #  4. Inside the function (label func_start), we:
    #     - Copy the return address from x21 to x1 so that our debug prints can verify it.
    #     - Execute an operation (addi x23, x0, 777).
    #     - Then return using "jalr x0, x21, 0".
    #  5. After the return, we jump to the halt section so that the program does not loop forever.
    la     x20, func_start    # x20 = address of function start (using la pseudoinstruction)
    jalr   x21, x20, 0        # Call function: jump to func_start; x21 = return address (PC+4)
    addi   x22, x0, 999       # This instruction should be flushed.
    # If, for any reason, execution continues here, jump to halt:
    j      halt_section

func_start:
    add    x1, x21, x0        # Copy return address to x1 for debugging.
                             # Expected: x1 = (address of the jalr instruction + 4)
    addi   x23, x0, 777       # x23 = 777, function body operation.
    jalr   x0, x21, 0         # Return from function: jump to address in x21.

    ####################################################
    # Halt: Use the specified halt condition
halt_section:
    li     a0, 0x0002FFFC     # Load halt address 0x2FFFC into a0.
    sw     zero, 0(a0)        # Write to memory-mapped exit signal to halt simulation.
