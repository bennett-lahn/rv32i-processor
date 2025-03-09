.section .text
.global _start

_start:
    # Initialize registers
    addi x1, x0, 10       # x1 = 10 (used for store value)
    addi x2, x0, 20       # x2 = 20 (used for store address)
    addi x3, x0, 30       # x3 = 30 (constant)
    addi x4, x0, 0        # x4 will hold the loaded value
    addi x5, x0, 0        # x5 will hold arithmetic result
    addi x6, x0, 0        # x6 will hold branch result
    addi x7, x0, 0        # x7 will hold final arithmetic result

    # Store a value at address x2
    sw x1, 0(x2)          # Mem[x2] = x1 (store 10 at address 20)

    ## Test Case 1: Load followed by arithmetic
    lw x4, 0(x2)          # Load from memory (should get 10)
    add x5, x4, x3        # x5 = x4 + x3 (expect 10 + 30 = 40)

    ## Test Case 2: Load followed by branch (taken if x4 == 20)
    sw x2, 0(x2)
    lw x4, 0(x2)          # Load from memory again
    beq x4, x2, branch_taken  # Branch if x4 == 20

    addi x6, x0, 1        # Should not execute
    j end_test            # Should not execute

branch_taken:
    addi x6, x0, 2        # Should execute if branch is taken

    ## Test Case 3: Load followed by store
    sw x1, 0(x2)
    lw x4, 0(x2)          # Load value from memory
    sw x4, 4(x2)          # Store x4 at Mem[x2 + 4] (should store 10)
    lw x4, 4(x2)          # Load from stored location (should get 10)
    add x7, x4, x3        # x7 = x4 + x3 (expect 10 + 30 = 40)

end_test:
    li     a0, 0x0002FFFC     # Load halt address 0x2FFFC into a0.
    sw     x1, 0(a0)        # Write to memory-mapped exit signal to halt simulation.
