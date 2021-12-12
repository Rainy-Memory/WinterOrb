`include "header.v"

/*
 * module ArithmeticLogicUnit
 * --------------------------------------------------
 * This module implements ArithmeticLogic in tomasulo's
 * algorithm.
 */

module ArithmeticLogicUnit (
    // ReservationStation
    input  wire                     rs_calculate_signal_in,
    input  wire [`INNER_INST_RANGE] rs_op_in,
    input  wire [`WORD_RANGE]       rs_imm_in,
    input  wire [`WORD_RANGE]       rs_pc_in,
    input  wire [`WORD_RANGE]       rs_rs1val_in,
    input  wire [`WORD_RANGE]       rs_rs2val_in,
    input  wire [`ROB_TAG_RANGE]    rs_dest_in,

    // ReservationStation && LoadStoreBuffer && ReorderBuffer
    output wire                     broadcast_signal_out,
    output reg  [`WORD_RANGE]       result_out,
    output wire [`ROB_TAG_RANGE]    dest_tag_out,

    // ReorderBuffer
    output  reg  [`WORD_RANGE]      rob_new_pc_out
);

    wire [`WORD_RANGE] rs_shamt_in;
    assign rs_shamt_in = {27'b0, rs_imm_in[4:0]};

    assign dest_tag_out = rs_dest_in;
    assign broadcast_signal_out = rs_calculate_signal_in;

    always @(*) begin
        rob_new_pc_out = rs_pc_in + 4;
        case (rs_op_in)
            `LUI: result_out = rs_imm_in;
            `AUIPC: begin
                result_out = rs_pc_in + rs_imm_in;
                rob_new_pc_out = rs_pc_in + rs_imm_in;
            end
            `JAL: result_out = rs_pc_in + 4;
            `JALR: begin
                result_out = rs_pc_in + 4;
                rob_new_pc_out = (rs_rs1val_in + rs_imm_in) & -1;
            end
            `BEQ: begin
                result_out = rs_rs1val_in == rs_rs2val_in;
                rob_new_pc_out = rs_rs1val_in == rs_rs2val_in ? rs_pc_in + rs_imm_in : rs_pc_in + 4;
            end
            `BNE: begin
                result_out = rs_rs1val_in != rs_rs2val_in;
                rob_new_pc_out = rs_rs1val_in != rs_rs2val_in ? rs_pc_in + rs_imm_in : rs_pc_in + 4;
            end
            `BLT: begin
                result_out = $signed(rs_rs1val_in) < $signed(rs_rs2val_in);
                rob_new_pc_out = $signed(rs_rs1val_in) < $signed(rs_rs2val_in) ? rs_pc_in + rs_imm_in : rs_pc_in + 4;
            end
            `BGE: begin
                result_out = $signed(rs_rs1val_in) >= $signed(rs_rs2val_in);
                rob_new_pc_out = $signed(rs_rs1val_in) >= $signed(rs_rs2val_in) ? rs_pc_in + rs_imm_in : rs_pc_in + 4;
            end
            `BLTU: begin
                result_out = rs_rs1val_in < rs_rs2val_in;
                rob_new_pc_out = rs_rs1val_in < rs_rs2val_in ? rs_pc_in + rs_imm_in : rs_pc_in + 4;
            end
            `BGEU: begin
                result_out = rs_rs1val_in >= rs_rs2val_in;
                rob_new_pc_out = rs_rs1val_in >= rs_rs2val_in ? rs_pc_in + rs_imm_in : rs_pc_in + 4;
            end
            `ADDI:  result_out = rs_rs1val_in + rs_imm_in;
            `SLTI:  result_out = $signed(rs_rs1val_in) < $signed(rs_imm_in) ? 1 : 0;
            `SLTIU: result_out = rs_rs1val_in < rs_imm_in ? 1 : 0;
            `XORI:  result_out = rs_rs1val_in ^ rs_imm_in;
            `ORI:   result_out = rs_rs1val_in | rs_imm_in;
            `ANDI:  result_out = rs_rs1val_in & rs_imm_in;
            `SLLI:  result_out = rs_rs1val_in << rs_shamt_in;
            `SRLI:  result_out = rs_rs1val_in >> rs_shamt_in;
            `SRAI:  result_out = rs_rs1val_in >>> rs_shamt_in;
            `ADD:   result_out = rs_rs1val_in + rs_rs2val_in;
            `SUB:   result_out = rs_rs1val_in - rs_rs2val_in;
            `SLL:   result_out = rs_rs1val_in << rs_rs2val_in;
            `SRL:   result_out = rs_rs1val_in >> rs_rs2val_in;
            `SRA:   result_out = rs_rs1val_in >>> rs_rs2val_in;
            `SLT:   result_out = $signed(rs_rs1val_in) < $signed(rs_rs2val_in) ? 1 : 0;
            `SLTU:  result_out = rs_rs1val_in < rs_rs2val_in ? 1 : 0;
            `XOR:   result_out = rs_rs1val_in ^ rs_rs2val_in;
            `OR:    result_out = rs_rs1val_in | rs_rs2val_in;
            `AND:   result_out = rs_rs1val_in & rs_rs2val_in;
            default: begin
                result_out = `ZERO_WORD;
                rob_new_pc_out = rs_pc_in;
            end
        endcase
    end
    
endmodule