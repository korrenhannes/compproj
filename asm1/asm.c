#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#include "asm.h"

/*
  This assembler does two passes:
  1. Identify labels and assign instruction addresses.
  2. Encode instructions and handle .word directives.

  Output:
    - imemin.txt : instruction memory initial content (48-bit instructions)
    - dmemin.txt : data memory initial content (32-bit words)

  If you only want to print up to the highest address actually used, we track
  that with `max_dmem_addr`.
*/

// ------------------ Global Variables ------------------
LineInfo lines[MAX_LINES];
int line_count=0;
Label labels[MAX_LABELS];
int label_count=0;
uint32_t dmem[DMEM_SIZE];

// We add a variable to track the highest dmem address used
static int max_dmem_addr = -1;

// Register mapping
typedef struct {
    const char *name;
    int num;
} RegMapping;

static RegMapping regMap[] = {
    {"$zero",0},{"$imm1",1},{"$imm2",2},{"$v0",3},{"$a0",4},{"$a1",5},{"$a2",6},
    {"$t0",7},{"$t1",8},{"$t2",9},{"$s0",10},{"$s1",11},{"$s2",12},{"$gp",13},{"$sp",14},{"$ra",15}
};
#define REG_COUNT (sizeof(regMap)/sizeof(regMap[0]))

// Opcodes as per specification
static const char* opcodes[] = {
    "add","sub","mac","and","or","xor","sll","sra","srl",
    "beq","bne","blt","bgt","ble","bge","jal","lw","sw","reti","in","out","halt"
};

// Forward declarations
static void trim(char *s);
static int is_label_definition(const char *token);
static char* clean_reg(char *s);
static void first_pass();
static void second_pass(FILE *f_imem, FILE *f_dmem);

/* extern from asm.h
LineInfo lines[MAX_LINES];
int line_count;
Label labels[MAX_LABELS];
int label_count;
uint32_t dmem[DMEM_SIZE];
*/

// ------------------ Utility Functions ------------------
int opcode_of(const char *mnemonic) {
    int count=(int)(sizeof(opcodes)/sizeof(opcodes[0]));
    for(int i=0;i<count;i++){
        if(strcmp(mnemonic,opcodes[i])==0) return i;
    }
    fprintf(stderr,"Unknown opcode: %s\n",mnemonic);
    exit(1);
}

int register_number(const char *reg) {
    for(int i=0;i<REG_COUNT;i++){
        if(strcmp(regMap[i].name,reg)==0) return regMap[i].num;
    }
    fprintf(stderr,"Unknown register: %s\n",reg);
    exit(1);
}

int find_label_address(const char *label_name) {
    for(int i=0;i<label_count;i++){
        if(strcmp(labels[i].name,label_name)==0) {
            return labels[i].address;
        }
    }
    fprintf(stderr,"Label not found: %s\n",label_name);
    exit(1);
}

int32_t parse_immediate_final(const char *imm_str) {
    if(imm_str[0]=='0' && imm_str[1]=='x') {
        unsigned val=0;
        sscanf(imm_str,"%x",&val);
        return (int32_t)val;
    } else if(isdigit((unsigned char)imm_str[0]) ||
              (imm_str[0]=='-' && isdigit((unsigned char)imm_str[1]))) {
        // decimal integer (can be negative)
        int val=atoi(imm_str);
        return val;
    } else {
        // label
        return find_label_address(imm_str);
    }
}

// Encode a 48-bit instruction into 12 hex digits
void encode_instruction(FILE *fout, int opcode,int rd,int rs,int rt,int rm,int32_t imm1,int32_t imm2) {
    int32_t i1 = imm1 & 0xFFF; // keep lower 12 bits
    int32_t i2 = imm2 & 0xFFF; // keep lower 12 bits

    uint64_t inst=0;
    inst = ((uint64_t)(opcode &0xFF)<<40) |
           ((uint64_t)(rd&0xF)<<36) |
           ((uint64_t)(rs&0xF)<<32) |
           ((uint64_t)(rt&0xF)<<28) |
           ((uint64_t)(rm&0xF)<<24) |
           ((uint64_t)(i1&0xFFF)<<12)|
           ((uint64_t)(i2&0xFFF));

    fprintf(fout,"%012llX\n",(unsigned long long)inst);
}

// ------------------ Helpers ------------------
static void trim(char *s) {
    // remove trailing spaces
    char *end=s+strlen(s)-1;
    while(end>=s && isspace((unsigned char)*end)) {
        *end=0; 
        end--;
    }
    // remove leading
    char *start=s;
    while(*start && isspace((unsigned char)*start)) start++;
    if(start!=s) memmove(s,start,strlen(start)+1);
}

static int is_label_definition(const char *token) {
    int len=(int)strlen(token);
    return (len>0 && token[len-1]==':');
}

static char* clean_reg(char *s) {
    // just skip leading spaces, keep the '$'
    while(*s && isspace((unsigned char)*s)) s++;
    return s;
}

