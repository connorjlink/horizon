###############################
## (c) 2026 Connor J. Link. All Rights Reserved.
## bubblesort.s
###############################

# t3 is the success/failure flag
# t4 contains the test number to diagnose failures easily

.data
before: .word 1, 5, 4, 3, 2

after: .word 1, 2, 3, 4, 5

.text
_start:
    # since RV32I doesn't really mandate a specific stack pointer base, we'll use what RARS uses :)
    li sp, 0x7FFFEFFC  # 7ffff137
                       # ffc10113
 
    # Test 1.) bubblesort N = 5, input = [1, 5, 4, 3, 2]
    li a0, 5           # 00500513
    la a1, before      # 0fc10597
                       # ff458593
    jal ra, bubblesort # 03c000ef

    # Compare results  
    la t0, before      # 0fc10297
                       # fe828293
    la t1, after       # 0fc10317
                       # ff430313
    li t2, 5           # 00500393

compare_loop:
    beq t2, x0, done   # 02038063 ; 3800ns
    lw t5, 0(t0)       # 0002af03
    lw t6, 0(t1)       # 00032f83
    bne t5, t6, fail   # 09ff1063
    addi t0, t0, 4     # 00428293
    addi t1, t1, 4     # 00430313
    addi t2, t2, -1    # fff38393
    j compare_loop     # fe5ff06f

done:
    # Success if execution reaches here
    j pass


# Signature: void bubblesort(int N, int array[])
bubblesort:
    # Standard prologue
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    addi s0, sp, 16

    # My bubble sorting algorithm
    # - a0 contains N
    # - a1 contains address to array

    beq a0, x0, sorted     # no need to sort an empty array

outer_loop:
    add t0, x0, x0         # bool was_swapped = false;
    add t1, x0, x0         # int i = 0;
    add t2, a0, x0         # int max = n - 1;
    addi t2, t2, -1

inner_loop:                # do {
    slli t3, t1, 2         # int offset = i * sizeof(array[0]);
    add t4, a1, t3         # ; effective address = array base + offset
    lw t5, 0(t4)           # ; t5 = array[i]
    lw t6, 4(t4)           # ; t6 = array[i+1]

    ble t5, t6, skip_swap  # if (arr[i] <= arr[i+1]) goto skip;
                           # else {
    sw t6, 0(t4)           # array[i] = array[i+1];
    sw t5, 4(t4)           # array[i+1] = array[i];
    li t0, 1               # swapped = 1;
                           # }

skip_swap:
    addi t1, t1, 1         # ++i;
    blt t1, t2, inner_loop # if (i < max) continue;
    beq t0, x0, sorted     # if (!was_swapped) break;

    addi a0, a0, -1        # --n;
                           # ; NOTE: mutating the argument variable to indicate the number of elements left to sort
    bgtz a0, outer_loop    # } while (n > 0);

sorted:

    # Standard epilogue
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    jr ra


fail:
    li t3, 1           # return EXIT_FAILURE;
    li t4, 0xFA11
    j end

pass:
    li t3, 0           # return EXIT_SUCCESS;
    li t4, 0xC0FFEE

end:
    ebreak
    