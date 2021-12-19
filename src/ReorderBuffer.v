`include "header.v"

/*
 * module ReorderBuffer
 * --------------------------------------------------
 * This module inplements ReorderBuffer in tomasulo's
 * algorithm. By maintaining a circular queue, this
 * module commit all instruction in order to avoid
 * data hazard.
 */

module ReorderBuffer (
    input  wire                    clk,
    input  wire                    rst,

    output wire                    full_out,
    output reg                     rollback_out,

    // Fetcher
    output reg  [`WORD_RANGE]      fet_rollback_pc_out,
    output reg                     commit_fet_signal_out,
    output reg                     fet_branch_taken,

    // Decoder
    input  wire                    dec_issue_in,
    input  wire [`WORD_RANGE]      dec_predict_pc_in,
    input  wire [`WORD_RANGE]      dec_inst_in,
    input  wire [`REG_INDEX_RANGE] dec_rd_in,
    input  wire [`ROB_TAG_RANGE]   dec_Qj_in,
    input  wire [`ROB_TAG_RANGE]   dec_Qk_in,
    input  wire [`WORD_RANGE]      dec_pc_in,
    input  wire [`WORD_RANGE]      dec_imm_in,
    output wire [`ROB_TAG_RANGE]   dec_next_tag_out,
    output wire                    dec_Vj_ready_out,
    output wire                    dec_Vk_ready_out,
    output wire [`WORD_RANGE]      dec_Vj_out,
    output wire [`WORD_RANGE]      dec_Vk_out,

    // ArithmeticLogicUnit
    input  wire [`WORD_RANGE]      alu_new_pc_in,

    // BroadCast (ArithmeticLogicUnit && LoadStoreBuffer)
    input  wire                    alu_broadcast_signal_in,
    input  wire [`WORD_RANGE]      alu_result_in,
    input  wire [`ROB_TAG_RANGE]   alu_dest_tag_in,
    input  wire                    lsb_broadcast_signal_in,
    input  wire [`WORD_RANGE]      lsb_result_in,
    input  wire [`ROB_TAG_RANGE]   lsb_dest_tag_in,

    // broadcast
    output reg                      broadcast_signal_out,
    output reg  [`WORD_RANGE]       result_out,
    output reg  [`ROB_TAG_RANGE]    dest_tag_out,

    // LoadStoreBuffer
    input  wire                     lsb_mark_as_io_load_in,
    input  wire [`ROB_TAG_RANGE]    lsb_io_load_tag_in,


    // RegisterFile && LoadStoreBuffer
    output reg                     commit_signal_out,
    output reg                     commit_rf_signal_out,
    output reg                     commit_lsb_signal_out,
    output reg  [`WORD_RANGE]      commit_pc_out,
    output reg  [`ROB_TAG_RANGE]   commit_tag_out,
    output reg  [`WORD_RANGE]      commit_data_out,
    output reg  [`REG_INDEX_RANGE] commit_target_out
);

    integer i;

    // index of head doesn't store any data, index of tail store data
    // head == tail -> empty
    // head == tail.next -> full
    reg [`ROB_TAG_RANGE] head, tail;
    wire [`ROB_TAG_RANGE] head_next, tail_next;
    reg ready [`ROB_RANGE];
    reg [6:0] opcode [`ROB_RANGE];
    reg [`WORD_RANGE] data [`ROB_RANGE];
    reg [`REG_INDEX_RANGE] dest [`ROB_RANGE];
    reg [`WORD_RANGE] pc [`ROB_RANGE];
    reg [`WORD_RANGE] imm [`ROB_RANGE];
    reg [`WORD_RANGE] predict_pc [`ROB_RANGE];
    reg [`WORD_RANGE] new_pc [`ROB_RANGE];
    reg is_io_load [`ROB_RANGE];
    wire in_queue [`ROB_RANGE];

    reg need_to_rollback;
    reg inner_rollback;
    reg [`WORD_RANGE] rollback_pc;

`ifdef PRINT_PREDICTION_RATE
    integer rob_log, success, total;
    initial begin
        rob_log = $fopen("bin/rob_log.txt", "w");
        success = 0;
        total = 0;
    end    
`endif

    assign dec_Vj_ready_out = in_queue[dec_Qj_in] ? ready[dec_Qj_in] : `FALSE;
    assign dec_Vk_ready_out = in_queue[dec_Qk_in] ? ready[dec_Qk_in] : `FALSE;
    assign dec_Vj_out       = data[dec_Qj_in];
    assign dec_Vk_out       = data[dec_Qk_in];

    assign head_next = head == `ROB_CAPACITY - 1 ? 1 : head + 1;
    assign tail_next = tail == `ROB_CAPACITY - 1 ? 1 : tail + 1;
    assign full_out  = head == tail_next;
    assign dec_next_tag_out = (head != tail_next) ? tail_next : `NULL_TAG;

    always @(posedge clk) begin
        rollback_out <= `FALSE;
        broadcast_signal_out <= `FALSE;
        commit_signal_out <= `FALSE;
        commit_rf_signal_out <= `FALSE;
        commit_lsb_signal_out <= `FALSE;
        commit_fet_signal_out <= `FALSE;
        need_to_rollback <= `FALSE;
        inner_rollback <= `FALSE;
        if (rst || inner_rollback) begin
            tail <= 1;
            head <= 1;
            for (i = 0; i < `ROB_CAPACITY; i = i + 1) begin
                ready[i] <= `FALSE;
                opcode[i] <= 7'b0;
                data[i] <= `ZERO_WORD;
                dest[i] <= `ZERO_REG_INDEX;
                pc[i] <= `ZERO_WORD;
                imm[i] <= `ZERO_WORD;
                predict_pc[i] <= `ZERO_WORD;
                new_pc[i] <= `ZERO_WORD;
                is_io_load[i] <= `FALSE;
            end
        end else if (need_to_rollback) begin
            // rollback:
            // (1) reset pc
            // (2) execute all committed instruction in lsb
            // (3) keep register value in RegisterFile
            // (4) rst all other modules
            rollback_out <= `TRUE;
            fet_rollback_pc_out <= rollback_pc;
            inner_rollback <= `TRUE;
        end else begin
            if (dec_issue_in) begin
                // add new entry
                ready[tail_next] <= `FALSE;
                opcode[tail_next] <= dec_inst_in[6:0];
                data[tail_next] <= `ZERO_WORD;
                dest[tail_next] <= dec_rd_in;
                pc[tail_next] <= dec_pc_in;
                imm[tail_next] <= dec_imm_in;
                predict_pc[tail_next] <= dec_predict_pc_in;
                tail <= tail_next;
            end
            // update data by snoopy on cdb (i.e., alu && lsb)
            if (alu_broadcast_signal_in && in_queue[alu_dest_tag_in]) begin
                data[alu_dest_tag_in] <= alu_result_in;
                ready[alu_dest_tag_in] <= `TRUE;
                new_pc[alu_dest_tag_in] <= alu_new_pc_in;
            end
            if (lsb_broadcast_signal_in && in_queue[lsb_dest_tag_in]) begin
                data[lsb_dest_tag_in] <= lsb_result_in;
                ready[lsb_dest_tag_in] <= `TRUE;
            end
            if (lsb_mark_as_io_load_in && in_queue[lsb_io_load_tag_in]) begin
                is_io_load[lsb_io_load_tag_in] <= `TRUE;
            end
            // commit when not empty
            if (head != tail) begin
                // store will automatically committed when it reach rob head
                if (ready[head_next] || opcode[head_next] == `STORE_OPCODE) begin
                    ready[head_next] <= `FALSE;
                    commit_signal_out <= `TRUE;
                    commit_rf_signal_out <= opcode[head_next] != `BRANCH_OPCODE && opcode[head_next] != `STORE_OPCODE;
                    // only store and io load in lsb need commit (load will always be committed after its exectuion in lsb)
                    commit_lsb_signal_out <= opcode[head_next] == `STORE_OPCODE;
                    commit_pc_out <= pc[head_next];
                    commit_tag_out <= head_next;
                    commit_data_out <= data[head_next];
                    commit_target_out <= dest[head_next];
                    head <= head_next;
                    // broadcast
                    broadcast_signal_out <= `TRUE;
                    result_out <= data[head_next];
                    dest_tag_out <= head_next;
                    // rollback
                    if (opcode[head_next] == `JALR_OPCODE  || 
                        opcode[head_next] == `AUIPC_OPCODE ||
                        opcode[head_next] == `BRANCH_OPCODE) begin
                        if (new_pc[head_next] != predict_pc[head_next]) begin
                            need_to_rollback <= `TRUE;
                            rollback_pc <= new_pc[head_next];
                        end
                        // for branch predict
                        if (opcode[head_next] == `BRANCH_OPCODE) begin
                            commit_fet_signal_out <= `TRUE;
                            fet_branch_taken <= new_pc[head_next] == pc[head_next] + imm[head_next];
`ifdef PRINT_PREDICTION_RATE
                            if (new_pc[head_next] == predict_pc[head_next]) success = success + 1;
                            total = total + 1;
                            $fdisplay(rob_log, "branch_taken: %s, success_rate = %d / %d", new_pc[head_next] == predict_pc[head_next] ? "true" : "false", success, total);
`endif
                        end
                    end
                end else if (is_io_load[head_next]) begin
                    is_io_load[head_next] <= `FALSE;
                    commit_lsb_signal_out <= `TRUE;
                end
            end
        end
    end

    assign in_queue[`NULL_TAG] = `FALSE;
    generate
        genvar index;
        for (index = 1; index < `ROB_CAPACITY; index = index + 1) begin : generate_in_queue
            assign in_queue[index] = head < tail ? head < index && index <= tail :
                                     head > tail ? head < index || index <= tail : `FALSE;
            // assign in_queue[index] = `TRUE;
        end
    endgenerate

endmodule