#ifndef ASM_H
#define ASM_H

#include <stdint.h>
#include <stdio.h>

#define MAX_LINES 5000
#define MAX_LABELS 1000
#define MAX_LINE_LEN 512
#define DMEM_SIZE 4096

// Holds one line of input assembly
typedef struct {
    char line[MAX_LINE_LEN];
    int is_instruction;       // 1 if line is an actual instruction
    int instruction_address;  // PC address of the instruction
} LineInfo;

// Label table: each label + the PC address it represents
typedef struct {
    char name[64];
    int address; // instruction address (PC)
} Label;

// Extern declarations for global variables
extern LineInfo lines[MAX_LINES];
extern int line_count;
extern Label labels[MAX_LABELS];
extern int label_count;
extern uint32_t dmem[DMEM_SIZE];

// Function prototypes
int opcode_of(const char *mnemonic);
int register_number(const char *reg);
int find_label_address(const char *label_name);
int32_t parse_immediate_final(const char *imm_str);
void encode_instruction(FILE *fout, int opcode, int rd, int rs, int rt, int rm, int32_t imm1, int32_t imm2);

#endif // ASM_H
