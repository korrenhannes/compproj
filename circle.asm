# Load radius from MEM[0x100]
add $v0, $zero, $imm1, $zero, 0x100,0
lw  $t0, $v0, $zero,$zero,0,0   # t0 = radius

# Compute radius^2 in s0 using mac
# s0 = t0*t0
mac $s0, $t0, $t0, $zero,0,0

# x=0
add $t1, $zero, $zero,$zero,0,0

Loop_x:
# y=0
add $t2, $zero, $zero,$zero,0,0

Loop_y:
# dx = x-128
add $t3, $t1, $imm1,$zero,-128,0
# dy = y-128
add $t4, $t2, $imm1,$zero,-128,0

# Compute dist² = dx*dx + dy*dy using mac
mac $v0,$t3,$t3,$zero,0,0    # v0 = dx*dx
mac $v0,$t4,$t4,$v0,0,0       # v0 = dx*dx+dy*dy

# Compare dist² with radius²
sub $v1,$v0,$s0,$zero,0,0
# if v1 <= 0 => dist² <= radius²
ble $v1,$zero,$imm1,Inside,0,0

Outside:
# pixel=0x00 (black)
add $a2,$zero,$zero,$zero,0,0
beq $zero,$zero,$zero,DrawPixel,0,0

Inside:
# pixel=0xFF (white)
add $a2,$zero,$imm1,$zero,0xFF,0

DrawPixel:
# pixel address = x*256+y
sll $a0,$t1,$imm1,$zero,8,0  # a0 = x<<8 = x*256
add $a0,$a0,$t2,$zero,0,0    # a0 = x*256+y

# out monitoraddr= a0
add $v0,$zero,$imm1,$zero,20,0
out $zero,$v0,$zero,$a0,0,0

# out monitordata= a2
add $v0,$zero,$imm1,$zero,21,0
out $zero,$v0,$zero,$a2,0,0

# out monitorcmd=1
add $v0,$zero,$imm1,$zero,22,0
add $v1,$zero,$imm1,$zero,1,0
out $zero,$v0,$zero,$v1,0,0

# y++
add $t2,$t2,$imm1,$zero,1,0
sub $v0,$t2,$imm1,$zero,256,0
blt $zero,$v0,$imm1,Loop_y,0,0

# x++
add $t1,$t1,$imm1,$zero,1,0
sub $v0,$t1,$imm1,$zero,256,0
blt $zero,$v0,$imm1,Loop_x,0,0

# done
halt $zero,$zero,$zero,$zero,0,0
