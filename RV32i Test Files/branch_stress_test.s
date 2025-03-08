.section .text
.global _start

_start:
    ####################################################
    # Test A: Two Back-to-Back Branches (No intervening instr)
    # Setup registers for branch conditions.
    addi   x1, x0, 5         # x50 = 5
    addi   x2, x0, 10        # x51 = 10
    # First branch: bge x50, x51, branch_true_A
    # Condition: 5 >= 10 is false, so branch not taken.
    bge    x1, x2, branch_true_A  # Should NOT branch; fall through.
    # Second branch: bge x51, x50, branch_true_A
    # Condition: 10 >= 5 is true, so branch is taken.
    bge    x2, x1, branch_true_A  # Should branch; the instruction immediately after is flushed.
    addi   x1, x0, 999       # This instruction should be flushed if the second branch is taken.
branch_true_A:
    addi   x1, x0, 111       # x53 = 111, branch target executed.

    ####################################################
    # Test 1: Backward Branch Loop (Correct Prediction)
    # Load comparison values into registers.
    addi   x1, x0, 5          # x1 = 5 (loop counter initialization)
    addi   x2, x0, 10         # x2 = 10 (loop limit)
back_loop:
    addi   x1, x1, 1          # Increment counter
    blt    x1, x2, back_loop  # Branch if x1 < x2 (backward branch, predicted taken)
    # Expected: Loop iterates until x1 equals 10.

    ####################################################
    # Test 2: Forward Branch (Mispredicted)
    # Load values for the branch condition.
    addi   x3, x0, 10         # x3 = 10
    addi   x4, x0, 5          # x4 = 5
    # Forward branch: bge x3, x4, forward_target
    # BTFNT predicts forward branches as not taken.
    # Condition: 10 >= 5 is true, so branch is taken, but mispredicted.
    bge    x3, x4, forward_target  
    addi   x5, x0, 999        # x5 should be flushed.
forward_target:
    addi   x6, x0, 2          # x6 = 2, branch target executed.

    ####################################################
    # Test 3: Back-to-Back Jumps
    # These jumps should flush the instruction immediately following each jump.
    addi   x7, x0, 100        # x7 = 100 (dummy value)
    addi   x8, x0, 200        # x8 = 200 (dummy target value)
    jal    x9, jump_target1   # Jump and link; x9 gets return address.
    addi   x10, x0, 999       # Should be flushed.
jump_target1:
    addi   x11, x0, 300       # x11 = 300, executed at jump_target1.
    jal    x12, jump_target2  # Second jump.
    addi   x13, x0, 888       # Should be flushed.
jump_target2:
    addi   x14, x0, 400       # x14 = 400, executed at jump_target2.

    ####################################################
    # Test 4: Branch Chain (Back-to-Back Branches)
    # A chain of branch instructions.
    addi   x15, x0, 0         # x15 = 0, initialize counter.
branch_chain:
    addi   x15, x15, 1        # Increment counter.
    bne    x15, x2, branch_chain  # Loop until x15 equals x2 (10).
    # Expected: x15 becomes 10.

    ####################################################
    # Halt: Use the specified halt condition
    li     a0, 0x0002FFFC     # Load halt address 0x2FFFC into a0.
    sw     zero, 0(a0)        # Write to memory-mapped exit signal to halt simulation.
