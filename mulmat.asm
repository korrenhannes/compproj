#############################################################
# Suppose we want to test with RADIUS = 10 (stored at MEM[0x100])
#############################################################

# 1) Load radius into $s0
      lw     $s0,     $imm1,   $zero,  $zero, 0x100, 0   # $s0 = Memory[0x100]

# 2) Compute radius^2 in $s1
      mac    $s1,     $s0,     $s0,    $zero, 0, 0       # $s1 = (radius * radius)

# 3) Initialize x = 128 - radius into $t1
      sub    $t1,     $imm1,   $s0,    $zero, 128, 0

LOOP_XSCAN:
      # Check if x == 128 + radius => end
      add    $t0,     $imm1,   $s0,    $zero, 128, 0
      beq    $zero,   $t0,     $t1,    $imm1, FINISH, 0  # if (x == 128 + radius) => jump to FINISH

      # Initialize y = 128 - radius => $t2
      sub    $t2,     $imm1,   $s0,    $zero, 128, 0

LOOP_YSCAN:
      # if y == 128 + radius => go increment X
      beq    $zero,   $t0,     $t2,    $imm1, INCR_X, 0

      ########################################################
      # Compute distance^2 = (128 - x)^2 + (128 - y)^2
      ########################################################

      # dx = 128 - x => $s2
      sub    $s2,     $imm1,   $t1,    $zero, 128, 0

      # dy = 128 - y => $a1
      sub    $a1,     $imm1,   $t2,    $zero, 128, 0

      # dist^2 = dx^2 + dy^2 => store in $v0
      mac    $v0,     $s2,     $s2,    $zero, 0, 0
      mac    $v0,     $a1,     $a1,    $v0,   0, 0

      # 7) Compare dist^2 ($v0) to radius^2 ($s1)
      ble    $zero,   $v0,     $s1,    $imm1, PIXEL_INSIDE, 0

      # If not inside, jump to next Y
      beq    $zero,   $zero,   $zero,  $imm1, INCR_Y, 0

PIXEL_INSIDE:
      # Pixel is inside => color = 0xFF (white)
      add    $a2,     $zero,   $imm1,  $zero, 0xFF, 0

DRAW_PIXEL:
      # a0 = (x << 8) + y for pixel coordinate
      sll    $a0,     $t1,     $imm1,  $zero, 8, 0
      add    $a0,     $a0,     $t2,    $zero, 0, 0

      # Send pixel address to IO register #20
      out    $zero,   $imm1,   $zero,  $a0,   20, 0

      # Send pixel color to IO register #21
      out    $zero,   $imm1,   $zero,  $a2,   21, 0

      # Write command (1) to IO register #22 to draw
      out    $zero,   $zero,   $imm2,  $imm1, 1, 22

INCR_Y:
      # y++
      add    $t2,     $t2,     $imm1,  $zero, 1, 0
      beq    $zero,   $zero,   $zero,  $imm1, LOOP_YSCAN, 0  # Unconditional

INCR_X:
      # x++
      add    $t1,     $t1,     $imm1,  $zero, 1, 0
      beq    $zero,   $zero,   $zero,  $imm1, LOOP_XSCAN, 0  # Unconditional

FINISH:
      halt   $zero,   $zero,   $zero,  $zero, 0, 0

#############################################################
# Data section: radius stored here (10 by default)
#############################################################
      .word 0x100 10
