		add $sp, $zero, $imm1, $zero, 0x6FF, 0			#$sp=4090(points on the last cell in memory)
		lw  $a0, $imm1, $zero, $zero, 256, 0			#$a0=Memory[256] (value of n)
		lw  $a1, $imm1, $zero, $zero, 257, 0			#$a1=Memory[257] (value of k)
		add $s0, $zero, $zero, $zero, 0, 0			#$s0=0
		add $ra, $zero, $zero, $imm1, END, 0			#$ra=value of the pc of "END"
binom:
		add $sp, $sp, $imm1, $zero, -4, 0				#$sp=$sp-4
		sw  $ra, $sp, $zero, $zero, 0, 0				#store $ra in Memory[$sp]
		sw  $a0, $sp, $imm1, $zero, 1, 0				#store $a0 in Memory[$sp+1]
		sw  $a1, $sp, $imm1, $zero, 2, 0				#store $a1 in Memory[$sp+2]
		sw  $s0, $sp, $imm1, $zero, 3, 0				#store $s0 in Memory[$sp+3]
		bne $zero,  $a1, $zero, $imm1, Continue_1, 0		#jump to "Continue_1" if (k!=0)
		beq $zero, $zero, $zero, $imm1, Continue_2, 0		#jump to "Continue_2"
Continue_1:
		bne $zero, $a0, $a1, $imm1, Continue, 0			#jump to "Continue" if (n!=k)
Continue_2:	
		add $s0, $zero, $imm1, $zero, 1, 0				#$s0=1
		beq $zero, $zero, $zero, $imm1, return, 0			#jump to "return"
Continue:	
		add $a0, $a0, $imm1, $zero, -1, 0				#$a0=$a0-1 (n=n-1)
		jal $ra, $zero,  $zero, $imm1, binom, 0			#jump to "binom" and return to "bin_1" [binom(n-1,k)] 
bin_1:	
		add $a1, $a1, $imm1, $zero, -1, 0				#$a1=$a1-1 (k=k-1)
		jal $ra, $zero, $zero, $imm1, binom, 0			#jump to "binom" and return to "bin_2" [binom(n-1,k-1)]
return:	
		add $v0, $v0, $s0, $zero, 0, 0				#$v0=$v0+$s0
		add $s0, $zero, $zero ,$zero, 0, 0			#$s0=0
		lw  $ra, $sp, $zero, $zero, 0, 0				#$ra=value of Memory[$sp]
		lw  $a0, $sp,  $imm1, $zero, 1, 0				#$a0=value of Memory[$sp+1]
		lw  $a1, $sp, $imm1, $zero, 2, 0				#$a1=value of Memory[$sp+2]
		lw  $s0, $sp, $imm1, $zero, 3, 0				#$s0=value of Memory[$sp+3]
		add $sp, $sp, $imm1, $zero, 4, 0				#$sp=$sp+4
		jal $t2, $zero, $zero, $ra, 0, 0				#jump to pc=$ra, and return to "END"
END:	
		sw  $v0, $zero, $imm1, $zero, 258, 0			#Memory[258]=value of $v0 (this is the result that will be written in 0X102)
		halt  $zero, $zero, $zero, $zero, 0, 0					#Exit Simulator
.word 0x100 4  # n=4
.word 0x101 2  # k=2