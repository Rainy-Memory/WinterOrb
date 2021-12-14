`include "header.v"

/*
 * module Fetcher
 * --------------------------------------------------
 * This module implements Fetcher in tomasulo's algorithm.
 * Meanwhile, it stores pc, has builtin i-cache and handles
 * branch prediction.
 */

`define USE_ICACHE

module Fetcher (
    input  wire               clk,
    input  wire               rst,

    // MemoryController
    input  wire               mc_ready_in,
    input  wire [`WORD_RANGE] mc_instruction_in,
    output reg                mc_request_out,
    output reg  [`WORD_RANGE] mc_address_out,

    // ReservationStation
    input  wire               rs_full_in,

    // LoadStoreBuffer
    input  wire               lsb_full_in,

    // ReorderBuffer
    input  wire               rob_full_in,
    input  wire               rob_rollback_in,
    input  wire [`WORD_RANGE] rob_rollback_pc_in,
    input  wire               rob_commit_signal_in,
    input  wire [`WORD_RANGE] rob_commit_pc_in,
    input  wire               rob_branch_taken_in,

    // Decoder
    output reg                dec_issue_out,
    output reg  [`WORD_RANGE] dec_inst_out,
    output reg  [`WORD_RANGE] dec_pc_out,
    output reg  [`WORD_RANGE] dec_predict_pc_out
);

    localparam IDLE = 2'b0, WAITING = 2'b1, ISSUING = 2'b10;
    reg [1:0] status;

    reg [`WORD_RANGE] pc;
    reg [`WORD_RANGE] current_inst;
    reg [`WORD_RANGE] immB;
    reg [`WORD_RANGE] immJ;

    // branch prediction
    integer i;
    reg [1:0] branch_history_table [`BP_RANGE];

`ifdef USE_ICACHE
    // direct-mapped i-cache
    reg [`TAG_RANGE] tags [`ICACHE_RANGE];
    reg [`WORD_RANGE] cached_insts [`ICACHE_RANGE];
    reg valid [`ICACHE_RANGE];
    wire cache_hit;
    wire [`WORD_RANGE] cache_inst;

    assign cache_hit = valid[pc[`INDEX_RANGE]] && tags[pc[`INDEX_RANGE]] == pc[`TAG_RANGE];
    assign cache_inst = cached_insts[pc[`INDEX_RANGE]];
`endif

    always @(posedge clk) begin
        dec_issue_out <= `FALSE;
        mc_request_out <= `FALSE;
        if (rst) begin
            pc <= `ZERO_WORD;
            current_inst <= `ZERO_WORD;
            status <= IDLE;
            for (i = 0; i < `BP_CAPACITY; i = i + 1) begin
                branch_history_table[i] <= 2'b10;
            end
`ifdef USE_ICACHE
            for (i = 0; i < `ICACHE_CAPACITY; i = i + 1) begin
                tags[i] <= 0;
                cached_insts[i] <= 0;
                valid[i] <= `FALSE;
            end
`endif
        end else if (rob_rollback_in) begin
            pc <= rob_rollback_pc_in;
            current_inst <= `ZERO_WORD;
            status <= IDLE;
        end else begin
            if (rob_commit_signal_in) begin
                case (branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]])
                    2'b00: branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]] <= rob_branch_taken_in ? branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]] + 1 : branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]];
                    2'b11: branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]] <= rob_branch_taken_in ? branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]] : branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]] - 1;
                    default: branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]] <= rob_branch_taken_in ? branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]] + 1 : branch_history_table[rob_commit_pc_in[`BP_HASH_RANGE]] - 1;
                endcase
            end
            if (status == IDLE) begin
`ifdef USE_ICACHE
                if (cache_hit) begin
                    status <= ISSUING;
                    current_inst <= cache_inst;
                    immJ <= {{12{cache_inst[31]}}, cache_inst[19:12], cache_inst[20], cache_inst[30:21], 1'b0};
                    immB <= {{20{cache_inst[31]}}, cache_inst[7], cache_inst[30:25], cache_inst[11:8], 1'b0};
                end else begin
`endif
                    status <= WAITING;
                    mc_address_out <= pc;
                    mc_request_out <= `TRUE;
`ifdef USE_ICACHE
                end
`endif
            end else if (status == WAITING) begin
                if (mc_ready_in) begin
                    status <= ISSUING;
                    current_inst <= mc_instruction_in;
                    immJ <= {{12{mc_instruction_in[31]}}, mc_instruction_in[19:12], mc_instruction_in[20], mc_instruction_in[30:21], 1'b0};
                    immB <= {{20{mc_instruction_in[31]}}, mc_instruction_in[7], mc_instruction_in[30:25], mc_instruction_in[11:8], 1'b0};
`ifdef USE_ICACHE
                    valid[pc[`INDEX_RANGE]] <= `TRUE;
                    tags[pc[`INDEX_RANGE]] <= pc[`TAG_RANGE];
                    cached_insts[pc[`INDEX_RANGE]] <= mc_instruction_in;
`endif
                end
            end else begin // status == ISSUING
                if (!rs_full_in && !lsb_full_in && !rob_full_in) begin
                    status <= IDLE;
                    dec_issue_out <= `TRUE;
                    dec_inst_out <= current_inst;
                    dec_pc_out <= pc;
                    // directly jump in fetcher
                    if (current_inst[6:0] == `JAL_OPCODE) begin
                        pc <= pc + immJ;
                        dec_predict_pc_out <= pc + immJ;
                    end else if (current_inst[6:0] == `BRANCH_OPCODE) begin
                        if (branch_history_table[pc[`BP_HASH_RANGE]][1]) begin
                            pc <= pc + immB;
                            dec_predict_pc_out <= pc + immB;
                        end else begin
                            pc <= pc + 4;
                            dec_predict_pc_out <= pc + 4;
                        end
                    end else begin // JALR always need rollback
                        pc <= pc + 4;
                        dec_predict_pc_out <= pc + 4;
                    end
                end
            end
        end
    end

endmodule