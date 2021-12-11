`include "header.v"
`include "MemoryController.v"
`include "Fetcher.v"
`include "Decoder.v"
`include "Dispatcher.v"
`include "ArithmeticLogicUnit.v"
`include "LoadStoreBuffer.v"
`include "RegisterFile.v"
`include "ReorderBuffer.v"
`include "ReservationStation.v"

// RISCV32I CPU top module
// port modification allowed for debugging purposes

module cpu (
    input  wire                 clk_in,          // system clock signal
    input  wire                 rst_in,          // reset signal
    input  wire                 rdy_in,          // ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,         // data input bus
    output wire [ 7:0]          mem_dout,        // data output bus
    output wire [31:0]          mem_a,           // address bus (only 17:0 is used)
    output wire                 mem_wr,          // write/read signal (1 for write)

    input  wire                 io_buffer_full,  // 1 if uart buffer is full

    output wire [31:0]          dbgreg_dout      // cpu register output (debugging demo)
);

    // some details for homework:

    // Specifications:
    // - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
    // - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
    // - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
    // - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
    // - 0x30000 read: read a byte from input
    // - 0x30000 write: write a byte to output (write 0x00 is ignored)
    // - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
    // - 0x30004 write: indicates program stop (will output '\0' through uart tx)

    // some code format in ths project:

    // variable (in cpu.v) name format:
    // for a wire named NAME from module X to Y
    // i.e. in X NAME is output and in Y NAME is input
    // cpu.v -> X_Y_NAME
    // X -> Y_NAME
    // Y -> X_NAME
    // for a wire named NAME from module X to Y, Z, ...
    // i.e. in X NAME is output and in Y, Z, ... NAME is input
    // cpu.v -> X_NAME_out
    // X -> NAME_out
    // Y -> X_NAME

    // inside module:
    // interfaces with same module should be placed together
    // and input interfaces at the top of output interfaces

    // MemoryController to Fetcher
    wire               mc_fet_ready;
    wire [`WORD_RANGE] mc_fet_instruction;
    // Fetcher to MemoryController
    wire               fet_mc_request;
    wire [`WORD_RANGE] fet_mc_address;

    // MemoryController to LoadStoreBuffer
    wire               mc_lsb_ready;
    wire [`WORD_RANGE] mc_lsb_data;
    // LoadStoreBuffer to MemoryController
    wire               lsb_mc_request;
    wire               lsb_mc_rw_signal;
    wire [`WORD_RANGE] lsb_mc_address;
    wire [2:0]         lsb_mc_goal; // LB: 1, LHW: 2, LW: 4
    wire [`WORD_RANGE] lsb_mc_data;

    // Fetcher to Decoder
    wire               fet_dec_issue;
    wire [`WORD_RANGE] fet_dec_inst;
    wire [`WORD_RANGE] fet_dec_pc;
    wire [`WORD_RANGE] fet_dec_predict_pc;

    // Deocder to Dispatcher
    wire [`WORD_RANGE]       dec_dis_imm;
    wire                     dec_dis_ready;
    wire [`WORD_RANGE]       dec_rs_pc;
    wire [1:0]               dec_dis_to_lsb_signal;
    wire [2:0]               dec_lsb_goal;

    // Decoder to ReservationStation
    wire [`INNER_INST_RANGE] dec_rs_op;

    // Decoder to RegisterFile
    wire [`REG_INDEX_RANGE] dec_rf_rs1;
    wire [`REG_INDEX_RANGE] dec_rf_rs2;
    wire [`REG_INDEX_RANGE] dec_rf_rd;
    wire                    dec_rf_occpuy_rd;
    // RegisterFile to Decoder
    wire [`WORD_RANGE]      rf_dec_Vj;
    wire [`WORD_RANGE]      rf_dec_Vk;
    wire [`ROB_TAG_RANGE]   rf_dec_Qj;
    wire [`ROB_TAG_RANGE]   rf_dec_Qk;
    wire [`ROB_TAG_RANGE]   rf_dec_dest;

    // Decoder to ReservationStation && LoadStoreBuffer
    wire [`WORD_RANGE]    dec_Vj_out;
    wire [`WORD_RANGE]    dec_Vk_out;
    wire [`ROB_TAG_RANGE] dec_Qj_out;
    wire [`ROB_TAG_RANGE] dec_Qk_out;
    wire [`WORD_RANGE]    dec_imm_out;
    wire [`ROB_TAG_RANGE] dec_next_tag_out;

    // Decoder to ReorderBuffer
    wire                    dec_rob_issue;
    wire [`WORD_RANGE]      dec_rob_predict_pc;
    wire [`WORD_RANGE]      dec_rob_inst;
    wire [`REG_INDEX_RANGE] dec_rob_rd;
    wire [`ROB_TAG_RANGE]   dec_rob_Qj;
    wire [`ROB_TAG_RANGE]   dec_rob_Qk;
    // ReorderBuffer to Decoder
    wire [`ROB_TAG_RANGE]   rob_dec_next_tag;
    wire                    rob_dec_Vj_ready;
    wire                    rob_dec_Vk_ready;
    wire [`WORD_RANGE]      rob_dec_Vj;
    wire [`WORD_RANGE]      rob_dec_Vk;

    // Dispatcher to ReservationStation
    wire dis_rs_new_inst_signal;

    // Dispatcher to LoadStoreBuffer
    wire dis_lsb_new_inst_signal;
    wire dis_lsb_load_store_signal;
    wire [2:0] dis_lsb_goal;

    // ReorderBuffer to Fetcher
    wire [`WORD_RANGE] rob_fet_rollback_pc;

    // Global Signal
    wire rs_full_out;
    wire lsb_full_out;
    wire rob_full_out;
    wire rob_rollback_out;

    // ReorderBuffer to RegisterFile && LoadStoreBuffer
    wire                    rob_commit_signal_out;
    wire [`ROB_TAG_RANGE]   rob_commit_tag_out;
    wire [`WORD_RANGE]      rob_commit_data_out;
    wire [`REG_INDEX_RANGE] rob_commit_target_out;

    // ReservationStation to ArithmeticLogicUnit
    wire                     rs_alu_calculate_signal;
    wire [`INNER_INST_RANGE] rs_alu_op;
    wire [`WORD_RANGE]       rs_alu_imm;
    wire [`WORD_RANGE]       rs_alu_pc;
    wire [`WORD_RANGE]       rs_alu_rs1val;
    wire [`WORD_RANGE]       rs_alu_rs2val;
    wire [`ROB_TAG_RANGE]    rs_alu_dest;

    // ArithmeticLogicUnit to ReorderBuffer
    wire [`WORD_RANGE]    alu_rob_new_pc;

    // ArithmeticLogicUnit broadcast
    wire                  alu_broadcast_signal_out;
    wire [`WORD_RANGE]    alu_result_out;
    wire [`ROB_TAG_RANGE] alu_dest_tag_out;
    // LoadStoreBuffer broadcast
    wire                  lsb_broadcast_signal_out;
    wire [`WORD_RANGE]    lsb_result_out;
    wire [`ROB_TAG_RANGE] lsb_dest_tag_out;

    MemoryController mc (
        .clk(clk_in),
        .rst(rst_in),

        .ram_data_in(mem_din),
        .ram_data_out(mem_dout),
        .ram_address_out(mem_a),
        .ram_rw_signal_out(mem_wr),

        .rob_rollback_in(rob_rollback_out),

        .fet_request_in(fet_mc_request),
        .fet_address_in(fet_mc_address),
        .fet_ready_out(mc_fet_ready),
        .fet_instruction_out(mc_fet_instruction),

        .lsb_request_in(lsb_mc_request),
        .lsb_rw_signal_in(lsb_mc_rw_signal),
        .lsb_address_in(lsb_mc_address),
        .lsb_goal_in(lsb_mc_goal),
        .lsb_data_in(lsb_mc_data),
        .lsb_ready_out(mc_lsb_ready),
        .lsb_data_out(mc_lsb_data)
    );

    Fetcher fet (
        .clk(clk_in),
        .rst(rst_in),
        
        .mc_ready_in(mc_fet_ready),
        .mc_instruction_in(mc_fet_instruction),
        .mc_request_out(fet_mc_request),
        .mc_address_out(fet_mc_address),

        .rs_full_in(rs_full_out),

        .lsb_full_in(lsb_full_out),

        .rob_full_in(rob_full_out),
        .rob_rollback_in(rob_rollback_out),
        .rob_rollback_pc_in(rob_fet_rollback_pc),

        .dec_issue_out(fet_dec_issue),
        .dec_inst_out(fet_dec_inst),
        .dec_pc_out(fet_dec_pc),
        .dec_predict_pc_out(fet_dec_predict_pc)
    );

    Decoder dec (
        .fet_issue_in(fet_dec_issue),
        .fet_inst_in(fet_dec_inst),
        .fet_pc_in(fet_dec_pc),
        .fet_predict_pc_in(fet_dec_predict_pc),

        .dis_ready_out(dec_dis_ready),
        .dis_to_lsb_signal_out(dec_dis_to_lsb_signal),

        .rf_Vj_in(rf_dec_Vj),
        .rf_Vk_in(rf_dec_Vk),
        .rf_Qj_in(rf_dec_Qj),
        .rf_Qk_in(rf_dec_Qk),
        .rf_rs1_out(dec_rf_rs1),
        .rf_rs2_out(dec_rf_rs2),
        .rf_rd_out(dec_rf_rd),
        .rf_occupy_rd_out(dec_rf_occpuy_rd),

        .Vj_out(dec_Vj_out),
        .Vk_out(dec_Vk_out),
        .Qj_out(dec_Qj_out),
        .Qk_out(dec_Qk_out),
        .imm_out(dec_imm_out),

        .next_tag_out(dec_next_tag_out),

        .rs_op_out(dec_rs_op),
        .rs_pc_out(dec_rs_pc),
        
        .lsb_goal_out(dec_lsb_goal),

        .rob_next_tag_in(rob_dec_next_tag),
        .rob_Vj_ready_in(rob_dec_Vj_ready),
        .rob_Vk_ready_in(rob_dec_Vk_ready),
        .rob_Vj_in(rob_dec_Vj),
        .rob_Vk_in(rob_dec_Vk),
        .rob_issue_out(dec_rob_issue),
        .rob_predict_pc_out(dec_rob_predict_pc),
        .rob_inst_out(dec_rob_inst),
        .rob_rd_out(dec_rob_rd),
        .rob_Qj_out(dec_rob_Qj),
        .rob_Qk_out(dec_rob_Qk)
    );

    Dispatcher dis (
        .dec_ready_in(dec_dis_ready),
        .dec_to_lsb_signal_in(dec_dis_to_lsb_signal),

        .rs_new_inst_signal_out(dis_rs_new_inst_signal),

        .lsb_new_inst_signal_out(dis_lsb_new_inst_signal),
        .lsb_load_store_signal_out(dis_lsb_load_store_signal)
    );

    RegisterFile rf (
        .clk(clk_in),
        .rst(rst_in),

        .dec_next_tag_in(dec_next_tag_out),
        .dec_rs1_in(dec_rf_rs1),
        .dec_rs2_in(dec_rf_rs2),
        .dec_rd_in(dec_rf_rd),
        .dec_occupy_rd_in(dec_rf_occpuy_rd),
        .dec_Vj_out(rf_dec_Vj),
        .dec_Vk_out(rf_dec_Vk),
        .dec_Qj_out(rf_dec_Qj),
        .dec_Qk_out(rf_dec_Qk),

        .rob_rollback_in(rob_rollback_out),
        .rob_commit_signal_in(rob_commit_signal_out),
        .rob_commit_tag_in(rob_commit_tag_out),
        .rob_commit_data_in(rob_commit_data_out),
        .rob_commit_target_in(rob_commit_target_out)
    );

    ArithmeticLogicUnit alu (
        .rs_calculate_signal_in(rs_alu_calculate_signal),
        .rs_op_in(rs_alu_op),
        .rs_imm_in(rs_alu_imm),
        .rs_pc_in(rs_alu_pc),
        .rs_rs1val_in(rs_alu_rs1val),
        .rs_rs2val_in(rs_alu_rs2val),
        .rs_dest_in(rs_alu_dest),

        .broadcast_signal_out(alu_broadcast_signal_out),
        .result_out(alu_result_out),
        .dest_tag_out(alu_dest_tag_out),

        .rob_new_pc_out(alu_rob_new_pc)
    );

    ReservationStation rs (
        .clk(clk_in),
        .rst(rst_in),

        .full_out(rs_full_out),

        .dis_new_inst_signal_in(dis_rs_new_inst_signal),

        .dec_next_tag_in(dec_next_tag_out),
        .dec_op_in(dec_rs_op),
        .dec_Vj_in(dec_Vj_out),
        .dec_Vk_in(dec_Vk_out),
        .dec_Qj_in(dec_Qj_out),
        .dec_Qk_in(dec_Qk_out),
        .dec_imm_in(dec_imm_out),
        .dec_pc_in(dec_rs_pc),
        
        .alu_calculate_signal_out(rs_alu_calculate_signal),
        .alu_op_out(rs_alu_op),
        .alu_imm_out(rs_alu_imm),
        .alu_pc_out(rs_alu_pc),
        .alu_rs1val_out(rs_alu_rs1val),
        .alu_rs2val_out(rs_alu_rs2val),
        .alu_dest_out(rs_alu_dest),

        .rob_rollback_in(rob_rollback_out),

        .alu_broadcast_signal_in(alu_broadcast_signal_out),
        .alu_result_in(alu_result_out),
        .alu_dest_tag_in(alu_dest_tag_out),
        .lsb_broadcast_signal_in(lsb_broadcast_signal_out),
        .lsb_result_in(lsb_result_out),
        .lsb_dest_tag_in(lsb_dest_tag_out)
    );

    LoadStoreBuffer lsb (
        .clk(clk_in),
        .rst(rst_in),

        .full_out(lsb_full_out),

        .broadcast_signal_out(lsb_broadcast_signal_out),
        .result_out(lsb_result_out),
        .dest_tag_out(lsb_dest_tag_out),

        .dis_new_inst_signal_in(dis_lsb_new_inst_signal),
        .dis_load_store_signal_in(dis_lsb_load_store_signal),

        .dec_next_tag_in(dec_next_tag_out),
        .dec_Vj_in(dec_Vj_out),
        .dec_Vk_in(dec_Vk_out),
        .dec_Qj_in(dec_Qj_out),
        .dec_Qk_in(dec_Qk_out),
        .dec_imm_in(dec_imm_out),
        .dec_goal_in(dec_lsb_goal),

        .alu_broadcast_signal_in(alu_broadcast_signal_out),
        .alu_result_in(alu_result_out),
        .alu_dest_tag_in(alu_dest_tag_out),

        .rob_rollback_in(rob_rollback_out),
        .rob_commit_signal_in(rob_commit_signal_out),
        .rob_commit_tag_in(rob_commit_tag_out),

        .mc_ready_in(mc_lsb_ready),
        .mc_data_in(mc_lsb_data),
        .mc_request_out(lsb_mc_request),
        .mc_rw_signal_out(lsb_mc_rw_signal),
        .mc_address_out(lsb_mc_address),
        .mc_goal_out(lsb_mc_goal),
        .mc_data_out(lsb_mc_data)
    );

    ReorderBuffer rob (
        .clk(clk_in),
        .rst(rst_in),

        .full_out(rob_full_out),
        .rollback_out(rob_rollback_out),

        .fet_rollback_pc_out(rob_fet_rollback_pc),

        .dec_issue_in(dec_rob_issue),
        .dec_predict_pc_in(dec_rob_predict_pc),
        .dec_inst_in(dec_rob_inst),
        .dec_rd_in(dec_rob_rd),
        .dec_Qj_in(dec_rob_Qj),
        .dec_Qk_in(dec_rob_Qk),
        .dec_next_tag_out(rob_dec_next_tag),
        .dec_Vj_ready_out(rob_dec_Vj_ready),
        .dec_Vk_ready_out(rob_dec_Vk_ready),
        .dec_Vj_out(rob_dec_Vj),
        .dec_Vk_out(rob_dec_Vk),

        .alu_new_pc_in(alu_rob_new_pc),

        .alu_broadcast_signal_in(alu_broadcast_signal_out),
        .alu_result_in(alu_result_out),
        .alu_dest_tag_in(alu_dest_tag_out),
        .lsb_broadcast_signal_in(lsb_broadcast_signal_out),
        .lsb_result_in(lsb_result_out),
        .lsb_dest_tag_in(lsb_dest_tag_out),

        .commit_signal_out(rob_commit_signal_out),
        .commit_tag_out(rob_commit_tag_out),
        .commit_data_out(rob_commit_data_out),
        .commit_target_out(rob_commit_target_out)
    );

endmodule