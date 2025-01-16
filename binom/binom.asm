###############################################
# BINOMIAL COEFFICIENT (ALTERNATE VERSION)
# Calculates binom(n, k) recursively and stores
# the result in memory address 0x102 (decimal 258).
###############################################

        # 1) Set $ra to jump to the end of the program when done.
        add     $ra,   $zero, $zero, $imm1, PROG_DONE, 0     
        # 2) Initialize stack pointer to 4090 (0x6FF).
        add     $sp,   $zero, $imm1, $zero, 0x6FF,     0     # $sp = 4090
        # 3) Load n from Memory[256] => $a0
        lw      $a0,   $imm1, $zero, $zero, 256,       0     
        # 4) Load k from Memory[257] => $a1
        lw      $a1,   $imm1, $zero, $zero, 257,       0     
        # 5) Initialize $s0 to 0
        add     $s0,   $zero, $zero, $zero, 0,         0     

###############################################
# FUNC_BINOM: Computes binom($a0, $a1)
###############################################
FUNC_BINOM:
        # Create stack frame: push 4 words ($ra, $a0, $a1, $s0)
        add     $sp,   $sp,   $imm1,  $zero, -4,  0    
        sw      $ra,   $sp,   $zero,  $zero,   0,   0 
        sw      $a0,   $sp,   $imm1,  $zero,   1,   0 
        sw      $a1,   $sp,   $imm1,  $zero,   2,   0 
        sw      $s0,   $sp,   $imm1,  $zero,   3,   0 

        # If k != 0 => jump to label CHECK_K_ISNT_ZERO
        bne     $zero, $a1,   $zero,  $imm1, CHECK_K_ISNT_ZERO, 0
        # Else (k == 0) => skip to label K_IS_ZERO_PATH
        beq     $zero, $zero, $zero,  $imm1, K_IS_ZERO_PATH,    0

CHECK_K_ISNT_ZERO:
        # If n != k => jump to label N_K_NOT_EQUAL
        bne     $zero, $a0,   $a1,    $imm1, N_K_NOT_EQUAL,     0

K_IS_ZERO_PATH:
        # If we got here => (k == 0) or (n == k)
        add     $s0,   $zero, $imm1,  $zero, 1, 0     # s0 = 1
        beq     $zero, $zero, $zero,  $imm1, BINOM_RET, 0

N_K_NOT_EQUAL:
        # Decrement n: (n = n - 1)
        add     $a0,   $a0,   $imm1,  $zero, -1, 0
        # Recursively call FUNC_BINOM => binom(n-1,k)
        jal     $ra,   $zero, $zero,  $imm1, FUNC_BINOM, 0

AFTER_FIRST_CALL:
        # Decrement k: (k = k - 1)
        add     $a1,   $a1,   $imm1,  $zero, -1, 0
        # Recursively call FUNC_BINOM => binom(n-1,k-1)
        jal     $ra,   $zero, $zero,  $imm1, FUNC_BINOM, 0

###############################################
# BINOM_RET: Final part of recursion
###############################################
BINOM_RET:
        # Accumulate partial sums in $v0: v0 += s0
        add     $v0,   $v0,   $s0,    $zero, 0, 0
        # Reset s0
        add     $s0,   $zero, $zero,  $zero, 0, 0

        # Restore registers from stack frame
        lw      $ra,   $sp,   $zero,  $zero, 0,   0 
        lw      $a0,   $sp,   $imm1,  $zero, 1,   0 
        lw      $a1,   $sp,   $imm1,  $zero, 2,   0 
        lw      $s0,   $sp,   $imm1,  $zero, 3,   0 
        add     $sp,   $sp,   $imm1,  $zero, 4,   0 

        # Return to caller
        jal     $t2,   $zero, $zero,  $ra,   0,   0

###############################################
# PROG_DONE: Wrap up the program
###############################################
PROG_DONE:
        # Store the final result in Memory[258]
        sw      $v0,   $zero, $imm1,  $zero, 258, 0
        halt    $zero, $zero, $zero,  $zero, 0,   0

###############################################
# Data initialization
###############################################
.word 0x100 4   # n = 4  (Memory[0x100])
.word 0x101 2   # k = 2  (Memory[0x101])
