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

.text
_start:

    ebreak
