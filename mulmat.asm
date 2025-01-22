###########################################################
# Initialize i = 0
###########################################################
    add   $s0, $zero, $zero, $zero, 0, 0    # i = 0

ROW_LOOP:
    # if (i == 4) then exit the row loop
    beq   $zero, $imm2, $s0, $imm1, END_ROW_LOOP, 4

    ###########################################################
    # Initialize j = 0
    ###########################################################
    add   $s1, $zero, $zero, $zero, 0, 0    # j = 0

COLUMN_LOOP:
    # if (j == 4) then exit the column loop
    beq   $zero, $imm2, $s1, $imm1, END_COLUMN_LOOP, 4

    ###########################################################
    # Initialize k = 0, sum = 0
    ###########################################################
    add   $t0, $zero, $zero, $zero, 0, 0    # k = 0
    add   $s2, $zero, $zero, $zero, 0, 0    # sum = 0

MULT_LOOP:
    # if (k == 4) then exit multiplication loop
    beq   $zero, $imm2, $t0, $imm1, END_MULT_LOOP, 4
    
    # Calculate address of A[i][k]
    sll   $a1, $s0,   $imm1, $zero, 2, 0      # offset = i * 4
    add   $a1, $a1,   $t0,   $zero, 0,   0      # offset += k
    add   $a1, $a1,   $imm1, $zero, 256, 0     # base address of A
    lw    $t1, $a1,   $zero, $zero, 0,   0      # $t1 = A[i][k]

    # Calculate address of B[k][j]
    sll   $a1, $t0,   $imm1, $zero, 2, 0      # offset = k * 4
    add   $a1, $a1,   $s1,   $zero, 0,   0      # offset += j
    add   $a1, $a1,   $imm1, $zero, 272, 0     # base address of B
    lw    $t2, $a1,   $zero, $zero, 0,   0      # $t2 = B[k][j]

    # sum += A[i][k] * B[k][j]
    mac   $s2, $t1, $t2, $s2, 0, 0

    # k++
    add   $t0, $t0, $imm1, $zero, 1, 0

    # Repeat until k == 4
    beq   $zero, $zero, $zero, $imm1, MULT_LOOP, 0

END_MULT_LOOP:
    # Now store sum into C[i][j]
    sll   $a1, $s0,   $imm1, $zero, 2, 0      # offset = i * 4
    add   $a1, $a1,   $s1,   $zero, 0,   0      # offset += j
    add   $a1, $a1,   $imm1, $zero, 288, 0     # base address of C
    sw    $s2, $a1,   $zero, $zero, 0,   0      # C[i][j] = sum

    # j++
    add   $s1, $s1, $imm1, $zero, 1, 0
    
    # Repeat until j == 4
    beq   $zero, $zero, $zero, $imm1, COLUMN_LOOP, 0

END_COLUMN_LOOP:
    # i++
    add   $s0, $s0, $imm1, $zero, 1, 0

    # Repeat until i == 4
    beq   $zero, $zero, $zero, $imm1, ROW_LOOP, 0

END_ROW_LOOP:
    halt  $zero, $zero, $zero, $zero, 0, 0

###########################################################
# Data Section
#
# The first 16 words (addresses 256..271) are matrix A.
# The next 16 words (addresses 272..287) are matrix B.
# The code stores matrix C at addresses 288..303.
###########################################################

    .word 256 1
    .word 257 2
    .word 258 3
    .word 259 4
    .word 260 5
    .word 261 6
    .word 262 7
    .word 263 8
    .word 264 9
    .word 265 10
    .word 266 11
    .word 267 12
    .word 268 13
    .word 269 14
    .word 270 15
    .word 271 16

    .word 272 1
    .word 273 2
    .word 274 3
    .word 275 4
    .word 276 5
    .word 277 6
    .word 278 7
    .word 279 8
    .word 280 9
    .word 281 10
    .word 282 11
    .word 283 12
    .word 284 13
    .word 285 14
    .word 286 15
    .word 287 16
