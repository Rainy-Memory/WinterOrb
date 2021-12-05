`include "header.v"

module ArithmeticLogicUnit (
    // ReservationStation
    input  wire [`INNER_INST_RANGE] rs_op_in,
    input  wire [`WORD_RANGE]       rs_imm_in,
    input  wire [`WORD_RANGE]       rs_pc_in,
    input  wire [`WORD_RANGE]       rs_lhs_in,
    input  wire [`WORD_RANGE]       rs_rhs_in,
    input  wire [`ROB_TAG_RANGE]    rs_dest_in,

    // ReservationStation && LoadStoreBuffer && ReorderBuffer
    output reg                      broadcast_signal_out,
    output reg  [`WORD_RANGE]       result_out,
    output wire [`ROB_TAG_RANGE]    dest_tag_out,

    // ReorderBuffer
    output  reg  [`WORD_RANGE]      rob_new_pc_out
);

    assign dest_tag_out = rs_dest_in;

    always @(*) begin
        rob_new_pc_out = rs_pc_in;
        case (rs_op_in)
            `LUI: result_out = rs_imm_in;
            `AUIPC: begin
                result_out = rs_pc_in + rs_imm_in;
                rob_new_pc_out = rs_pc_in + rs_imm_in;
            end
            `JAL: begin
                result_out = rs_pc_in + 4;
                rob_new_pc_out = rs_pc_in + rs_imm_in;
            end
            `JALR: begin
                result_out = rs_pc_in + 4;
                rob_new_pc_out = rs_lhs_in + rs_imm_in;
            end
            `BEQ: result_out = rs_lhs_in == rs_rhs_in;
            `BNE: result_out = rs_lhs_in != rs_rhs_in;
            `BLT: result_out = $signed(rs_lhs_in) < $signed(rs_rhs_in);
            `BGE: result_out = $signed(rs_lhs_in) >= $signed(rs_rhs_in);
            `BLTU: result_out = rs_lhs_in < rs_rhs_in;
            `BGEU: result_out = rs_lhs_in >= rs_rhs_in;
            `ADDI: result_out = rs_lhs_in + rs_imm_in;
            `SLTI: result_out = $signed(rs_lhs_in) < $signed(rs_imm_in) ? 1 : 0;
            `SLTIU: result_out = rs_lhs_in < rs_imm_in ? 1 : 0;

        endcase
        broadcast_signal_out = `TRUE;
    end
    
endmodule