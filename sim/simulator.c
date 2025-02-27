#include "simulator.h"

/* ------------------ Global State ------------------ */

/* Memories (static => internal linkage) */
static uint64_t imem[IMEM_SIZE];       /* Instruction memory (48-bit lines) */
static uint32_t dmem[DMEM_SIZE];       /* Data memory (32-bit words) */
static uint32_t disk[DISK_SIZE];       /* Disk (32-bit words) */
static uint8_t  monitor[MONITOR_SIZE]; /* 256x256 monochrome frame buffer */

/* CPU registers */
static uint32_t R[NUM_REGS];           /* R0..R15 */

/* Hardware IO registers */
static uint32_t IOReg[IO_REGS_COUNT];  /* Up to index 22 */

/* CPU control */
static int      inISR       = 0;
static int      halted      = 0;
static uint64_t cycle_count = 0;
static uint32_t PC          = 0;

/* irq2 data */
static int* irq2_cycles = NULL;
static int  irq2_count   = 0;
static int  irq2_index   = 0;

/* LED & 7seg logging (to detect changes) */
static uint32_t last_leds  = 0;
static uint32_t last_7seg  = 0;

/* Disk busy state */
static int      disk_busy        = 0;
static uint64_t disk_start_cycle = 0;

/* We store disk cmd/buffer/sector for the delayed (1024-cycle) transfer */
static int      g_diskcmd    = 0;
static uint32_t g_disksector = 0;
static uint32_t g_diskbuffer = 0;

/* Output file pointers */
static FILE *fdmemout, *fregout, *ftrace, *fhwregtrace, *fcycles;
static FILE *fleds, *f7seg, *fdiskout, *fmonitor, *fmonitoryuv;


/* ------------------ Helper Functions ------------------ */

FILE* safe_fopen(const char* filename, const char* mode) {
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
    *opcode = (uint8_t)((inst >> 40) & 0xFF);
    *rd     = (uint8_t)((inst >> 36) & 0x0F);
    *rs     = (uint8_t)((inst >> 32) & 0x0F);
    *rt     = (uint8_t)((inst >> 28) & 0x0F);
    *rm     = (uint8_t)((inst >> 24) & 0x0F);

    uint32_t i1 = (uint32_t)((inst >> 12) & 0xFFF);
    uint32_t i2 = (uint32_t)(inst & 0xFFF);

    *imm1 = sign_extend_12(i1);
    *imm2 = sign_extend_12(i2);
}

