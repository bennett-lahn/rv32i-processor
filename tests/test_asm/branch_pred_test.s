.text
.globl _start

_start:
    #############################################
    # Branch Test Case 1: Predict Taken (Correct)
    # Backward branch with condition true.
    # Expectation: Branch is taken, so only the instruction
    # in the decode stage (fetched with PC+4) is flushed.
    #############################################
    addi   x1, x0, 5          # x1 = 5
    addi   x2, x0, 10         # x2 = 10
label_case1_target:
    addi   x3, x0, 100        # x3 = 100 (target for branch)
    nop                       # Delay to avoid hazards
    nop
    blt    x1, x2, label_case1_target   # Condition: 5 < 10 is true,
                                           # target is backward, so predicted taken.
                                           # (Correct prediction: flush decode only)

    #############################################
    # Branch Test Case 2: Predict Taken (Incorrect)
    # Backward branch with condition false.
    # Expectation: Branch was predicted taken (because backward),
    # but condition is false so branch is not taken.
    # The processor must flush the fetch stage and the
    # following instruction that was fetched speculatively.
    #############################################
    addi   x4, x0, 20         # x4 = 20
    addi   x5, x0, 10         # x5 = 10
label_case2_target:
    addi   x6, x0, 200        # x6 = 200 (target for branch)
    nop                       # Delay to avoid hazards
    nop
    blt    x4, x5, label_case2_target   # Condition: 20 < 10 is false,
                                           # but branch offset is negative so predicted taken.
                                           # (Misprediction: flush fetch and next instruction from memory)

    #############################################
    # Branch Test Case 3: Predict Not Taken (Correct)
    # Forward branch with condition false.
    # Expectation: Since the branch offset is positive, the predictor
    # predicts not taken, and the condition is false so no flush occurs.
    #############################################
    addi   x7, x0, 5          # x7 = 5
    addi   x8, x0, 10         # x8 = 10
    nop                       # Delay to avoid hazards
    nop
    bge    x7, x8, label_case3_target   # Condition: 5 >= 10 is false,
                                           # forward branch so predicted not taken.
                                           # (Correct: no flush.)
    nop                       # Extra delay to ensure separation
label_case3_target:
    addi   x9, x0, 300        # x9 = 300 (target for branch, executed sequentially)

    #############################################
    # Branch Test Case 4: Predict Not Taken (Incorrect)
    # Forward branch with condition true.
    # Expectation: The branch offset is positive so predicted not taken,
    # but the condition is true, so the branch is actually taken.
    # The processor must flush the decode, fetch, and the in-flight memory instruction.
    #############################################
    addi   x10, x0, 10        # x10 = 10
    addi   x11, x0, 5         # x11 = 5
    nop                       # Delay to avoid hazards
    nop
    bge    x10, x11, label_case4_target  # Condition: 10 >= 5 is true,
                                           # forward branch so predicted not taken.
                                           # (Misprediction: flush decode, fetch, and next instruction from memory)
    nop
    nop
    addi   x12, x0, 999       # This instruction should be flushed (should not execute)
label_case4_target:
    addi   x13, x0, 400       # x13 = 400 (branch target executed on misprediction)
    addi   x1,  x0, 1
    addi   x2,  x0, 2
    nop
    nop

    #############################################
    # End Test (Halt Simulation)
    # Write a halt signal to a memory-mapped location.
    # Not currently supported.
    ############################################