    add $s0, $zero, $zero, $zero, 0, 0  # i = 0
outer_loop:
    beq $zero, $imm2, $s0, $imm1, end_outer_loop, 4  # if i == 4, exit outer loop    Check if i == 4 (end of rows in A)
    add $s1, $zero, $zero, $zero, 0, 0  # j = 0 # Initialize j = 0
inner_loop:
    beq $zero, $imm2, $s1, $imm1, end_inner_loop, 4  # if j == 4, exit inner loop     Check if j == 4 (end of columns in B)
    add $t0, $zero, $zero, $zero, 0, 0  # k = 0 # Initialize k = 0, sum = 0
    add $s2, $zero, $zero, $zero, 0, 0  # sum = 0
mul_loop: 
    beq $zero, $imm2, $t0, $imm1, end_mul_loop, 4  # if k == 4, exit mul loop   Check if k == 4 (end of columns in A or rows in B)
    sll $a1, $s0, $imm1, $zero, 2, 0  # Address offset = i * 4 (shift left by 2) # Load A[i][k] into $t1
    add $a1, $a1, $t0, $zero, 0, 0   # Address = i * 4 + k
    add $a1, $a1, $imm1, $zero, 256, 0  # Base address of A
    lw $t1, $a1, $zero, $zero, 0, 0  # $t1 = A[i][k]
    sll $a1, $t0, $imm1, $zero, 2, 0  # Address offset = k * 4 (shift left by 2)  # Load B[k][j] into $t2
    add $a1, $a1, $s1, $zero, 0, 0   # Address = k * 4 + j
    add $a1, $a1, $imm1, $zero, 272, 0  # Base address of B
    lw $t2, $a1, $zero, $zero, 0, 0  # $t2 = B[k][j]
    mac $s2, $t1, $t2, $s2, 0, 0  # sum += $t1 * $t2  # Multiply and accumulate: sum += A[i][k] * B[k][j]    
    add $t0, $t0, $imm1, $zero, 1, 0  # k = k + 1 # Increment k
    beq $zero, $zero, $zero, $imm1, mul_loop, 0  # Loop back
end_mul_loop:     # Store result C[i][j] = sum
    sll $a1, $s0, $imm1, $zero, 2, 0  # Address offset = i * 4 (shift left by 2)
    add $a1, $a1, $s1, $zero, 0, 0   # Address = i * 4 + j
    add $a1, $a1, $imm1, $zero, 288, 0  # Base address of C
    sw $s2, $a1, $zero, $zero, 0, 0  # C[i][j] = sum  // check if sw wor good
    add $s1, $s1, $imm1, $zero, 1, 0  # j = j + 1     # Increment j
    beq $zero, $zero, $zero, $imm1, inner_loop, 0  # Loop back
end_inner_loop: 
    add $s0, $s0, $imm1, $zero, 1, 0  # i = i + 1 # Increment i
    beq $zero, $zero, $zero, $imm1, outer_loop, 0  # Loop back
end_outer_loop:
    halt $zero, $zero, $zero, $zero, 0, 0   # End program

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