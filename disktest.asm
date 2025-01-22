######################################################
# "in"  => rd = IO[rs + rt]
# "out" => IO[rs + rt] = rm
#
# Using: rd rs rt rm
######################################################

# 1) Enable IRQ1
out   $zero,  $imm1,  $zero, $imm1,  1, 0       # IO[1] = 1

# 2) Set IRQHANDLER to label IRQRoutine
out   $zero,  $imm1,  $zero, $imm2,  6,  IRQRoutine

# 3) $t1 = DISKSTATUS (IO[17])
in    $t1,    $imm1,  $zero, $zero,  17, 0

# 4) Set DISKBUFFER (IO[16]) = 0
out   $zero,  $imm1,  $zero, $imm2,  16, 0

# 5) Initialize $s0 = 7
add   $s0,    $imm1,  $zero, $zero,  7,  0

# If diskstatus == 0 => jump to PROCESS
beq   $zero,  $t1,    $imm1, $imm2,  0,  PROCESS

# Otherwise => halt
halt  $zero,  $zero,  $zero, $zero,  0,  0


######################################################
# Main loop
######################################################
PROCESS:
    sub   $s0,   $s0,   $imm1,  $zero, 2, 0     # s0 -= 2

    # If s0 >= 0 => jump to SECTOR_READ
    bge   $zero, $s0,   $zero,  $imm1, SECTOR_READ, 0

    # Else if s0 < 0 => jump to FINISHED
    blt   $zero, $s0,   $zero,  $imm1, FINISHED, 0

######################################################
# 1) SECTOR_READ
######################################################
SECTOR_READ:
    # out IO[15] = s0   (sector number)
    out   $zero, $imm1,  $zero, $s0,   15,  0
    
    # out IO[14] = 1    (read command)
    out   $zero, $imm1,  $zero, $imm2, 14,  1

    # t0 = 0
    add   $t0,   $zero,  $zero, $zero, 0,   0

    # Wait 1024 cycles => check t0 < 1024
    blt   $zero, $t0,    $imm1, $imm2, 1024, LOOPREAD

######################################################
# 2) SECTOR_WRITE
######################################################
WRITE_STEP:
    # s0++
    add   $s0,   $s0,    $imm1, $zero, 1,   0

    # out IO[15] = s0   (sector #)
    out   $zero, $imm1,  $zero, $s0,   15,  0

    # out IO[14] = 2    (write command)
    out   $zero, $imm1,  $zero, $imm2, 14,  2

    # t0 = 0
    add   $t0,   $zero,  $zero, $zero, 0,   0

    # Wait 1024 cycles => check t0 < 1024
    blt   $zero, $t0,    $imm1, $imm2, 1024, LOOPWRITE


######################################################
# Reading loop
######################################################
LOOPREAD:
    add   $t0,   $t0,    $imm1, $zero, 1,   0
    blt   $zero, $t0,    $imm1, $imm2, 1024, LOOPREAD
    beq   $zero, $t0,    $imm1, $imm2, 1024, ENDREAD

ENDREAD:
    # After read done => jump to WRITE_STEP
    beq   $zero, $zero,  $zero, $imm1, WRITE_STEP, 0


######################################################
# Writing loop
######################################################
LOOPWRITE:
    add   $t0,   $t0,    $imm1, $zero, 1,   0
    blt   $zero, $t0,    $imm1, $imm2, 1024, LOOPWRITE
    beq   $zero, $t0,    $imm1, $imm2, 1024, ENDWRITE

ENDWRITE:
    # After write => go back to PROCESS
    beq   $zero, $zero,  $zero, $imm1, PROCESS, 0

FINISHED:
    halt  $zero, $zero,  $zero,  $zero, 0,  0


######################################################
# IRQ Service Routine
######################################################
IRQRoutine:
    # $t2++
    add   $t2,   $t2,    $imm1,  $zero, 1, 0

    # Return from interrupt
    reti  $zero, $zero,  $zero,  $zero, 0,  0
