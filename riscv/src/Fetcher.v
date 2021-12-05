`include "header.v"

/*
 * module Fetcher
 * --------------------------------------------------
 * This module implements Fetcher in tomasulo's algorithm.
 * Meanwhile, it stores pc and handles branch prediction(to be done).
 */

module Fetcher (
    input  wire                      clk,
    input  wire                      rst,

    // InstructionBuffer
    output reg  [`WORD_RANGE]        ib_address_out,
    input  wire                      ib_ready_in,
    input  wire [`INSTRUCTION_RANGE] ib_instruction_in,

    // Decoder
    output reg                       dec_issue_signal_out,
    output reg  [`INSTRUCTION_RANGE] dec_inst_out,
    output reg  [`WORD_RANGE]        dec_pc_out
);

    integer fet_log;
    integer cnt;

    localparam IDLE = 2'b0, WAITING = 2'b1, ISSUING = 2'b10;
    reg [1:0] status;

    reg [`WORD_RANGE] pc;
    reg [`INSTRUCTION_RANGE] current_inst;

    initial begin
        status = IDLE;
        pc = `ZERO_WORD;
        fet_log = $fopen(`FET_LOG_PATH, "w");
        cnt = 0;
    end

    always @(posedge clk) begin
        $fdisplay(fet_log, "No.%d cycle", cnt);
        cnt <= cnt + 1;
        dec_issue_signal_out <= `FALSE;
        dec_inst_out <= `ZERO_WORD;
        if (rst) begin
            pc <= `ZERO_WORD;
        end else begin
            if (status == IDLE) begin
                status <= WAITING;
                ib_address_out <= pc;
                pc <= pc + 4;
                $fdisplay(fet_log, "start fetch instruction at address %h", pc);
            end else if (status == WAITING) begin
                if (ib_ready_in) begin
                    status <= ISSUING;
                    current_inst <= ib_instruction_in;
                    $fdisplay(fet_log, "receive instruction %h from InstructionBuffer", ib_instruction_in);
                end else begin
                    $fdisplay(fet_log, "waiting...");
                end
            end else begin // status == ISSUING
                status <= IDLE;
                dec_issue_signal_out <= `TRUE;
                dec_inst_out <= current_inst;
                dec_pc_out <= pc - 4;
                $fdisplay(fet_log, "issue instruction %h to Decoder", current_inst);
            end
        end
    end

endmodule