.text
.globl _start

_start:
    # Initialize registers with immediate values (no hazards here)
    addi    x1, x0, 10      # x1 = 10
    addi    x2, x0, 5       # x2 = 5

    # Instruction 3: depends on x1 and x2 (forwarding required if pipeline is deep)
    add     x3, x1, x2      # x3 = 10 + 5 = 15
    # (x3 is produced here and may be forwarded in subsequent instructions)

    # Instruction 4: uses x3 immediately (hazard distance = 1)
    add     x4, x3, x1      # x4 = 15 + 10 = 25

    # Instruction 5: uses x3 and x4
    add     x5, x3, x4      # x5 = 15 + 25 = 40
    # (x3 is 2 cycles old; x4 is 1 cycle old)

    # Instruction 6: uses x5 immediately (hazard distance = 1)
    sub     x6, x5, x2      # x6 = 40 - 5 = 35

    # Instruction 7: uses x6 and x3 (x6 is 1 cycle old, x3 is now 4 cycles old)
    xor     x7, x6, x3      # x7 = 35 XOR 15

    # Instruction 8: uses x7 and x4 (hazard distance = 1 for x7, and 3 for x4)
    or      x8, x7, x4      # x8 = x7 OR 25

    # Instruction 9: uses x8 and x1 (x8 is 1 cycle old, x1 is much older)
    and     x9, x8, x1      # x9 = x8 AND 10

    # --- Halt section (modified) ---
    # Instead of using a single addi that exceeds the immediate range,
    # we load 0x2FFC into a register using LUI+ADDI, then store a value there.
    li     a0, 196604
    sw     zero, 0(a0)      # Write zero to memory-mapped halt address