/* IO Register names for hwregtrace */
static const char* ioreg_name(int idx) {
    static const char* names[] = {
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

/* Log hardware register accesses to hwregtrace.txt */
static void log_hwregtrace(int read_write, int reg, uint32_t data) {
    fprintf(fhwregtrace, "%llu %s %s %08x\n",
        (unsigned long long)cycle_count,
        (read_write==0) ? "READ":"WRITE",
        ioreg_name(reg),
        data
    );
}

/* Check LED changes */
static void check_leds() {
    if(IOReg[LEDS] != last_leds) {
        fprintf(fleds, "%llu %08x\n",
            (unsigned long long)cycle_count,
            IOReg[LEDS]
        );
        last_leds = IOReg[LEDS];
    }
}

/* Check 7seg changes */
static void check_7seg() {
    if(IOReg[DISPLAY7SEG] != last_7seg) {
        fprintf(f7seg, "%llu %08x\n",
            (unsigned long long)cycle_count,
            IOReg[DISPLAY7SEG]
        );
        last_7seg = IOReg[DISPLAY7SEG];
    }
}

/* Possibly raise IRQ2 this cycle */
static void check_irq2() {
    if(irq2_index < irq2_count) {
        if(irq2_cycles[irq2_index] == (int)cycle_count) {
            IOReg[IRQ2STATUS] = 1;
            irq2_index++;
        }
    }
}

/* Timer logic */
static void update_timer() {
    if(IOReg[TIMERENABLE] == 1) {
        IOReg[TIMERCURRENT]++;
        /* If it just reached timermax => raise IRQ0 */
        if(IOReg[TIMERCURRENT] == IOReg[TIMERMAX]) {
            IOReg[TIMERCURRENT] = 0;
            IOReg[IRQ0STATUS]   = 1;
        }
    }
}

/* Disk logic: if busy, check if 1024 cycles elapsed; then do actual transfer */
static void update_disk() {
    if(disk_busy) {
        if((cycle_count - disk_start_cycle) >= 1024) {
            disk_busy = 0;
            IOReg[DISKSTATUS] = 0;
            IOReg[DISKCMD]    = 0;

            /* If sector <128, do the read/write */
            if(g_disksector < 128) {
                int base = g_disksector * 128;
                if(g_diskcmd == 1) {
                    /* read disk -> memory */
                    for(int i=0; i<128; i++) {
                        dmem[g_diskbuffer + i] = disk[base + i];
                    }
                } else if(g_diskcmd == 2) {
                    /* write memory -> disk */
                    for(int i=0; i<128; i++) {
                        disk[base + i] = dmem[g_diskbuffer + i];
                    }
                }
            }
            g_diskcmd = 0;
            IOReg[IRQ1STATUS] = 1; /* Disk operation complete => raise IRQ1 */
        }
    }
}

/* Check & handle interrupts. If pending & not inISR => jump to IOReg[IRQHANDLER] */
static void check_interrupts() {
    uint32_t irq = 0;
    if((IOReg[IRQ0ENABLE] & IOReg[IRQ0STATUS]) ||
       (IOReg[IRQ1ENABLE] & IOReg[IRQ1STATUS]) ||
       (IOReg[IRQ2ENABLE] & IOReg[IRQ2STATUS])) {
        irq=1;
    }
    if(irq && !inISR) {
        IOReg[IRQRETURN] = PC;
        PC = (IOReg[IRQHANDLER] & 0xFFF);
        inISR = 1;
    }
}

/* Start a disk operation (if free) */
static void start_disk_op() {
    int cmd = IOReg[DISKCMD];
    if(cmd == 1 || cmd == 2) {
        if(IOReg[DISKSTATUS] == 0) {
            disk_busy = 1;
            disk_start_cycle = cycle_count;
            IOReg[DISKSTATUS] = 1;

            g_diskcmd    = cmd;
            g_disksector = IOReg[DISKSECTOR] & 0x7F;
            g_diskbuffer = IOReg[DISKBUFFER] & 0xFFF;
        }
    }
}

/* Write pixel to monitor (IOReg[MONITORCMD]==1) */
static void write_monitor_pixel() {
    if(IOReg[MONITORCMD] == 1) {
        uint32_t addr = IOReg[MONITORADDR] & 0xFFFF;
        uint8_t  val  = (uint8_t)(IOReg[MONITORDATA] & 0xFF);
        if(addr < MONITOR_SIZE) {
            monitor[addr] = val;
        }
        IOReg[MONITORCMD] = 0; /* Done writing this pixel */
    }
}

/* Print one line to trace.txt */
static void print_trace_line(
    uint64_t inst,
    uint32_t pc_before,
    const uint32_t *regs_before,
    uint8_t opcode, uint8_t rd, uint8_t rs, uint8_t rt, uint8_t rm,
    int32_t imm1, int32_t imm2)
{
    fprintf(ftrace, "%03X ", (pc_before & 0xFFF));
    uint64_t mask48 = (inst & 0xFFFFFFFFFFFFULL);
    fprintf(ftrace, "%012llX ", (unsigned long long)mask48);

    /* R0 => 00000000 */
    fprintf(ftrace, "00000000 ");

    /* R1 => imm1 */
    fprintf(ftrace, "%08x ", (uint32_t)imm1);

    /* R2 => imm2 */
    fprintf(ftrace, "%08x ", (uint32_t)imm2);

    /* R3..R15 */
    for(int i=3; i<16; i++){
        fprintf(ftrace, "%08x ", regs_before[i]);
    }
    fseek(ftrace, -1, SEEK_CUR);
    fprintf(ftrace, "\n");
}

/* Execute one instruction */
void execute_instruction(void) {
    if(PC >= IMEM_SIZE) {
        halted = 1;
        return;
    }
    uint64_t inst = imem[PC];
    uint8_t opcode, rd, rs, rt, rm;
    int32_t imm1, imm2;
    decode_instruction(inst, &opcode, &rd, &rs, &rt, &rm, &imm1, &imm2);

    /* Load immediate regs: R1=$imm1, R2=$imm2 */
    R[1] = (uint32_t)imm1;
    R[2] = (uint32_t)imm2;

    uint32_t oldPC = PC;
    uint32_t regs_before[16];
    for(int i=0; i<16; i++){
        regs_before[i] = R[i];
    }

    uint32_t RS = R[rs];
    uint32_t RT = R[rt];
    uint32_t RMv= R[rm];
    uint32_t result = 0, addr = 0;

    switch(opcode) {
        case 0:  // add
            result = RS + RT + RMv;
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
            break;
        case 1:  // sub
            result = RS - RT - RMv;
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
            break;
        case 2:  // mac
        {
            int64_t mul = (int64_t)(int32_t)RS * (int64_t)(int32_t)RT;
            mul += (int64_t)(int32_t)RMv;
            result = (uint32_t)mul;
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
        }
        break;
        case 3:  // and
            result = RS & RT & RMv;
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
            break;
        case 4:  // or
            result = RS | RT | RMv;
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
            break;
        case 5:  // xor
            result = (RS ^ RT) ^ RMv;
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
            break;
        case 6:  // sll
            result = RS << (RT & 31);
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
            break;
        case 7:  // sra
        {
            int32_t s  = (int32_t)RS;
            int32_t sh = s >> (RT & 31);
            result = (uint32_t)sh;
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
        }
        break;
        case 8:  // srl
            result = RS >> (RT & 31);
            if(rd!=0 && rd!=1 && rd!=2) R[rd] = result;
            break;
        case 9:  // beq
            if(RS == RT) {
                PC = (R[rm]&0xFFF);
            } else {
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 10: // bne
            if(RS != RT) {
                PC = (R[rm]&0xFFF);
            } else {
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 11: // blt
            if((int32_t)RS < (int32_t)RT) {
                PC = (R[rm]&0xFFF);
            } else {
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 12: // bgt
            if((int32_t)RS > (int32_t)RT) {
                PC = (R[rm]&0xFFF);
            } else {
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 13: // ble
            if((int32_t)RS <= (int32_t)RT) {
                PC = (R[rm]&0xFFF);
            } else {
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 14: // bge
            if((int32_t)RS >= (int32_t)RT) {
                PC = (R[rm]&0xFFF);
            } else {
                PC++;
            }
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 15: // jal
            if(rd!=0 && rd!=1 && rd!=2) {
                R[rd] = PC+1;
            }
            PC = (R[rm]&0xFFF);
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 16: // lw
            addr = (R[rs] + R[rt]) & 0xFFF;
            if(rd!=0 && rd!=1 && rd!=2) {
                R[rd] = dmem[addr] + RMv;
            }
            break;
        case 17: // sw
            addr = (R[rs] + R[rt]) & 0xFFF;
            dmem[addr] = (RMv + R[rd]);
            break;
        case 18: // reti
            PC = (IOReg[IRQRETURN] & 0xFFF);
            inISR = 0;
            print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
            return;
        case 19: // in
        {
            uint32_t ioaddr = (R[rs] + R[rt]);
            if(ioaddr < IO_REGS_COUNT) {
                uint32_t val = IOReg[ioaddr];
                log_hwregtrace(0, ioaddr, val);
                if(rd!=0 && rd!=1 && rd!=2) {
                    R[rd] = val;
                }
            }
        }
        break;
        case 20: // out
        {
            uint32_t ioaddr = (R[rs] + R[rt]);
            uint32_t val    = R[rm];
            if(ioaddr < IO_REGS_COUNT) {
                IOReg[ioaddr] = val;
                log_hwregtrace(1, ioaddr, val);

                /* Check for special I/O effect */
                if(ioaddr == LEDS)        check_leds();
                if(ioaddr == DISPLAY7SEG) check_7seg();
                if(ioaddr == MONITORCMD)  write_monitor_pixel();
                if(ioaddr == DISKCMD)     start_disk_op();
            }
        }
        break;
        case 21: // halt
            halted = 1;
            break;
        default:
            // unknown opcode => treat as nop
            break;
    }

    /* For non-branch ops, increment PC if not halted */
    if(!halted &&
       (opcode<9 || opcode==16 || opcode==17 ||
        opcode==19|| opcode==20|| opcode>21))
    {
        PC++;
    }
    print_trace_line(inst, oldPC, regs_before, opcode, rd, rs, rt, rm, imm1, imm2);
}

/* --------------------------------------------------- */
/*                File Readers                         */
/* --------------------------------------------------- */

void read_imem(const char* filename) {
    FILE* f = fopen(filename, "r");
    if(!f) {
        memset(imem, 0, sizeof(imem));
        return;
    }
    char line[64];
    int addr=0;
    while(fgets(line, sizeof(line), f)) {
        if(addr >= IMEM_SIZE) break;
        uint64_t val=0;
        sscanf(line, "%llx", &val);
        imem[addr++] = (val & 0xFFFFFFFFFFFFULL);
    }
    fclose(f);
}

void read_dmem(const char* filename) {
    FILE* f = fopen(filename, "r");
    if(!f) {
        memset(dmem, 0, sizeof(dmem));
        return;
    }
    char line[64];
    int addr=0;
    while(fgets(line, sizeof(line), f)) {
        if(addr >= DMEM_SIZE) break;
        dmem[addr++] = hex_to_u32(line);
    }
    fclose(f);
}

void read_disk(const char* filename) {
    FILE* f = fopen(filename, "r");
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

void read_irq2(const char* filename) {
    FILE* f = fopen(filename, "r");
    if(!f) {
        irq2_cycles=NULL;
        irq2_count=0;
        return;
    }
    int capacity=128;
    irq2_cycles = (int*)malloc(capacity * sizeof(int));
    irq2_count=0;
    int x;
    while(fscanf(f,"%d",&x)==1) {
        if(irq2_count >= capacity){
            capacity *= 2;
            irq2_cycles = (int*)realloc(irq2_cycles, capacity*sizeof(int));
        }
        irq2_cycles[irq2_count++] = x;
    }
    fclose(f);
}

/* ----------------------------------------- */
/*        Write outputs after halt          */
/* ----------------------------------------- */
void write_outputs(const char* dmemout,
                   const char* regout,
                   const char* cyclesf,
                   const char* diskout,
                   const char* monitorf,
                   const char* monitoryuvf)
{
    /* 1) dmemout: skip trailing zero lines */
    int last_nonzero_dmem = -1;
    for(int i=0; i<DMEM_SIZE; i++){
        if(dmem[i] != 0) last_nonzero_dmem = i;
    }
    for(int i=0; i<=last_nonzero_dmem; i++){
        fprintf(fdmemout, "%08x\n", dmem[i]);
    }

    /* 2) regout: R3..R15 */
    for(int i=3; i<16; i++){
        fprintf(fregout, "%08x\n", R[i]);
    }

    /* 3) cycles.txt => final cycle_count */
    fprintf(fcycles, "%llu\n", (unsigned long long)cycle_count);

    /* 4) diskout: skip trailing zero lines */
    int last_nonzero_disk = -1;
    for(int i=0; i<DISK_SIZE; i++){
        if(disk[i] != 0) last_nonzero_disk = i;
    }
    for(int i=0; i<=last_nonzero_disk; i++){
        fprintf(fdiskout, "%08x\n", disk[i]);
    }

    /* 5) monitor.txt => 65536 lines, each pixel in 2 hex digits */
    for(int i=0; i<MONITOR_SIZE; i++){
        fprintf(fmonitor, "%02x\n", monitor[i]);
    }

    /* 6) monitor.yuv => binary dump of the same 65536 bytes */
    fwrite(monitor, 1, MONITOR_SIZE, fmonitoryuv);
}

/* ----------------------------------------- */
/*                 MAIN                      */
/* ----------------------------------------- */
int main(int argc, char* argv[]){
    if(argc != 15){
        fprintf(stderr,
            "Usage: %s imemin.txt dmemin.txt diskin.txt irq2in.txt "
            "dmemout.txt regout.txt trace.txt hwregtrace.txt cycles.txt "
            "leds.txt display7seg.txt diskout.txt monitor.txt monitor.yuv\n",
            argv[0]);
        return 1;
    }

    /* Open output files */
    fdmemout    = safe_fopen(argv[5],  "w");
    fregout     = safe_fopen(argv[6],  "w");
    ftrace      = safe_fopen(argv[7],  "w");
    fhwregtrace = safe_fopen(argv[8],  "w");
    fcycles     = safe_fopen(argv[9],  "w");
    fleds       = safe_fopen(argv[10], "w");
    f7seg       = safe_fopen(argv[11], "w");
    fdiskout    = safe_fopen(argv[12], "w");
    fmonitor    = safe_fopen(argv[13], "w");
    fmonitoryuv = safe_fopen(argv[14], "wb");

    /* Read inputs */
    read_imem(argv[1]);
    read_dmem(argv[2]);
    read_disk(argv[3]);
    read_irq2(argv[4]);

    /* Initialize CPU & IO registers */
    memset(R, 0, sizeof(R));
    memset(IOReg, 0, sizeof(IOReg));
    memset(monitor, 0, sizeof(monitor));

    inISR       = 0;
    halted      = 0;
    disk_busy   = 0;
    cycle_count = 0;
    PC          = 0;
    last_leds   = 0;
    last_7seg   = 0;
    g_diskcmd   = 0;

    /* Main simulation loop */
    while(!halted) {
        /* 1) CLKS register tracks current cycle */
        IOReg[CLKS] = (uint32_t)(cycle_count & 0xFFFFFFFF);

        /* 2) Execute one instruction */
        execute_instruction();

        /* 3) Possibly raise irq2 */
        check_irq2();

        /* 4) Timer update => might raise irq0 */
        update_timer();

        /* 5) Disk update => handle 1024-cycle latency */
        update_disk();

        /* 6) Check interrupts => jump to ISR if needed */
        check_interrupts();

        /* End of cycle */
        cycle_count++;
    }

    /* Write final outputs */
    write_outputs(argv[5], argv[6], argv[9],
                  argv[12], argv[13], argv[14]);

    /* Close all files */
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

    /* Cleanup irq2 data if allocated */
    if(irq2_cycles) {
        free(irq2_cycles);
        irq2_cycles = NULL;
    }

    return 0;
}
