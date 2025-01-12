############################################################
# disktest.asm
# Moves contents of sectors 0..7 forward by one:
#   sector X -> sector (X+1)
############################################################

    # s0 = 0x200 (buffer base address)
    add    $s0,   $zero, $imm1,  $zero,  0x200, 0

    # t0 = 0 (sector counter)
    add    $t0,   $zero, $zero,  $zero,  0, 0

Loop_s:

    ################################################################
    # Read from sector t0 into memory at 0x200
    ################################################################

    # disksector = t0  (IORegister[15] = t0)
    add    $v0,   $zero, $imm1,  $zero,  15, 0      # v0 = 15
    out    $zero, $v0,   $zero,  $t0,    0, 0       # IOReg[15] = t0

    # diskbuffer = 0x200  (IORegister[16] = s0)
    add    $v0,   $zero, $imm1,  $zero,  16, 0      # v0 = 16
    out    $zero, $v0,   $zero,  $s0,    0, 0       # IOReg[16] = s0

    # diskcmd = 1 (read)
    add    $v0,   $zero, $imm1,  $zero,  14, 0      # v0 = 14
    add    $a0,   $zero, $imm1,  $zero,  1,  0      # a0 = 1
    out    $zero, $v0,   $zero,  $a0,    0, 0       # IOReg[14] = 1

WaitRead:
    # in a1 = diskstatus (IORegister[17])
    add    $v0,   $zero, $imm1,  $zero,  17, 0      # v0 = 17
    in     $a1,   $zero, $zero,  $v0,    0, 0       # a1 = IOReg[17]
    # if (a1 == 0) => goto DoneRead
    add    $imm1, $zero, $imm1,  $zero,  DoneRead, 0
    beq    $zero, $a1,   $imm1,  $zero,  0, 0

    # else => spin
    add    $imm1, $zero, $imm1,  $zero,  WaitRead, 0
    beq    $zero, $zero, $imm1,  $zero,  0, 0

DoneRead:

    ################################################################
    # Write to sector (t0+1) from memory at 0x200
    ################################################################

    # t1 = t0 + 1
    add    $t1,   $t0,   $imm1,  $zero,  1,  0

    # disksector = t1  (IORegister[15] = t1)
    add    $v0,   $zero, $imm1,  $zero,  15, 0
    out    $zero, $v0,   $zero,  $t1,    0, 0

    # diskbuffer = 0x200  (IORegister[16] = s0)
    add    $v0,   $zero, $imm1,  $zero,  16, 0
    out    $zero, $v0,   $zero,  $s0,    0, 0

    # diskcmd = 2 (write)
    add    $v0,   $zero, $imm1,  $zero,  14, 0
    add    $a0,   $zero, $imm1,  $zero,  2,  0
    out    $zero, $v0,   $zero,  $a0,    0, 0

WaitWrite:
    # in a1 = diskstatus (IORegister[17])
    add    $v0,   $zero, $imm1,  $zero,  17, 0
    in     $a1,   $zero, $zero,  $v0,    0, 0
    # if (a1 == 0) => goto DoneWrite
    add    $imm1, $zero, $imm1,  $zero,  DoneWrite, 0
    beq    $zero, $a1,   $imm1,  $zero,  0, 0

    # else => spin
    add    $imm1, $zero, $imm1,  $zero,  WaitWrite, 0
    beq    $zero, $zero, $imm1,  $zero,  0, 0

DoneWrite:

    ################################################################
    # t0++
    ################################################################
    add    $t0,   $t0,   $imm1,  $zero,  1,  0        # t0++
    sub    $v0,   $t0,   $imm1,  $zero,  8,  0        # v0 = t0 - 8

    # if (v0 < 0) => jump back to Loop_s
    add    $imm1, $zero, $imm1,  $zero,  Loop_s, 0
    blt    $v0,   $zero, $imm1,  $zero,  0, 0

    # done
    halt   $zero, $zero, $zero,  $zero,  0, 0
