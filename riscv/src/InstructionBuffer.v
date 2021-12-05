`include "header.v"

/*
 * module InstructionBuffer
 * --------------------------------------------------
 * This module implements a simple buffer to read and 
 * store 4 bytes from MemoryController, pack them as
 * an instruction and send the instruction to InstructionQueue.
 */

module InstructionBuffer (
    input  wire                      clk,
    input  wire                      rst,

    // MemoryController
    input  wire                      mc_ready_in,
    output reg                       mc_rw_signal_out, // 1->write, 0->read
    output reg  [`WORD_RANGE]        mc_address_out,
    input  wire [`RAM_DATA_RANGE]    mc_data_in,

    // InstructionQueue
    input  wire [`WORD_RANGE]        iq_address_in,
    output reg                       iq_ready_out,
    output reg  [`INSTRUCTION_RANGE] iq_instruction_out
);

    integer ib_log;
    integer cnt;

    localparam IDLE = 2'b00, BUSY = 2'b01, FINISH = 2'b10;

    reg [1:0] status;
    reg [1:0] current;
    reg [31:0] buffer;
    reg [`WORD_RANGE] current_address;
    reg waiting; // read from ram takes 2 cycles

    initial begin
        status = IDLE;
        ib_log = $fopen(`IB_LOG_PATH, "w");
        cnt = 0;
    end

    always @(posedge clk) begin
        $fdisplay(ib_log, "No.%d cycle", cnt);
        cnt <= cnt + 1;
        iq_ready_out <= `FALSE;
        iq_instruction_out <= `ZERO_WORD;
        mc_rw_signal_out <= `READ;
        mc_address_out <= `ZERO_WORD;
        if (rst) begin
            status <= IDLE;
            current <= 2'd0;
            buffer <= `ZERO_WORD;
        end else begin
            if (status == IDLE) begin
                mc_rw_signal_out <= `READ;
                mc_address_out <= iq_address_in;
                $fdisplay(ib_log, "start fetch instruction in address: %h", iq_address_in);
                current_address <= iq_address_in;
                current <= 2'd0;
                status <= BUSY;
                waiting <= `TRUE;
            end else if (status == BUSY) begin
                if (mc_ready_in && !waiting) begin
                    $fdisplay(ib_log, "mc_data_in in InstructionBuffer: %h", mc_data_in);
                    buffer[current * `RAM_DATA_LEN +: `RAM_DATA_LEN] <= mc_data_in;
                    current <= current + 1;
                    if (current == 2'd3) begin
                        status <= FINISH;
                        current <= 2'd0;
                    end else begin
                        mc_rw_signal_out <= `READ;
                        mc_address_out <= current_address + (current + 1);
                        waiting <= `TRUE;
                        $fdisplay(ib_log, "continue fetch instruction with current = %d, in address: %h", current + 1, current_address + (current + 1));
                    end
                end else if (waiting) begin
                    waiting <= `FALSE;
                    $fdisplay(ib_log, "waiting...");
                end else begin
                    $fdisplay(ib_log, "mc_ready_in is `FALSE");
                end
            end else begin // status == FINISH
                iq_instruction_out <= buffer;
                buffer <= `ZERO_WORD;
                iq_ready_out <= `TRUE;
                status <= IDLE;
            end
        end
    end

endmodule