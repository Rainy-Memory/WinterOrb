`include "header.v"

/*
 * module RegisterFile
 * --------------------------------------------------
 * This module implements RegisterFile in tomasulo's algorithm.
 * Mainly it manage registers and their occupancy, provides
 * Vj, Vk, Qj, Qk for RS and LSB.
 */

`define PRINT_RF_STATUS


module RegisterFile (
    input  wire                    clk,
    input  wire                    rst,

    // Decoder
    input  wire [`ROB_TAG_RANGE]   dec_next_tag_in,
    input  wire [`REG_INDEX_RANGE] dec_rs1_in,
    input  wire [`REG_INDEX_RANGE] dec_rs2_in,
    input  wire [`REG_INDEX_RANGE] dec_rd_in,
    input  wire                    dec_occupy_rd_in,
    output wire [`WORD_RANGE]      dec_Vj_out, // value of rs1
    output wire [`WORD_RANGE]      dec_Vk_out, // value of rs2
    output wire [`ROB_TAG_RANGE]   dec_Qj_out, // tag of rs1
    output wire [`ROB_TAG_RANGE]   dec_Qk_out, // tag of rs2

    // ReorderBuffer
    input  wire                    rob_rollback_in,
    input  wire                    rob_commit_signal_in,
    input  wire                    rob_commit_rf_signal_in,
    input  wire [`WORD_RANGE]      rob_commit_pc_in,
    input  wire [`ROB_TAG_RANGE]   rob_commit_tag_in,
    input  wire [`WORD_RANGE]      rob_commit_data_in,
    input  wire [`REG_INDEX_RANGE] rob_commit_target_in
);

    reg [`WORD_RANGE] value [`RF_RANGE];
    reg busy [`RF_RANGE];
    reg [`ROB_TAG_RANGE] rob_tag [`RF_RANGE];
    
    integer i;

    assign dec_Vj_out = busy[dec_rs1_in] ? `ZERO_WORD : value[dec_rs1_in];
    assign dec_Qj_out = busy[dec_rs1_in] ? rob_tag[dec_rs1_in] : `NULL_TAG;
    assign dec_Vk_out = busy[dec_rs2_in] ? `ZERO_WORD : value[dec_rs2_in];
    assign dec_Qk_out = busy[dec_rs2_in] ? rob_tag[dec_rs2_in] : `NULL_TAG;

`ifdef PRINT_RF_STATUS
    integer rf_log, cnt;
    initial rf_log = $fopen("bin/rf_log.txt", "w");
    initial cnt = 1;
`endif

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `RF_CAPACITY; i = i + 1) begin
                value[i] <= `ZERO_WORD;
                busy[i] <= `FALSE;
                rob_tag[i] <= `NULL_TAG;
            end
        end else if (rob_rollback_in) begin
            for (i = 0; i < `RF_CAPACITY; i = i + 1) begin
                busy[i] <= `FALSE;
                rob_tag[i] <= `NULL_TAG;
            end
        end else begin
            if (rob_commit_signal_in) begin
                if (rob_commit_rf_signal_in && busy[rob_commit_target_in]) begin
                    // only wb the last inst that occupy this register
                    if (rob_tag[rob_commit_target_in] == rob_commit_tag_in) begin
                        busy[rob_commit_target_in] <= `FALSE;
                        rob_tag[rob_commit_target_in] <= `NULL_TAG; 
                    end
                    value[rob_commit_target_in] <= rob_commit_data_in;
                end
`ifdef PRINT_RF_STATUS
                $fdisplay(rf_log, "cnt: %d", cnt);
                cnt <= cnt + 1;
                $fdisplay(rf_log, "pc: %h", rob_commit_pc_in);
                for (i = 0; i < `RF_CAPACITY; i = i + 1) begin
                    $fdisplay(rf_log, "reg %d: %h", i, ((i == rob_commit_target_in) && busy[i] && rob_commit_rf_signal_in) ? rob_commit_data_in : value[i]);
                end
`endif
            end
            if (dec_occupy_rd_in) begin
                // reg 0 cannot be occupied
                if (dec_rd_in != 0) begin
                    busy[dec_rd_in] <= `TRUE;
                    rob_tag[dec_rd_in] <= dec_next_tag_in; // straightly cover original tag
                end
            end
        end
    end

endmodule