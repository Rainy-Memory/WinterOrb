`include "header.v"

/*
 * module Decoder
 * --------------------------------------------------
 * This module implements Decoder in tomasulo's algorithm.
 * Meanwhile, it expands immediate number to 32 bit by its
 * sign bit.
 */

module Decoder (
    input  wire                      rst,

    // Fetcher
    input  wire                      fet_issue_signal_in,
    input  wire [`INSTRUCTION_RANGE] fet_inst_in,
    input  wire [`WORD_RANGE]        fet_pc_in,

    // Dispatcher
    output reg  [`WORD_RANGE]        dis_imm_out,
    output reg  [`INNER_INST_RANGE]  dis_inst_type_out,
    output wire [`REG_INDEX_RANGE]   dis_rs1_out,
    output wire [`REG_INDEX_RANGE]   dis_rs2_out,
    output wire [`REG_INDEX_RANGE]   dis_rd_out,
    output wire [`SHAMT_RANGE]       dis_shamt_out,
    output wire                      dis_ready_out,
    output wire [`WORD_RANGE]        dis_pc_out,
    output reg  [1:0]                dis_to_lsb_signal_out, // first bit represents to LSB, second bit: LOAD->0, STORE->1
    output reg  [2:0]                dis_lsb_goal_out,

    // RegisterFile
    output wire [`REG_INDEX_RANGE]   rf_rs1_out,
    output wire [`REG_INDEX_RANGE]   rf_rs2_out,
    output wire [`REG_INDEX_RANGE]   rf_rd_out,
    output reg                       rf_occpuy_rd_out,
    input  wire [`WORD_RANGE]        rf_Vj_in, // value of rs1
    input  wire [`WORD_RANGE]        rf_Vk_in, // value of rs2
    input  wire [`ROB_TAG_RANGE]     rf_Qj_in, // tag of rs1
    input  wire [`ROB_TAG_RANGE]     rf_Qk_in, // tag of rs2
    input  wire [`ROB_TAG_RANGE]     rf_dest_in,

    // ReservationStation & LoadStoreBuffer
    output wire [`WORD_RANGE]        Vj_out,
    output wire [`WORD_RANGE]        Vk_out,
    output wire [`ROB_TAG_RANGE]     Qj_out,
    output wire [`ROB_TAG_RANGE]     Qk_out,
    output wire [`ROB_TAG_RANGE]     dest_out,

    // ReorderBuffer
    output wire [`INSTRUCTION_RANGE] rob_inst_out,
    output wire [`REG_INDEX_RANGE]   rob_rd_out,
    output wire [`ROB_TAG_RANGE]     rob_Qj_out,
    output wire [`ROB_TAG_RANGE]     rob_Qk_out,
    input  wire                      rob_Vj_ready_in,
    input  wire                      rob_Vk_ready_in,
    input  wire [`WORD_RANGE]        rob_Vj_in,
    input  wire [`WORD_RANGE]        rob_Vk_in
);

    integer dec_log;

    wire [`WORD_RANGE] immI, immS, immB, immU, immJ;

    assign immI = {{20{fet_inst_in[31]}}, fet_inst_in[31:20]};
    assign immS = {{20{fet_inst_in[31]}}, fet_inst_in[31:25], fet_inst_in[11:7]};
    assign immB = {{20{fet_inst_in[31]}}, fet_inst_in[7], fet_inst_in[30:25], fet_inst_in[11:8], 1'b0};
    assign immU = {fet_inst_in[31:12], 12'b0};
    assign immJ = {{12{fet_inst_in[31]}}, fet_inst_in[19:12], fet_inst_in[20], fet_inst_in[30:21], 1'b0};

    assign dis_rs1_out   = fet_inst_in[19:15];
    assign dis_rs2_out   = fet_inst_in[24:20];
    assign dis_rd_out    = fet_inst_in[11: 7];
    assign dis_shamt_out = fet_inst_in[24:20];
    assign dis_ready_out = fet_issue_signal_in;
    assign dis_pc_out    = fet_pc_in;

    assign rf_rs1_out = dis_rs1_out;
    assign rf_rs2_out = dis_rs2_out;
    assign rf_rd_out  = dis_rd_out;
    
    assign rob_inst_out = fet_inst_in;
    assign rob_rd_out   = dis_rd_out;

    assign rob_Qj_out = rf_Qj_in;
    assign rob_Qk_out = rf_Qk_in;

    assign Vj_out   = rf_Qj_in == `NULL_TAG ? rf_Vj_in : (rob_Vj_ready_in ? rob_Vj_in : `ZERO_WORD);
    assign Vk_out   = rf_Qk_in == `NULL_TAG ? rf_Vk_in : (rob_Vk_ready_in ? rob_Vk_in : `ZERO_WORD);
    assign Qj_out   = rf_Qj_in == `NULL_TAG ? `NULL_TAG : (rob_Vj_ready_in ? `NULL_TAG : rf_Qj_in);
    assign Qk_out   = rf_Qk_in == `NULL_TAG ? `NULL_TAG : (rob_Vk_ready_in ? `NULL_TAG : rf_Qk_in);
    assign dest_out = rf_dest_in;

    initial begin
        dec_log = $fopen(`DEC_LOG_PATH, "w");
    end

    always @(*) begin
        $fdisplay(dec_log, "current instruction: %h, issue_signal: %d, rst: %d", fet_inst_in, fet_issue_signal_in, rst);
            dis_to_lsb_signal_out = {`FALSE, 1'b0};
            dis_lsb_goal_out = 3'b0;
            rf_occpuy_rd_out = `TRUE;
        if (rst) begin
            $fdisplay(dec_log, "resetting...");
            dis_imm_out = `ZERO_WORD;
            dis_inst_type_out = `NOP;
        end else begin
            if (fet_issue_signal_in) begin
                case (fet_inst_in[6:0])
                    `LUI_OPCODE: begin
                        dis_imm_out = immU;
                        dis_inst_type_out = `LUI;
                        $fdisplay(dec_log, "LUI, immU = %d, rd = %d", immU, dis_rd_out);
                    end
                    `AUIPC_OPCODE: begin
                        dis_imm_out = immU;
                        dis_inst_type_out = `AUIPC;
                        $fdisplay(dec_log, "AUIPC, immU = %d, rd = %d", immU, dis_rd_out);
                    end
                    `JAL_OPCODE: begin
                        dis_imm_out = immJ;
                        dis_inst_type_out = `JAL;
                        $fdisplay(dec_log, "JAL, immJ = %d, rd = %d", immJ, dis_rd_out);
                    end
                    `JALR_OPCODE: begin
                        dis_imm_out = immI;
                        dis_inst_type_out = `JALR;
                        $fdisplay(dec_log, "JALR, immI = %d, rd = %d", immI, dis_rd_out);
                    end
                    `BRANCH_OPCODE: begin
                        dis_imm_out = immB;
                        case (fet_inst_in[14:12])
                            `BEQ_FUNCT3:  begin dis_inst_type_out = `BEQ;  $fdisplay(dec_log, "BEQ, immB = %d, rs1 = %d, rs2 = %d",  immB, dis_rs1_out, dis_rs2_out); end
                            `BNE_FUNCT3:  begin dis_inst_type_out = `BNE;  $fdisplay(dec_log, "BNE, immB = %d, rs1 = %d, rs2 = %d",  immB, dis_rs1_out, dis_rs2_out); end
                            `BLT_FUNCT3:  begin dis_inst_type_out = `BLT;  $fdisplay(dec_log, "BLT, immB = %d, rs1 = %d, rs2 = %d",  immB, dis_rs1_out, dis_rs2_out); end
                            `BGE_FUNCT3:  begin dis_inst_type_out = `BGE;  $fdisplay(dec_log, "BGE, immB = %d, rs1 = %d, rs2 = %d",  immB, dis_rs1_out, dis_rs2_out); end
                            `BLTU_FUNCT3: begin dis_inst_type_out = `BLTU; $fdisplay(dec_log, "BLTU, immB = %d, rs1 = %d, rs2 = %d", immB, dis_rs1_out, dis_rs2_out); end
                            `BGEU_FUNCT3: begin dis_inst_type_out = `BGEU; $fdisplay(dec_log, "BGEU, immB = %d, rs1 = %d, rs2 = %d", immB, dis_rs1_out, dis_rs2_out); end
                        endcase
                        rf_occpuy_rd_out = `FALSE;
                    end
                    `LOAD_OPCODE: begin
                        dis_imm_out = immI;
                        case (fet_inst_in[14:12])
                            `LB_FUNCT3:  begin dis_inst_type_out = `LB;  dis_lsb_goal_out = 3'b001; $fdisplay(dec_log, "LB, immI = %d, rs1 = %d, rd = %d",  immI, dis_rs1_out, dis_rd_out); end
                            `LH_FUNCT3:  begin dis_inst_type_out = `LH;  dis_lsb_goal_out = 3'b010; $fdisplay(dec_log, "LH, immI = %d, rs1 = %d, rd = %d",  immI, dis_rs1_out, dis_rd_out); end
                            `LW_FUNCT3:  begin dis_inst_type_out = `LW;  dis_lsb_goal_out = 3'b100; $fdisplay(dec_log, "LW, immI = %d, rs1 = %d, rd = %d",  immI, dis_rs1_out, dis_rd_out); end
                            `LBU_FUNCT3: begin dis_inst_type_out = `LBU; dis_lsb_goal_out = 3'b001; $fdisplay(dec_log, "LBU, immI = %d, rs1 = %d, rd = %d", immI, dis_rs1_out, dis_rd_out); end
                            `LHU_FUNCT3: begin dis_inst_type_out = `LHU; dis_lsb_goal_out = 3'b010; $fdisplay(dec_log, "LHU, immI = %d, rs1 = %d, rd = %d", immI, dis_rs1_out, dis_rd_out); end
                        endcase
                        dis_to_lsb_signal_out = {`TRUE, 1'b0};
                    end
                    `STORE_OPCODE: begin
                        dis_imm_out = immS;
                        case (fet_inst_in[14:12])
                            `SB_FUNCT3: begin dis_inst_type_out = `SB; dis_lsb_goal_out = 3'b001; $fdisplay(dec_log, "SB, immS = %d, rs1 = %d, rs2 = %d", immS, dis_rs1_out, dis_rs2_out); end
                            `SH_FUNCT3: begin dis_inst_type_out = `SH; dis_lsb_goal_out = 3'b010; $fdisplay(dec_log, "SH, immS = %d, rs1 = %d, rs2 = %d", immS, dis_rs1_out, dis_rs2_out); end
                            `SW_FUNCT3: begin dis_inst_type_out = `SW; dis_lsb_goal_out = 3'b100; $fdisplay(dec_log, "SW, immS = %d, rs1 = %d, rs2 = %d", immS, dis_rs1_out, dis_rs2_out); end
                        endcase
                        dis_to_lsb_signal_out = {`TRUE, 1'b1};
                        rf_occpuy_rd_out = `FALSE;
                    end
                    `ARITH_IMM_OPCODE: begin
                        dis_imm_out = immI;
                        case (fet_inst_in[14:12])
                            `ADDI_FUNCT3:  begin dis_inst_type_out = `ADDI;  $fdisplay(dec_log, "ADDI, immI = %d, rs1 = %d, rd = %d",  immI,          dis_rs1_out, dis_rd_out); end
                            `SLTI_FUNCT3:  begin dis_inst_type_out = `SLTI;  $fdisplay(dec_log, "SLTI, immI = %d, rs1 = %d, rd = %d",  immI,          dis_rs1_out, dis_rd_out); end
                            `SLTIU_FUNCT3: begin dis_inst_type_out = `SLTIU; $fdisplay(dec_log, "SLTIU, immI = %d, rs1 = %d, rd = %d", immI,          dis_rs1_out, dis_rd_out); end
                            `XORI_FUNCT3:  begin dis_inst_type_out = `XORI;  $fdisplay(dec_log, "XORI, immI = %d, rs1 = %d, rd = %d",  immI,          dis_rs1_out, dis_rd_out); end
                            `ORI_FUNCT3:   begin dis_inst_type_out = `ORI;   $fdisplay(dec_log, "ORI, immI = %d, rs1 = %d, rd = %d",   immI,          dis_rs1_out, dis_rd_out); end
                            `ANDI_FUNCT3:  begin dis_inst_type_out = `ANDI;  $fdisplay(dec_log, "ANDI, immI = %d, rs1 = %d, rd = %d",  immI,          dis_rs1_out, dis_rd_out); end
                            `SLLI_FUNCT3:  begin dis_inst_type_out = `SLLI;  $fdisplay(dec_log, "SLLI, shamt = %d, rs1 = %d, rd = %d", dis_shamt_out, dis_rs1_out, dis_rd_out); end
                            `SRxI_FUNCT3:  begin
                                if (fet_inst_in[31:25] == `ZERO_FUNCT7) begin
                                    dis_inst_type_out = `SRLI; $fdisplay(dec_log, "SRLI, shamt = %d, rs1 = %d, rd = %d", dis_shamt_out, dis_rs1_out, dis_rd_out);
                                end else begin 
                                    dis_inst_type_out = `SRAI; $fdisplay(dec_log, "SRAI, shamt = %d, rs1 = %d, rd = %d", dis_shamt_out, dis_rs1_out, dis_rd_out);
                                end
                            end
                        endcase
                    end
                    `ARITH_OPCODE: begin
                        dis_imm_out = `ZERO_WORD; // R type inst does not have imm
                        case (fet_inst_in[14:12])
                            `AS_FUNCT3:  begin
                                if (fet_inst_in[31:25] == `ZERO_FUNCT7) begin
                                    dis_inst_type_out = `ADD; $fdisplay(dec_log, "ADD, no imm, rs1 = %d, rs2 = %d, rd = %d",  dis_rs1_out, dis_rs2_out, dis_rd_out);
                                end else begin
                                    dis_inst_type_out = `SUB; $fdisplay(dec_log, "SUB, no imm, rs1 = %d, rs2 = %d, rd = %d",  dis_rs1_out, dis_rs2_out, dis_rd_out);
                                end
                            end
                            `SLL_FUNCT3:  begin dis_inst_type_out = `SLL;  $fdisplay(dec_log, "SLL, no imm, rs1 = %d, rs2 = %d, rd = %d",  dis_rs1_out, dis_rs2_out, dis_rd_out); end
                            `SLT_FUNCT3:  begin dis_inst_type_out = `SLT;  $fdisplay(dec_log, "SLT, no imm, rs1 = %d, rs2 = %d, rd = %d",  dis_rs1_out, dis_rs2_out, dis_rd_out); end
                            `SLTU_FUNCT3: begin dis_inst_type_out = `SLTU; $fdisplay(dec_log, "SLTU, no imm, rs1 = %d, rs2 = %d, rd = %d", dis_rs1_out, dis_rs2_out, dis_rd_out); end
                            `XOR_FUNCT3:  begin dis_inst_type_out = `XOR;  $fdisplay(dec_log, "XOR, no imm, rs1 = %d, rs2 = %d, rd = %d",  dis_rs1_out, dis_rs2_out, dis_rd_out); end
                            `SRL_FUNCT3:  begin dis_inst_type_out = `SRL;  $fdisplay(dec_log, "SRL, no imm, rs1 = %d, rs2 = %d, rd = %d",  dis_rs1_out, dis_rs2_out, dis_rd_out); end
                            `SRA_FUNCT3:  begin dis_inst_type_out = `SRA;  $fdisplay(dec_log, "SRA, no imm, rs1 = %d, rs2 = %d, rd = %d",  dis_rs1_out, dis_rs2_out, dis_rd_out); end
                            `OR_FUNCT3:   begin dis_inst_type_out = `OR;   $fdisplay(dec_log, "OR, no imm, rs1 = %d, rs2 = %d, rd = %d",   dis_rs1_out, dis_rs2_out, dis_rd_out); end
                            `AND_FUNCT3:  begin dis_inst_type_out = `AND;  $fdisplay(dec_log, "AND, no imm, rs1 = %d, rs2 = %d, rd = %d",  dis_rs1_out, dis_rs2_out, dis_rd_out); end
                        endcase
                    end
                endcase
            end else $fdisplay(dec_log, "waiting for instruction to decode...");
        end
    end

endmodule