###############################
## (c) 2026 Connor J. Link. All Rights Reserved.
## extensionm.s
###############################

# RV32M Extension Tests
# x2 contains the test number to diagnose failures easily
# x5 is the first arithmetic operand
# x6 is the second arithmetic operand
# x7 is the actual arithmetic result
# x8 is the expected arithmetic result

.text
_start:
    # Test 1.) mul: small positive
    li x2, 1
    li x5, 7
    li x6, 6
    li x8, 42
    mul x7, x5, x6
    bne x7, x8, fail

    # Test 2.) mul: negative * positive
    li x2, 2
    li x5, -7
    li x6, 6
    li x8, -42
    mul x7, x5, x6
    bne x7, x8, fail

    # Test 3.) mul: overflow wraps (low 32 bits)
    li x2, 3
    li x5, 0x80000000
    li x6, 2
    li x8, 0x00000000
    mul x7, x5, x6
    bne x7, x8, fail

    # Test 4.) mulh: (2^30) * (2^30) = 2^60 => high32 = 0x10000000
    li x2, 4
    li x5, 0x40000000
    li x6, 0x40000000
    li x8, 0x10000000
    mulh x7, x5, x6
    bne x7, x8, fail

    # Test 5.) mulh: (-2^31) * 2 = 0xFFFFFFFF00000000 => high32 = 0xFFFFFFFF
    li x2, 5
    li x5, 0x80000000
    li x6, 2
    li x8, 0xFFFFFFFF
    mulh x7, x5, x6
    bne x7, x8, fail

    # Test 6.) mulhsu: (0x7FFFFFFF signed) * (0xFFFFFFFF unsigned)
    # 0x7FFFFFFF * 0xFFFFFFFF = 0x7FFFFFFE80000001 => high32 = 0x7FFFFFFE
    li x2, 6
    li x5, 0x7FFFFFFF
    li x6, 0xFFFFFFFF
    li x8, 0x7FFFFFFE
    mulhsu x7, x5, x6
    bne x7, x8, fail

    # Test 7.) mulhu: (2^32-1) * (2^32-1) = 0xFFFFFFFE00000001 => high32 = 0xFFFFFFFE
    li x2, 7
    li x5, 0xFFFFFFFF
    li x6, 0xFFFFFFFF
    li x8, 0xFFFFFFFE
    mulhu x7, x5, x6
    bne x7, x8, fail

    # Test 8.) div: 20 / 5 = 4
    li x2, 8
    li x5, 20
    li x6, 5
    li x8, 4
    div x7, x5, x6
    bne x7, x8, fail

    # Test 9.) div: -20 / 5 = -4 (truncate toward zero)
    li x2, 9
    li x5, -20
    li x6, 5
    li x8, -4
    div x7, x5, x6
    bne x7, x8, fail

    # Test 10.) div: overflow case INT_MIN / -1 = INT_MIN
    li x2, 10
    li x5, 0x80000000
    li x6, -1
    li x8, 0x80000000
    div x7, x5, x6
    bne x7, x8, fail

    # Test 11.) div: divide by zero => -1
    li x2, 11
    li x5, 123
    li x6, 0
    li x8, -1
    div x7, x5, x6
    bne x7, x8, fail

    # Test 12.) divu: 0xFFFFFFFE / 2 = 0x7FFFFFFF
    li x2, 12
    li x5, 0xFFFFFFFE
    li x6, 2
    li x8, 0x7FFFFFFF
    divu x7, x5, x6
    bne x7, x8, fail

    # Test 13.) divu: divide by zero => 0xFFFFFFFF
    li x2, 13
    li x5, 0x12345678
    li x6, 0
    li x8, 0xFFFFFFFF
    divu x7, x5, x6
    bne x7, x8, fail

    # Test 14.) rem: 20 % 6 = 2
    li x2, 14
    li x5, 20
    li x6, 6
    li x8, 2
    rem x7, x5, x6
    bne x7, x8, fail

    # Test 15.) rem: -20 % 6 = -2 (remainder sign follows dividend)
    li x2, 15
    li x5, -20
    li x6, 6
    li x8, -2
    rem x7, x5, x6
    bne x7, x8, fail

    # Test 16.) rem: overflow case INT_MIN % -1 = 0
    li x2, 16
    li x5, 0x80000000
    li x6, -1
    li x8, 0
    rem x7, x5, x6
    bne x7, x8, fail

    # Test 17.) rem: divide by zero => dividend
    li x2, 17
    li x5, -123
    li x6, 0
    li x8, -123
    rem x7, x5, x6
    bne x7, x8, fail

    # Test 18.) remu: 0xFFFFFFFE % 3 = 2
    li x2, 18
    li x5, 0xFFFFFFFE
    li x6, 3
    li x8, 2
    remu x7, x5, x6
    bne x7, x8, fail

    # Test 19.) remu: divide by zero => dividend
    li x2, 19
    li x5, 0x12345678
    li x6, 0
    li x8, 0x12345678
    remu x7, x5, x6
    bne x7, x8, fail

    # Success if execution reaches here
    j pass

fail:
    li x1, 1           # return 1 (EXIT_FAILURE)
    j end

pass:
    li x1, 0           # return 0 (EXIT_SUCCESS)

end:
    ebreak
