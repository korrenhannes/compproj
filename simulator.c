#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>

/*
  SIMP Simulator
  --------------

  Command line:
   sim.exe imemin.txt dmemin.txt diskin.txt irq2in.txt dmemout.txt regout.txt \
           trace.txt hwregtrace.txt cycles.txt leds.txt display7seg.txt \
           diskout.txt monitor.txt monitor.yuv
*/

#define IMEM_SIZE 4096
#define DMEM_SIZE 4096
#define DISK_SIZE 16384
#define MONITOR_WIDTH 256
#define MONITOR_HEIGHT 256
#define MONITOR_SIZE (MONITOR_WIDTH * MONITOR_HEIGHT)

#define NUM_REGS 16
#define IO_REGS_COUNT 23 /* Up to monitorcmd indexed at 22 */

enum {
    IRQ0ENABLE = 0, IRQ1ENABLE, IRQ2ENABLE,
    IRQ0STATUS, IRQ1STATUS, IRQ2STATUS,
    IRQHANDLER, IRQRETURN,
    CLKS,
    LEDS,
    DISPLAY7SEG,
    TIMERENABLE,
    TIMERCURRENT,
    TIMERMAX,
    DISKCMD,
    DISKSECTOR,
    DISKBUFFER,
    DISKSTATUS,
    RESERVED1, RESERVED2,
    MONITORADDR,
    MONITORDATA,
    MONITORCMD
};

/* Global State */
static uint64_t imem[IMEM_SIZE];    
static uint32_t dmem[DMEM_SIZE];    
static uint32_t disk[DISK_SIZE];    
static uint8_t  monitor[MONITOR_SIZE];

static uint32_t R[NUM_REGS];        
static uint32_t IOReg[IO_REGS_COUNT];

static int inISR            = 0;
static int halted           = 0;
static uint64_t cycle_count = 0;  /* <-- starts from 0 now */
static uint32_t PC          = 0;

/* For external interrupts from irq2in.txt */
static int* irq2_cycles = NULL;
static int  irq2_count   = 0;
static int  irq2_index   = 0;

/* For logging changes */
static uint32_t last_leds  = 0;
static uint32_t last_7seg  = 0;

/* Disk busy state */
static int      disk_busy        = 0;
static uint64_t disk_start_cycle = 0;

/* Output file pointers */
static FILE *fdmemout, *fregout, *ftrace, *fhwregtrace, *fcycles;
static FILE *fleds, *f7seg, *fdiskout, *fmonitor, *fmonitoryuv;


/* -------------- Helpers -------------- */

static FILE* safe_fopen(const char* filename, const char* mode) {
    FILE* f = fopen(filename, mode);
    if(!f) {
        fprintf(stderr, "ERROR: Cannot open file '%s' with mode '%s'\n", filename, mode);
        exit(1);
    }
    return f;
}

static uint32_t hex_to_u32(const char* str) {
    uint32_t val = 0;
    sscanf(str, "%x", &val);
    return val;
}

/* Read 48-bit instructions (12 hex digits per line) */
static void read_imem(const char* filename) {
    FILE* f = fopen(filename, "r");
    if(!f) {
        memset(imem, 0, sizeof(imem));
        return;
    }
    char line[64];
    int addr=0;
    while(fgets(line, sizeof(line), f)) {
        if(addr>=IMEM_SIZE) break;
        uint64_t val=0;
        sscanf(line, "%llx", &val);
        imem[addr++] = (val & 0xFFFFFFFFFFFFULL);
    }
    fclose(f);
}

static void read_dmem(const char* filename) {
    FILE* f = fopen(filename,"r");
    if(!f) {
        memset(dmem,0,sizeof(dmem));
        return;
    }
    char line[64];
    int addr=0;
    while(fgets(line,sizeof(line),f)) {
        if(addr>=DMEM_SIZE) break;
        dmem[addr++] = hex_to_u32(line);
    }
    fclose(f);
}

static void read_disk(const char* filename) {
    FILE* f = fopen(filename,"r");
    if(!f) {
        memset(disk,0,sizeof(disk));
        return;
    }
    char line[64];
    int addr=0;
    while(fgets(line,sizeof(line),f)) {
        if(addr>=DISK_SIZE) break;
        disk[addr++] = hex_to_u32(line);
    }
    fclose(f);
}

