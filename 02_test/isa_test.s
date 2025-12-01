# ISA Test with formatted output to LEDR
# Each test prints test name followed by PASS/FAIL
# Memory-mapped I/O: LEDR at 0x10000000

.section .text
.globl _start

_start:
    # Initialize LEDR address
    lui  x31, 0x10000        # x31 = 0x10000000 (LEDR base address)

    # Test 1: ADD instruction
    jal  x1, print_add
    addi x10, x0, 5
    addi x11, x0, 7
    add  x12, x10, x11
    addi x13, x0, 12
    beq  x12, x13, test1_pass
    jal  x1, print_fail
    jal  x0, test2
test1_pass:
    jal  x1, print_pass
    jal  x0, test2

test2:
    # Test 2: SUB instruction
    jal  x1, print_sub
    addi x10, x0, 10
    addi x11, x0, 3
    sub  x12, x10, x11
    addi x13, x0, 7
    beq  x12, x13, test2_pass
    jal  x1, print_fail
    jal  x0, test3
test2_pass:
    jal  x1, print_pass
    jal  x0, test3

test3:
    # Test 3: AND instruction
    jal  x1, print_and
    lui  x10, 0xAAAAA
    addi x10, x10, 0x555
    lui  x11, 0x55555
    addi x11, x11, 0x555
    and  x12, x10, x11
    addi x13, x0, 0x555
    beq  x12, x13, test3_pass
    jal  x1, print_fail
    jal  x0, test4
test3_pass:
    jal  x1, print_pass
    jal  x0, test4

test4:
    # Test 4: OR instruction
    jal  x1, print_or
    addi x10, x0, 0x0F
    addi x11, x0, 0xF0
    or   x12, x10, x11
    addi x13, x0, 0xFF
    beq  x12, x13, test4_pass
    jal  x1, print_fail
    jal  x0, test5
test4_pass:
    jal  x1, print_pass
    jal  x0, test5

test5:
    # Test 5: XOR instruction
    jal  x1, print_xor
    addi x10, x0, 0xFF
    addi x11, x0, 0xAA
    xor  x12, x10, x11
    addi x13, x0, 0x55
    beq  x12, x13, test5_pass
    jal  x1, print_fail
    jal  x0, done
test5_pass:
    jal  x1, print_pass
    jal  x0, done

done:
    # Write newline
    addi x2, x0, 10
    sb   x2, 0(x31)
    
    # HALT - store to 0xFFFFFFFC
    addi x30, x0, -4
    sw   x0, 0(x30)
    
    # Infinite loop
halt_loop:
    jal  x0, halt_loop

# Print functions
print_add:
    addi x2, x0, 'a'
    sb   x2, 0(x31)
    addi x2, x0, 'd'
    sb   x2, 0(x31)
    addi x2, x0, 'd'
    sb   x2, 0(x31)
    jal  x0, print_dots

print_sub:
    addi x2, x0, 's'
    sb   x2, 0(x31)
    addi x2, x0, 'u'
    sb   x2, 0(x31)
    addi x2, x0, 'b'
    sb   x2, 0(x31)
    jal  x0, print_dots

print_and:
    addi x2, x0, 'a'
    sb   x2, 0(x31)
    addi x2, x0, 'n'
    sb   x2, 0(x31)
    addi x2, x0, 'd'
    sb   x2, 0(x31)
    jal  x0, print_dots

print_or:
    addi x2, x0, 'o'
    sb   x2, 0(x31)
    addi x2, x0, 'r'
    sb   x2, 0(x31)
    addi x2, x0, '.'
    sb   x2, 0(x31)
    jal  x0, print_dots

print_xor:
    addi x2, x0, 'x'
    sb   x2, 0(x31)
    addi x2, x0, 'o'
    sb   x2, 0(x31)
    addi x2, x0, 'r'
    sb   x2, 0(x31)
    jal  x0, print_dots

print_dots:
    addi x2, x0, '.'
    sb   x2, 0(x31)
    addi x2, x0, '.'
    sb   x2, 0(x31)
    addi x2, x0, '.'
    sb   x2, 0(x31)
    addi x2, x0, '.'
    sb   x2, 0(x31)
    addi x2, x0, '.'
    sb   x2, 0(x31)
    addi x2, x0, '.'
    sb   x2, 0(x31)
    jalr x0, x1, 0

print_pass:
    addi x2, x0, 'P'
    sb   x2, 0(x31)
    addi x2, x0, 'A'
    sb   x2, 0(x31)
    addi x2, x0, 'S'
    sb   x2, 0(x31)
    addi x2, x0, 'S'
    sb   x2, 0(x31)
    addi x2, x0, 10         # newline
    sb   x2, 0(x31)
    jalr x0, x1, 0

print_fail:
    addi x2, x0, 'F'
    sb   x2, 0(x31)
    addi x2, x0, 'A'
    sb   x2, 0(x31)
    addi x2, x0, 'I'
    sb   x2, 0(x31)
    addi x2, x0, 'L'
    sb   x2, 0(x31)
    addi x2, x0, 10         # newline
    sb   x2, 0(x31)
    jalr x0, x1, 0
