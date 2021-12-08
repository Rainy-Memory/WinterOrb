`include "header.v"

/*
 * module Fetcher
 * --------------------------------------------------
 * This module implements Fetcher in tomasulo's algorithm.
 * Meanwhile, it stores pc and handles branch prediction(to be done).
 */

module Fetcher (
    input  wire               clk,
    input  wire               rst,

    // MemoryController
    input  wire               mc_ready_in,
    input  wire [`WORD_RANGE] mc_instruction_in,
    output reg                mc_request_signal_out,
    output reg  [`WORD_RANGE] mc_address_out,

    // Decoder
    output reg                dec_issue_signal_out,
    output reg  [`WORD_RANGE] dec_inst_out,
    output reg  [`WORD_RANGE] dec_pc_out
);

    localparam IDLE = 2'b0, WAITING = 2'b1, ISSUING = 2'b10;
    reg [1:0] status;

    reg [`WORD_RANGE] pc;
    reg [`WORD_RANGE] current_inst;

    reg [`WORD_RANGE] immJ;

    always @(posedge clk) begin
        dec_issue_signal_out <= `FALSE;
        mc_request_signal_out <= `FALSE;
        if (rst) begin
            pc <= `ZERO_WORD;
            current_inst <= `ZERO_WORD;
            status <= IDLE;
        end else begin
            if (status == IDLE) begin
                status <= WAITING;
                mc_address_out <= pc;
                mc_request_signal_out <= `TRUE;
            end else if (status == WAITING) begin
                if (mc_ready_in) begin
                    status <= ISSUING;
                    current_inst <= mc_instruction_in;
                    immJ <= {{12{mc_instruction_in[31]}}, mc_instruction_in[19:12], mc_instruction_in[20], mc_instruction_in[30:21], 1'b0};
                end
            end else begin // status == ISSUING
                status <= IDLE;
                dec_issue_signal_out <= `TRUE;
                dec_inst_out <= current_inst;
                dec_pc_out <= pc;
                // directly jump in fetcher
                if (current_inst[6:0] == `JAL_OPCODE) pc <= pc + immJ;
                else pc <= pc + 4;
            end
        end
    end

endmodule