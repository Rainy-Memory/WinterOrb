`include "header.v"

/*
 * module Dispatcher
 * --------------------------------------------------
 * This module implements Dispatcher in tomasulo's algorithm.
 * Mainly it dispatch decoded instruction to LSB or RS.
 */

module Dispatcher (
    // Decoder
    input  wire       dec_ready_in,
    input  wire [1:0] dec_to_lsb_signal_in, // first bit represents to LSB, second bit: LOAD -> 0, STORE -> 1

    // ReservationStation
    output wire       rs_new_inst_signal_out,

    // LoadStoreBuffer
    output wire       lsb_new_inst_signal_out,
    output wire       lsb_load_store_signal_out
);
    
    assign lsb_load_store_signal_out = dec_to_lsb_signal_in[0];
    assign lsb_new_inst_signal_out   = dec_ready_in ?  dec_to_lsb_signal_in[1] : `FALSE;
    assign rs_new_inst_signal_out    = dec_ready_in ? ~dec_to_lsb_signal_in[1] : `FALSE;

endmodule