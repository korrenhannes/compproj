#ifndef SIMULATOR_H
#define SIMULATOR_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>

/* ------------------ Constants ------------------ */
#define IMEM_SIZE       4096
#define DMEM_SIZE       4096
#define DISK_SIZE       16384
#define MONITOR_WIDTH   256
#define MONITOR_HEIGHT  256
#define MONITOR_SIZE    (MONITOR_WIDTH * MONITOR_HEIGHT)

#define NUM_REGS        16
#define IO_REGS_COUNT   23 /* Up to monitorcmd indexed at 22 */

/* IO Register indices */
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

/* --------------- Function Prototypes --------------- */

/* Safe file open */
FILE* safe_fopen(const char* filename, const char* mode);

/* Reading memory/disk/irq2 from files */
void read_imem(const char* filename);
void read_dmem(const char* filename);
void read_disk(const char* filename);
void read_irq2(const char* filename);

/* Main CPU execution steps */
void execute_instruction(void);

/* Post-halt: write final outputs to files */
void write_outputs(const char* dmemout,
                   const char* regout,
                   const char* cyclesf,
                   const char* diskout,
                   const char* monitorf,
                   const char* monitoryuvf);

/* The main entry point */
int main(int argc, char* argv[]);

#endif /* SIMULATOR_H */
