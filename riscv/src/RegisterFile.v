`include "header.v"

/*
 * module RegisterFile
 * --------------------------------------------------
 * This module implements RegisterFile in tomasulo's algorithm.
 * Mainly it manage registers and their occupancy, provides
 * Vj, Vk, Qj, Qk for RS and LSB.
 */

module RegisterFile (
    input  wire                      rst,

    // ReorderBuffer
    input  wire [`ROB_TAG_RANGE]     dis_tag_in,

    // Decoder
    input  wire [`REG_INDEX_RANGE]   dec_rs1_in,
    input  wire [`REG_INDEX_RANGE]   dec_rs2_in,
    input  wire [`REG_INDEX_RANGE]   dec_rd_in,
    input  wire                      dec_occpuy_rd_in,
    output reg  [`WORD_RANGE]        dec_Vj_out, // value of rs1
    output reg  [`WORD_RANGE]        dec_Vk_out, // value of rs2
    output reg  [`ROB_TAG_RANGE]     dec_Qj_out, // tag of rs1
    output reg  [`ROB_TAG_RANGE]     dec_Qk_out, // tag of rs2
    output reg  [`ROB_TAG_RANGE]     dec_dest_out,

    // ReorderBuffer
    input  wire                      rob_commit_signal_in,
    input  wire [`ROB_TAG_RANGE]     rob_commit_tag_in,
    input  wire [`WORD_RANGE]        rob_commit_data_in,
    input  wire [`REG_INDEX_RANGE]   rob_commit_target_in
);

    reg [`WORD_RANGE] value [`RF_RANGE];
    reg busy [`RF_RANGE];
    reg [`ROB_TAG_RANGE] rob_tag [`RF_RANGE];
    reg assert_bit;
    
    integer i;

    always @(*) begin
        assert_bit = `FALSE;
        if (rst) begin
            for (i = 0; i < `RF_CAPACITY; i = i + 1) begin
                value[i] = `ZERO_WORD;
                busy[i] = `FALSE;
                rob_tag[i] = `NULL_TAG;
            end
        end else begin
            for (i = 0; i < `RF_CAPACITY; i = i + 1) begin
                if (dec_occpuy_rd_in && dec_rd_in == i) begin
                    busy[i] = `TRUE;
                    rob_tag[i] = dis_tag_in; // straightly cover original tag
                    dec_dest_out = dis_tag_in;
                end
                if (dec_rs1_in == i) begin
                    if (busy[i]) begin
                        dec_Vj_out = `ZERO_WORD;
                        dec_Qj_out = rob_tag[i];
                    end else begin
                        dec_Vj_out = value[i];
                        dec_Qj_out = `NULL_TAG; // null tag represent not busy
                    end
                end
                if (dec_rs2_in == i) begin
                    if (busy[i]) begin
                        dec_Vk_out = `ZERO_WORD;
                        dec_Qk_out = rob_tag[i];
                    end else begin
                        dec_Vk_out = value[i];
                        dec_Qk_out = `NULL_TAG; // null tag represent not busy
                    end
                end
            end
            if (rob_commit_signal_in) begin
                if (!busy[rob_commit_target_in] || rob_tag[rob_commit_target_in] == rob_commit_tag_in) begin
                    assert_bit <= `TRUE;
                end else begin
                    busy[rob_commit_target_in] = `FALSE;
                    rob_tag[rob_commit_target_in] = `NULL_TAG;
                    value[rob_commit_target_in] = rob_commit_data_in;
                end
            end
        end
    end

endmodule