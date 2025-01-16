##############################################################################
# Enable interrupt #1 and assign the interrupt handler address:
##############################################################################
out   $zero, $imm1, $zero, $imm1, 1, 0     # irq1enable = 1
out   $zero, $imm1, $zero, $imm2, 6, _INT  # irqhandler = _INT

##############################################################################
# Check diskstatus, set buffer base, and proceed only if disk is ready:
##############################################################################
in    $t1,   $imm1, $zero, $zero, 17, 0    # t1 = diskstatus
out   $zero, $imm1, $zero, $imm2, 16, 0    # diskbuffer = 0
add   $s0,   $imm1, $zero, $zero, 7, 0     # s0 = 7
beq   $zero, $t1,   $imm1, $imm2, 0, _RDY  # Jump if diskstatus=0
halt  $zero, $zero, $zero, $zero, 0, 0

##############################################################################
# MAIN routine: Decrement s0 and branch accordingly
##############################################################################
_MAIN:
  sub   $s0, $s0,   $imm1,  $zero, 2, 0
  bge   $zero, $s0, $zero,  $imm1, _RDY, 0
  blt   $zero, $s0, $zero,  $imm1, _DONE, 0

##############################################################################
# _RDY: Issue a disk read command if s0 is valid
##############################################################################
_RDY:
  out   $zero, $imm1, $zero, $s0,   15, 0  # disksector = s0
  out   $zero, $imm1, $zero, $imm2, 14, 1  # diskcmd = 1 (read)
  add   $t0,   $zero, $zero, $zero, 0, 0
  blt   $zero, $t0,   $imm1, $imm2, 1024, _READLOOP

##############################################################################
# _INC: After reading, move on to the next sector and write it back
##############################################################################
_INC:
  add   $s0,   $s0,   $imm1, $zero, 1, 0
  out   $zero, $imm1, $zero, $s0,   15, 0  # disksector = s0
  out   $zero, $imm1, $zero, $imm2, 14, 2  # diskcmd = 2 (write)
  add   $t0,   $zero, $zero, $zero, 0, 0
  blt   $zero, $t0,   $imm1, $imm2, 1024, _WRLOOP

##############################################################################
# _READLOOP: Loop until t0 >= 1024
##############################################################################
_READLOOP:
  add   $t0,   $t0,   $imm1, $zero, 1, 0
  blt   $t0,   $imm1, $zero, $imm2, 1024, _READLOOP
  beq   $zero, $t0,   $imm1, $imm2, 1024, _FINREAD

##############################################################################
# _FINREAD: Jump to _INC after finishing read
##############################################################################
_FINREAD:
  beq   $zero, $zero, $zero, $imm1, _INC, 0

##############################################################################
# _WRLOOP: Loop until t0 >= 1024
##############################################################################
_WRLOOP:
  add   $t0,   $t0,   $imm1, $zero, 1, 0
  blt   $t0,   $imm1, $zero, $imm2, 1024, _WRLOOP
  beq   $zero, $t0,   $imm1, $imm2, 1024, _FINWR

##############################################################################
# _FINWR: Jump back to _MAIN after writing
##############################################################################
_FINWR:
  beq   $zero, $zero, $zero, $imm1, _MAIN, 0

##############################################################################
# _DONE: Halt once s0 is out of range
##############################################################################
_DONE:
  halt  $zero, $zero, $zero, $zero, 0, 0

##############################################################################
# _INT: Simple IRQ1 handler - increment t2, then return from interrupt
##############################################################################
_INT:
  add   $t2,   $t2,   $imm1, $zero, 1, 0
  reti  $zero, $zero, $zero, $zero, 0, 0
