###############################
## (c) 2026 Connor J. Link. All Rights Reserved.
## control_flow.s
###############################

# t3 contains whether or not the program was successful
# t4 contains the test number to diagnose failures easily

.text
_start:
    # since RV32I doesn't really mandate a specific stack pointer base, we'll use what RARS uses :)
    li sp, 0x7FFFEFFC # 7ffff137 ; lui x2, $7ffff
                      # ffc10113 ; addi x2, x2, $fffffffc

    # Test 1.) depth = 0
    li t4, 1
    jal ra, function1
   
    # Success if execution reaches here
    j pass


# Signature: void function1(void)
# Description: test linking to other function calls off a fresh stack
function1:
    # Standard prologue
    addi sp, sp, -16 # ff010113
    sw ra, 12(sp)    # 00112623
    sw s0, 8(sp)     # 00812423
    addi s0, sp, 16  # 01010413

    # Test 2.) depth = 1
    li t4, 2
    jal ra, function2

    # expect a return value of 0
    bne a0, x0, fail

    # Standard epilogue
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    jr ra


# Signature: bool function2(void)
# Description: return whether a number is less a computed value from another function call
function2:
    # Standard prologue
    addi sp, sp, -16 
    sw ra, 12(sp)
    sw s0, 8(sp)
    addi s0, sp, 16

    # Test 3.) depth = 2
    li t4, 3
    jal ra, function3
    slti a0, a0, 34

    # Standard epilogue
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    jr ra


# Signature int function3(void)
# Description: shift left once from a function value and return
function3:
    # Standard prologue
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    addi s0, sp, 16

    # Test 4.) depth = 3
    li t4, 4
    jal ra, function4
    slli a0, a0, 1

    # Standard epilogue
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    jr ra


# Signature: int function4(void)
# Description: add 2 to the value from a function and return to existing record
function4:
    # Standard prologue
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    addi s0, sp, 16

    # Test 5.) depth = 4 (total activation records = 5)
    li t4, 5
    jal ra, function5
    addi a0, a0, 2

    # Standard epilogue
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    jr ra


# Signature: int function5(void)
# Description: compute a value (15) and return to existing function
function5:
    # Standard prologue
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    addi s0, sp, 16

    li t4, 6
    li t0, 5
    li t1, 10
    add a0, t0, t1

    # Standard epilogue
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    jr ra


fail:
    li t3, 1      # return 1 (EXIT_FAILURE)a
    j end

pass:
    li t3, 0      # return 0 (EXIT_SUCCESS)
    li t4, 0xF00D # 0000feb7 ; lui x29, 15
                  # 00de8e93 ; addi x29, x29, 13

end:
    ebreak
