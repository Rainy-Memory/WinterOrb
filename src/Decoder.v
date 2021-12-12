`include "header.v"

/*
 * module Decoder
 * --------------------------------------------------
 * This module implements Decoder in tomasulo's algorithm.
 * Meanwhile, it expands immediate number to 32 bit by its
 * sign bit and fetch register value.
 */

module Decoder (
    // Fetcher
    input  wire                     fet_issue_in,
    input  wire [`WORD_RANGE]       fet_inst_in,
    input  wire [`WORD_RANGE]       fet_pc_in,
    input  wire [`WORD_RANGE]       fet_predict_pc_in,

    // Dispatcher
    output wire                     dis_ready_out,
    output reg  [1:0]               dis_to_lsb_signal_out, // first bit represents to LSB, second bit: LOAD->0, STORE->1

    // RegisterFile
    input  wire [`WORD_RANGE]       rf_Vj_in, // value of rs1
    input  wire [`WORD_RANGE]       rf_Vk_in, // value of rs2
    input  wire [`ROB_TAG_RANGE]    rf_Qj_in, // tag of rs1
    input  wire [`ROB_TAG_RANGE]    rf_Qk_in, // tag of rs2
    output wire [`REG_INDEX_RANGE]  rf_rs1_out,
    output wire [`REG_INDEX_RANGE]  rf_rs2_out,
    output wire [`REG_INDEX_RANGE]  rf_rd_out,
    output reg                      rf_occupy_rd_out,

    // ReservationStation & LoadStoreBuffer
    output reg  [`INNER_INST_RANGE] op_out,
    output wire [`WORD_RANGE]       Vj_out,
    output wire [`WORD_RANGE]       Vk_out,
    output wire [`ROB_TAG_RANGE]    Qj_out,
    output wire [`ROB_TAG_RANGE]    Qk_out,
    output reg  [`WORD_RANGE]       imm_out,
    output wire [`WORD_RANGE]       pc_out,

    // ReservationStation & LoadStoreBuffer & RegisterFile
    output wire [`ROB_TAG_RANGE]    next_tag_out,

    // ReservationStation
    output reg  [1:0]               rs_have_source_register_out,

    // LoadStoreBuffer
    output reg  [2:0]               lsb_goal_out,

    // ReorderBuffer
    input  wire [`ROB_TAG_RANGE]    rob_next_tag_in, // tag of rd
    input  wire                     rob_Vj_ready_in,
    input  wire                     rob_Vk_ready_in,
    input  wire [`WORD_RANGE]       rob_Vj_in,
    input  wire [`WORD_RANGE]       rob_Vk_in,
    output wire                     rob_issue_out,
    output wire [`WORD_RANGE]       rob_predict_pc_out,
    output wire [`WORD_RANGE]       rob_inst_out,
    output wire [`REG_INDEX_RANGE]  rob_rd_out,
    output wire [`ROB_TAG_RANGE]    rob_Qj_out,
    output wire [`ROB_TAG_RANGE]    rob_Qk_out
);

    wire [`WORD_RANGE] immI, immS, immB, immU, immJ;

    assign immI = {{20{fet_inst_in[31]}}, fet_inst_in[31:20]};
    assign immS = {{20{fet_inst_in[31]}}, fet_inst_in[31:25], fet_inst_in[11:7]};
    assign immB = {{20{fet_inst_in[31]}}, fet_inst_in[7], fet_inst_in[30:25], fet_inst_in[11:8], 1'b0};
    assign immU = {fet_inst_in[31:12], 12'b0};
    assign immJ = {{12{fet_inst_in[31]}}, fet_inst_in[19:12], fet_inst_in[20], fet_inst_in[30:21], 1'b0};

    assign next_tag_out = rob_next_tag_in;

    assign dis_ready_out = fet_issue_in;

    assign pc_out = fet_pc_in;

    assign rf_rs1_out = fet_inst_in[19:15];
    assign rf_rs2_out = fet_inst_in[24:20];
    assign rf_rd_out  = fet_inst_in[11: 7];

    assign rob_Qj_out = rf_Qj_in;
    assign rob_Qk_out = rf_Qk_in;
    assign Vj_out     = rf_Qj_in == `NULL_TAG ?  rf_Vj_in : (rob_Vj_ready_in ? rob_Vj_in : `ZERO_WORD);
    assign Vk_out     = rf_Qk_in == `NULL_TAG ?  rf_Vk_in : (rob_Vk_ready_in ? rob_Vk_in : `ZERO_WORD);
    assign Qj_out     = rf_Qj_in == `NULL_TAG ? `NULL_TAG : (rob_Vj_ready_in ? `NULL_TAG : rf_Qj_in);
    assign Qk_out     = rf_Qk_in == `NULL_TAG ? `NULL_TAG : (rob_Vk_ready_in ? `NULL_TAG : rf_Qk_in);

    assign rob_issue_out      = fet_issue_in;
    assign rob_predict_pc_out = fet_predict_pc_in;
    assign rob_inst_out       = fet_inst_in;
    assign rob_rd_out         = rf_rd_out;

    always @(*) begin
        dis_to_lsb_signal_out = {`FALSE, 1'b0};
        lsb_goal_out = 3'b0;
        rf_occupy_rd_out = fet_issue_in ? `TRUE : `FALSE;
        imm_out = `ZERO_WORD;
        op_out = `NOP;
        rs_have_source_register_out = 2'b11;
        if (fet_issue_in) begin
            case (fet_inst_in[6:0])
                `LUI_OPCODE: begin
                    imm_out = immU;
                    op_out = `LUI;
                    rs_have_source_register_out = 2'b00;
                end
                `AUIPC_OPCODE: begin
                    imm_out = immU;
                    op_out = `AUIPC;
                    rs_have_source_register_out = 2'b00;
                end
                `JAL_OPCODE: begin
                    imm_out = immJ;
                    op_out = `JAL;
                    rs_have_source_register_out = 2'b00;
                end
                `JALR_OPCODE: begin
                    imm_out = immI;
                    op_out = `JALR;
                    rs_have_source_register_out = 2'b01;
                end
                `BRANCH_OPCODE: begin
                    imm_out = immB;
                    case (fet_inst_in[14:12])
                        `BEQ_FUNCT3:  begin op_out = `BEQ;  end
                        `BNE_FUNCT3:  begin op_out = `BNE;  end
                        `BLT_FUNCT3:  begin op_out = `BLT;  end
                        `BGE_FUNCT3:  begin op_out = `BGE;  end
                        `BLTU_FUNCT3: begin op_out = `BLTU; end
                        `BGEU_FUNCT3: begin op_out = `BGEU; end
                    endcase
                    rf_occupy_rd_out = `FALSE;
                end
                `LOAD_OPCODE: begin
                    imm_out = immI;
                    case (fet_inst_in[14:12])
                        `LB_FUNCT3:  begin op_out = `LB;  lsb_goal_out = 3'b001; end
                        `LH_FUNCT3:  begin op_out = `LH;  lsb_goal_out = 3'b010; end
                        `LW_FUNCT3:  begin op_out = `LW;  lsb_goal_out = 3'b100; end
                        `LBU_FUNCT3: begin op_out = `LBU; lsb_goal_out = 3'b001; end
                        `LHU_FUNCT3: begin op_out = `LHU; lsb_goal_out = 3'b010; end
                    endcase
                    dis_to_lsb_signal_out = {`TRUE, 1'b0};
                    rs_have_source_register_out = 2'b01;
                end
                `STORE_OPCODE: begin
                    imm_out = immS;
                    case (fet_inst_in[14:12])
                        `SB_FUNCT3: begin op_out = `SB; lsb_goal_out = 3'b001; end
                        `SH_FUNCT3: begin op_out = `SH; lsb_goal_out = 3'b010; end
                        `SW_FUNCT3: begin op_out = `SW; lsb_goal_out = 3'b100; end
                    endcase
                    dis_to_lsb_signal_out = {`TRUE, 1'b1};
                    rf_occupy_rd_out = `FALSE;
                end
                `ARITH_IMM_OPCODE: begin
                    imm_out = immI;
                    case (fet_inst_in[14:12])
                        `ADDI_FUNCT3:  begin op_out = `ADDI;  end
                        `SLTI_FUNCT3:  begin op_out = `SLTI;  end
                        `SLTIU_FUNCT3: begin op_out = `SLTIU; end
                        `XORI_FUNCT3:  begin op_out = `XORI;  end
                        `ORI_FUNCT3:   begin op_out = `ORI;   end
                        `ANDI_FUNCT3:  begin op_out = `ANDI;  end
                        `SLLI_FUNCT3:  begin op_out = `SLLI;  end
                        `SRxI_FUNCT3:  begin
                            if (fet_inst_in[31:25] == `ZERO_FUNCT7) op_out = `SRLI;
                            else op_out = `SRAI;
                        end
                    endcase
                    rs_have_source_register_out = 2'b01;
                end
                `ARITH_OPCODE: begin
                    imm_out = `ZERO_WORD; // R type inst does not have imm
                    case (fet_inst_in[14:12])
                        `AS_FUNCT3:   begin
                            if (fet_inst_in[31:25] == `ZERO_FUNCT7) op_out = `ADD;
                            else op_out = `SUB;
                        end
                        `SLL_FUNCT3:  begin op_out = `SLL;  end
                        `SLT_FUNCT3:  begin op_out = `SLT;  end
                        `SLTU_FUNCT3: begin op_out = `SLTU; end
                        `XOR_FUNCT3:  begin op_out = `XOR;  end
                        `SRL_FUNCT3:  begin op_out = `SRL;  end
                        `SRA_FUNCT3:  begin op_out = `SRA;  end
                        `OR_FUNCT3:   begin op_out = `OR;   end
                        `AND_FUNCT3:  begin op_out = `AND;  end
                    endcase
                end
            endcase
        end
    end

endmodule