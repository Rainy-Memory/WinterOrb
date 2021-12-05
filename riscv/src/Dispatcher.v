`include "header.v"

/*
 * module Dispatcher
 * --------------------------------------------------
 * This module implements Dispatcher in tomasulo's algorithm.
 * Mainly it dispatch decoded instruction to LSB or RS.
 */

module Dispatcher (
    input  wire                      rst,

    // Decoder
    input  wire [`WORD_RANGE]        dec_imm_in,
    input  wire [`INNER_INST_RANGE]  dec_inst_type_in,
    input  wire [`REG_INDEX_RANGE]   dec_rs1_in,
    input  wire [`REG_INDEX_RANGE]   dec_rs2_in,
    input  wire [`REG_INDEX_RANGE]   dec_rd_in,
    input  wire [`SHAMT_RANGE]       dec_shamt_in,
    input  wire                      dec_ready_in,
    input  wire [`WORD_RANGE]        dec_pc_in,
    input  wire [1:0]                dec_to_lsb_signal_in, // first bit represents to LSB, second bit: LOAD -> 0, STORE -> 1
    input  wire [2:0]                dec_lsb_goal_in,

    // ReorderBuffer
    input  wire [`ROB_TAG_RANGE]     rob_tag_in,

    // RegisterFile && LoadStoreBuffer
    output wire [`ROB_TAG_RANGE]     tag_out,

    // ReservationStation && LoadStoreBuffer
    output wire [`INNER_INST_RANGE]  inst_out,
    output wire [`WORD_RANGE]        imm_out,
    output wire [`WORD_RANGE]        pc_out,
    output wire [`ROB_TAG_RANGE]     dest_out,

    // ReservationStation
    output reg                       rs_new_inst_signal_out,

    // LoadStoreBuffer
    output reg                       lsb_new_inst_signal_out,
    output reg                       lsb_load_store_signal_out,
    output wire [2:0]                lsb_goal_out
);

    integer dis_log;

    initial begin
        dis_log = $fopen(`DIS_LOG_PATH, "w");
    end

    assign tag_out = rob_tag_in;
    assign inst_out = dec_inst_type_in;
    assign imm_out = dec_imm_in;
    assign pc_out = dec_pc_in;
    assign dest_out = rob_tag_in;
    assign lsb_goal_out = dec_lsb_goal_in;

    always @(*) begin
        rs_new_inst_signal_out = `FALSE;
        lsb_new_inst_signal_out = `FALSE;
        if (rst) begin
            $fdisplay(dis_log, "resetting...");
        end else if (dec_ready_in) begin
            $fdisplay(dis_log, "receive inst type: %s", dec_inst_type_in);
            if (dec_to_lsb_signal_in[1]) begin // dispatch to LSB
                lsb_new_inst_signal_out = `TRUE;
                lsb_load_store_signal_out = dec_to_lsb_signal_in[0];
            end else begin // dispatch to RS
                rs_new_inst_signal_out = `TRUE;
            end
            // TODO send to rob
        end else $fdisplay(dis_log, "waiting instruction...");
    end

endmodule