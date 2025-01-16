################################################################################
# Disktest Program (Fixed)
# Demonstrates reading/writing disk sectors using DMA and irq1. The key fix is
# in the "blt" / "beq" instructions that compare t0 against 1024, ensuring the
# code no longer spins forever.
################################################################################

###############################################################################
# Enable disk interrupt (irq1)
###############################################################################
out   $zero, $imm1, $zero, $imm1, 1, 0            # IORegister[1] = 1 => Enable irq1
out   $zero, $imm1, $zero, $imm2, 6, DiskIrqHandler   # IORegister[6] = address of DiskIrqHandler

###############################################################################
# Check disk status; store into $t1
###############################################################################
in    $t1,   $imm1, $zero, $zero, 17, 0           # $t1 = IORegister[diskstatus]
out   $zero, $imm1, $zero, $imm2, 16, 0           # IORegister[16] = 0 => set diskbuffer=0
add   $s0,   $imm1, $zero, $zero, 7, 0            # $s0 = 7

###############################################################################
# If the disk is busy (diskstatus != 0), jump below and halt
###############################################################################
beq   $zero, $t1,   $imm1, $imm2, 0, WaitIfBusy    # if(diskstatus == 0) => branch
halt  $zero, $zero, $zero, $zero, 0, 0             # else => HALT

###############################################################################
# Main program loop
###############################################################################
MainLoop:
sub   $s0,   $s0,   $imm1, $zero, 2, 0             # $s0 -= 2

###############################################################################
# If $s0 >= 0, jump to WaitIfBusy; else if $s0 < 0, go to Terminate
###############################################################################
bge   $zero, $s0,   $zero, $imm1, WaitIfBusy, 0
blt   $zero, $s0,   $zero, $imm1, Terminate, 0

###############################################################################
# WaitIfBusy: read a sector from disk
###############################################################################
WaitIfBusy:
out   $zero, $imm1, $zero, $s0,   15, 0            # IORegister[15] = $s0 => disksector
out   $zero, $imm1, $zero, $imm2, 14, 1            # IORegister[14] = 1 => diskcmd=READ
add   $t0,   $zero, $zero, $zero, 0, 0             # $t0 = 0 initially

# Spin until (t0 >= 1024)
blt   $zero, $t0,   $imm1, $imm2, 1024, ReadWait   # if(t0 < 1024) => goto ReadWait

###############################################################################
# DoWrite: after reading, increment $s0, then write to the next sector
###############################################################################
DoWrite:
add   $s0,   $s0,   $imm1, $zero, 1, 0             # $s0++
out   $zero, $imm1, $zero, $s0,   15, 0            # disksector = $s0
out   $zero, $imm1, $zero, $imm2, 14, 2            # diskcmd = 2 => WRITE
add   $t0,   $zero, $zero, $zero, 0, 0             # $t0 = 0

# Spin until (t0 >= 1024)
blt   $zero, $t0,   $imm1, $imm2, 1024, WriteWait  # if(t0 < 1024) => goto WriteWait

###############################################################################
# ReadWait: loop until we've waited 1024 cycles for the read
###############################################################################
ReadWait:
add   $t0,   $t0,   $imm1, $zero, 1, 0             # $t0++
blt   $zero, $t0,   $imm1, $imm2, 1024, ReadWait   # if(t0 < 1024) => loop
beq   $zero, $t0,   $imm1, $imm2, 1024, EndReadWait   # if(t0 == 1024) => goto EndReadWait

EndReadWait:
beq   $zero, $zero, $zero, $imm1, DoWrite, 0       # Unconditional jump => goto DoWrite

###############################################################################
# WriteWait: loop until we've waited 1024 cycles for the write
###############################################################################
WriteWait:
add   $t0,   $t0,   $imm1, $zero, 1, 0             # $t0++
blt   $zero, $t0,   $imm1, $imm2, 1024, WriteWait  # if(t0 < 1024) => loop
beq   $zero, $t0,   $imm1, $imm2, 1024, EndWriteWait   # if(t0 == 1024) => goto EndWriteWait

EndWriteWait:
beq   $zero, $zero, $zero, $imm1, MainLoop, 0      # Unconditional => goto MainLoop

###############################################################################
# Terminate: done shifting sectors, end program
###############################################################################
Terminate:
halt  $zero, $zero, $zero, $zero, 0, 0

###############################################################################
# DiskIrqHandler: interrupt service routine for disk
###############################################################################
DiskIrqHandler:
add   $t2,   $t2,   $imm1, $zero, 1, 0             # For demonstration, $t2++
reti  $zero, $zero, $zero, $zero, 0, 0             # Return from ISR
