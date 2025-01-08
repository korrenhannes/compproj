# Load n from MEM[0x100] into t0
add $t0, $zero, $imm1, $zero, 0x100, 0    # t0=0x100
lw  $t1, $t0, $zero, $zero, 0,0           # t1 = MEM[0x100]
# t1 now contains n

# Load k from MEM[0x101] into t2
add $t0, $zero, $imm1, $zero, 0x101,0     # t0=0x101
lw  $t2, $t0, $zero, $zero,0,0            # t2 = MEM[0x101]
# t2 now contains k

# Set arguments a0=n, a1=k
add $a0, $t1, $zero, $zero,0,0  # a0=n
add $a1, $t2, $zero, $zero,0,0  # a1=k

# Set stack pointer
add $sp, $zero, $imm1, $zero, 0xFFF, 0  # sp=0xFFF

# Call binom_func(n, k)
jal $ra, $zero, $zero, $imm1, BINOM, 0
# result in v0

# Store result in MEM[0x102]
add $t0, $zero, $imm1, $zero,0x102,0
sw  $t0, $zero, $v0, $zero,0,0

# halt
halt $zero,$zero,$zero,$zero,0,0

# Function: binom_func(n,k)
# Entry: a0=n, a1=k
# if (k==0 || n==k) return 1
# else return binom(n-1,k-1)+binom(n-1,k)

BINOM:
# Save n,k in s0,s1
add $s0, $a0, $zero, $zero,0,0   # s0=n
add $s1, $a1, $zero, $zero,0,0   # s1=k

# Check base cases
# if(k==0) return 1
sub $t0, $a1, $imm1, $zero,0,0 # t0=k
beq $t0, $zero, $zero, RET_ONE,0,0

# if(n==k) return 1
sub $t0, $a0, $a1, $zero,0,0
beq $t0,$zero,$zero,RET_ONE,0,0

# Recursive case:
# Save return address on stack
add $sp,$sp,$imm1,$zero,-1,0
sw  $sp,$zero,$ra,$zero,0,0

# binom(n-1,k-1)
sub $a0,$s0,$imm1,$zero,1,0   # a0 = n-1
sub $a1,$s1,$imm1,$zero,1,0   # a1 = k-1
jal $ra,$zero,$zero,$imm1,BINOM,0
add $s2,$v0,$zero,$zero,0,0    # s2 = binom(n-1,k-1)

# binom(n-1,k)
# restore n,k for second call:
add $a0,$s0,$zero,$zero,0,0  # a0=n
add $a1,$s1,$zero,$zero,0,0  # a1=k
sub $a0,$a0,$imm1,$zero,1,0  # a0 = n-1 (again)
# k stays same

jal $ra,$zero,$zero,$imm1,BINOM,0
# v0=binom(n-1,k)

# sum results
add $v0,$s2,$v0,$zero,0,0

# restore ra
lw  $ra,$sp,$zero,$zero,0,0
add $sp,$sp,$imm1,$zero,1,0

# return
jr $ra,$zero,$zero,$zero,0,0

RET_ONE:
add $v0,$zero,$imm1,$zero,1,0 # return 1
jr $ra,$zero,$zero,$zero,0,0
