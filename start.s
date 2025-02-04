    .text
    .globl _start
_start:

    # ----------------------
    # Test Setup: Initialize Registers
    # ----------------------
    addi   x1, x0, 10         # x1 = 10
    addi   x2, x0, -5         # x2 = -5
    addi   x3, x0, 255        # x3 = 255
    lui    x4, 0x1            # x4 = 0x1000 (Base address for memory tests)

    # --------------------------------------
    # Test AUIPC and LUI (Upper Immediate)
    # --------------------------------------
    lui    x5, 0x12345        # x5 = 0x12345000
    auipc  x6, 0x1            # x6 = PC + 0x1000 (tests relative addressing)

    # -----------------------------------
    # Test Store Instructions (SW, SH, SB)
    # -----------------------------------
    sw     x1, 0(x4)          # Store word: Mem[0x1000] = x1 (10)
    sh     x2, 4(x4)          # Store halfword: Mem[0x1004] = x2 (-5, sign-extended)
    sb     x3, 6(x4)          # Store byte: Mem[0x1006] = x3 (255, unsigned)

    # -----------------------------------
    # Test Load Instructions (LW, LH, LB, LHU, LBU)
    # -----------------------------------
    lw     x7, 0(x4)          # Load word: x7 = Mem[0x1000] (should be 10)
    lh     x8, 4(x4)          # Load halfword: x8 = Mem[0x1004] (should be -5, sign-extended)
    lb     x9, 6(x4)          # Load byte: x9 = Mem[0x1006] (should be -1, sign-extended from 255)
    lhu    x10, 4(x4)         # Load halfword unsigned: x10 = Mem[0x1004]
    lbu    x11, 6(x4)         # Load byte unsigned: x11 = Mem[0x1006] (should be 255)

    # ----------------------
    # Unaligned Byte Load/Store Tests
    # ----------------------
    li     x9, 0x1100         # x9 = 0x1100; base address for byte tests

    li     x10, 0xAA          # x10 = 0xAA
    li     x11, 0xBB          # x11 = 0xBB
    li     x12, 0xCC          # x12 = 0xCC
    li     x13, 0xDD          # x13 = 0xDD

    sb     x10, 0(x9)         # Store 0xAA at 0x1100
    sb     x11, 1(x9)         # Store 0xBB at 0x1101
    sb     x12, 2(x9)         # Store 0xCC at 0x1102
    sb     x13, 3(x9)         # Store 0xDD at 0x1103

    lb     x14, 0(x9)         # Load signed byte from 0x1100; expect sign-extended 0xAA
    lbu    x15, 0(x9)         # Load unsigned byte from 0x1100; expect 0xAA

    lb     x16, 1(x9)         # Load signed byte from 0x1101; expect sign-extended 0xBB
    lbu    x17, 1(x9)         # Load unsigned byte from 0x1101; expect 0xBB

    lb     x18, 2(x9)         # Load signed byte from 0x1102; expect sign-extended 0xCC
    lbu    x19, 2(x9)         # Load unsigned byte from 0x1102; expect 0xCC

    lb     x20, 3(x9)         # Load signed byte from 0x1103; expect sign-extended 0xDD
    lbu    x21, 3(x9)         # Load unsigned byte from 0x1103; expect 0xDD

    # ----------------------
    # Unaligned Halfword Load/Store Tests
    # ----------------------
    li     x22, 0x1300         # x22 = 0x1300; base address for halfword tests
    li     x23, 0x1234         # x23 = 0x1234 (test halfword value)
    li     x24, 0xABCD         # x24 = 0xABCD (test halfword value)

    sh     x23, 0(x22)         # Store halfword 0x1234 at aligned address 0x1300
    sh     x24, 2(x22)         # Store halfword 0xABCD at misaligned address 0x1301

    lh     x25, 0(x22)         # Load signed halfword from 0x1300; expect sign-extended 0x1234
    lhu    x26, 0(x22)         # Load unsigned halfword from 0x1300; expect 0x1234

    lh     x27, 2(x22)         # Load signed halfword from misaligned address 0x1301; expect sign extension of 0xABCD
    lhu    x28, 2(x22)         # Load unsigned halfword from misaligned address 0x1301; expect 0xABCD

    # ----------------------
    # Previously Implemented Tests (R & I type)
    # ----------------------
    add    x12, x1, x2        # x12 = x1 + x2 (10 + -5 = 5)
    sub    x13, x1, x2        # x13 = x1 - x2 (10 - (-5) = 15)
    and    x14, x1, x2        # x14 = x1 & x2
    or     x15, x1, x2        # x15 = x1 | x2
    xor    x16, x1, x2        # x16 = x1 ^ x2
    sll    x17, x1, x2        # x17 = x1 << (x2 & 0x1F)
    srl    x18, x1, x2        # x18 = x1 >> (x2 & 0x1F)
    sra    x19, x1, x2        # x19 = x1 >>> (x2 & 0x1F)
    slt    x20, x1, x2        # x20 = (x1 < x2) ? 1 : 0
    sltu   x21, x1, x2        # x21 = (x1 < x2) unsigned ? 1 : 0
    addi   x22, x1, 7         # x22 = x1 + 7
    andi   x23, x1, 3         # x23 = x1 & 3
    ori    x24, x1, 8         # x24 = x1 | 8
    xori   x25, x1, 4         # x25 = x1 ^ 4
    slli   x26, x1, 2         # x26 = x1 << 2
    srli   x27, x1, 1         # x27 = x1 >> 1
    srai   x28, x1, 1         # x28 = x1 >>> 1
    slti   x29, x1, -3        # x29 = (x1 < -3) ? 1 : 0
    sltiu  x30, x1, 20        # x30 = (x1 < 20) unsigned ? 1 : 0

    # ----------------------
    # Simulation Stop Signal
    # ----------------------
    li     x31, 0x2FFFC       # Load stop signal address into x31 using the li pseudoinstruction
    li     x10, 0xDEADBEEF    # Load stop signal value into x10
    sw     x10, 0(x31)        # Store at 0x2FFFC to signal simulation stop

    # Halt execution (Loop back indefinitely)
    j      _start            # Loop back to start (or replace with a termination mechanism)