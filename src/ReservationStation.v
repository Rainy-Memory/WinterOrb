`include "header.v"

/*
 * module ReservationStation
 * --------------------------------------------------
 * This module inplements ReservationStation in tomasulo's
 * algorithm. By store issued instruction and wait them
 * for ready (Qj, Qk finished their compute), this module
 * support out-of-order instruction execution.
 */

module ReservationStation (
    input  wire                     clk,
    input  wire                     rst,

    output wire                     full_out,

    // Dispatcher
    input  wire                     dis_new_inst_signal_in,

    // Decoder
    input  wire [`ROB_TAG_RANGE]    dec_next_tag_in,
    input  wire [`INNER_INST_RANGE] dec_op_in,
    input  wire [`WORD_RANGE]       dec_Vj_in,
    input  wire [`WORD_RANGE]       dec_Vk_in,
    input  wire [`ROB_TAG_RANGE]    dec_Qj_in,
    input  wire [`ROB_TAG_RANGE]    dec_Qk_in,
    input  wire [`WORD_RANGE]       dec_imm_in,
    input  wire [`WORD_RANGE]       dec_pc_in,
    input  wire [1:0]               dec_have_source_register_in,

    // ArithmeticLogicUnit
    output reg                      alu_calculate_signal_out,
    output reg  [`INNER_INST_RANGE] alu_op_out,
    output reg  [`WORD_RANGE]       alu_imm_out,
    output reg  [`WORD_RANGE]       alu_pc_out,
    output reg  [`WORD_RANGE]       alu_rs1val_out,
    output reg  [`WORD_RANGE]       alu_rs2val_out,
    output reg  [`ROB_TAG_RANGE]    alu_dest_out,

    // ReorderBuffer
    input  wire                     rob_rollback_in,

    // broadcast
    input  wire                     alu_broadcast_signal_in,
    input  wire [`WORD_RANGE]       alu_result_in,
    input  wire [`ROB_TAG_RANGE]    alu_dest_tag_in,
    input  wire                     lsb_broadcast_signal_in,
    input  wire [`WORD_RANGE]       lsb_result_in,
    input  wire [`ROB_TAG_RANGE]    lsb_dest_tag_in,
    input  wire                     rob_broadcast_signal_in,
    input  wire [`WORD_RANGE]       rob_result_in,
    input  wire [`ROB_TAG_RANGE]    rob_dest_tag_in
);

    integer i;
    wire [4:0] next_free_entry;
    wire [4:0] next_ready;

    reg busy [`RS_RANGE];
    wire ready [`RS_RANGE];
    reg [1:0] have_source_register [`RS_RANGE]; // {have rs2, have rs1}
    reg [`INNER_INST_RANGE] op [`RS_RANGE];
    reg [`WORD_RANGE] imm [`RS_RANGE];
    reg [`WORD_RANGE] pc [`RS_RANGE];
    reg [`WORD_RANGE] Vj [`RS_RANGE];
    reg [`WORD_RANGE] Vk [`RS_RANGE];
    reg [`ROB_TAG_RANGE] Qj [`RS_RANGE];
    reg [`ROB_TAG_RANGE] Qk [`RS_RANGE];
    reg [`REG_INDEX_RANGE] dest [`RS_RANGE];

    assign full_out = next_free_entry == `NULL_ENTRY;
    
    always @(posedge clk) begin
        alu_calculate_signal_out <= `FALSE;
        if (rst || rob_rollback_in) begin
            for (i = 0; i < `RS_CAPACITY; i = i + 1) begin
                busy[i] <= `FALSE;
                have_source_register[i] <= 2'b0;
                op[i] <= `NOP;
                imm[i] <= `ZERO_WORD;
                pc[i] <= `ZERO_WORD;
                Vj[i] <= `ZERO_WORD;
                Vk[i] <= `ZERO_WORD;
                Qj[i] <= `NULL_TAG;
                Qk[i] <= `NULL_TAG;
                dest[i] <= `ZERO_REG_INDEX;
            end
        end else begin
            if (dis_new_inst_signal_in) begin
                busy[next_free_entry] <= `TRUE;
                have_source_register[next_free_entry] <= dec_have_source_register_in;
                op[next_free_entry] <= dec_op_in;
                imm[next_free_entry] <= dec_imm_in;
                pc[next_free_entry] <= dec_pc_in;
                Vj[next_free_entry] <= dec_Vj_in;
                Vk[next_free_entry] <= dec_Vk_in;
                Qj[next_free_entry] <= dec_Qj_in;
                Qk[next_free_entry] <= dec_Qk_in;
                dest[next_free_entry] <= dec_next_tag_in;
                if (rob_broadcast_signal_in) begin
                    if (dec_Qj_in == rob_dest_tag_in) begin
                        Qj[next_free_entry] <= `NULL_TAG;
                        Vj[next_free_entry] <= rob_result_in;
                    end
                    if (dec_Qk_in == rob_dest_tag_in) begin
                        Qk[next_free_entry] <= `NULL_TAG;
                        Vk[next_free_entry] <= rob_result_in;
                    end
                end
            end
            if (next_ready != `NULL_ENTRY) begin
                alu_calculate_signal_out <= `TRUE;
                busy[next_ready] <= `FALSE;
                alu_op_out <= op[next_ready];
                alu_imm_out <= imm[next_ready];
                alu_pc_out <= pc[next_ready];
                alu_rs1val_out <= Vj[next_ready];
                alu_rs2val_out <= Vk[next_ready];
                alu_dest_out <= dest[next_ready];
            end
            // update data by snoopy on cdb (i.e., alu && lsb && rob)
            if (alu_broadcast_signal_in) begin
                for (i = 0; i < `RS_CAPACITY; i = i + 1) begin
                    if (busy[i]) begin
                        if (alu_dest_tag_in == Qj[i]) begin
                            Qj[i] <= `NULL_TAG;
                            Vj[i] <= alu_result_in;
                        end
                        if (alu_dest_tag_in == Qk[i]) begin
                            Qk[i] <= `NULL_TAG;
                            Vk[i] <= alu_result_in;
                        end
                    end
                end
            end
            if (lsb_broadcast_signal_in) begin
                for (i = 0; i < `RS_CAPACITY; i = i + 1) begin
                    if (busy[i]) begin
                        if (lsb_dest_tag_in == Qj[i]) begin
                            Qj[i] <= `NULL_TAG;
                            Vj[i] <= lsb_result_in;
                        end
                        if (lsb_dest_tag_in == Qk[i]) begin
                            Qk[i] <= `NULL_TAG;
                            Vk[i] <= lsb_result_in;
                        end
                    end
                end
            end
            if (rob_broadcast_signal_in) begin
                for (i = 0; i < `RS_CAPACITY; i = i + 1) begin
                    if (busy[i]) begin
                        if (rob_dest_tag_in == Qj[i]) begin
                            Qj[i] <= `NULL_TAG;
                            Vj[i] <= rob_result_in;
                        end
                        if (rob_dest_tag_in == Qk[i]) begin
                            Qk[i] <= `NULL_TAG;
                            Vk[i] <= rob_result_in;
                        end
                    end
                end
            end
        end
    end

    generate
        genvar index;
        for (index = 0; index < `RS_CAPACITY; index = index + 1) begin : generate_ready
            assign ready[index] = busy[index]
                                && (have_source_register[index][0] ? Qj[index] == `NULL_TAG : `TRUE)
                                && (have_source_register[index][1] ? Qk[index] == `NULL_TAG : `TRUE);
        end
    endgenerate

    assign next_free_entry = ~busy[ 0] ?  0 :
                             ~busy[ 1] ?  1 :
                             ~busy[ 2] ?  2 :
                             ~busy[ 3] ?  3 :
                             ~busy[ 4] ?  4 :
                             ~busy[ 5] ?  5 :
                             ~busy[ 6] ?  6 :
                             ~busy[ 7] ?  7 :
                             ~busy[ 8] ?  8 :
                             ~busy[ 9] ?  9 :
                             ~busy[10] ? 10 :
                             ~busy[11] ? 11 :
                             ~busy[12] ? 12 :
                             ~busy[13] ? 13 :
                             ~busy[14] ? 14 :
                             `NULL_ENTRY;

    assign next_ready = ready[ 0] ?  0 :
                        ready[ 1] ?  1 :
                        ready[ 2] ?  2 :
                        ready[ 3] ?  3 :
                        ready[ 4] ?  4 :
                        ready[ 5] ?  5 :
                        ready[ 6] ?  6 :
                        ready[ 7] ?  7 :
                        ready[ 8] ?  8 :
                        ready[ 9] ?  9 :
                        ready[10] ? 10 :
                        ready[11] ? 11 :
                        ready[12] ? 12 :
                        ready[13] ? 13 :
                        ready[14] ? 14 :
                        `NULL_ENTRY;

endmodule