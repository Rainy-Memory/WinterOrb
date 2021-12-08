`include "header.v"

/*
 * module MemoryController
 * --------------------------------------------------
 * This module implements a simple interface with
 * <ram.v>, for ram does not support read and write at
 * the same time.
 */

module MemoryController (
    input  wire                   clk,
    input  wire                   rst,

    // ram.v
    input  wire [`RAM_DATA_RANGE] ram_data_in,
    output reg  [`RAM_DATA_RANGE] ram_data_out,
    output reg  [`WORD_RANGE]     ram_address_out,
    output reg                    ram_rw_signal_out, // 1->write, 0->read

    // Fetcher
    input  wire                   fet_request_signal_in,
    input  wire [`WORD_RANGE]     fet_address_in,
    output reg                    fet_ready_out,
    output reg  [`WORD_RANGE]     fet_instruction_out,

    // LoadStoreBuffer
    input  wire                   lsb_request_signal_in,
    input  wire                   lsb_rw_signal_in,
    input  wire [`WORD_RANGE]     lsb_address_in,
    input  wire [2:0]             lsb_goal_in, // LB: 1, LHW: 2, LW: 4
    input  wire [`WORD_RANGE]     lsb_data_in,
    output reg                    lsb_ready_out,
    output reg  [`WORD_RANGE]     lsb_data_out
);

    localparam IDLE = 2'b00, BUSY = 2'b01, FINISH = 2'b10;
    reg [1:0] status;

    localparam NONE = 2'b00, INSTRUCTION = 2'b01, LOAD = 2'b10, STORE = 2'b11;
    reg [1:0] working_on;
    reg waiting; // read from ram takes 2 cycles
    reg [2:0] goal;
    reg [2:0] current;
    reg [`WORD_RANGE] current_address;
    reg [`WORD_RANGE] current_data;
    reg [`WORD_RANGE] buffer;

    reg have_instruction_request;
    reg [`WORD_RANGE] instruction_address;

    reg have_load_request;
    reg [`WORD_RANGE] load_address;
    reg [2:0] load_goal; // LB: 1, LHW: 2, LW: 4

    reg have_store_request;
    reg [`WORD_RANGE] store_address;
    reg [2:0] store_goal; // LB: 1, LHW: 2, LW: 4
    reg [`WORD_RANGE] store_data;

    always @(posedge clk) begin
        fet_ready_out <= `FALSE;
        lsb_ready_out <= `FALSE;
        if (rst) begin
            status <= IDLE;
            working_on <= NONE;
            have_instruction_request <= `FALSE;
            have_load_request <= `FALSE;
            have_store_request <= `FALSE;
            buffer <= `ZERO_WORD;
            current <= 3'd0;
        end else begin
            if (fet_request_signal_in) begin
                have_instruction_request <= `TRUE;
                instruction_address <= fet_address_in;
            end
            if (lsb_request_signal_in) begin
                // LOAD -> 0, STORE -> 1
                if (lsb_rw_signal_in) begin // store
                    have_store_request <= `TRUE;
                    store_address <= lsb_address_in;
                    store_goal <= lsb_goal_in;
                    store_data <= lsb_data_in;
                end else begin
                    have_load_request <= `TRUE;
                    load_address <= lsb_address_in;
                    load_goal <= lsb_goal_in;
                end
            end
            if (status == IDLE) begin
                if (have_store_request) begin
                    have_store_request <= `FALSE;
                    status <= BUSY;
                    working_on <= STORE;
                    // store doesn't need wait 2 cycle
                    goal <= store_goal;
                    current_address <= store_address;
                    current_data <= store_data;
                    ram_rw_signal_out <= `WRITE;
                    ram_address_out <= store_address;
                    ram_data_out <= store_data[current * `RAM_DATA_LEN +: `RAM_DATA_LEN];
                    current <= current + 1;
                end else if (have_load_request) begin
                    have_load_request <= `FALSE;
                    status <= BUSY;
                    working_on <= LOAD;
                    waiting <= `TRUE;
                    goal <= load_goal;
                    current_address <= load_address;
                    ram_rw_signal_out <= `READ;
                    ram_address_out <= load_address;
                end else if (have_instruction_request) begin
                    have_instruction_request <= `FALSE;
                    status <= BUSY;
                    working_on <= INSTRUCTION;
                    waiting <= `TRUE;
                    goal <= 3'd4; // ib read one instruction (4 byte) at once
                    current_address <= instruction_address;
                    ram_rw_signal_out <= `READ;
                    ram_address_out <= instruction_address;
                end
            end else if (status == BUSY) begin
                if (waiting) waiting <= `FALSE;
                else begin
                    if (working_on == STORE) begin
                        if (current == goal) begin
                            status <= FINISH;
                            current <= 3'd0;
                        end else begin
                            ram_rw_signal_out <= `WRITE;
                            ram_address_out <= current_address + current;
                            ram_data_out <= current_data[current * `RAM_DATA_LEN +: `RAM_DATA_LEN];
                            current <= current + 1;
                        end
                    end else begin // working_on == INSTRUCTION || LOAD
                        buffer[current * `RAM_DATA_LEN +: `RAM_DATA_LEN] <= ram_data_in;
                        current <= current + 1;
                        if (current == goal - 1) begin
                            status <= FINISH;
                            current <= 3'd0;
                        end else begin
                            waiting <= `TRUE;
                            ram_rw_signal_out <= `READ;
                            ram_address_out <= current_address + (current + 1);
                        end
                    end
                end
            end else begin // status == FINISH
                if (working_on == STORE) begin
                    lsb_ready_out <= `TRUE;
                end else if (working_on == LOAD) begin
                    lsb_ready_out <= `TRUE;
                    lsb_data_out <= buffer;
                    buffer <= `ZERO_WORD;
                end else begin
                    fet_ready_out <= `TRUE;
                    fet_instruction_out <= buffer;
                    buffer <= `ZERO_WORD;
                end
                status <= IDLE;
            end
        end
    end
    
endmodule