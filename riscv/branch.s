# (c) 2025 Dr. Henry Duwe, Iowa State University

main:
	ori x1, x0, 0x123  # $00 : 12306093 
	j skip             # $04 : 0080006f
	li x31, 0xe0       # $08 : 0e000f93
skip:
	ori x2, x0, 0x123  # $0C : 12306113
	beq x1, x2, skip2  # $10 : 00208463
	li x31, 0xe1       # $14 : 0e100f93
skip2:
	jal fun            # $18 : 018000ef
	ori x4, x0, 0x123  # $1C : 12306213
	beq x1, x0, exit   # $20 : 00008c63
	ori x5, x0, 0x123  # $24 : 12306293
	j exit             # $28 : 0100006f
	li x31, 0xe2       # $2C : 0e200f93
fun:
	ori x3, x0, 0x123  # $30 : 12306193
	jr ra              # $34 : 00008067
exit:
	ebreak             # $38 : 00100073