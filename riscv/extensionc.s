###############################
## (c) 2026 Connor J. Link. All Rights Reserved.
## extensionc.s
###############################

# RV32C Extension Tests
# x2 contains the test number to diagnose failures easily
# x5 is the first arithmetic operand
# x6 is the second arithmetic operand
# x7 is the actual arithmetic result
# x8 is the expected arithmetic result

.option rvc

.data
.align 2
mem_data:   .word 0x12345678, 0x9ABCDEF0
scratch:    .word 0x0, 0x0

.text
_start:
    # Test 1.) c.lwsp: load word from stack pointer
    li x3, 1
    la x2, mem_data
    c.lwsp x7, 0(x2)
    mv x2, x3
    li x8, 0x12345678
    bne x7, x8, fail

    # Test 2.) c.lwsp: load with offset
    li x3, 2
    la x2, mem_data
    c.lwsp x7, 4(x2)
    mv x2, x3
    li x8, 0x9ABCDEF0
    bne x7, x8, fail

    # Test 3.) c.swsp: store word to stack pointer
    li x3, 3
    la x2, scratch
    li x5, 0xDEADBEEF
    c.swsp x5, 0(x2)
    lw x7, 0(x2)
    mv x2, x3
    li x8, 0xDEADBEEF
    bne x7, x8, fail

    # Test 4.) c.swsp: store with offset
    li x3, 4
    la x2, scratch
    li x5, 0xCAFEBABE
    c.swsp x5, 4(x2)
    lw x7, 4(x2)
    mv x2, x3
    li x8, 0xCAFEBABE
    bne x7, x8, fail

    # Test 5.) c.lw: load using C-registers
    li x2, 5
    la x9, mem_data
    c.lw x10, 0(x9)
    mv x7, x10
    li x8, 0x12345678
    bne x7, x8, fail

    # Test 6.) c.lw: load using C-registers with offset
    li x2, 6
    la x9, mem_data
    c.lw x10, 4(x9)
    mv x7, x10
    li x8, 0x9ABCDEF0
    bne x7, x8, fail

    # Test 7.) c.sw: store using C-registers
    li x2, 7
    la x9, scratch
    li x10, 0x11223344
    c.sw x10, 0(x9)
    lw x7, 0(x9)
    li x8, 0x11223344
    bne x7, x8, fail

    # Test 8.) c.sw: store using C-registers with offset
    li x2, 8
    la x9, scratch
    li x10, 0x55667788
    c.sw x10, 4(x9)
    lw x7, 4(x9)
    li x8, 0x55667788
    bne x7, x8, fail
    
    # Test 9.) c.j: unconditional jump forward
    li x2, 9
    c.j target_9
    j fail
target_9:

    # Test 10.) c.j: unconditional jump backward
    li x2, 10
    j setup_10
target_10:
    j end_10
setup_10:
    c.j target_10
    j fail
end_10:
    
    # Test 11.) c.j: unconditional jump tracking
    li x2, 11
    c.j target_11
    j fail
    nop
    nop
    nop
target_11:

    # Test 12.) c.jal: jump and link
    li x2, 12
    c.jal target_12
    j fail
target_12:
    # x1 === ra
    beqz x1, fail

    # Test 13.) c.jal: second jump and link check
    li x2, 13
    li x1, 0
    c.jal target_13
    j fail
target_13:
    beqz x1, fail
    
    # Test 14.) c.jr: jump register
    li x2, 14
    la x5, target_14
    c.jr x5
    j fail
target_14:

    # Test 15.) c.jr: jump register tracking
    li x2, 15
    la x5, target_15
    c.jr x5
    j fail
target_15:

    # Test 16.) c.jalr: jump and link register
    li x2, 16
    li x1, 0
    la x5, target_16
    c.jalr x5
    j fail
target_16:
    beqz x1, fail
    
    # Test 17.) c.jalr: verification
    li x2, 17
    li x1, 0
    la x5, target_17
    c.jalr x5
    j fail
target_17:
    beqz x1, fail

    # Test 18.) c.beqz: branch if zero - taken
    li x2, 18
    li x8, 0
    c.beqz x8, target_18
    j fail
target_18:

    # Test 19.) c.beqz: branch if zero - not taken
    li x2, 19
    li x8, 1
    c.beqz x8, fail

    # Test 20.) c.bnez: branch if not zero - taken
    li x2, 20
    li x8, 1
    c.bnez x8, target_20
    j fail
