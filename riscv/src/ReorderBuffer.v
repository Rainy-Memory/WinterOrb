`include "header.v"

module ReorderBuffer (
    input  wire                    clk,
    input  wire                    rst,

    // Dispatcher
    output wire [`ROB_TAG_RANGE]   dis_tag_out,

    // Decoder
    input  wire [`WORD_RANGE]      dec_inst_in,
    input  wire [`REG_INDEX_RANGE] dec_rd_in,
    input  wire [`ROB_TAG_RANGE]   dec_Qj_in,
    input  wire [`ROB_TAG_RANGE]   dec_Qk_in,
    output wire                    dec_Vj_ready_out,
    output wire                    dec_Vk_ready_out,
    output wire [`WORD_RANGE]      dec_Vj_out,
    output wire [`WORD_RANGE]      dec_Vk_out,

    // BroadCast (ArithmeticLogicUnit && LoadStoreBuffer)
    input  wire                    alu_broadcast_signal_in,
    input  wire [`WORD_RANGE]      alu_result_in,
    input  wire [`ROB_TAG_RANGE]   alu_dest_tag_in,
    input  wire                    lsb_broadcast_signal_in,
    input  wire [`WORD_RANGE]      lsb_result_in,
    input  wire [`ROB_TAG_RANGE]   lsb_dest_tag_in,

    // RegisterFile
    output reg                     rf_commit_signal_out,
    output reg  [`ROB_TAG_RANGE]   rf_commit_tag_out,
    output reg  [`WORD_RANGE]      rf_commit_data_out,
    output reg  [`REG_INDEX_RANGE] rf_commit_target_out,

    // ArithmeticLogicUnit
    input  wire [`WORD_RANGE]      alu_new_pc_in
);

    reg [`ROB_TAG_RANGE] head, tail;
    reg ready [`ROB_RANGE];
    reg [`WORD_RANGE] inst [`ROB_RANGE];
    reg [`WORD_RANGE] data [`ROB_RANGE];
    reg [`REG_INDEX_RANGE] dest [`ROB_RANGE];

    assign dec_Vj_ready_out = ready[dec_Qj_in];
    assign dec_Vk_ready_out = ready[dec_Qk_in];
    assign dec_Vj_out       = data[dec_Qj_in];
    assign dec_Vk_out       = data[dec_Qk_in];

    assign dis_tag_out = (head != tail) ? tail : `NULL_TAG;

    always @(posedge clk) begin
        if (rst) begin
            tail <= 1;
            head <= 1;
            ready[`NULL_TAG] <= `FALSE;
        end else begin
            // add new entry
            ready[tail] <= `FALSE;
            inst[tail] <= dec_inst_in;
            data[tail] <= `ZERO_WORD;
            dest[tail] <= dec_rd_in;
            tail <= tail == `ROB_CAPACITY ? 1 : tail + 1;
            // update data by snoopy on cdb (i.e., alu && lsb)
            if (alu_broadcast_signal_in) begin
                data[alu_dest_tag_in] = alu_result_in;
            end
            if (lsb_broadcast_signal_in) begin
                data[lsb_dest_tag_in] = lsb_result_in;
            end
            // commit
            if (ready[head]) begin
                rf_commit_signal_out <= `TRUE;
                rf_commit_tag_out <= head;
                rf_commit_data_out <= data[head];
                rf_commit_target_out <= dest[head];
                head <= head == `ROB_CAPACITY ? 1 : head + 1;
            end
        end
    end

endmodule