static void read_irq2(const char* filename) {
    FILE* f = fopen(filename,"r");
    if(!f) {
        irq2_cycles=NULL;
        irq2_count=0;
        return;
    }
    int capacity=128;
    irq2_cycles = (int*)malloc(capacity*sizeof(int));
    irq2_count=0;
    int x;
    while(fscanf(f,"%d",&x)==1) {
        if(irq2_count>=capacity){
            capacity*=2;
            irq2_cycles=(int*)realloc(irq2_cycles, capacity*sizeof(int));
        }
        irq2_cycles[irq2_count++] = x;
    }
    fclose(f);
}

/* Sign-extend 12-bit immediate */
static int32_t sign_extend_12(uint32_t val) {
    if(val & 0x800) { 
        return (int32_t)(val | 0xFFFFF000);
    }
    return (int32_t)val;
}

/* Decode 48-bit instruction */
static void decode_instruction(uint64_t inst,
    uint8_t *opcode, uint8_t *rd, uint8_t *rs, uint8_t *rt, uint8_t *rm,
    int32_t *imm1, int32_t *imm2)
{
    *opcode = (uint8_t)((inst>>40) & 0xFF);
    *rd     = (uint8_t)((inst>>36) & 0x0F);
    *rs     = (uint8_t)((inst>>32) & 0x0F);
    *rt     = (uint8_t)((inst>>28) & 0x0F);
    *rm     = (uint8_t)((inst>>24) & 0x0F);

    uint32_t i1=(uint32_t)((inst>>12)&0xFFF);
    uint32_t i2=(uint32_t)(inst&0xFFF);

    *imm1 = sign_extend_12(i1);
    *imm2 = sign_extend_12(i2);
}

/* IO Register names for hwregtrace */
static const char* ioreg_name(int idx) {
    static const char* names[]={
      "irq0enable","irq1enable","irq2enable",
      "irq0status","irq1status","irq2status",
      "irqhandler","irqreturn","clks","leds",
      "display7seg","timerenable","timercurrent","timermax",
      "diskcmd","disksector","diskbuffer","diskstatus",
      "reserved","reserved","monitoraddr","monitordata","monitorcmd"
    };
    if(idx>=0 && idx<IO_REGS_COUNT) return names[idx];
    return "unknown";
}

/* Log hardware register accesses */
static void log_hwregtrace(int read_write, int reg, uint32_t data) {
    fprintf(fhwregtrace, "%llu %s %s %08x\n",
        (unsigned long long)cycle_count,
        (read_write==0)?"READ":"WRITE",
        ioreg_name(reg),
        data
    );
}

/* Check LED changes */
static void check_leds() {
    if(IOReg[LEDS]!=last_leds){
        fprintf(fleds, "%llu %08x\n",
            (unsigned long long)cycle_count,
            IOReg[LEDS]
        );
        last_leds=IOReg[LEDS];
    }
}

/* Check 7seg changes */
static void check_7seg(){
    if(IOReg[DISPLAY7SEG]!=last_7seg){
        fprintf(f7seg, "%llu %08x\n",
            (unsigned long long)cycle_count,
            IOReg[DISPLAY7SEG]
        );
        last_7seg=IOReg[DISPLAY7SEG];
    }
}

/* Raise irq2 if needed */
static void check_irq2(){
    if(irq2_index<irq2_count){
        if(irq2_cycles[irq2_index]==(int)cycle_count){
            IOReg[IRQ2STATUS]=1;
            irq2_index++;
        }
    }
}

/* Timer logic */
static void update_timer(){
    if(IOReg[TIMERENABLE]==1){
        IOReg[TIMERCURRENT]++;
        /* If it just wrapped around to timermax => raise irq0status now */
        if(IOReg[TIMERCURRENT]==IOReg[TIMERMAX]){
            IOReg[TIMERCURRENT]=0;
            IOReg[IRQ0STATUS]=1;
        }
    }
}

/* Disk logic */
static void update_disk(){
    if(disk_busy){
        if((cycle_count - disk_start_cycle)>=1024){
            disk_busy=0;
            IOReg[DISKSTATUS]=0;
            IOReg[DISKCMD]=0;
            IOReg[IRQ1STATUS]=1;
        }
    }
}