// ------------------ Pass #1: Label Addresses ------------------
static void first_pass() {
    int pc=0; 
    for(int i=0;i<line_count;i++){
        char *line=lines[i].line;
        // remove comment
        char *hash=strchr(line,'#');
        if(hash) *hash=0;
        trim(line);

        if(strlen(line)==0) {
            lines[i].is_instruction=0;
            continue;
        }

        char buffer[MAX_LINE_LEN];
        strcpy(buffer,line);
        char *token=strtok(buffer," \t,");
        if(!token) {
            lines[i].is_instruction=0;
            continue;
        }

        if(is_label_definition(token)) {
            // label definition
            token[strlen(token)-1]=0; // remove ':'
            strcpy(labels[label_count].name, token);
            labels[label_count].address=pc;
            label_count++;

            // see if there's an instruction or .word after
            char *next=strtok(NULL," \t,");
            if(!next) {
                lines[i].is_instruction=0;
            } else {
                if(strcmp(next,".word")==0) {
                    lines[i].is_instruction=0;
                } else {
                    lines[i].is_instruction=1;
                    lines[i].instruction_address=pc;
                    pc++;
                }
            }
        } else {
            if(strcmp(token,".word")==0) {
                lines[i].is_instruction=0;
            } else {
                // it’s an instruction
                lines[i].is_instruction=1;
                lines[i].instruction_address=pc;
                pc++;
            }
        }
    }
}

// ------------------ Pass #2: Encode + Data Memory ------------------
static void second_pass(FILE *f_imem, FILE *f_dmem) {
    // zero out dmem
    for(int i=0;i<DMEM_SIZE;i++){
        dmem[i]=0;
    }
    max_dmem_addr = -1; // nothing used yet

    for(int i=0;i<line_count;i++){
        char *line = lines[i].line;
        // remove comment
        char *hash = strchr(line,'#');
        if(hash) *hash=0;
        trim(line);
        if(strlen(line)==0) continue;

        char buffer[MAX_LINE_LEN];
        strcpy(buffer, line);
        char *token=strtok(buffer," \t,");
        if(!token) continue;

        // If label at start
        if(is_label_definition(token)) {
            // skip label
            token=strtok(NULL," \t,");
            if(!token) continue;
        }

        if(strcmp(token,".word")==0) {
            // .word address data
            char *addr_str=strtok(NULL," \t,");
            char *data_str=strtok(NULL," \t,");
            int32_t addr_val = parse_immediate_final(addr_str);
            int32_t data_val = parse_immediate_final(data_str);
            if(addr_val<0 || addr_val>=DMEM_SIZE) {
                fprintf(stderr,".word address out of range: %d\n",addr_val);
                exit(1);
            }
            dmem[addr_val] = (uint32_t)data_val;
            if(addr_val > max_dmem_addr) {
                max_dmem_addr = addr_val;
            }
            continue;
        }

        // Otherwise: instruction
        int opcode=opcode_of(token);

        char *rd_str   = strtok(NULL," \t,");
        char *rs_str   = strtok(NULL," \t,");
        char *rt_str   = strtok(NULL," \t,");
        char *rm_str   = strtok(NULL," \t,");
        char *imm1_str = strtok(NULL," \t,");
        char *imm2_str = strtok(NULL," \t,");

        if(!rd_str||!rs_str||!rt_str||!rm_str||!imm1_str||!imm2_str) {
            fprintf(stderr,"Invalid instruction format: %s\n", line);
            exit(1);
        }

        rd_str  = clean_reg(rd_str);
        rs_str  = clean_reg(rs_str);
        rt_str  = clean_reg(rt_str);
        rm_str  = clean_reg(rm_str);

        trim(imm1_str);
        trim(imm2_str);

        int32_t imm1 = parse_immediate_final(imm1_str);
        int32_t imm2 = parse_immediate_final(imm2_str);

        encode_instruction(f_imem, opcode,
                           register_number(rd_str),
                           register_number(rs_str),
                           register_number(rt_str),
                           register_number(rm_str),
                           imm1, imm2);
    }

    // Now write ONLY up to max_dmem_addr
    // If no .word used, max_dmem_addr will be -1 => we skip
    for(int i=0; i<=max_dmem_addr; i++){
        fprintf(f_dmem, "%08X\n", dmem[i]);
    }
}

int main(int argc, char *argv[]) {
    if(argc<4) {
        fprintf(stderr,"Usage: asm.exe program.asm imemin.txt dmemin.txt\n");
        return 1;
    }

    FILE *fin = fopen(argv[1],"r");
    if(!fin) {
        perror("fopen program.asm");
        return 1;
    }

    // read lines from program.asm
    while(line_count<MAX_LINES && fgets(lines[line_count].line, sizeof(lines[line_count].line), fin)) {
        trim(lines[line_count].line);
        line_count++;
    }
    fclose(fin);

    // pass #1 => label addresses
    first_pass();

    FILE *f_imem = fopen(argv[2],"w");
    FILE *f_dmem = fopen(argv[3],"w");
    if(!f_imem || !f_dmem) {
        perror("fopen output");
        return 1;
    }

    // pass #2 => encode instructions + build data memory
    second_pass(f_imem, f_dmem);

    fclose(f_imem);
    fclose(f_dmem);
    return 0;
}
