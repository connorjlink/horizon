.data
before: .word 0

.text
li t0, 0x1000
la t1, before
la t2, before
add t2, t2, t0

start:
    addi t1, t1, 4
    sw t1, 0(t1)
    lw t1, 0(t1)
    blt t1, t2, start
end:
    ebreak
    