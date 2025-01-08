# Set buffer address in s0
add $s0, $zero, $imm1, $zero, 0x200,0  # s0=0x200

# t0 = 0 (sector counter)
add $t0, $zero, $zero,$zero,0,0

Loop_s:
# Read sector t0 into buffer

# out disksector = t0
add $v0,$zero,$imm1,$zero,15,0
out $zero,$v0,$zero,$t0,0,0

# out diskbuffer = 0x200
add $v0,$zero,$imm1,$zero,16,0
out $zero,$v0,$zero,$s0,0,0

# out diskcmd = 1 (read)
add $v0,$zero,$imm1,$zero,14,0
add $v1,$zero,$imm1,$zero,1,0
out $zero,$v0,$zero,$v1,0,0

# wait until diskstatus=0
WaitRead:
add $v0,$zero,$imm1,$zero,17,0
in $v1,$zero,$zero,$v0,0,0  # v1=diskstatus
beq $v1,$zero,$zero,DoneRead,0,0
beq $zero,$zero,$zero,WaitRead,0,0

DoneRead:

# Now write to sector t0+1

# out disksector = t0+1
add $t1,$t0,$imm1,$zero,1,0
add $v0,$zero,$imm1,$zero,15,0
out $zero,$v0,$zero,$t1,0,0

# out diskbuffer=0x200
add $v0,$zero,$imm1,$zero,16,0
out $zero,$v0,$zero,$s0,0,0

# out diskcmd=2 (write)
add $v0,$zero,$imm1,$zero,14,0
add $v1,$zero,$imm1,$zero,2,0
out $zero,$v0,$zero,$v1,0,0

# wait until diskstatus=0 again
WaitWrite:
add $v0,$zero,$imm1,$zero,17,0
in $v1,$zero,$zero,$v0,0,0
beq $v1,$zero,$zero,DoneWrite,0,0
beq $zero,$zero,$zero,WaitWrite,0,0

DoneWrite:

# t0++
add $t0,$t0,$imm1,$zero,1,0
sub $v0,$t0,$imm1,$zero,8,0
blt $zero,$v0,$imm1,Loop_s,0,0  # if t0<8 continue

# done
halt $zero,$zero,$zero,$zero,0,0
