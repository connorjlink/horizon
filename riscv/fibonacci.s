# Compute several Fibonacci numbers and put in array, then print
# s0 = x8/fp
# s1 = x9 
# s2 = x18
# s3 = x19
# s4 = x20
# s5 = x21
# s6 = x22

# a0 = x10
# a1 = x11
# a7 = x17

# t0 = x5
# t1 = x6
# t2 = x7

.data
fibs: .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
size: .word 19
prompt: .asciz "How many Fibonacci numbers to generate? (2 <= x <= 19)"
.text
    la   x8,    fibs      # $00 : 0fc10417
                          # $04 : 00040413
    la   x21,   size      # $08 : 0fc10a97
                          # $0C : 044a8a93
    lw   x21, 0(x21)      # $10 : 000aaa83 
    li   x18, 1           # $14 : 00100913 
    sw   x18, 0(x8)       # $18 : 01242023 
    sw   x18, 4(x8)       # $1C : 01242223
    addi x9,    x21, -2   # $20 : ffea8493
                        
loop:
    lw   x19, 0(x8)       # $24 : 00042983 
    lw   x20, 4(x8)       # $28 : 00442a03
    add  x18,   x19, x20  # $2C : 01498933
    sw   x18, 8(x8)       # $30 : 01242423 
    addi x8,    x8,  4    # $34 : 00440413
    addi x9,    x9, -1    # $38 : fff48493
    bne  x9,    x0, loop  # $3C : fe0494e3 
    la   x10,   fibs      # $40 : 0fc10517
                          # $44 : fc050513
    add  x11, x0, x21     # $48 : 015005b3
    jal  print            # $4C : 008000ef

    j die                 # $50 : 0480006f

    .data
space:.asciz  " "
head: .asciz  "The Fibonacci numbers are:\n"
    .text
print:
    add  x5,     x0,  x10 # $54 : 00a002b3
    add  x6,     x0,  x11 # $58 : 00b00333
    la   x10,    head     # $5C : 0fc10517
                          # $60 : 02d50513
    ori  x17,    x0,  4   # $64 : 00406893
    ecall                 # $68 : 00000073
    
out:
    lw    x10, 0(x5)      # $6C : 0002a503
    ori   x17,   x0,  1   # $70 : 00106893
    ecall                 # $74 : 00000073
    
    la    x10,   space    # $78 : 0fc10517
                          # $7C : 00f50513
    ori   x17,   x0,  4   # $80 : 00406893
    ecall                 # $84 : 00000073
    
    addi  x5,    x5,  4   # $88 : 00428293
    addi  x6,    x6, -1   # $8C : fff30313
    bne   x6,    x0, out  # $90 : fc031ee3
    
    jr    ra              # $94 : 00008067
    
die:
    ebreak
    