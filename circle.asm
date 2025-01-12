############################################################
# circle.asm
#
# Draws a white circle of radius = MEM[0x100], centered at (128,128),
# on a 256x256 gray-scale screen (0..255 for x and y).  Any pixel whose
# distance from (128,128) is less than or equal to radius is painted
# white (0xFF); otherwise, it remains black (0x00).
#
# Register usage:
#   $v0 (#3) : general scratch register
#   $a0 (#4) : pixel address
#   $a1 (#5) : comparison result dist^2 - radius^2
#   $a2 (#6) : pixel color (0x00 = black, 0xFF = white)
#   $t0 (#7) : radius
#   $t1 (#8) : x loop counter
#   $t2 (#9) : y loop counter
#   $s0 (#10): radius^2
#   $s1 (#11): dx = x - 128
#   $s2 (#12): dy = y - 128
#   $zero (#0), $imm1 (#1), $imm2 (#2)
############################################################

#----------------------------------------
# 1 Load radius from MEM[0x100] into $t0
#----------------------------------------
add  $v0, $zero, $imm1, $zero, 0x100, 0   # v0 = 0x100
lw   $t0, $v0,   $zero, $zero, 0, 0       # t0 = MEM[0x100]

#----------------------------------------
# 2 Compute radius^2 in s0 using MAC
#    s0 = t0 * t0
#----------------------------------------
mac  $s0, $t0,   $t0,   $zero, 0, 0       # s0 = (t0 * t0) + 0

# x = 0
add  $t1, $zero, $zero, $zero, 0, 0

Loop_x:
  # y = 0
  add  $t2, $zero, $zero, $zero, 0, 0

Loop_y:
  # dx = x - 128 -> s1
  add  $s1, $t1,   $imm1, $zero, -128, 0
  # dy = y - 128 -> s2
  add  $s2, $t2,   $imm1, $zero, -128, 0

  # dist^2 = dx*dx + dy*dy => store in v0
  mac  $v0, $s1,   $s1,   $zero, 0, 0     # v0 = (dx*dx) + 0
  mac  $v0, $s2,   $s2,   $v0,   0, 0     # v0 = v0 + (dy*dy) = dx^2 + dy^2

  # a1 = dist^2 - radius^2
  sub  $a1, $v0,   $s0,   $zero, 0, 0     # a1 = (dist^2) - (radius^2)

  # if (a1 <= 0) => jump Inside
  # ble means if (R[rs] <= R[rt]) => pc = R[rm][11:0]
  # We want if (a1 <= 0). So rs=$a1, rt=$zero => if(a1 <= 0).
  # That is encoded as ble $zero, $a1, $zero, $imm1, Inside, 0
  ble  $zero, $a1, $zero, $imm1, Inside, 0

Outside:
  # pixel = 0x00 (black)
  add  $a2, $zero, $zero, $zero, 0, 0
  # unconditional jump to DrawPixel
  # beq if (R[rs]==R[rt]) => pc = R[rm][11:0]
  beq  $zero, $zero, $zero, $imm1, DrawPixel, 0

Inside:
  # pixel = 0xFF (white)
  add  $a2, $zero, $imm1, $zero, 0xFF, 0

DrawPixel:
  # pixel address = x*256 + y
  sll  $a0, $t1,   $imm1, $zero, 8, 0     # a0 = x << 8 (i.e. x*256)
  add  $a0, $a0,   $t2,   $zero, 0, 0     # a0 = (x * 256) + y

  # out monitoraddr = a0  (HW reg #20)
  add  $v0, $zero, $imm1, $zero, 20, 0
  out  $zero, $v0,  $zero, $a0,   0, 0

  # out monitordata = a2  (HW reg #21)
  add  $v0, $zero, $imm1, $zero, 21, 0
  out  $zero, $v0,  $zero, $a2,   0, 0

  # out monitorcmd = 1    (HW reg #22)
  add  $v0, $zero, $imm1, $zero, 22, 0
  add  $a1, $zero, $imm1, $zero, 1, 0
  out  $zero, $v0,  $zero, $a1,   0, 0

  # y++
  add  $t2, $t2,   $imm1, $zero, 1, 0
  # check if (y < 256): v0 = t2 - 256
  sub  $v0, $t2,   $imm1, $zero, 256, 0
  # if (v0 < 0) => jump Loop_y
  blt  $zero, $v0,  $zero, $imm1, Loop_y, 0

# x++
add  $t1, $t1,   $imm1, $zero, 1, 0
# v0 = t1 - 256
sub  $v0, $t1,   $imm1, $zero, 256, 0
# if (v0 < 0) => jump Loop_x
blt  $zero, $v0,  $zero, $imm1, Loop_x, 0

# end
halt $zero, $zero, $zero, $zero, 0, 0