target_20:

    # Test 21.) c.bnez: branch if not zero - not taken
    li x2, 21
    li x8, 0
    c.bnez x8, fail

    # Test 22.) c.li: load immediate positive
    li x2, 22
    c.li x7, 15
    li x8, 15
    bne x7, x8, fail

    # Test 23.) c.li: load immediate negative
    li x2, 23
    c.li x7, -15
    li x8, -15
    bne x7, x8, fail

    # Test 24.) c.lui: load upper immediate positive
    li x2, 24
    c.lui x7, 0x12
    li x8, 0x12000
    bne x7, x8, fail

    # Test 25.) c.lui: load upper immediate negative
    li x2, 25
    c.lui x7, 0x3F
    li x8, 0x3F000
    bne x7, x8, fail

    # Test 26.) c.addi: add immediate
    li x2, 26
    li x7, 5
    c.addi x7, 10
    li x8, 15
    bne x7, x8, fail

    # Test 27.) c.addi: add immediate negative
    li x2, 27
    li x7, 5
    c.addi x7, -10
    li x8, -5
    bne x7, x8, fail

    # Test 28.) c.addi16sp: adjust sp positive
    li x3, 28
    li x2, 0x4000
    c.addi16sp x2, 64
    mv x7, x2
    mv x2, x3
    li x8, 0x4040
    bne x7, x8, fail

    # Test 29.) c.addi16sp: adjust sp negative
    li x3, 29
    li x2, 0x4000
    c.addi16sp x2, -64
    mv x7, x2
    mv x2, x3
    li x8, 0x3FC0
    bne x7, x8, fail
    
    # Test 30.) c.slli: shift left logical
    li x2, 30
    li x7, 2
    c.slli x7, 4
    li x8, 32
    bne x7, x8, fail

    # Test 31.) c.slli:
    li x2, 31
    li x7, 1
    c.slli x7, 31
    li x8, 0x80000000
    bne x7, x8, fail
    
    # Test 32.) c.addi4spn: load address from sp
    li x3, 32
    li x2, 0x2000
    c.addi4spn x10, x2, 12
    mv x7, x10
    mv x2, x3
    li x8, 0x200C
    bne x7, x8, fail
    
    # Test 33.) c.addi4spn: load address from sp
    li x3, 33
    li x2, 0x2000
    c.addi4spn x10, x2, 1020
    mv x7, x10
    mv x2, x3
    li x8, 0x23FC
    bne x7, x8, fail

    # Test 34.) c.srli: shift right constant
    li x2, 34
    li x10, 32
    c.srli x10, 4
    mv x7, x10
    li x8, 2
    bne x7, x8, fail

    # Test 35.) c.srli: shift right all bits
    li x2, 35
    li x10, 0x80000000
    c.srli x10, 31
    mv x7, x10
    li x8, 1
    bne x7, x8, fail

    # Test 36.) c.andi: and immediate
    li x2, 36
    li x10, 0xFF
    c.andi x10, 0x0F
    mv x7, x10
    li x8, 0x0F
    bne x7, x8, fail

    # Test 37.) c.andi: sign extended immediate
    li x2, 37
    li x10, 0xFF
    c.andi x10, -1
    mv x7, x10
    li x8, 0xFF
    bne x7, x8, fail
    
    # Test 38.) c.mv: move register
    li x2, 38
    li x9, 123
    c.mv x7, x9
    li x8, 123
    bne x7, x8, fail

    # Test 39.) c.mv: zero
    li x2, 39
    li x7, 456
    c.mv x7, x0
    li x8, 0
    bne x7, x8, fail

    # Test 40.) c.add: register + register
    li x2, 40
    li x7, 10
    li x9, 20
    c.add x7, x9
    li x8, 30
    bne x7, x8, fail

    # Test 41.) c.add: negative addition
    li x2, 41
    li x7, 10
    li x9, -15
    c.add x7, x9
    li x8, -5
    bne x7, x8, fail
    
    # Test 42.) c.and: register & register
    li x2, 42
    li x10, 0b1100
    li x11, 0b1010
    c.and x10, x11
    mv x7, x10
    li x8, 0b1000
    bne x7, x8, fail

    # Test 43.) c.and: disjoint bits
    li x2, 43
    li x10, 0x0F
    li x11, 0xF0
    c.and x10, x11
    mv x7, x10
    li x8, 0
    bne x7, x8, fail
    
    # Test 44.) c.or: register | register
    li x2, 44
    li x10, 0b1100
    li x11, 0b1010
    c.or x10, x11
    mv x7, x10
    li x8, 0b1110
    bne x7, x8, fail

    # Test 45.) c.or: identical bits
    li x2, 45
    li x10, 0xAA
    li x11, 0xAA
    c.or x10, x11
    mv x7, x10
    li x8, 0xAA
    bne x7, x8, fail
    
    # Test 46.) c.xor: register ^ register
    li x2, 46
    li x10, 0b1100
    li x11, 0b1010
    c.xor x10, x11
    mv x7, x10
    li x8, 0b0110
    bne x7, x8, fail

    # Test 47.) c.xor: cancel out
    li x2, 47
    li x10, 0xFF
    li x11, 0xFF
    c.xor x10, x11
    mv x7, x10
    li x8, 0
    bne x7, x8, fail
    
    # Test 48.) c.sub: subtract registers
    li x2, 48
    li x10, 20
    li x11, 5
    c.sub x10, x11
    mv x7, x10
    li x8, 15
    bne x7, x8, fail
    
    # Test 49.) c.sub: subtract negative
    li x2, 49
    li x10, 10
    li x11, -5
    c.sub x10, x11
    mv x7, x10
    li x8, 15
    bne x7, x8, fail
    
    # Test 50.) c.nop: do nothing
    li x2, 50
    li x7, 42
    c.nop
    li x8, 42
    bne x7, x8, fail

    # Success if execution reaches here
    j pass

fail:
    li x1, 1           # return 1 (EXIT_FAILURE)
    j end

pass:
    li x1, 0           # return 0 (EXIT_SUCCESS)

end:
    # Test 51.) c.ebreak:
    li x2, 51
    c.ebreak
