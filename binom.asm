############################################################
# binom.asm
# Computes binomial(n, k) recursively:
#
#   binom(n,k) = 1,               if (k==0 || n==k)
#                binom(n-1,k-1) + binom(n-1,k),  otherwise
#
# Inputs:
#   MEM[0x100] = n
#   MEM[0x101] = k
# Output:
#   MEM[0x102] = binom(n,k)
#
# Register usage:
#   $zero (#0)  = constant 0
#   $imm1 (#1)  = sign-extended immediate 1
#   $imm2 (#2)  = sign-extended immediate 2
#   $v0   (#3)  = function return value
#   $a0   (#4)  = first function argument
#   $a1   (#5)  = second function argument
#   $t0   (#7)  = temporary register
#   $t1   (#8)  = temporary register
#   $t2   (#9)  = temporary register
#   $s0   (#10) = saved register (holds n locally)
#   $s1   (#11) = saved register (holds k locally)
#   $s2   (#12) = saved register (holds partial result)
#   $sp   (#14) = stack pointer
#   $ra   (#15) = return address
############################################################

#------------------------------------------------------------------
# MAIN CODE
#------------------------------------------------------------------

# Load n from MEM[0x100] into t1
add  $t0, $zero, $imm1, $zero, 0x100, 0  # t0 = 0x100
lw   $t1, $t0,   $zero, $zero, 0, 0      # t1 = MEM[0x100] => n

# Load k from MEM[0x101] into t2
add  $t0, $zero, $imm1, $zero, 0x101, 0  # t0 = 0x101
lw   $t2, $t0,   $zero, $zero, 0, 0      # t2 = MEM[0x101] => k

# Set arguments a0=n, a1=k
add  $a0, $t1,   $zero, $zero, 0, 0      # a0 = n
add  $a1, $t2,   $zero, $zero, 0, 0      # a1 = k

# Set stack pointer = 0xFFF
add  $sp, $zero, $imm1, $zero, 0xFFF, 0  # sp = 0xFFF

# Call binom_func(n, k)
#    => jal R[rd]=pc+1, pc=R[rm] => address BINOM in imm fields
jal  $ra,  $zero, $zero, $imm1, BINOM, 0

# After returning, result is in v0

# Store result in MEM[0x102]
add  $t0, $zero, $imm1, $zero, 0x102, 0   # t0 = 0x102
sw   $t0, $zero, $v0,   $zero, 0, 0       # MEM[t0] = v0

# halt
halt $zero, $zero, $zero, $zero, 0, 0


#------------------------------------------------------------------
# binom_func(n, k)
#   a0 = n, a1 = k
#   returns v0 = binom(n,k)
#------------------------------------------------------------------
BINOM:
  # Save n,k in s0,s1
  add  $s0, $a0,   $zero, $zero, 0, 0    # s0 = n
  add  $s1, $a1,   $zero, $zero, 0, 0    # s1 = k

  #----------------------------------------------------
  # if (k == 0) => return 1
  #   sub t0 = k - 0
  #   if (t0 == 0) => goto RET_ONE
  #----------------------------------------------------
  sub  $t0, $a1,   $imm1, $zero, 0, 0    # t0 = k - 0 => t0 = k
  beq  $zero, $t0,  $zero, $imm1, RET_ONE, 0
  #  ^^^^^   ^^^^
  #  rs=$t0, rt=$zero => if(t0 == 0), jump to label "RET_ONE"

  #----------------------------------------------------
  # if (n == k) => return 1
  #   sub t0 = n - k
  #   if (t0 == 0) => goto RET_ONE
  #----------------------------------------------------
  sub  $t0, $a0,   $a1,   $zero, 0, 0    # t0 = n - k
  beq  $zero, $t0,  $zero, $imm1, RET_ONE, 0
  #  rs=$t0, rt=$zero => if(t0 == 0), jump to label "RET_ONE"

  #----------------------------------------------------
  # Recursive case: binom(n,k) = binom(n-1,k-1) + binom(n-1,k)
  #----------------------------------------------------
  # 1 Save return address on stack
  add  $sp,  $sp,   $imm1, $zero, -1, 0   # sp--
  sw   $sp,  $zero, $ra,   $zero, 0, 0    # MEM[sp] = ra

  # 2 binom(n-1,k-1)
  sub  $a0,  $s0,   $imm1, $zero, 1, 0    # a0 = n-1
  sub  $a1,  $s1,   $imm1, $zero, 1, 0    # a1 = k-1
  jal  $ra,  $zero, $zero, $imm1, BINOM, 0  
  add  $s2,  $v0,   $zero, $zero, 0, 0    # s2 = binom(n-1, k-1)

  # 3 binom(n-1,k)
  #    restore n,k for second call
  add  $a0,  $s0,   $zero, $zero, 0, 0    # a0 = n
  add  $a1,  $s1,   $zero, $zero, 0, 0    # a1 = k
  sub  $a0,  $a0,   $imm1, $zero, 1, 0    # a0 = n-1
  #  k remains same

  jal  $ra,  $zero, $zero, $imm1, BINOM, 0
  # now v0 = binom(n-1, k)

  # 4 sum results: v0 = binom(n-1,k-1) + binom(n-1,k)
  add  $v0,  $s2,   $v0,   $zero, 0, 0

  # 5 restore ra, pop stack
  lw   $ra,  $sp,   $zero, $zero, 0, 0
  add  $sp,  $sp,   $imm1, $zero, 1, 0   # sp++

  # return => pc = R[$ra]
  jal  $zero, $zero, $zero, $ra, 0, 0


RET_ONE:
  # v0 = 1
  add  $v0,  $zero, $imm1, $zero, 1, 0

  # return => pc = R[$ra]
  jal  $zero, $zero, $zero, $ra, 0, 0
