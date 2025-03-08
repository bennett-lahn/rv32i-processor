.section .text
.global _start

_start:
    # Simple addi, store, load, arithmetic test (no negative or large numbers)
    addi x1, x0, 5      # x1 = 5
    addi x2, x0, 1024   # Base memory address (aligned)
    nop
    nop
    nop
    nop
    sw   x1, 0(x2)      # Store x1 (5) at 0x0400
    nop
    nop # with only two nops, load was skipped for some reason?
    nop
    lw   x3, 0(x2)      # Load from memory -> x3 = 5
    nop
    nop
    add  x4, x3, x3     # x4 = x3 + x3 = 5 + 5 = 10
    nop
    nop

    # Initialize registers with values (using valid immediate range)
    addi x3, x0, 10     # x3 = 10
    addi x5, x0, -5     # x5 = -5 (negative for signed tests)
    addi x6, x0, 255    # x6 = 255 (0xFF, useful for byte tests)
    addi x7, x0, 1024   # x7 = 1024 (useful for halfword tests)
    addi x8, x0, 2047   # x8 = 2047 (max positive 12-bit value)

    # Store values to memory
    sw  x3,  0(x2)       # Store word (10) at 0x0400
    sh  x5,  4(x2)       # Store halfword (-5) at 0x0404
    sb  x6,  6(x2)       # Store byte (255) at 0x0406
    sh  x7,  8(x2)       # Store halfword (1024) at 0x0408
    sw  x8,  12(x2)      # Store word (2047) at 0x040C

    # Load values back from memory
    lw  x10,  0(x2)      # Load word from 0x0400 -> x10 = 10
    lh  x11,  4(x2)      # Load halfword from 0x0404 -> x11 = -5
    lhu x12, 4(x2)       # Load halfword unsigned from 0x0404 -> x12 = 65531
    lb  x13, 6(x2)       # Load byte from 0x0406 -> x13 = -1
    lbu x14, 6(x2)       # Load byte unsigned from 0x0406 -> x14 = 255
    lh  x15, 8(x2)       # Load halfword from 0x0408 -> x15 = 1024
    lhu x16, 8(x2)       # Load halfword unsigned from 0x0408 -> x16 = 1024
    lw  x17, 12(x2)      # Load word from 0x040C -> x17 = 2047

    # Perform arithmetic operations to verify loads
    add x19, x10, x11    # x19 = 10 + (-5) = 5
    add x20, x12, x13    # x20 = 65531 + (-1) = 65530
    add x21, x14, x15    # x21 = 255 + 1024 = 1279
    sub x22, x16, x17    # x22 = 1024 - 2047 = -1023

    # Conditional branch to test loads impact on flow
    bge x19, x5, label1  # Branch if 5 >= -5 (should be taken)
    addi x24, x0, 999    # Should be skipped if branch is taken

label1:
    addi x25, x0, 123    # Executed if branch taken

    # Jump test (control flow)
    jal x26, jump_dest   # Jump and link
    add x27, x26, x26    # Should be skipped

jump_dest:
    addi x28, x0, 456    # Should be executed
    nop
    nop
    nop
    nop

# Halt signal not implemented (li would cause data hazard)
