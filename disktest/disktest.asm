################################################################
#  Initialize and check disk status
################################################################

      out  $zero, $imm1, $zero, $imm1, 1, 0     # Enable IRQ1
      out  $zero, $imm1, $zero, $imm2, 6,  L3   # IO[6] = L3 => IRQ Handler address
      in   $t1,   $imm1, $zero, $zero, 17, 0    # $t1 = diskstatus (IO[17])
      out  $zero, $imm1, $zero, $imm2, 16, 0    # IO[16] = buffer address (set to 0)
      add  $s0,   $imm1, $zero, $zero, 7,  0     # $s0 = 7

      beq  $zero, $t1,   $imm1, $imm2, 0,  L1    # If diskstatus==0 => jump to L1
      halt $zero, $zero, $zero,  $zero, 0,  0    # Halt if disk busy

################################################################
#  MAIN_LOOP
################################################################
MAIN:
      sub  $s0,   $s0,   $imm1,  $zero,  2,   0  # $s0 -= 2
      bge  $zero, $s0,   $zero,  $imm1,  L1,  0
      blt  $zero, $s0,   $zero,  $imm1,  ENDMAIN, 0

L1:
      out  $zero, $imm1, $zero,  $s0,    15,  0  # IO[15] = sector number ($s0)
      out  $zero, $imm1, $zero,  $imm2, 14,  1  # IO[14] = 1 => read command
      add  $t0,   $zero, $zero,  $zero,  0,   0  # $t0 = 0
      blt  $zero, $t0,   $imm1,  $imm2,  1024, LOOPREAD

L2:
      add  $s0,   $s0,   $imm1,  $zero,  1,   0  # $s0 += 1
      out  $zero, $imm1, $zero,  $s0,    15,  0  # sector number
      out  $zero, $imm1, $zero,  $imm2, 14,  2  # IO[14] = 2 => write command
      add  $t0,   $zero, $zero,  $zero,  0,   0
      blt  $zero, $t0,   $imm1,  $imm2,  1024, LOOPWRITE

################################################################
#  READ_LOOP
################################################################
LOOPREAD:
      add  $t0,   $t0,   $imm1,  $zero,  1,   0  # $t0++
      blt  $zero, $t0,   $imm1,  $imm2,  1024, LOOPREAD
      beq  $zero, $t0,   $imm1,  $imm2,  1024, ENDREAD

ENDREAD:
      beq  $zero, $zero, $zero,  $imm1,  L2,   0

################################################################
#  WRITE_LOOP
################################################################
LOOPWRITE:
      add  $t0,   $t0,   $imm1,  $zero,  1,   0  # $t0++
      blt  $zero, $t0,   $imm1,  $imm2,  1024, LOOPWRITE
      beq  $zero, $t0,   $imm1,  $imm2,  1024, ENDWRITE

ENDWRITE:
      beq  $zero, $zero, $zero,  $imm1,  MAIN, 0

################################################################
#  End of MAIN_LOOP
################################################################
ENDMAIN:
      halt $zero, $zero, $zero,  $zero, 0, 0

################################################################
#  IRQ Handler (L3)
################################################################
L3:
      add  $t2,   $t2,   $imm1,  $zero,  1,   0  # $t2++
      reti $zero, $zero, $zero,  $zero, 0,  0   # Return from interrupt
