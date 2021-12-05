`include "header.v"

/*
 * module MemoryController
 * --------------------------------------------------
 * This module implements a simple interface with
 * <ram.v>, for ram does not support read and write at
 * the same time.
 */

module MemoryController (
    input  wire                   rst,

    // ram.v
    input  wire [`RAM_DATA_RANGE] ram_data_in,
    output wire [`RAM_DATA_RANGE] ram_data_out,
    output wire [`WORD_RANGE]     ram_address_out,
    output wire                   ram_rw_signal_out, // 1->write, 0->read

    // InstructionBuffer
    output wire                   ib_ready_out,
    input  wire                   ib_rw_signal_in,
    input  wire [`WORD_RANGE]     ib_address_in,
    output wire [`RAM_DATA_RANGE] ib_data_out
);

    assign ib_ready_out = rst ? `FALSE : `TRUE;
    assign ram_rw_signal_out = rst ? `FALSE : ib_rw_signal_in;
    assign ram_address_out = rst ? `ZERO_WORD : ib_address_in;
    assign ib_data_out = rst ? `ZERO_BYTE : ram_data_in;
    
endmodule