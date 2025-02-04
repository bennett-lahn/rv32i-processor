    .text
    .globl _start
_start:

    # ----------------------
    # Test Setup: Initialize Registers
    # ----------------------
    addi x1, x0, 10       # x1 = 10
    addi x2, x0, -5       # x2 = -5
    addi x3, x0, 255      # x3 = 255

    lui x4, 0x1           # x4 = 0x1000 (Base address for memory tests)

    # --------------------------------------
    # Test AUIPC and LUI (Upper Immediate)
    # --------------------------------------
    lui x5, 0x12345       # x5 = 0x12345000
    auipc x6, 0x1         # x6 = PC + 0x1000 (tests relative addressing), should be 69652 in sim

    # -----------------------------------
    # Test Store Instructions (SW, SH, SB)
    # -----------------------------------
    sw x1, 0(x4)          # Store word: Mem[0x1000] = x1 (10)
    sh x2, 4(x4)          # Store halfword: Mem[0x1004] = x2 (-5, sign-extended)
    sb x3, 6(x4)          # Store byte: Mem[0x1006] = x3 (255, unsigned)

    # -----------------------------------
    # Test Load Instructions (LW, LH, LB, LHU, LBU)
    # -----------------------------------
    lw x7, 0(x4)          # Load word: x7 = Mem[0x1000] (should be 10)
    lh x8, 4(x4)          # Load halfword: x8 = Mem[0x1004] (should be -5, sign-extended)
    lb x9, 6(x4)          # Load byte: x9 = Mem[0x1006] (should be -1, sign-extended from 255)
    lhu x10, 4(x4)        # Load halfword unsigned: x10 = Mem[0x1004] (should be 0xFFFB if sign-extended)
    lbu x11, 6(x4)        # Load byte unsigned: x11 = Mem[0x1006] (should be 255)

    # ----------------------
    # Previously Implemented Tests (R & I type)
    # ----------------------
    add x12, x1, x2       # x12 = x1 + x2 (10 + -5 = 5)
    sub x13, x1, x2       # x13 = x1 - x2 (10 - (-5) = 15)
    and x14, x1, x2       # x14 = x1 & x2
    or x15, x1, x2        # x15 = x1 | x2
    xor x16, x1, x2       # x16 = x1 ^ x2
    sll x17, x1, x2       # x17 = x1 << (x2 & 0x1F)
    srl x18, x1, x2       # x18 = x1 >> (x2 & 0x1F)
    sra x19, x1, x2       # x19 = x1 >>> (x2 & 0x1F)
    slt x20, x1, x2       # x20 = (x1 < x2) ? 1 : 0
    sltu x21, x1, x2      # x21 = (x1 < x2) unsigned ? 1 : 0
    addi x22, x1, 7       # x22 = x1 + 7
    andi x23, x1, 3       # x23 = x1 & 3
    ori x24, x1, 8        # x24 = x1 | 8
    xori x25, x1, 4       # x25 = x1 ^ 4
    slli x26, x1, 2       # x26 = x1 << 2
    srli x27, x1, 1       # x27 = x1 >> 1
    srai x28, x1, 1       # x28 = x1 >>> 1
    slti x29, x1, -3      # x29 = (x1 < -3) ? 1 : 0
    sltiu x30, x1, 20     # x30 = (x1 < 20) unsigned ? 1 : 0

    # ----------------------
    # Simulation Stop Signal at 0x2FFFC
    # ----------------------
    lui x31, 0x2FF        # x31 = 0x2F000
    addi x31, x31, 252    # x31 = 0x2FFFC (VALID 12-bit offset)

    li x10, 0xDEADBEEF   # Load stop signal value
    sw x10, 0(x31)       # Store at 0x2FFFC to signal simulation stop

    # Halt execution (Loop back indefinitely)
    j _start  # Loop back to start (or replace with a termination mechanism)
