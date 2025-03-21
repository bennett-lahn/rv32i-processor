#.extern main
.globl _start

.text

_start:
#
# Uncomment / add to / etc to test lab 2


                        auipc   a4,0x1000
                        addi    a4,a4,-436
                        add a5,a5,a4
                        add a5,a5,a4
#
# place additional test instructions here
   # Setup: Initialize registers with known values.
    addi   x1, x0, 5         # x1 = 5
    addi   x2, x0, 5         # x2 = 5
    addi   x3, x0, 10        # x3 = 10
    addi   x4, x0, 20        # x4 = 20

    # -------------------------
    # Branch Instruction Tests
    # -------------------------
    # Test BEQ: if x1 == x2 then branch to L_beq.
    beq    x1, x2, L_beq     # Condition true (5==5): branch taken.
    addi   x5, x0, 99        # (Should not execute if branch is taken.)
    addi   x5, x0, 99        # (Should not execute if branch is taken.)
    addi   x5, x0, 99        # (Should not execute if branch is taken.)
L_beq:
    addi   x5, x0, 1         # x5 = 1 indicates BEQ was taken.

    # Test BNE: if x1 != x3 then branch to L_bne.
    bne    x1, x3, L_bne     # Condition true (5 != 10): branch taken.
    addi   x6, x0, 99        # (Should not execute if branch is taken.)
L_bne:
    addi   x6, x0, 2         # x6 = 2 indicates BNE was taken.

    # Test BLT: if x1 < x4 then branch to L_blt.
    blt    x1, x4, L_blt     # Condition true (5 < 20): branch taken.
    addi   x7, x0, 99        # (Should not execute if branch is taken.)
    addi   x7, x0, 99        # (Should not execute if branch is taken.)
L_blt:
    addi   x7, x0, 3         # x7 = 3 indicates BLT was taken.

    # Test BGE: if x4 >= x1 then branch to L_bge.
    bge    x4, x1, L_bge     # Condition true (20 >= 5): branch taken.
    addi   x8, x0, 99        # (Should not execute if branch is taken.)
L_bge:
    addi   x8, x0, 4         # x8 = 4 indicates BGE was taken.

    # Test BLTU: Unsigned compare: if x1 < x3 then branch to L_bltu.
    bltu   x1, x3, L_bltu    # Condition true (5 < 10 unsigned): branch taken.
    addi   x9, x0, 99        # (Should not execute if branch is taken.)
L_bltu:
    addi   x9, x0, 5         # x9 = 5 indicates BLTU was taken.

    # Test BGEU: Unsigned compare: if x3 >= x1 then branch to L_bgeu.
    bgeu   x3, x1, L_bgeu    # Condition true (10 >= 5 unsigned): branch taken.
    addi   x10, x0, 99       # (Should not execute if branch is taken.)
L_bgeu:
    addi   x10, x0, 6        # x10 = 6 indicates BGEU was taken.

    # -------------------------
    # Jump Instruction Tests
    # -------------------------
    # Test JAL: Unconditional jump to JAL_LABEL.
    jal    x0, JAL_LABEL     # Jump to JAL_LABEL; link (x0) is discarded.
    addi   x11, x0, 99       # (Should not execute if JAL is taken.)
    addi   x11, x0, 99       # (Should not execute if JAL is taken.)
    addi   x11, x0, 99       # (Should not execute if JAL is taken.)
JAL_LABEL:
    addi   x11, x0, 7        # x11 = 7 indicates JAL was taken.

    # Test JALR: Use a register to hold the jump target.
    la     x12, JALR_LABEL   # Load the address of JALR_LABEL into x12.
    jalr   x0, x12, 0        # Jump to address in x12.
    addi   x13, x0, 99       # (Should not execute if JALR is taken.)
    addi   x13, x0, 99       # (Should not execute if JALR is taken.)
    addi   x13, x0, 99       # (Should not execute if JALR is taken.)
JALR_LABEL:
    addi   x13, x0, 8        # x13 = 8 indicates JALR was taken.


    # -------------------------
    # End of Test: Stop Signal
    # -------------------------

    li     x31, 0x2FFFC       # Load stop signal address into x31 using the li pseudoinstruction
    li     x10, 0xDEADBEEF    # Load stop signal value into x10
    sw     x10, 0(x31)        # Store at 0x2FFFC to signal simulation stop

### Everything below here is not required for lab2.
######
#
#  halt
#        li a0, 0x0002FFFC
#        sw zero, 0(a0)
        
# Eventually this is is the start of your code for future labs (by lab 4 this will be needed)
#    li      sp, (0x00030000 - 16)
#    call    main
#    call    halt
#    j       _start

