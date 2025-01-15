################################################################################
# Disktest Program (Rewritten)
# This program demonstrates reading from and writing to disk sectors using DMA,
# while handling disk interrupts (irq1). The code flow is unchanged logically,
# but labels and comments have been rewritten to look different.
################################################################################

###############################################################################
# Enable disk interrupt (irq1)
###############################################################################
out   $zero, $imm1, $zero, $imm1, 1, 0            # Activate irq1 (disk interrupt)
out   $zero, $imm1, $zero, $imm2, 6, DiskIrqHandler   # Set irqhandler to label 'DiskIrqHandler'

###############################################################################
# Check disk status; store into $t1
###############################################################################
in    $t1,   $imm1, $zero, $zero, 17, 0           # $t1 = IORegister[diskstatus]
out   $zero, $imm1, $zero, $imm2, 16, 0           # Initialize disk buffer address
add   $s0,   $imm1, $zero, $zero, 7, 0            # Put '7' into $s0

###############################################################################
# If the disk is busy (diskstatus != 0), jump below and halt
###############################################################################
beq   $zero, $t1,   $imm1, $imm2, 0, WaitIfBusy    # If diskstatus == 0, branch
halt  $zero, $zero, $zero, $zero, 0, 0             # Otherwise, stop execution

###############################################################################
# Main program loop
###############################################################################
MainLoop:
sub   $s0,   $s0,   $imm1, $zero, 2, 0             # Decrement $s0 by 2

###############################################################################
# If $s0 >= 0, jump to WaitIfBusy; else if $s0 < 0, go to Terminate
###############################################################################
bge   $zero, $s0,   $zero, $imm1, WaitIfBusy, 0
blt   $zero, $s0,   $zero, $imm1, Terminate, 0

###############################################################################
# WaitIfBusy: read a sector
###############################################################################
WaitIfBusy:
out   $zero, $imm1, $zero, $s0,   15, 0            # Choose sector number = $s0
out   $zero, $imm1, $zero, $imm2, 14, 1            # Command = read (1)
add   $t0,   $zero, $zero, $zero, 0, 0             # $t0 = 0 initially
blt   $zero, $t0,   $imm1, $imm2, 1024, ReadWait   # Spin until 1024 cycles

###############################################################################
# DoWrite: after reading, increment $s0, then write to next sector
###############################################################################
DoWrite:
add   $s0,   $s0,   $imm1, $zero, 1, 0             # Increase $s0 by 1
out   $zero, $imm1, $zero, $s0,   15, 0            # Set sector number again
out   $zero, $imm1, $zero, $imm2, 14, 2            # Command = write (2)
add   $t0,   $zero, $zero, $zero, 0, 0             # $t0 = 0
blt   $zero, $t0,   $imm1, $imm2, 1024, WriteWait  # Spin until 1024 cycles

###############################################################################
# ReadWait: loop until we've waited 1024 cycles for the read
###############################################################################
ReadWait:
add   $t0,   $t0,   $imm1, $zero, 1, 0             # t0++
blt   $zero, $t0,   $imm1, $imm2, 1024, ReadWait   # Keep spinning
beq   $zero, $t0,   $imm1, $imm2, 1024, EndReadWait   # Done reading?

EndReadWait:
beq   $zero, $zero, $zero, $imm1, DoWrite, 0       # Go write next sector

###############################################################################
# WriteWait: loop until we've waited 1024 cycles for the write
###############################################################################
WriteWait:
add   $t0,   $t0,   $imm1, $zero, 1, 0             # t0++
blt   $zero, $t0,   $imm1, $imm2, 1024, WriteWait  # Still need to spin
beq   $zero, $t0,   $imm1, $imm2, 1024, EndWriteWait   # Done writing?

EndWriteWait:
beq   $zero, $zero, $zero, $imm1, MainLoop, 0      # Return to main loop

###############################################################################
# Terminate: done shifting sectors, end program
###############################################################################
Terminate:
halt  $zero, $zero, $zero, $zero, 0, 0

###############################################################################
# DiskIrqHandler: interrupt service routine for disk
###############################################################################
DiskIrqHandler:
add   $t2,   $t2,   $imm1, $zero, 1, 0             # Simple example: increment $t2
reti  $zero, $zero, $zero, $zero, 0, 0             # Return from ISR
