`include "header.v"

/*
 * module LoadStoreBuffer
 * --------------------------------------------------
 * This module implements LoadStoreBuffer in tomasulo's
 * algorithm. By maintaining a circular queue, this
 * module handle all ram interaction in order.
 */

module LoadStoreBuffer (
    input  wire                     clk,
    input  wire                     rst,

    output wire                     full_out,
    
    // ReservationStation && LoadStoreBuffer && ReorderBuffer
    output reg                      broadcast_signal_out,
    output reg  [`WORD_RANGE]       result_out,
    output reg  [`ROB_TAG_RANGE]    dest_tag_out,

    // Dispatcher
    input  wire                     dis_new_inst_signal_in,
    input  wire                     dis_load_store_signal_in,

    // Decoder
    input  wire [`ROB_TAG_RANGE]    dec_next_tag_in,
    input  wire [`INNER_INST_RANGE] dec_op_in,
    input  wire [`WORD_RANGE]       dec_Vj_in,
    input  wire [`WORD_RANGE]       dec_Vk_in,
    input  wire [`ROB_TAG_RANGE]    dec_Qj_in,
    input  wire [`ROB_TAG_RANGE]    dec_Qk_in,
    input  wire [`WORD_RANGE]       dec_imm_in,
    input  wire [2:0]               dec_goal_in,

    // BroadCast ArithmeticLogicUnit
    input  wire                     alu_broadcast_signal_in,
    input  wire [`WORD_RANGE]       alu_result_in,
    input  wire [`ROB_TAG_RANGE]    alu_dest_tag_in,

    // ReorderBuffer
    input  wire                     rob_rollback_in,
    input  wire                     rob_commit_lsb_signal_in,
    input  wire [`ROB_TAG_RANGE]    rob_commit_tag_in,

    // MemoryController
    input  wire                     mc_ready_in,
    input  wire [`WORD_RANGE]       mc_data_in,
    output reg                      mc_request_out,
    output reg                      mc_rw_signal_out,
    output reg  [`WORD_RANGE]       mc_address_out,
    output reg  [2:0]               mc_goal_out, // LB: 1, LHW: 2, LW: 4
    output reg  [`WORD_RANGE]       mc_data_out
);

    reg [`LSB_INDEX_RANGE] head, tail, unexecute_committed_store_cnt;
    wire [`LSB_INDEX_RANGE] head_next, tail_next;

    // use overflow to ensure head_next and tail_next in `LSB_RANGE
    assign head_next = head + 1;
    assign tail_next = tail + 1;
    assign full_out = head == tail_next;

    reg load_store_flag [`LSB_RANGE]; // LOAD -> 0, STORE -> 1
    reg commit_flag [`LSB_RANGE];
    reg [`INNER_INST_RANGE] op [`LSB_RANGE];
    reg [`ROB_TAG_RANGE] rob_tag [`LSB_RANGE];
    reg [`WORD_RANGE] imm [`LSB_RANGE];
    reg [`WORD_RANGE] Vj [`LSB_RANGE];
    reg [`WORD_RANGE] Vk [`LSB_RANGE];
    reg [`ROB_TAG_RANGE] Qj [`LSB_RANGE];
    reg [`ROB_TAG_RANGE] Qk [`LSB_RANGE];
    reg [2:0] load_store_goal [`LSB_RANGE];

    wire ready [`LSB_RANGE];
    wire in_queue [`LSB_RANGE];

    integer i;

    localparam IDLE = 2'b0, LOAD = 2'b1, STORE = 2'b10;
    reg [1:0] status;
    reg [`ROB_TAG_RANGE] current_tag;
    reg [`INNER_INST_RANGE] current_op;

    wire [`WORD_RANGE] lb_zext;
    wire [`WORD_RANGE] lh_zext;
    wire [`WORD_RANGE] lw;
    wire [`WORD_RANGE] lb_sext;
    wire [`WORD_RANGE] lh_sext;
    wire [`WORD_RANGE] load_result;

    assign lb_sext = {{24{mc_data_in[ 7]}}, mc_data_in[ 7:0]};
    assign lh_sext = {{16{mc_data_in[15]}}, mc_data_in[15:0]};
    assign lw      = mc_data_in;
    assign lb_zext = {24'b0, mc_data_in[ 7:0]};
    assign lh_zext = {16'b0, mc_data_in[15:0]};
    assign load_result = current_op == `LB  ? lb_sext :
                         current_op == `LBU ? lb_zext :
                         current_op == `LH  ? lh_sext :
                         current_op == `LHU ? lh_zext :
                         current_op == `LW  ? lw : `ZERO_WORD;

    always @(posedge clk) begin
        mc_request_out <= `FALSE;
        broadcast_signal_out <= `FALSE;
        if (rst) begin
            head <= 0;
            tail <= 0;
            unexecute_committed_store_cnt <= 0;
            status <= IDLE;
            current_tag <= `NULL_TAG;
        end else if (rob_rollback_in) begin
            // overflow
            tail <= head + unexecute_committed_store_cnt;
            unexecute_committed_store_cnt <= 0;
            if (status == LOAD) begin
                status <= IDLE;
                current_tag <= `NULL_TAG;
            end
        end else begin
            if (dis_new_inst_signal_in) begin
                load_store_flag[tail_next] <= dis_load_store_signal_in;
                commit_flag[tail_next] <= `FALSE;
                op[tail_next] <= dec_op_in;
                rob_tag[tail_next] <= dec_next_tag_in;
                imm[tail_next] <= dec_imm_in;
                Vj[tail_next] <= dec_Vj_in;
                Vk[tail_next] <= dec_Vk_in;
                Qj[tail_next] <= dec_Qj_in;
                Qk[tail_next] <= dec_Qk_in;
                load_store_goal[tail_next] <= dec_goal_in;
                tail <= tail_next;
            end
            // waiting for commit signal
            if (rob_commit_lsb_signal_in) begin
                for (i = 0; i < `LSB_CAPACITY; i = i + 1) begin
                    if (in_queue[i] && rob_tag[i] == rob_commit_tag_in) begin
                        commit_flag[i] <= `TRUE;
                        if (load_store_flag[i]) // is store
                            unexecute_committed_store_cnt <= unexecute_committed_store_cnt + 1;
                    end
                end
            end
            // update data by snoopy on cdb (i.e., alu)
            if (alu_broadcast_signal_in) begin
                for (i = 0; i < `LSB_CAPACITY; i = i + 1) begin
                    if (Qj[i] == alu_dest_tag_in && in_queue[i]) begin
                        Qj[i] <= `NULL_TAG;
                        Vj[i] <= alu_result_in;
                    end
                    if (Qk[i] == alu_dest_tag_in && in_queue[i]) begin
                        Qk[i] <= `NULL_TAG;
                        Vk[i] <= alu_result_in;
                    end
                end
            end
            // issue queue head when not empty
            if (head != tail && status == IDLE && ready[head_next]) begin
                rob_tag[head_next] <= `NULL_TAG;
                commit_flag[head_next] <= `FALSE;
                mc_request_out <= `TRUE;
                mc_goal_out <= load_store_goal[head_next];
                mc_rw_signal_out <= load_store_flag[head_next];
                current_tag <= rob_tag[head_next];
                current_op <= op[head_next];
                mc_address_out <= Vj[head_next] + imm[head_next];
                mc_data_out <= Vk[head_next];
                status <= load_store_flag[head_next] ? STORE : LOAD;
                if (load_store_flag[head_next]) unexecute_committed_store_cnt <= unexecute_committed_store_cnt - 1;
                head <= head_next;
            end else if (status == STORE) begin
                if (mc_ready_in) begin
                    status <= IDLE;
                end
            end else if (status == LOAD)  begin
                if (mc_ready_in) begin
                    status <= IDLE;
                    // broadcast
                    broadcast_signal_out <= `TRUE;
                    result_out <= load_result;
                    dest_tag_out <= current_tag;
                    // inner broadcast
                    for (i = 0; i < `LSB_CAPACITY; i = i + 1) begin
                        if (Qj[i] == current_tag && in_queue[i]) begin
                            Qj[i] <= `NULL_TAG;
                            Vj[i] <= load_result;
                        end
                        if (Qk[i] == current_tag && in_queue[i]) begin
                            Qk[i] <= `NULL_TAG;
                            Vk[i] <= load_result;
                        end
                    end
                end
            end
        end
    end    

    generate
        genvar index;
        for (index = 0; index < `LSB_CAPACITY; index = index + 1) begin : generate_ready
            // load doesn't need wait commit
            assign ready[index] = load_store_flag[index] ? commit_flag[index] && Qj[index] == `NULL_TAG && Qk[index] == `NULL_TAG : Qj[index] == `NULL_TAG;
        end
        for (index = 0; index < `LSB_CAPACITY; index = index + 1) begin : generate_in_queue
            assign in_queue[index] = head < tail ? head < index && index <= tail :
                                     head > tail ? head < index || index <= tail : 0;
        end
    endgenerate

endmodule