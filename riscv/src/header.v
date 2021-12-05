`default_nettype none

// log paths
`define FET_LOG_PATH   "bin/fetcher_log.txt"
`define IB_LOG_PATH    "bin/instruction_buffer_log.txt"
`define DEC_LOG_PATH   "bin/decoder_log.txt"
`define DIS_LOG_PATH   "bin/dispatcher_log.txt"

// constants
`define TRUE                       1'b1
`define FALSE                      1'b0
`define WRITE                      1'b1
`define READ                       1'b0
`define ZERO_WORD                 32'b0
`define ZERO_BYTE                  8'b0
`define NULL_TAG        `ROB_TAG_LEN'b0
`define ZERO_REG_INDEX             5'b0 // @see REG_INDEX_RANGE
`define NULL_ENTRY                 4'b1111

// capacities
`define RF_CAPACITY    32 // @see RF_INDEX_LEN
`define ROB_CAPACITY   15 // @see ROB_TAG_LEN
`define LSB_CAPACITY   15 // @see LSB_INDEX_RANGE
`define RS_CAPACITY    15

// lens
`define RAM_DATA_LEN    8
`define ROB_TAG_LEN     4 // @see ROB_CAPACITY

// ranges
`define INSTRUCTION_RANGE                  31 : 0
`define RAM_DATA_RANGE      `RAM_DATA_LEN - 1 : 0
`define WORD_RANGE                         31 : 0
`define RF_RANGE             `RF_CAPACITY - 1 : 0
`define RS_RANGE             `RS_CAPACITY - 1 : 0
`define LSB_RANGE           `LSB_CAPACITY - 1 : 0
`define LSB_INDEX_RANGE                     4 : 0
`define ROB_RANGE           `ROB_CAPACITY - 1 : 0
`define ROB_TAG_RANGE        `ROB_TAG_LEN - 1 : 0
`define INNER_INST_RANGE                   39 : 0
`define REG_INDEX_RANGE                     4 : 0 // @see ZERO_REG_INDEX
`define SHAMT_RANGE                         4 : 0

// opcode
`define LUI_OPCODE         7'b0110111
`define AUIPC_OPCODE       7'b0010111
`define JAL_OPCODE         7'b1101111
`define JALR_OPCODE        7'b1100111
`define BRANCH_OPCODE      7'b1100011
`define LOAD_OPCODE        7'b0000011
`define STORE_OPCODE       7'b0100011
`define ARITH_IMM_OPCODE   7'b0010011
`define ARITH_OPCODE       7'b0110011

// funct3
`define ZERO_FUNCT3    3'b000
`define JALR_FUNCT3    3'b000
`define BEQ_FUNCT3     3'b000
`define BNE_FUNCT3     3'b001
`define BLT_FUNCT3     3'b100
`define BGE_FUNCT3     3'b101
`define BLTU_FUNCT3    3'b110
`define BGEU_FUNCT3    3'b111
`define LB_FUNCT3      3'b000
`define LH_FUNCT3      3'b001
`define LW_FUNCT3      3'b010
`define LBU_FUNCT3     3'b100
`define LHU_FUNCT3     3'b101
`define SB_FUNCT3      3'b000
`define SH_FUNCT3      3'b001
`define SW_FUNCT3      3'b010
`define ADDI_FUNCT3    3'b000
`define SLTI_FUNCT3    3'b010
`define SLTIU_FUNCT3   3'b011
`define XORI_FUNCT3    3'b100
`define ORI_FUNCT3     3'b110
`define ANDI_FUNCT3    3'b111
`define SLLI_FUNCT3    3'b001
`define SRxI_FUNCT3    3'b101
`define AS_FUNCT3      3'b000
`define SLL_FUNCT3     3'b001
`define SLT_FUNCT3     3'b010
`define SLTU_FUNCT3    3'b011
`define XOR_FUNCT3     3'b100
`define SRL_FUNCT3     3'b101
`define SRA_FUNCT3     3'b101
`define OR_FUNCT3      3'b110
`define AND_FUNCT3     3'b111

// funct7
`define ZERO_FUNCT7   7'b0000000
`define ONE_FUNCT7    7'b0100000

// using blank to ensure fix-length of inner instruction identifier
// @see INNER_INST_RANGE
`define NOP     "NOP  "
`define LUI     "LUI  "
`define AUIPC   "AUIPC"
`define JAL     "JAL  "
`define JALR    "JALR "
`define BEQ     "BEQ  "
`define BNE     "BNE  "
`define BLT     "BLT  "
`define BGE     "BGE  "
`define BLTU    "BLTU "
`define BGEU    "BGEU "
`define LB      "LB   "
`define LH      "LH   "
`define LW      "LW   "
`define LBU     "LBU  "
`define LHU     "LHU  "
`define SB      "SB   "
`define SH      "SH   "
`define SW      "SW   "
`define ADDI    "ADDI "
`define SLTI    "SLTI "
`define SLTIU   "SLTIU"
`define XORI    "XORI "
`define ORI     "ORI  "
`define ANDI    "ANDI "
`define SLLI    "SLLI "
`define SRLI    "SRLI "
`define SRAI    "SRAI "
`define ADD     "ADD  "
`define SUB     "SUB  "
`define SLL     "SLL  "
`define SLT     "SLT  "
`define SLTU    "SLTU "
`define XOR     "XOR  "
`define SRL     "SRL  "
`define SRA     "SRA  "
`define OR      "OR   "
`define AND     "AND  "