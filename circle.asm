# Suppose we want radius= 10 for testing. You can change as needed.
 

# 1) Load radius into $s0
lw    $s0,   $imm1,   $zero,  $zero, 0x100, 0        # $s0 = MEM[0x100] (radius)

mac   $s1,   $s0,   $s0,    $zero, 0, 0        # $s1 = (radius * radius) + 0

sub   $t1,   $imm1, $s0,  $zero, 128, 0        # $t1 = 128 - radius   (x)
 
Loop_x:
  # Check if x = 256 => end
  add $t0, $imm1, $s0, $zero, 128, 0
  beq $zero, $t0, $t1, $imm1, EndProgram, 0 # if (x = 128 + radius) => jump => EndProgram
  
  # y=0 in $t2
  sub   $t2,   $imm1, $s0,  $zero, 128, 0      # $t2 = 128 - radius   (y)

Loop_y:
  beq $zero, $t0, $t2, $imm1, NextX, 0 # if (y = 256) => jump => NextX
 
  # 6) dx = 128 - x => $s2
  sub   $s2,   $imm1,   $t1,  $zero, 128, 0
  #    dy = 128 -y => $a1
  sub   $a1,   $imm1,   $t2,  $zero, 128, 0

  # dist^2 = dx^2 + dy^2 => $v0
  mac   $v0,   $s2,   $s2,   $zero, 0, 0
  mac   $v0,   $a1,   $a1,   $v0,   0, 0

  # 7) Compare dist^2 ($v0) to radius^2 ($s1)
  ble $zero, $v0, $s1, $imm1, Inside, 0   # if (dist^2 <= r^2) => jump => Inside

  beq  $zero, $zero, $zero, $imm1, NextY, 0 # not white jump to next pixel

Inside:
  # Pixel inside => color=0xFF (white)
  add   $a2,   $zero, $imm1,  $zero, 0xFF, 0   # $a2=0xFF

DrawPixel:
  # a0 = (x << 8) + y
  sll   $a0,   $t1,   $imm1,  $zero, 8, 0
  add   $a0,   $a0,   $t2,    $zero, 0, 0

  # monitoraddr = a0  (IO register #20)
  out   $zero, $imm1,   $zero,  $a0,   20, 0

  # monitordata = a2  (IO register #21)
  out   $zero, $imm1,   $zero,  $a2,   21, 0

  # monitorcmd = 1    (IO register #22) => commit pixel
  out $zero, $zero, $imm2, $imm1, 1, 22

NextY:
  add   $t2,   $t2,   $imm1,  $zero, 1, 0
  beq   $zero, $zero, $zero,  $imm1, Loop_y, 0
  # unconditional => Loop_y

NextX:
  # x++
  add   $t1,   $t1,   $imm1,  $zero, 1, 0
  beq   $zero, $zero, $zero,  $imm1, Loop_x, 0
  # unconditional => Loop_x

EndProgram:
  halt  $zero, $zero, $zero,  $zero, 0, 0

  .word 0x100 10