############################################################
#  Initialize Stack Pointer and Load Inputs (n, k)
############################################################

      add   $sp,   $zero, $imm1,  $zero, 0x6FF, 0      # $sp = 4090 (top of stack)
      lw    $a0,   $imm1, $zero,  $zero, 256,   0      # $a0 = Memory[256] = n
      lw    $a1,   $imm1, $zero,  $zero, 257,   0      # $a1 = Memory[257] = k
      add   $s0,   $zero, $zero,  $zero, 0,     0      # $s0 = 0
      add   $ra,   $zero, $zero,  $imm1, FINISH, 0     # $ra = address of FINISH

############################################################
#  Compute Binomial (Recursive Function)
############################################################
BINOMIAL:
      # Make space on stack and store registers
      add   $sp,   $sp,   $imm1,  $zero, -4,    0
      sw    $ra,   $sp,   $zero,  $zero, 0,     0
      sw    $a0,   $sp,   $imm1,  $zero, 1,     0
      sw    $a1,   $sp,   $imm1,  $zero, 2,     0
      sw    $s0,   $sp,   $imm1,  $zero, 3,     0

      # If k == 0, jump to CHECK_N_OR_K
      bne   $zero, $a1,   $zero,  $imm1, CHECK_K_NOT_ZERO, 0
      beq   $zero, $zero, $zero,  $imm1, CHECK_N_OR_K,     0

CHECK_K_NOT_ZERO:
      # If n != k, jump to L_CONTINUE
      bne   $zero, $a0,   $a1,    $imm1, L_CONTINUE, 0

CHECK_N_OR_K:
      # If we reach here, then (k==0) or (n==k) => s0 = 1
      add   $s0,   $zero, $imm1,  $zero, 1,     0
      beq   $zero, $zero, $zero,  $imm1, L_RETURN, 0

L_CONTINUE:
      # Decrement n and recurse: binomial(n-1, k)
      add   $a0,   $a0,   $imm1,  $zero, -1,    0
      jal   $ra,   $zero, $zero,  $imm1, BINOMIAL, 0

BIN_RECURSE_1:
      # Decrement k and recurse: binomial(n-1, k-1)
      add   $a1,   $a1,   $imm1,  $zero, -1,    0
      jal   $ra,   $zero, $zero,  $imm1, BINOMIAL, 0

L_RETURN:
      # Add local result (s0) to $v0, then restore saved values
      add   $v0,   $v0,   $s0,    $zero, 0,     0
      add   $s0,   $zero, $zero,  $zero, 0,     0
      lw    $ra,   $sp,   $zero,  $zero, 0,     0
      lw    $a0,   $sp,   $imm1,  $zero, 1,     0
      lw    $a1,   $sp,   $imm1,  $zero, 2,     0
      lw    $s0,   $sp,   $imm1,  $zero, 3,     0
      add   $sp,   $sp,   $imm1,  $zero, 4,     0
      jal   $t2,   $zero, $zero,  $ra,   0,     0

############################################################
#  End of Program: Store Result and Halt
############################################################
FINISH:
      sw    $v0,   $zero, $imm1,  $zero, 258,   0   # Memory[258] = $v0
      halt  $zero, $zero, $zero,  $zero, 0,     0   # Stop simulation

############################################################
#  Data Section
############################################################
      .word 0x100  4    # At address 0x100 (decimal 256): 4
      .word 0x101  2    # At address 0x101 (decimal 257): 2
