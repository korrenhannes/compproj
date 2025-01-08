# Initialize base addresses of matrices
add $s0, $zero, $imm1, $zero, 0x100, 0   # s0 = 0x100 (base of first matrix M1)
add $s1, $zero, $imm1, $zero, 0x110, 0   # s1 = 0x110 (base of second matrix M2)
add $s2, $zero, $imm1, $zero, 0x120, 0   # s2 = 0x120 (base of result matrix M3)

# i = 0
add $t0, $zero, $zero, $zero, 0, 0

L_i:
# j = 0
add $t1, $zero, $zero, $zero, 0,0

L_j:
# sum = 0
add $a0, $zero, $zero, $zero, 0,0

# k = 0
add $t2, $zero, $zero, $zero, 0,0

L_k:
# Compute address for M1[i,k]:
# offset_i_k = i*4 + k
sll $v0, $t0, $imm1, $zero, 2,0    # v0 = i*4
add $v0, $v0, $t2, $zero,0,0       # v0 = i*4 + k
add $v1, $s0, $v0, $zero,0,0       # address = s0 + (i*4+k)
lw  $v0, $v1, $zero, $zero, 0,0     # v0 = M1[i,k]

# Compute address for M2[k,j]:
# offset_k_j = k*4 + j
sll $v1, $t2, $imm1, $zero, 2,0    # v1 = k*4
add $v1, $v1, $t1, $zero,0,0       # v1 = k*4 + j
add $v1, $s1, $v1, $zero,0,0       # address = s1 + (k*4+j)
lw  $v1, $v1, $zero,$zero,0,0       # v1 = M2[k,j]

# sum = sum + (M1[i,k]*M2[k,j])
mac $a0, $v0, $v1, $a0, 0,0

# k++
add $t2, $t2, $imm1, $zero, 1,0
sub $v0, $t2, $imm1, $zero,4,0
blt $zero,$v0,$imm1,L_k,0,0  # if k<4, go back to L_k

# Store sum in M3[i,j]:
# offset_i_j = i*4 + j
sll $v0, $t0, $imm1, $zero,2,0   # v0 = i*4
add $v0, $v0, $t1, $zero,0,0     # v0 = i*4+j
add $v1, $s2, $v0, $zero,0,0     # address = s2+(i*4+j)
sw  $v1, $zero, $a0, $zero,0,0   # M3[i,j] = sum

# j++
add $t1,$t1,$imm1,$zero,1,0
sub $v0,$t1,$imm1,$zero,4,0
blt $zero,$v0,$imm1,L_j,0,0  # if j<4, go back to L_j

# i++
add $t0,$t0,$imm1,$zero,1,0
sub $v0,$t0,$imm1,$zero,4,0
blt $zero,$v0,$imm1,L_i,0,0  # if i<4, go back to L_i

# Done
halt $zero,$zero,$zero,$zero,0,0