/* Check interrupts and jump if enabled + not in ISR */
static void check_interrupts(){
    uint32_t irq=0;
    if((IOReg[IRQ0ENABLE]&IOReg[IRQ0STATUS]) ||
       (IOReg[IRQ1ENABLE]&IOReg[IRQ1STATUS]) ||
       (IOReg[IRQ2ENABLE]&IOReg[IRQ2STATUS])){
        irq=1;
    }
    if(irq && !inISR){
        IOReg[IRQRETURN]=PC;
        PC= (IOReg[IRQHANDLER]&0xFFF);
        inISR=1;
    }
}

/* Start disk op if free */
static void start_disk_op(){
    int cmd=IOReg[DISKCMD];
    if(cmd==1||cmd==2){
        if(IOReg[DISKSTATUS]==0){
            disk_busy=1;
            disk_start_cycle=cycle_count;
            IOReg[DISKSTATUS]=1;

            uint32_t sector=IOReg[DISKSECTOR]&0x7F;
            uint32_t buffer=IOReg[DISKBUFFER]&0xFFF;
            if(sector<128){
                int base=sector*128;
                if(cmd==1){
                    // read disk->mem
                    for(int i=0;i<128;i++){
                        dmem[buffer+i] = disk[base+i];
                    }
                } else {
                    // write mem->disk
                    for(int i=0;i<128;i++){
                        disk[base+i]= dmem[buffer+i];
                    }
                }
            }
        }
    }
}

/* Write pixel to monitor if needed */
static void write_monitor_pixel(){
    if(IOReg[MONITORCMD]==1){
        uint32_t addr= IOReg[MONITORADDR]&0xFFFF;
        uint8_t  val= (uint8_t)(IOReg[MONITORDATA]&0xFF);
        if(addr<MONITOR_SIZE){
            monitor[addr]= val;
        }
        IOReg[MONITORCMD]=0;
    }
}

/* ------------------- 
   Print one line in trace.txt
   => PC & INST in UPPERCASE
   => Register values in lowercase hex
   ------------------- */
static void print_trace_line(
    uint64_t inst, 
    uint32_t pc_before,
    const uint32_t *regs_before,
    uint8_t opcode, uint8_t rd, uint8_t rs, uint8_t rt, uint8_t rm,
    int32_t imm1, int32_t imm2)
{
    // Print the PC (3 uppercase hex digits)
    fprintf(ftrace, "%03X ", (pc_before & 0xFFF));

    // Print the instruction (12 uppercase hex digits)
    uint64_t mask48 = (inst & 0xFFFFFFFFFFFFULL);
    fprintf(ftrace, "%012llX ", (unsigned long long)mask48);

    // Print R0 (fixed "00000000")
    fprintf(ftrace, "00000000 ");

    // Print R1 (imm1, 8 lowercase hex digits)
    fprintf(ftrace, "%08x ", (uint32_t)imm1);

    // Print R2 (imm2, 8 lowercase hex digits)
    fprintf(ftrace, "%08x ", (uint32_t)imm2);

    // Print R3 to R15 (8 lowercase hex digits each, space-separated)
    for (int i = 3; i < 16; i++) {
        fprintf(ftrace, "%08x ", regs_before[i]);
    }

    // Remove trailing space and end line
    fseek(ftrace, -1, SEEK_CUR);
    fprintf(ftrace, "\n");
}


