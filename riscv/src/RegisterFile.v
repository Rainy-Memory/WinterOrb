`include "header.v"

/*
 * module RegisterFile
 * --------------------------------------------------
 * This module implements RegisterFile in tomasulo's algorithm.
 * Mainly it manage registers and their occupancy, provides
 * Vj, Vk, Qj, Qk for RS and LSB.
 */

module RegisterFile (
    input  wire                    clk,
    input  wire                    rst,

    // ReorderBuffer
    input  wire [`ROB_TAG_RANGE]   dis_tag_in,

    // Decoder
    input  wire [`REG_INDEX_RANGE] dec_rs1_in,
    input  wire [`REG_INDEX_RANGE] dec_rs2_in,
    input  wire [`REG_INDEX_RANGE] dec_rd_in,
    input  wire                    dec_occupy_rd_in,
    output wire [`WORD_RANGE]      dec_Vj_out, // value of rs1
    output wire [`WORD_RANGE]      dec_Vk_out, // value of rs2
    output wire [`ROB_TAG_RANGE]   dec_Qj_out, // tag of rs1
    output wire [`ROB_TAG_RANGE]   dec_Qk_out, // tag of rs2
    output wire [`ROB_TAG_RANGE]   dec_dest_out,

    // ReorderBuffer
    input  wire                    rob_commit_signal_in,
    input  wire [`ROB_TAG_RANGE]   rob_commit_tag_in,
    input  wire [`WORD_RANGE]      rob_commit_data_in,
    input  wire [`REG_INDEX_RANGE] rob_commit_target_in
);

    reg [`WORD_RANGE] value [`RF_RANGE];
    reg busy [`RF_RANGE];
    reg [`ROB_TAG_RANGE] rob_tag [`RF_RANGE];
    reg assert_bit;
    
    integer i;

    assign dec_dest_out = dis_tag_in;
    assign dec_Vj_out = busy[dec_rs1_in] ? `ZERO_WORD : value[dec_rs1_in];
    assign dec_Qj_out = busy[dec_rs1_in] ? rob_tag[dec_rs1_in] : `NULL_TAG;
    assign dec_Vk_out = busy[dec_rs2_in] ? `ZERO_WORD : value[dec_rs2_in];
    assign dec_Qk_out = busy[dec_rs2_in] ? rob_tag[dec_rs2_in] : `NULL_TAG;

    always @(posedge clk) begin
        assert_bit <= `FALSE;
        if (rst) begin
            for (i = 0; i < `RF_CAPACITY; i = i + 1) begin
                value[i] <= `ZERO_WORD;
                busy[i] <= `FALSE;
                rob_tag[i] <= `NULL_TAG;
            end
        end else begin
            // reg 0 cannot be occupied
            for (i = 1; i < `RF_CAPACITY; i = i + 1) begin
                if (dec_occupy_rd_in && dec_rd_in == i) begin
                    busy[i] <= `TRUE;
                    rob_tag[i] <= dis_tag_in; // straightly cover original tag
                end
            end
            if (rob_commit_signal_in) begin
                if (!busy[rob_commit_target_in]) begin
                    assert_bit <= `TRUE;
                end else begin
                    // only wb the last inst that occupy this register
                    if (rob_tag[rob_commit_target_in] == rob_commit_tag_in) begin
                        busy[rob_commit_target_in] <= `FALSE;
                        rob_tag[rob_commit_target_in] <= `NULL_TAG; 
                    end
                    value[rob_commit_target_in] <= rob_commit_data_in;
                end
            end
        end
    end

endmodule