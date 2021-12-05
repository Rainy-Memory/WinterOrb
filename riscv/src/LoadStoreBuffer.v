`include "header.v"

module LoadStoreBuffer (
    input  wire                      clk,
    input  wire                      rst,
    
    // ReservationStation && LoadStoreBuffer && ReorderBuffer
    output reg                      broadcast_signal_out,
    output reg  [`WORD_RANGE]       result_out,
    output wire [`ROB_TAG_RANGE]    dest_tag_out,

    // Dispatcher
    input  wire                     dis_new_inst_signal_in,
    input  wire                     dis_load_store_signal_in,
    input  wire [`INNER_INST_RANGE] dis_inst_in,
    input  wire [`WORD_RANGE]       dis_imm_in,
    input  wire [`ROB_TAG_RANGE]    dis_dest_in,
    input  wire [`ROB_TAG_RANGE]    dis_tag_in,

    // Decoder
    input  wire [`WORD_RANGE]       dec_Vj_in,
    input  wire [`WORD_RANGE]       dec_Vk_in,
    input  wire [`ROB_TAG_RANGE]    dec_Qj_in,
    input  wire [`ROB_TAG_RANGE]    dec_Qk_in,

    // BroadCast ArithmeticLogicUnit
    input  wire                     alu_broadcast_signal_in,
    input  wire [`WORD_RANGE]       alu_result_in,
    input  wire [`ROB_TAG_RANGE]    alu_dest_tag_in
);

    reg [`LSB_INDEX_RANGE] head, tail;
    reg [`WORD_RANGE] inst [`LSB_RANGE];
    reg load_store_flag [`LSB_RANGE]; // LOAD -> 0, STORE -> 1
    reg commit_flag [`LSB_RANGE];
    reg [`ROB_TAG_RANGE] rob_tag [`LSB_RANGE];
    reg [`WORD_RANGE] Vj [`LSB_RANGE];
    reg [`WORD_RANGE] Vk [`LSB_RANGE];
    reg [`ROB_TAG_RANGE] Qj [`LSB_RANGE];
    reg [`ROB_TAG_RANGE] Qk [`LSB_RANGE];
    wire ready [`LSB_RANGE];

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            head <= 1;
            tail <= 1;
        end else begin
            if (dis_new_inst_signal_in) begin
                inst[tail] <= dis_inst_in;
                load_store_flag[tail] <= dis_load_store_signal_in;
                commit_flag[tail] <= `FALSE;
                rob_tag[tail] <= dis_tag_in;
                Vj[tail] <= dec_Vj_in;
                Vk[tail] <= dec_Vk_in;
                Qj[tail] <= dec_Qj_in;
                Qk[tail] <= dec_Qk_in;
                tail <= tail == `LSB_CAPACITY ? 1 : tail + 1;
            end

            // update data by snoopy on cdb (i.e., alu)
            if (alu_broadcast_signal_in) begin
                for (i = 0; i < `LSB_CAPACITY; i = i + 1) begin
                    if (Qj[i] == alu_dest_tag_in) begin
                        Qj[i] <= `NULL_TAG;
                        Vj[i] <= alu_result_in;
                    end
                    if (Qk[i] == alu_dest_tag_in) begin
                        Qk[i] <= `NULL_TAG;
                        Vk[i] <= alu_result_in;
                    end
                end
            end

            // issue queue head
            if (ready[head]) begin
                if (load_store_flag[head]) begin // store
                    
                end else begin // load
                    
                end
                head <= head == `LSB_CAPACITY ? 1 : head + 1;
            end
        end
    end

    generate
        genvar index;
        for (index = 0; index < `RS_CAPACITY; index = index + 1) begin : generate_ready
            // load doesn't need wait commit
            assign ready[index] = load_store_flag[index] ? (commit_flag[index] && (Qj[index] == `NULL_TAG) && (Qk[index] == `NULL_TAG)) : (Qj[index] == `NULL_TAG) && (Qk[index] == `NULL_TAG);
        end
    endgenerate

endmodule