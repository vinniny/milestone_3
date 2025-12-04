# Simple RISC-V Test to Verify Basic Functionality
# This test verifies:
# 1. ALU operations (add, sub)
# 2. Load/Store
# 3. Branches
# 4. Jumps
# 5. I/O output (LEDR at 0x10000000)

.global _start

_start:
    # Initialize base pointers
    lui x2, 0x10000        # x2 = 0x10000000 (LEDR base)
    lui x3, 0x1            # x3 = 0x00001000 (data memory base)
    
    # Test 1: Basic ALU
    addi x10, x0, 10       # x10 = 10
    addi x11, x0, 20       # x11 = 20
    add x12, x10, x11      # x12 = 30
    sub x13, x12, x10      # x13 = 20
    
    # Test 2: Memory operations
    sw x12, 0(x3)          # Store 30 to 0x1000
    lw x14, 0(x3)          # Load from 0x1000, x14 = 30
    
    # Test 3: Branch test
    beq x14, x12, branch_ok # Should take (30 == 30)
    addi x15, x0, 99       # Should NOT execute (branch taken)
    jal x0, fail
    
branch_ok:
    addi x15, x0, 100      # x15 = 100 (marker for branch success)
    
    # Test 4: Output 'P' to LEDR
    addi x16, x0, 0x50     # ASCII 'P'
    sw x16, 0(x2)          # Write to LEDR
    
    # Test 5: Jump test
    jal x1, jump_target    # Jump and save return address
    addi x17, x0, 99       # Should NOT execute
    jal x0, fail
    
jump_target:
    jalr x0, x1, 0         # Return (to next instruction after jal)
    
    # Test 6: Output 'A' to LEDR  
    addi x18, x0, 0x41     # ASCII 'A'
    sw x18, 0(x2)
    
    # Test 7: Output 'S' to LEDR
    addi x19, x0, 0x53     # ASCII 'S'
    sw x19, 0(x2)
    
    # Test 8: Output 'S' to LEDR again
    sw x19, 0(x2)
    
    # Success: Jump to completion marker at 0x1c (ebreak)
    lui x20, 0             # x20 = 0
    addi x20, x20, 0x1c    # x20 = 0x1c
    jalr x0, x20, 0        # Jump to 0x1c (ebreak location)
    
fail:
    # Failure: Output 'F' and halt
    addi x21, x0, 0x46     # ASCII 'F'
    sw x21, 0(x2)
    jal x0, fail           # Infinite loop
    
# Padding to place ebreak at 0x1c
.align 2
.org 0x1c
    ebreak                 # Test completion marker

# Infinite loop at 0x20
.org 0x20
loop:
    jal x0, loop
