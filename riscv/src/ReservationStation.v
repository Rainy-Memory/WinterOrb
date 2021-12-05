`include "header.v"

module ReservationStation (
    input  wire                     clk,
    input  wire                     rst,

    // Dispatcher
    input  wire                     dis_new_inst_signal_in,
    input  wire [`INNER_INST_RANGE] dis_inst_in,
    input  wire [`WORD_RANGE]       dis_imm_in,
    input  wire [`WORD_RANGE]       dis_pc_in,
    input  wire [`ROB_TAG_RANGE]    dis_dest_in,

    // Decoder
    input  wire [`WORD_RANGE]       dec_Vj_in,
    input  wire [`WORD_RANGE]       dec_Vk_in,
    input  wire [`ROB_TAG_RANGE]    dec_Qj_in,
    input  wire [`ROB_TAG_RANGE]    dec_Qk_in,

    // ArithmeticLogicUnit
    output reg  [`INNER_INST_RANGE] alu_op_out,
    output reg  [`WORD_RANGE]       alu_imm_out,
    output reg  [`WORD_RANGE]       alu_pc_out,
    output reg  [`WORD_RANGE]       alu_lhs_out,
    output reg  [`WORD_RANGE]       alu_rhs_out,
    output reg  [`ROB_TAG_RANGE]    alu_dest_out,

    // BroadCast (ArithmeticLogicUnit && LoadStoreBuffer)
    input  wire                     alu_broadcast_signal_in,
    input  wire [`WORD_RANGE]       alu_result_in,
    input  wire [`ROB_TAG_RANGE]    alu_dest_tag_in,
    input  wire                     lsb_broadcast_signal_in,
    input  wire [`WORD_RANGE]       lsb_result_in,
    input  wire [`ROB_TAG_RANGE]    lsb_dest_tag_in
);

    integer i;
    wire [4:0] next_free_entry;
    wire [4:0] next_ready;

    reg busy [`RS_RANGE];
    wire ready [`RS_RANGE];
    reg [`INNER_INST_RANGE] op [`RS_RANGE];
    reg [`WORD_RANGE] imm [`RS_RANGE];
    reg [`WORD_RANGE] pc [`RS_RANGE];
    reg [`WORD_RANGE] Vj [`RS_RANGE];
    reg [`WORD_RANGE] Vk [`RS_RANGE];
    reg [`ROB_TAG_RANGE] Qj [`RS_RANGE];
    reg [`ROB_TAG_RANGE] Qk [`RS_RANGE];
    reg [`REG_INDEX_RANGE] dest [`RS_RANGE];
    
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `RS_CAPACITY; i = i + 1) begin
                busy[i] <= `FALSE;
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
                op[next_free_entry] <= dis_inst_in;
                imm[i] <= dis_imm_in;
                pc[i] <= dis_pc_in;
                Vj[next_free_entry] <= dec_Vj_in;
                Vk[next_free_entry] <= dec_Vk_in;
                Qj[next_free_entry] <= dec_Qj_in;
                Qk[next_free_entry] <= dec_Qk_in;
                dest[next_free_entry] <= dis_dest_in;
            end
            if (next_ready != `NULL_ENTRY) begin
                alu_op_out <= op[next_ready];
                alu_imm_out <= imm[next_ready];
                alu_pc_out <= pc[next_ready];
                alu_lhs_out <= Vj[next_ready];
                alu_rhs_out <= Vk[next_ready];
                alu_dest_out <= dest[next_ready];
                busy[next_ready] <= `FALSE;
            end
            // update data by snoopy on cdb (i.e., alu && lsb)
            if (alu_broadcast_signal_in) begin
                for (i = 0; i < `RS_CAPACITY; i = i + 1) begin
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
            if (lsb_broadcast_signal_in) begin
                for (i = 0; i < `RS_CAPACITY; i = i + 1) begin
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
    end

    generate
        genvar index;
        for (index = 0; index < `RS_CAPACITY; index = index + 1) begin : generate_ready
            assign ready[index] = busy[index] && (Qj[index] == `NULL_TAG) && (Qk[index] == `NULL_TAG);
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