/* Execute one instruction */
static void execute_instruction(){
    if(PC>=IMEM_SIZE){
        halted=1;
        return;
    }
    uint64_t inst= imem[PC];
    uint8_t opcode, rd, rs, rt, rm;
    int32_t imm1, imm2;
    decode_instruction(inst, &opcode, &rd, &rs, &rt, &rm, &imm1, &imm2);

    // load imm
    R[1]= (uint32_t)imm1;
    R[2]= (uint32_t)imm2;

    uint32_t oldPC= PC;
    uint32_t regs_before[16];
    for(int i=0;i<16;i++){
        regs_before[i]= R[i];
    }

    uint32_t RS= R[rs];
    uint32_t RT= R[rt];
    uint32_t RM= R[rm];
    uint32_t result=0, addr=0;

    switch(opcode){
        case 0: // add
            result= RS + RT + RM;
            if(rd!=0 && rd!=1 && rd!=2) R[rd]= result;
            break;
        case 1: // sub
            result= RS - RT - RM;
            if(rd!=0 && rd!=1 && rd!=2) R[rd]= result;
            break;
        case 2: // mac
        {
            int64_t mul=((int64_t)(int32_t)RS)*((int64_t)(int32_t)RT);
            mul += (int64_t)(int32_t)RM;
            result= (uint32_t)mul;
            if(rd!=0 && rd!=1 && rd!=2) R[rd]= result;
        }
        break;
        case 3: // and
            result= RS & RT & RM;
            if(rd!=0 && rd!=1 && rd!=2) R[rd]=result;
            break;
        case 4: // or
            result= RS | RT | RM;
            if(rd!=0 && rd!=1 && rd!=2) R[rd]= result;
            break;
        case 5: // xor
            result= (RS ^ RT) ^ RM;
            if(rd!=0 && rd!=1 && rd!=2) R[rd]= result;
            break;
        case 6: // sll
            result= RS << (RT & 31);
            if(rd!=0 && rd!=1 && rd!=2) R[rd]= result;
            break;
        case 7: // sra
        {
            int32_t s= (int32_t)RS;
            int32_t sh= s >> (RT&31);
            result= (uint32_t)sh;
            if(rd!=0 && rd!=1 && rd!=2) R[rd]= result;
        }
        break;
        case 8: // srl
            result= RS >> (RT & 31);
            if(rd!=0 && rd!=1 && rd!=2) R[rd]= result;
            break;
        case 9: // beq
            if(RS==RT){
                PC= (R[rm]&0xFFF);
            } else{
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 10: // bne
            if(RS!=RT){
                PC= (R[rm]&0xFFF);
            } else{
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 11: // blt
            if((int32_t)RS<(int32_t)RT){
                PC= (R[rm]&0xFFF);
            } else{
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 12: // bgt
            if((int32_t)RS>(int32_t)RT){
                PC= (R[rm]&0xFFF);
            } else{
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 13: // ble
            if((int32_t)RS<=(int32_t)RT){
                PC= (R[rm]&0xFFF);
            } else{
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 14: // bge
            if((int32_t)RS>=(int32_t)RT){
                PC= (R[rm]&0xFFF);
            } else{
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 15: // jal
            if(rd!=0 && rd!=1 && rd!=2){
                R[rd]= PC+1;
            }
            PC= (R[rm]&0xFFF);
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 16: // lw
            addr= (R[rs]+R[rt])&0xFFF;
            if(rd!=0 && rd!=1 && rd!=2){
                R[rd]= dmem[addr] + RM;
            }
            break;
        case 17: // sw
            addr= (R[rs]+R[rt])&0xFFF;
            dmem[addr]= (RM+ R[rd]);
            break;
        case 18: // reti
            PC= (IOReg[IRQRETURN]&0xFFF);
            inISR=0;
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 19: // in
        {
            uint32_t ioaddr= (R[rs]+R[rt]);
            if(ioaddr<IO_REGS_COUNT){
                uint32_t val= IOReg[ioaddr];
                log_hwregtrace(0, ioaddr, val);
                if(rd!=0 && rd!=1 && rd!=2){
                    R[rd]=val;
                }
            }
        }
        break;
        case 20: // out
        {
            uint32_t ioaddr= (R[rs]+R[rt]);
            uint32_t val= R[rm];
            if(ioaddr<IO_REGS_COUNT){
                IOReg[ioaddr]= val;
                log_hwregtrace(1, ioaddr, val);
                if(ioaddr==LEDS)        check_leds();
                if(ioaddr==DISPLAY7SEG) check_7seg();
                if(ioaddr==MONITORCMD)  write_monitor_pixel();
                if(ioaddr==DISKCMD)     start_disk_op();
            }
        }
        break;
        case 21: // halt
            halted=1;
            break;
        default:
            // unknown => nop
            break;
    }

    /* For non-branch ops (opcode <9, or lw/sw, in/out, etc.), we do PC++ */
    if(!halted &&
       (opcode<9 || 
        opcode==16|| opcode==17||
        opcode==19|| opcode==20||
        (opcode>21 && opcode<255)))
    {
        PC++;
    }
    print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
}

/* After halt: write outputs */
static void write_outputs(
    const char* dmemout,
    const char* regout,
    const char* cyclesf,
    const char* diskout,
    const char* monitorf,
    const char* monitoryuvf)
{
    /* --- DMEMOUT: skip trailing zeros --- */
    int last_nonzero_dmem = -1;
    for(int i=0; i<DMEM_SIZE; i++){
        if(dmem[i] != 0) {
            last_nonzero_dmem = i;
        }
    }
    if(last_nonzero_dmem >= 0) {
        /* Print dmem[0]..dmem[last_nonzero_dmem] */
        for(int i=0; i<=last_nonzero_dmem; i++){
            fprintf(fdmemout, "%08x\n", dmem[i]);
        }
    }
    /* If everything was zero, we simply produce an empty dmemout.txt */

    /* REGOUT */
    for(int i=3; i<16; i++){
        fprintf(fregout, "%08x\n", R[i]);
    }

    /* CYCLES */
    fprintf(fcycles, "%llu\n", (unsigned long long)cycle_count);

    /* DISKOUT => already skipping trailing zeros */
    int last_nonzero=-1;
    for(int i=0; i<DISK_SIZE; i++){
        if(disk[i]!=0) last_nonzero=i;
    }
    if(last_nonzero >= 0){
        for(int i=0; i<=last_nonzero; i++){
            fprintf(fdiskout, "%08x\n", disk[i]);
        }
    }

    /* MONITOR.TXT */
    for(int i=0; i<MONITOR_SIZE; i++){
        fprintf(fmonitor, "%02x\n", monitor[i]);
    }

    /* MONITOR.YUV => binary dump */
    fwrite(monitor,1,MONITOR_SIZE,fmonitoryuv);
}


int main(int argc,char* argv[]){
    if(argc<15){
        fprintf(stderr,"Usage: sim.exe imemin.txt dmemin.txt diskin.txt irq2in.txt "
                       "dmemout.txt regout.txt trace.txt hwregtrace.txt cycles.txt "
                       "leds.txt display7seg.txt diskout.txt monitor.txt monitor.yuv\n");
        return 1;
    }

    fdmemout    = safe_fopen(argv[5],"w");
    fregout     = safe_fopen(argv[6],"w");
    ftrace      = safe_fopen(argv[7],"w");
    fhwregtrace = safe_fopen(argv[8],"w");
    fcycles     = safe_fopen(argv[9],"w");
    fleds       = safe_fopen(argv[10],"w");
    f7seg       = safe_fopen(argv[11],"w");
    fdiskout    = safe_fopen(argv[12],"w");
    fmonitor    = safe_fopen(argv[13],"w");
    fmonitoryuv = safe_fopen(argv[14],"wb");

    read_imem(argv[1]);
    read_dmem(argv[2]);
    read_disk(argv[3]);
    read_irq2(argv[4]);

    memset(R,0,sizeof(R));
    memset(IOReg,0,sizeof(IOReg));
    memset(monitor,0,sizeof(monitor));

    inISR      = 0;
    halted     = 0;
    disk_busy  = 0;
    cycle_count= 0;   /* Start from 0 per spec */
    PC         = 0;

    while(!halted)
    {
        /* (1) Update 'clks' to match this cycle's value */
        IOReg[CLKS] = (uint32_t)(cycle_count & 0xFFFFFFFF);

        /* (6) Fetch+Decode+Execute one instruction */
        execute_instruction();

        /* (2) Possibly raise irq2 this cycle */
        check_irq2();

        /* (3) Timer increments & possibly raises irq0status */
        update_timer();

        /* (4) Disk logic (DMA done? => raise irq1status) */
        update_disk();

        /* (5) Check interrupts & jump if needed */
        check_interrupts();


        /* (7) One full cycle done */
        cycle_count++;
    }

    write_outputs(argv[5],argv[6],argv[9],argv[12],argv[13],argv[14]);

    fclose(fdmemout);
    fclose(fregout);
    fclose(ftrace);
    fclose(fhwregtrace);
    fclose(fcycles);
    fclose(fleds);
    fclose(f7seg);
    fclose(fdiskout);
    fclose(fmonitor);
    fclose(fmonitoryuv);

    if(irq2_cycles) free(irq2_cycles);

    return 0;
}