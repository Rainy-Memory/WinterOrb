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
    //   ->   X_Y_NAME

    // inside module:
    // interfaces with same module should be placed together
    // and input interfaces at the top of output interfaces

    // MemoryController to Fetcher
    wire               mc_fet_ready;
    wire [`WORD_RANGE] mc_fet_instruction;
    // Fetcher to MemoryController
    wire               fet_mc_request_signal;
    wire [`WORD_RANGE] fet_mc_address;

    // MemoryController to LoadStoreBuffer
    wire               mc_lsb_ready;
    wire [`WORD_RANGE] mc_lsb_data;
    // LoadStoreBuffer to MemoryController
    wire               lsb_mc_request_signal;
    wire               lsb_mc_rw_signal;
    wire [`WORD_RANGE] lsb_mc_address;
    wire [2:0]         lsb_mc_goal; // LB: 1, LHW: 2, LW: 4
    wire [`WORD_RANGE] lsb_mc_data;

    // Fetcher to Decoder
    wire               fet_dec_issue_signal;
    wire [`WORD_RANGE] fet_dec_inst;
    wire [`WORD_RANGE] fet_dec_pc;

    // Deocder to Dispatcher
    wire [`WORD_RANGE]       dec_dis_imm;
    wire [`INNER_INST_RANGE] dec_dis_inst_type;
    wire [`REG_INDEX_RANGE]  dec_dis_rs1;
    wire [`REG_INDEX_RANGE]  dec_dis_rs2;
    wire [`REG_INDEX_RANGE]  dec_dis_rd;
    wire [`SHAMT_RANGE]      dec_dis_shamt;
    wire                     dec_dis_ready;
    wire [`WORD_RANGE]       dec_dis_pc;
    wire [1:0]               dec_dis_to_lsb_signal;
    wire [2:0]               dec_dis_lsb_goal;

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
    wire [`ROB_TAG_RANGE] dec_dest_out;

    // Decoder to ReorderBuffer
    wire [`WORD_RANGE]      dec_rob_inst;
    wire [`REG_INDEX_RANGE] dec_rob_rd;
    wire [`ROB_TAG_RANGE]   dec_rob_Qj;
    wire [`ROB_TAG_RANGE]   dec_rob_Qk;
    wire                    dec_rob_Vj_ready;
    wire                    dec_rob_Vk_ready;
    wire [`WORD_RANGE]      dec_rob_Vj;
    wire [`WORD_RANGE]      dec_rob_Vk;

    // ReorderBuffer to Dispatcher
    wire [`ROB_TAG_RANGE] rob_dis_tag;

    // ReorderBuffer to RegisterFile
    wire                    rob_rf_commit_signal;
    wire [`ROB_TAG_RANGE]   rob_rf_commit_tag;
    wire [`WORD_RANGE]      rob_rf_commit_data;
    wire [`REG_INDEX_RANGE] rob_rf_commit_target;

    // Dispatcher to RegisterFile && LoadStoreBuffer
    wire [`ROB_TAG_RANGE] dis_tag_out;

    // Dispatcher to ReservationStation && LoadStoreBuffer
    wire [`INNER_INST_RANGE] dis_inst_out;
    wire [`WORD_RANGE]       dis_imm_out;
    wire [`WORD_RANGE]       dis_pc_out;
    wire [`ROB_TAG_RANGE]    dis_dest_out;

    // Dispatcher to ReservationStation
    wire dis_rs_new_inst_signal;

    // Dispatcher to LoadStoreBuffer
    wire dis_lsb_new_inst_signal;
    wire dis_lsb_load_store_signal;
    wire [2:0] dis_lsb_goal;

    // ReservationStation to ArithmeticLogicUnit
    wire [`INNER_INST_RANGE] rs_alu_op;
    wire [`WORD_RANGE]       rs_alu_imm;
    wire [`WORD_RANGE]       rs_alu_pc;
    wire [`WORD_RANGE]       rs_alu_lhs;
    wire [`WORD_RANGE]       rs_alu_rhs;
    wire [`ROB_TAG_RANGE]    rs_alu_dest;

    // ArithmeticLogicUnit broadcast
    wire                  alu_broadcast_signal_out;
    wire [`WORD_RANGE]    alu_result_out;
    wire [`ROB_TAG_RANGE] alu_dest_tag_out;

    // ArithmeticLogicUnit to ReorderBuffer
    wire [`WORD_RANGE] alu_rob_new_pc;

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

        .fet_request_signal_in(fet_mc_request_signal),
        .fet_address_in(fet_mc_address),
        .fet_ready_out(mc_fet_ready),
        .fet_instruction_out(mc_fet_instruction)
    );

    Fetcher fet (
        .clk(clk_in),
        .rst(rst_in),
        
        .mc_ready_in(mc_fet_ready),
        .mc_instruction_in(mc_fet_instruction),
        .mc_request_signal_out(fet_mc_request_signal),
        .mc_address_out(fet_mc_address),

        .dec_issue_signal_out(fet_dec_issue_signal),
        .dec_inst_out(fet_dec_inst),
        .dec_pc_out(fet_dec_pc)
    );

    Decoder dec (
        .rst(rst_in),

        .fet_issue_signal_in(fet_dec_issue_signal),
        .fet_inst_in(fet_dec_inst),
        .fet_pc_in(fet_dec_pc),

        .dis_imm_out(dec_dis_imm),
        .dis_inst_type_out(dec_dis_inst_type),
        .dis_rs1_out(dec_dis_rs1),
        .dis_rs2_out(dec_dis_rs2),
        .dis_rd_out(dec_dis_rd),
        .dis_shamt_out(dec_dis_shamt),
        .dis_ready_out(dec_dis_ready),
        .dis_pc_out(dec_dis_pc),
        .dis_to_lsb_signal_out(dec_dis_to_lsb_signal),
        .dis_lsb_goal_out(dec_dis_lsb_goal),

        .rf_rs1_out(dec_rf_rs1),
        .rf_rs2_out(dec_rf_rs2),
        .rf_rd_out(dec_rf_rd),
        .rf_occupy_rd_out(dec_rf_occpuy_rd),
        .rf_Vj_in(rf_dec_Vj),
        .rf_Vk_in(rf_dec_Vk),
        .rf_Qj_in(rf_dec_Qj),
        .rf_Qk_in(rf_dec_Qk),
        .rf_dest_in(rf_dec_dest),

        .Vj_out(dec_Vj_out),
        .Vk_out(dec_Vk_out),
        .Qj_out(dec_Qj_out),
        .Qk_out(dec_Qk_out),
        .dest_out(dec_dest_out),

        .rob_inst_out(dec_rob_inst),
        .rob_rd_out(dec_rob_rd),
        .rob_Qj_out(dec_rob_Qj),
        .rob_Qk_out(dec_rob_Qk),
        .rob_Vj_ready_in(dec_rob_Vj_ready),
        .rob_Vk_ready_in(dec_rob_Vk_ready),
        .rob_Vj_in(dec_rob_Vj),
        .rob_Vk_in(dec_rob_Vk)
    );

    Dispatcher dis (
        .rst(rst_in),

        .dec_imm_in(dec_dis_imm),
        .dec_inst_type_in(dec_dis_inst_type),
        .dec_rs1_in(dec_dis_rs1),
        .dec_rs2_in(dec_dis_rs2),
        .dec_rd_in(dec_dis_rd),
        .dec_shamt_in(dec_dis_shamt),
        .dec_ready_in(dec_dis_ready),
        .dec_pc_in(dec_dis_pc),
        .dec_to_lsb_signal_in(dec_dis_to_lsb_signal),
        .dec_lsb_goal_in(dec_dis_lsb_goal),

        .rob_tag_in(rob_dis_tag),

        .tag_out(dis_tag_out),

        .inst_out(dis_inst_out),
        .imm_out(dis_imm_out),
        .pc_out(dis_pc_out),
        .dest_out(dis_dest_out),

        .rs_new_inst_signal_out(dis_rs_new_inst_signal),

        .lsb_new_inst_signal_out(dis_lsb_new_inst_signal),
        .lsb_load_store_signal_out(dis_lsb_load_store_signal),
        .lsb_goal_out(dis_lsb_goal)
    );

    RegisterFile rf (
        .rst(rst_in),

        .dis_tag_in(dis_tag_out),
        
        .dec_rs1_in(dec_rf_rs1),
        .dec_rs2_in(dec_rf_rs2),
        .dec_rd_in(dec_rf_rd),
        .dec_occupy_rd_in(dec_rf_occpuy_rd),
        .dec_Vj_out(rf_dec_Vj),
        .dec_Vk_out(rf_dec_Vk),
        .dec_Qj_out(rf_dec_Qj),
        .dec_Qk_out(rf_dec_Qk),
        .dec_dest_out(rf_dec_dest),

        .rob_commit_signal_in(rob_rf_commit_signal),
        .rob_commit_tag_in(rob_rf_commit_tag),
        .rob_commit_data_in(rob_rf_commit_data),
        .rob_commit_target_in(rob_rf_commit_target)
    );

    ArithmeticLogicUnit alu (
        .rs_op_in(rs_alu_op),
        .rs_imm_in(rs_alu_imm),
        .rs_pc_in(rs_alu_pc),
        .rs_lhs_in(rs_alu_lhs),
        .rs_rhs_in(rs_alu_rhs),
        .rs_dest_in(rs_alu_dest),

        .broadcast_signal_out(alu_broadcast_signal_out),
        .result_out(alu_result_out),
        .dest_tag_out(alu_dest_tag_out),

        .rob_new_pc_out(alu_rob_new_pc)
    );

    ReservationStation rs (
        .clk(clk_in),
        .rst(rst_in),

        .dis_new_inst_signal_in(dis_rs_new_inst_signal),
        .dis_inst_in(dis_inst_out),
        .dis_imm_in(dis_imm_out),
        .dis_pc_in(dis_pc_out),
        .dis_dest_in(dis_dest_out),

        .dec_Vj_in(dec_Vj_out),
        .dec_Vk_in(dec_Vk_out),
        .dec_Qj_in(dec_Qj_out),
        .dec_Qk_in(dec_Qk_out),
        
        .alu_op_out(rs_alu_op),
        .alu_imm_out(rs_alu_imm),
        .alu_pc_out(rs_alu_pc),
        .alu_lhs_out(rs_alu_lhs),
        .alu_rhs_out(rs_alu_rhs),
        .alu_dest_out(rs_alu_dest),

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

        .broadcast_signal_out(lsb_broadcast_signal_out),
        .result_out(lsb_result_out),
        .dest_tag_out(lsb_dest_tag_out),

        .dis_new_inst_signal_in(dis_lsb_new_inst_signal),
        .dis_load_store_signal_in(dis_lsb_load_store_signal),
        .dis_goal_in(dis_lsb_goal),
        .dis_inst_in(dis_inst_out),
        .dis_imm_in(dis_imm_out),
        .dis_dest_in(dis_dest_out),
        .dis_tag_in(dis_tag_out),

        .dec_Vj_in(dec_Vj_out),
        .dec_Vk_in(dec_Vk_out),
        .dec_Qj_in(dec_Qj_out),
        .dec_Qk_in(dec_Qk_out),

        .alu_broadcast_signal_in(alu_broadcast_signal_out),
        .alu_result_in(alu_result_out),
        .alu_dest_tag_in(alu_dest_tag_out),

        .mc_ready_in(mc_lsb_ready),
        .mc_data_in(mc_lsb_data),
        .mc_request_signal_out(lsb_mc_request_signal),
        .mc_rw_signal_out(lsb_mc_rw_signal),
        .mc_address_out(lsb_mc_address),
        .mc_goal_out(lsb_mc_goal),
        .mc_data_out(lsb_mc_data)
    );

    ReorderBuffer rob (
        .clk(clk_in),
        .rst(rst_in),

        .dis_tag_out(rob_dis_tag),

        .dec_inst_in(dec_rob_inst),
        .dec_rd_in(dec_rob_rd),
        .dec_Qj_in(dec_rob_Qj),
        .dec_Qk_in(dec_rob_Qk),
        .dec_Vj_ready_out(dec_rob_Vj_ready),
        .dec_Vk_ready_out(dec_rob_Vk_ready),
        .dec_Vj_out(dec_rob_Vj),
        .dec_Vk_out(dec_rob_Vk),

        .alu_broadcast_signal_in(alu_broadcast_signal_out),
        .alu_result_in(alu_result_out),
        .alu_dest_tag_in(alu_dest_tag_out),
        .lsb_broadcast_signal_in(lsb_broadcast_signal_out),
        .lsb_result_in(lsb_result_out),
        .lsb_dest_tag_in(lsb_dest_tag_out),

        .rf_commit_signal_out(rob_rf_commit_signal),
        .rf_commit_tag_out(rob_rf_commit_tag),
        .rf_commit_data_out(rob_rf_commit_data),
        .rf_commit_target_out(rob_rf_commit_target),

        .alu_new_pc_in(alu_rob_new_pc)
    );

endmodule