############################################################
# mulmat.asm
# Multiplies two 4x4 matrices:
#   M1 (base = 0x100) and M2 (base = 0x110)
# and stores the result in M3 (base = 0x120).
# M1[i,k] * M2[k,j] is summed for k=0..3 to produce M3[i,j].
#
# Register usage:
#   $s0 (#10) = base of M1
#   $s1 (#11) = base of M2
#   $s2 (#12) = base of M3
#   $t0 (#7)  = i
#   $t1 (#8)  = j
#   $t2 (#9)  = k
#   $a0 (#4)  = sum for M1[i,k] * M2[k,j]
#   $a1 (#5)  = address or temporary load
#   $v0 (#3)  = offset / temporary load
#   $zero (#0), $imm1 (#1), $imm2 (#2)
############################################################

# Initialize base addresses of matrices
add  $s0, $zero, $imm1, $zero, 0x100, 0   # s0 = 0x100 (M1 base)
add  $s1, $zero, $imm1, $zero, 0x110, 0   # s1 = 0x110 (M2 base)
add  $s2, $zero, $imm1, $zero, 0x120, 0   # s2 = 0x120 (M3 base)

# i = 0
add  $t0, $zero, $zero, $zero, 0, 0

L_i:
  # j = 0
  add  $t1, $zero, $zero, $zero, 0, 0

L_j:
  # sum = 0
  add  $a0, $zero, $zero, $zero, 0, 0

  # k = 0
  add  $t2, $zero, $zero, $zero, 0, 0

L_k:
  #---------------------------------------------------------
  # M1[i,k]: address = s0 + (i*4 + k)
  # offset_i_k = i*4 + k
  #---------------------------------------------------------
  sll  $v0, $t0, $imm1, $zero, 2, 0    # v0 = i * 4
  add  $v0, $v0, $t2,   $zero, 0, 0    # v0 = i*4 + k
  add  $a1, $s0, $v0,   $zero, 0, 0    # a1 = base(M1) + offset
  lw   $v0, $a1, $zero, $zero, 0, 0    # v0 = M1[i,k]

  #---------------------------------------------------------
  # M2[k,j]: address = s1 + (k*4 + j)
  # offset_k_j = k*4 + j
  #---------------------------------------------------------
  sll  $a1, $t2, $imm1, $zero, 2, 0    # a1 = k*4
  add  $a1, $a1, $t1,   $zero, 0, 0    # a1 = k*4 + j
  add  $a1, $s1, $a1,   $zero, 0, 0    # a1 = base(M2) + offset
  lw   $a1, $a1, $zero, $zero, 0, 0    # a1 = M2[k,j]

  # sum += M1[i,k] * M2[k,j]
  mac  $a0, $v0, $a1,   $a0,   0, 0    # a0 = a0 + (v0 * a1)

  # k++
  add  $t2, $t2, $imm1, $zero, 1, 0    # t2++
  sub  $v0, $t2, $imm1, $zero, 4, 0    # v0 = t2 - 4

  # if (t2 < 4) => (v0 < 0) => jump to L_k
  # IMPORTANT FIX: rs=$v0, rt=$zero => "if (v0 < 0)"
  blt  $zero, $v0, $zero, $imm1, L_k, 0

  #---------------------------------------------------------
  # Store sum in M3[i,j]: M3[i,j] = sum
  # offset_i_j = i*4 + j
  #---------------------------------------------------------
  sll  $v0, $t0, $imm1, $zero, 2, 0    # v0 = i*4
  add  $v0, $v0, $t1,   $zero, 0, 0    # v0 = i*4 + j
  add  $a1, $s2, $v0,   $zero, 0, 0    # a1 = base(M3) + offset

  # IMPORTANT FIX: store $a0 into MEM[a1]
  # sw format: MEM[R[rs]+R[rt]] = R[rm] + R[rd]
  # We want address = $a1, data = $a0 => so rs=$a1, rt=$zero, rm=$a0, rd=$zero
  sw   $zero, $a1, $zero, $a0, 0, 0    # M3[i,j] = sum

  # j++
  add  $t1, $t1, $imm1, $zero, 1, 0
  sub  $v0, $t1, $imm1, $zero, 4, 0    # v0 = t1 - 4

  # if (t1 < 4) => (v0 < 0) => jump to L_j
  # Again, rs=$v0, rt=$zero => "if (v0 < 0)"
  blt  $zero, $v0, $zero, $imm1, L_j, 0

# i++
add  $t0, $t0, $imm1, $zero, 1, 0
sub  $v0, $t0, $imm1, $zero, 4, 0    # v0 = t0 - 4

# if (t0 < 4) => (v0 < 0) => jump to L_i
blt  $zero, $v0, $zero, $imm1, L_i, 0

# Done
halt $zero, $zero, $zero, $zero, 0, 0

############################################################
# Initialize data memory with two 4x4 matrices (M1 & M2).
# M1: addresses 0x100 to 0x10F (256 to 271)
# M2: addresses 0x110 to 0x11F (272 to 287)
############################################################

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
