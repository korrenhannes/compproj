#in rd=IO[rs+rt]
#out IO[rs+rt]=rm
#rd rs rt rm
	out $zero, $imm1, $zero, $imm1, 1, 0 #enable irq1
	out $zero, $imm1, $zero, $imm2, 6, L3		# set irqhandler as L3
	in $t1, $imm1, $zero, $zero, 17, 0 #t1=diskstatus
	out $zero, $imm1, $zero, $imm2, 16, 0 #set buffer
	add $s0, $imm1, $zero, $zero, 7, 0
	beq $zero, $t1, $imm1, $imm2, 0, L1 #jump if diskstatus = 0
	halt $zero, $zero, $zero, $zero, 0, 0
MAIN:
	sub $s0, $s0, $imm1, $zero, 2, 0
	bge $zero, $s0, $zero, $imm1, L1, 0
	blt $zero, $s0, $zero, $imm1, ENDMAIN, 0
L1:
	out $zero, $imm1, $zero, $s0, 15, 0 #set sector number
	out $zero, $imm1, $zero, $imm2, 14, 1 #set read command
	add $t0, $zero, $zero, $zero, 0, 0
	blt $zero, $t0, $imm1, $imm2, 1024, LOOPREAD
L2:
	add $s0, $s0, $imm1, $zero, 1, 0
	out $zero, $imm1, $zero, $s0, 15, 0 #set sector number
	out $zero, $imm1, $zero, $imm2, 14, 2 #set write command
	add $t0, $zero, $zero, $zero, 0, 0
	blt $zero, $t0, $imm1, $imm2, 1024, LOOPWRITE
LOOPREAD:
	add $t0, $t0, $imm1, $zero, 1, 0
	blt $zero, $t0, $imm1, $imm2, 1024, LOOPREAD
	beq $zero, $t0, $imm1, $imm2, 1024, ENDREAD
ENDREAD:
	beq $zero, $zero, $zero, $imm1, L2, 0
LOOPWRITE:
	add $t0, $t0, $imm1, $zero, 1, 0
	blt $zero, $t0, $imm1, $imm2, 1024, LOOPWRITE
	beq $zero, $t0, $imm1, $imm2, 1024, ENDWRITE
ENDWRITE:
	beq $zero, $zero, $zero, $imm1, MAIN, 0
ENDMAIN:
	halt $zero, $zero, $zero, $zero, 0, 0
L3:
	add $t2, $t2, $imm1, $zero, 1, 0
	reti $zero, $zero, $zero, $zero, 0, 0		# return from interrupt