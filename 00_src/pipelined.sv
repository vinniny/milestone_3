`ifndef PIPELINED_SV
`define PIPELINED_SV

module pipelined (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic [31:0] i_io_sw,
    output logic [31:0] o_io_ledr,
    output logic [31:0] o_io_ledg,
    output logic [6:0]  o_io_hex0,
    output logic [6:0]  o_io_hex1,
    output logic [6:0]  o_io_hex2,
    output logic [6:0]  o_io_hex3,
    output logic [6:0]  o_io_hex4,
    output logic [6:0]  o_io_hex5,
    output logic [6:0]  o_io_hex6,
    output logic [6:0]  o_io_hex7,
    output logic [31:0] o_io_lcd,
    output logic [31:0] o_pc_frontend,
    output logic [31:0] o_pc_commit,
    output logic        o_insn_vld,
    output logic        o_ctrl,
    output logic        o_mispred,
    output logic        o_halt,
    output logic [3:0]  o_model_id
);

    // ========================================================================
    // Wires & Interconnects
    // ========================================================================

    // --- Hazard Unit Signals ---
    logic hu_stall_if;
    logic hu_stall_id;
    logic hu_flush_id_ex;
    logic hu_flush_if_id;

    // --- Forwarding Unit Signals ---
    logic [1:0] fu_forward_a_sel;    // EX ALU Op A
    logic [1:0] fu_forward_b_sel;    // EX ALU Op B
    logic [1:0] fu_forward_id_a_sel; // ID Branch Op A
    logic [1:0] fu_forward_id_b_sel; // ID Branch Op B

    // --- IF Stage Outputs ---
    logic [31:0] if_pc;
    logic [31:0] if_instr;
    logic        if_pred_taken;
    logic [31:0] if_imem_addr; // Not used externally, internal to stage_if
    logic [31:0] imem_rdata;   // IMEM Read Data

    // --- IF/ID Register Outputs ---
    logic [31:0] if_id_pc;
    logic [31:0] if_id_instr;
    logic        if_id_valid;
    logic        if_id_pred_taken;
    logic        if_id_bubble;
    logic        if_id_kill;

    // --- ID Stage Outputs ---
    logic [31:0] id_pc;
    logic [31:0] id_rs1_val;
    logic [31:0] id_rs2_val;
    logic [31:0] id_imm;
    logic [4:0]  id_rs1;
    logic [4:0]  id_rs2;
    logic [4:0]  id_rd;
    
    logic        id_ctrl_valid;
    logic        id_ctrl_bubble;
    logic        id_ctrl_kill;
    logic        id_ctrl_branch;
    logic        id_ctrl_jump;
    logic        id_ctrl_mem_read;
    logic        id_ctrl_mem_write;
    logic [3:0]  id_ctrl_alu_op;
    logic        id_ctrl_wb_en;
    logic        id_ctrl_mispred;
    logic [2:0]  id_ctrl_funct3;
    logic [1:0]  id_ctrl_op_a_sel;
    logic        id_ctrl_op_b_sel;

    logic [31:0] id_redirect_pc;
    logic        id_redirect_valid;
    logic        id_btb_update;
    logic [31:0] id_btb_update_pc;
    logic [31:0] id_btb_update_target;

    logic        id_use_rs1;
    logic        id_use_rs2;
    logic        id_is_branch;
    logic        id_is_jump;

    // --- ID/EX Register Outputs ---
    logic [31:0] id_ex_pc;
    logic [31:0] id_ex_rs1_val;
    logic [31:0] id_ex_rs2_val;
    logic [31:0] id_ex_imm;
    logic [4:0]  id_ex_rs1;
    logic [4:0]  id_ex_rs2;
    logic [4:0]  id_ex_rd;

    logic        id_ex_ctrl_valid;
    logic        id_ex_ctrl_bubble;
    logic        id_ex_ctrl_kill;
    logic        id_ex_ctrl_branch;
    logic        id_ex_ctrl_jump;
    logic        id_ex_ctrl_mem_read;
    logic        id_ex_ctrl_mem_write;
    logic [3:0]  id_ex_ctrl_alu_op;
    logic        id_ex_ctrl_wb_en;
    logic        id_ex_ctrl_mispred;
    logic [2:0]  id_ex_ctrl_funct3;
    logic [1:0]  id_ex_ctrl_op_a_sel;
    logic        id_ex_ctrl_op_b_sel;

    // --- EX Stage Outputs ---
    logic [31:0] ex_alu_result;
    logic [31:0] ex_store_data;

    // --- EX/MEM Register Outputs ---
    logic [31:0] ex_mem_pc;
    logic [31:0] ex_mem_alu_result;
    logic [31:0] ex_mem_store_data;
    logic [4:0]  ex_mem_rd;

    logic        ex_mem_ctrl_valid;
    logic        ex_mem_ctrl_bubble;
    logic        ex_mem_ctrl_kill;
    logic        ex_mem_ctrl_mem_read;
    logic        ex_mem_ctrl_mem_write;
    logic        ex_mem_ctrl_wb_en;
    logic        ex_mem_ctrl_mispred;
    logic        ex_mem_ctrl_is_control;
    logic [2:0]  ex_mem_ctrl_funct3;

    // --- MEM Stage Outputs ---
    logic [31:0] mem_dmem_rdata;
    logic [31:0] mem_io_rdata;
    logic [31:0] mem_rdata_muxed; // Muxed DMEM/IO data

    // --- MEM/WB Register Outputs ---
    logic [31:0] mem_wb_pc;
    logic [31:0] mem_wb_alu_result;
    logic [31:0] mem_wb_rdata; // From DMEM
    logic [4:0]  mem_wb_rd;

    logic        mem_wb_ctrl_valid;
    logic        mem_wb_ctrl_bubble;
    logic        mem_wb_ctrl_wb_en;
    logic        mem_wb_ctrl_mem_read;
    logic        mem_wb_ctrl_mispred;
    logic        mem_wb_ctrl_is_control;
    logic [2:0]  mem_wb_ctrl_funct3;

    // --- WB Stage Signals ---
    logic [31:0] wb_write_data;
    logic [31:0] wb_final_rdata; // Selected from DMEM or IO
    
    // --- HALT Detection ---
    logic r_halt;

    // ========================================================================
    // Module Instantiations
    // ========================================================================

    // ------------------------------------------------------------------------
    // Hazard Unit
    // ------------------------------------------------------------------------
    hazard_unit u_hazard_unit (
        .i_rs1(id_rs1),
        .i_rs2(id_rs2),
        .i_use_rs1(id_use_rs1),
        .i_use_rs2(id_use_rs2),
        .i_is_branch(id_is_branch),
        .i_is_jump(id_is_jump),
        .i_id_ex_rd(id_ex_rd),
        .i_id_ex_mem_read(id_ex_ctrl_mem_read),
        .i_id_ex_reg_write(id_ex_ctrl_wb_en),
        .i_ex_mem_rd(ex_mem_rd),
        .i_ex_mem_mem_read(ex_mem_ctrl_mem_read),
        .o_stall_if(hu_stall_if),
        .o_stall_id(hu_stall_id),
        .o_flush_id_ex(hu_flush_id_ex),
        .o_flush_if_id(hu_flush_if_id)
    );

    // ------------------------------------------------------------------------
    // Forwarding Unit
    // ------------------------------------------------------------------------
    forwarding_unit u_forwarding_unit (
        .i_id_ex_rs1(id_ex_rs1),
        .i_id_ex_rs2(id_ex_rs2),
        .i_id_rs1(id_rs1),
        .i_id_rs2(id_rs2),
        .i_ex_mem_rd(ex_mem_rd),
        .i_ex_mem_reg_write(ex_mem_ctrl_wb_en),
        .i_ex_mem_valid(ex_mem_ctrl_valid),
        .i_ex_mem_bubble(ex_mem_ctrl_bubble),
        .i_ex_mem_kill(ex_mem_ctrl_kill),
        .i_mem_wb_rd(mem_wb_rd),
        .i_mem_wb_reg_write(mem_wb_ctrl_wb_en),
        .i_mem_wb_valid(mem_wb_ctrl_valid),
        .i_mem_wb_bubble(mem_wb_ctrl_bubble),
        .o_forward_a_sel(fu_forward_a_sel),
        .o_forward_b_sel(fu_forward_b_sel),
        .o_forward_id_a_sel(fu_forward_id_a_sel),
        .o_forward_id_b_sel(fu_forward_id_b_sel)
    );

    // ------------------------------------------------------------------------
    // IF Stage
    // ------------------------------------------------------------------------
    stage_if u_stage_if (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_stall(hu_stall_if || r_halt),  // Stall IF when halted
        .i_flush(1'b0), // IF flush usually handled by redirect logic internally or via next PC
        .i_redirect_pc(id_redirect_pc),
        .i_redirect_valid(id_redirect_valid && !r_halt),  // No redirects when halted (stage_id now handles stall gating)
        .i_btb_update(id_btb_update && !r_halt),
        .i_btb_update_pc(id_btb_update_pc),
        .i_btb_update_target(id_btb_update_target),
        .o_imem_addr(if_imem_addr),
        .i_imem_rdata(imem_rdata),
        .o_pc(if_pc),
        .o_instr(if_instr),
        .o_pred_taken(if_pred_taken)
    );

    // IMEM Instantiation
    i_mem u_imem (
        .i_clk(i_clk),
        .i_addr(if_imem_addr), // Byte address
        .o_data(imem_rdata)
    );

    // ------------------------------------------------------------------------
    // IF/ID Register
    // ------------------------------------------------------------------------
    if_id_reg u_if_id_reg (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_stall(hu_stall_id || r_halt), // Stall ID means hold IF/ID, also stall when halted
        .i_flush((id_redirect_valid || hu_flush_if_id) && !r_halt), // Flush on mispredict (stage_id handles stall gating)
        .i_pc(if_pc),
        .i_instr(if_instr),
        .i_valid(1'b1), // Always valid from IF unless flush
        .i_pred_taken(if_pred_taken),
        .o_pc(if_id_pc),
        .o_instr(if_id_instr),
        .o_valid(if_id_valid),
        .o_pred_taken(if_id_pred_taken),
        .o_bubble(if_id_bubble),
        .o_kill(if_id_kill)
    );

    // ------------------------------------------------------------------------
    // ID Stage
    // ------------------------------------------------------------------------
    stage_id u_stage_id (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_stall(hu_stall_id),
        .i_flush(hu_flush_id_ex), // Flush ID means output 0s to ID/EX? No, flush input to stage_id is not standard.
                                  // stage_id doesn't have flush input that clears its state (RF is persistent).
                                  // The flush signal usually clears the pipeline register *after* the stage.
                                  // But stage_id has `i_flush` input in my code? Let's check.
                                  // Yes: `input logic i_flush`.
                                  // But looking at stage_id code, `i_flush` is not used!
                                  // It's fine. The flush happens at the register.
        .i_pc(if_id_pc),
        .i_instr(if_id_instr),
        .i_pred_taken(if_id_pred_taken),
        .i_wb_reg_write(mem_wb_ctrl_wb_en), // WB Stage
        .i_wb_rd(mem_wb_rd),                // WB Stage
        .i_wb_write_data(wb_write_data),    // WB Stage
        .i_forward_a_sel(fu_forward_id_a_sel),
        .i_forward_b_sel(fu_forward_id_b_sel),
        .i_ex_mem_alu_result(ex_mem_alu_result), // Forwarding from EX/MEM
        .o_pc(id_pc),
        .o_rs1_val(id_rs1_val),
        .o_rs2_val(id_rs2_val),
        .o_imm(id_imm),
        .o_rs1(id_rs1),
        .o_rs2(id_rs2),
        .o_rd(id_rd),
        .o_ctrl_valid(id_ctrl_valid),
        .o_ctrl_bubble(id_ctrl_bubble),
        .o_ctrl_kill(id_ctrl_kill),
        .o_ctrl_branch(id_ctrl_branch),
        .o_ctrl_jump(id_ctrl_jump),
        .o_ctrl_mem_read(id_ctrl_mem_read),
        .o_ctrl_mem_write(id_ctrl_mem_write),
        .o_ctrl_alu_op(id_ctrl_alu_op),
        .o_ctrl_wb_en(id_ctrl_wb_en),
        .o_ctrl_mispred(id_ctrl_mispred),
        .o_ctrl_funct3(id_ctrl_funct3),
        .o_ctrl_op_a_sel(id_ctrl_op_a_sel),
        .o_ctrl_op_b_sel(id_ctrl_op_b_sel),
        .o_redirect_pc(id_redirect_pc),
        .o_redirect_valid(id_redirect_valid),
        .o_btb_update(id_btb_update),
        .o_btb_update_pc(id_btb_update_pc),
        .o_btb_update_target(id_btb_update_target),
        .o_use_rs1(id_use_rs1),
        .o_use_rs2(id_use_rs2),
        .o_is_branch(id_is_branch),
        .o_is_jump(id_is_jump)
    );

    // ------------------------------------------------------------------------
    // ID/EX Register
    // ------------------------------------------------------------------------
    id_ex_reg u_id_ex_reg (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_stall(1'b0), // ID/EX must NOT stall - let producer advance while consumer held in ID
        .i_flush(hu_flush_id_ex), // Flush injects bubble when consumer stalls, enabling forwarding
        .i_pc(id_pc),
        .i_rs1_val(id_rs1_val),
        .i_rs2_val(id_rs2_val),
        .i_imm(id_imm),
        .i_rs1(id_rs1),
        .i_rs2(id_rs2),
        .i_rd(id_rd),
        .i_ctrl_valid(id_ctrl_valid),
        .i_ctrl_bubble(id_ctrl_bubble),
        .i_ctrl_kill(id_ctrl_kill),
        .i_ctrl_branch(id_ctrl_branch),
        .i_ctrl_jump(id_ctrl_jump),
        .i_ctrl_mem_read(id_ctrl_mem_read),
        .i_ctrl_mem_write(id_ctrl_mem_write),
        .i_ctrl_alu_op(id_ctrl_alu_op),
        .i_ctrl_wb_en(id_ctrl_wb_en),
        .i_ctrl_mispred(id_ctrl_mispred), // Mispred flag travels with branch instruction
        .i_ctrl_funct3(id_ctrl_funct3),
        .i_ctrl_op_a_sel(id_ctrl_op_a_sel),
        .i_ctrl_op_b_sel(id_ctrl_op_b_sel),
        .o_pc(id_ex_pc),
        .o_rs1_val(id_ex_rs1_val),
        .o_rs2_val(id_ex_rs2_val),
        .o_imm(id_ex_imm),
        .o_rs1(id_ex_rs1),
        .o_rs2(id_ex_rs2),
        .o_rd(id_ex_rd),
        .o_ctrl_valid(id_ex_ctrl_valid),
        .o_ctrl_bubble(id_ex_ctrl_bubble),
        .o_ctrl_kill(id_ex_ctrl_kill),
        .o_ctrl_branch(id_ex_ctrl_branch),
        .o_ctrl_jump(id_ex_ctrl_jump),
        .o_ctrl_mem_read(id_ex_ctrl_mem_read),
        .o_ctrl_mem_write(id_ex_ctrl_mem_write),
        .o_ctrl_alu_op(id_ex_ctrl_alu_op),
        .o_ctrl_wb_en(id_ex_ctrl_wb_en),
        .o_ctrl_mispred(id_ex_ctrl_mispred),
        .o_ctrl_funct3(id_ex_ctrl_funct3),
        .o_ctrl_op_a_sel(id_ex_ctrl_op_a_sel),
        .o_ctrl_op_b_sel(id_ex_ctrl_op_b_sel)
    );

    // ------------------------------------------------------------------------
    // EX Stage
    // ------------------------------------------------------------------------
    stage_ex u_stage_ex (
        .i_pc(id_ex_pc),
        .i_rs1_val(id_ex_rs1_val),
        .i_rs2_val(id_ex_rs2_val),
        .i_imm(id_ex_imm),
        .i_alu_op(id_ex_ctrl_alu_op),
        .i_op_a_sel(id_ex_ctrl_op_a_sel),
        .i_op_b_sel(id_ex_ctrl_op_b_sel),
        .i_forward_a_sel(fu_forward_a_sel),
        .i_forward_b_sel(fu_forward_b_sel),
        .i_ex_mem_alu_result(ex_mem_alu_result),
        .i_wb_write_data(wb_write_data),
        .o_alu_result(ex_alu_result),
        .o_store_data(ex_store_data)
    );

    // ------------------------------------------------------------------------
    // EX/MEM Register
    // ------------------------------------------------------------------------
    ex_mem_reg u_ex_mem_reg (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_stall(1'b0), // MEM stall?
        .i_flush(1'b0), // No flush in EX/MEM usually
        .i_pc(id_ex_pc),
        .i_alu_result(ex_alu_result),
        .i_store_data(ex_store_data),
        .i_rd(id_ex_rd),
        .i_ctrl_valid(id_ex_ctrl_valid),
        .i_ctrl_bubble(id_ex_ctrl_bubble),
        .i_ctrl_kill(id_ex_ctrl_kill),
        .i_ctrl_mem_read(id_ex_ctrl_mem_read),
        .i_ctrl_mem_write(id_ex_ctrl_mem_write),
        .i_ctrl_wb_en(id_ex_ctrl_wb_en),
        .i_ctrl_mispred(id_ex_ctrl_mispred),
        .i_ctrl_is_control(id_ex_ctrl_branch | id_ex_ctrl_jump),
        .i_ctrl_funct3(id_ex_ctrl_funct3),
        .o_pc(ex_mem_pc),
        .o_alu_result(ex_mem_alu_result),
        .o_store_data(ex_mem_store_data),
        .o_rd(ex_mem_rd),
        .o_ctrl_valid(ex_mem_ctrl_valid),
        .o_ctrl_bubble(ex_mem_ctrl_bubble),
        .o_ctrl_kill(ex_mem_ctrl_kill),
        .o_ctrl_mem_read(ex_mem_ctrl_mem_read),
        .o_ctrl_mem_write(ex_mem_ctrl_mem_write),
        .o_ctrl_wb_en(ex_mem_ctrl_wb_en),
        .o_ctrl_mispred(ex_mem_ctrl_mispred),
        .o_ctrl_is_control(ex_mem_ctrl_is_control),
        .o_ctrl_funct3(ex_mem_ctrl_funct3)
    );

    // ------------------------------------------------------------------------
    // MEM Stage
    // ------------------------------------------------------------------------
    stage_mem u_stage_mem (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_alu_result(ex_mem_alu_result),
        .i_store_data(ex_mem_store_data),
        .i_mem_write(ex_mem_ctrl_mem_write),
        .i_mem_read(ex_mem_ctrl_mem_read),
        .i_funct3(ex_mem_ctrl_funct3),
        .i_ctrl_kill(ex_mem_ctrl_kill),
        .i_ctrl_valid(ex_mem_ctrl_valid),
        .i_ctrl_bubble(ex_mem_ctrl_bubble),
        .i_io_sw(i_io_sw),
        .o_io_ledr(o_io_ledr),
        .o_io_ledg(o_io_ledg),
        .o_io_hex0(o_io_hex0),
        .o_io_hex1(o_io_hex1),
        .o_io_hex2(o_io_hex2),
        .o_io_hex3(o_io_hex3),
        .o_io_hex4(o_io_hex4),
        .o_io_hex5(o_io_hex5),
        .o_io_hex6(o_io_hex6),
        .o_io_hex7(o_io_hex7),
        .o_io_lcd(o_io_lcd),
        .o_dmem_rdata(mem_dmem_rdata),
        .o_io_rdata(mem_io_rdata)
    );

    // ------------------------------------------------------------------------
    // MEM/WB Register
    // ------------------------------------------------------------------------
    mem_wb_reg u_mem_wb_reg (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_stall(1'b0),
        .i_flush(1'b0),
        .i_pc(ex_mem_pc),
        .i_alu_result(ex_mem_alu_result),
        .i_rdata(mem_rdata_muxed), // Muxed DMEM/IO data
        .i_rd(ex_mem_rd),
        .i_ctrl_valid(ex_mem_ctrl_valid),
        .i_ctrl_bubble(ex_mem_ctrl_bubble),
        .i_ctrl_wb_en(ex_mem_ctrl_wb_en),
        .i_ctrl_mem_read(ex_mem_ctrl_mem_read),
        .i_ctrl_mispred(ex_mem_ctrl_mispred),
        .i_ctrl_is_control(ex_mem_ctrl_is_control),
        .i_ctrl_funct3(ex_mem_ctrl_funct3),
        .o_pc(mem_wb_pc),
        .o_alu_result(mem_wb_alu_result),
        .o_rdata(mem_wb_rdata),
        .o_rd(mem_wb_rd),
        .o_ctrl_valid(mem_wb_ctrl_valid),
        .o_ctrl_bubble(mem_wb_ctrl_bubble),
        .o_ctrl_wb_en(mem_wb_ctrl_wb_en),
        .o_ctrl_mem_read(mem_wb_ctrl_mem_read),
        .o_ctrl_mispred(mem_wb_ctrl_mispred),
        .o_ctrl_is_control(mem_wb_ctrl_is_control),
        .o_ctrl_funct3(mem_wb_ctrl_funct3)
    );

    // Mux for MEM/WB Input (DMEM vs IO)
    always_comb begin
        // Simple address check for IO range
        // IO Base is usually 0x1001xxxx or similar.
        // Let's check stage_mem.sv: `if (i_alu_result[31:16] == 16'h1001)`
        if (ex_mem_alu_result[31:16] == 16'h1001) begin
            mem_rdata_muxed = mem_io_rdata;
        end else begin
            mem_rdata_muxed = mem_dmem_rdata;
        end
    end

    // ------------------------------------------------------------------------
    // WB Stage Logic
    // ------------------------------------------------------------------------
    
    // Load Data Processing (Sign Extension)
    logic [31:0] wb_load_data;
    always_comb begin
        wb_load_data = mem_wb_rdata;
        case (mem_wb_ctrl_funct3)
            3'b000: wb_load_data = {{24{mem_wb_rdata[7]}}, mem_wb_rdata[7:0]};   // LB
            3'b001: wb_load_data = {{16{mem_wb_rdata[15]}}, mem_wb_rdata[15:0]}; // LH
            3'b010: wb_load_data = mem_wb_rdata;                                 // LW
            3'b100: wb_load_data = {24'b0, mem_wb_rdata[7:0]};                   // LBU
            3'b101: wb_load_data = {16'b0, mem_wb_rdata[15:0]};                  // LHU
            default: wb_load_data = mem_wb_rdata;
        endcase
    end
    
    // Final Write Back Mux
    // For JAL/JALR (control instructions that write back), write PC+4
    // For loads, write memory data
    // For ALU ops, write ALU result
    assign wb_write_data = mem_wb_ctrl_mem_read ? wb_load_data : 
                           (mem_wb_ctrl_is_control && mem_wb_ctrl_wb_en) ? (mem_wb_pc + 4) :
                           mem_wb_alu_result;

    // ========================================================================
    // HALT Detection (Section 1.9, 9.5.5)
    // ========================================================================
    // HALT occurs when a store commits to address 32'hFFFF_FFFC
    // Stores have ctrl_wb_en=0 but still commit (they are valid instructions)
    always_ff @(posedge i_clk) begin
        if (!i_reset) begin
            r_halt <= 1'b0;
        end else if (!r_halt && mem_wb_ctrl_valid && !mem_wb_ctrl_bubble && 
                     !mem_wb_ctrl_wb_en && !mem_wb_ctrl_mem_read && 
                     (mem_wb_alu_result == 32'hFFFF_FFFC)) begin
            r_halt <= 1'b1;
        end
    end
    
    // ========================================================================
    // Top-Level Output Assignments (Section 1.2)
    // ========================================================================
    // Model ID - hard-coded for MODEL_FWD_AT (Section 1.0.1)
    assign o_model_id = 4'd2;
    
    // PC outputs
    assign o_pc_frontend = if_pc;        // IF stage PC (Section 5.5.1)
    assign o_pc_commit = mem_wb_pc;      // WB commit PC (Section 9.5.1)
    
    // Commit interface
    assign o_insn_vld = mem_wb_ctrl_valid && !mem_wb_ctrl_bubble && !r_halt;
    assign o_ctrl = mem_wb_ctrl_is_control && !r_halt;
    assign o_mispred = mem_wb_ctrl_is_control && mem_wb_ctrl_valid && mem_wb_ctrl_mispred && !r_halt;
    assign o_halt = r_halt;

`ifndef SYNTHESIS
    // ========================================================================
    // DEBUG: Simple commit trace
    // ========================================================================
    
    logic r_halt_prev;
    always @(posedge i_clk) begin
      if (i_reset) begin
        r_halt_prev <= 1'b0;
      end else begin
        r_halt_prev <= r_halt;
      end
    end
    
    // Simple commit trace
    always @(posedge i_clk) begin
      if (o_insn_vld && !r_halt) begin
        $display("[%0t] COMMIT pc=0x%h", $time, o_pc_commit);
      end
      if (r_halt && !r_halt_prev) begin
        $display("[%0t] ===== HALT DETECTED ===== (PC=0x%h)", $time, o_pc_commit);
      end
      if (o_pc_commit == 32'h000000e4) begin
        $display("[%0t] COMMIT PC=0xe4 (SW to HALT addr): r_halt=%b alu_result=0x%h wb_en=%b mem_read=%b", 
                 $time, r_halt, mem_wb_alu_result, mem_wb_ctrl_wb_en, mem_wb_ctrl_mem_read);
      end
      if (id_redirect_valid && !r_halt) begin
        $display("[%0t] REDIRECT: from PC=0x%h to PC=0x%h", $time, if_id_pc, id_redirect_pc);
      end
      // Debug: check PC 0x04 (JAL)
      if (if_id_pc == 32'h00000004) begin
        $display("[%0t] IF/ID PC=0x04: instr=0x%h valid=%b bubble=%b", 
                 $time, if_id_instr, id_ctrl_valid, id_ctrl_bubble);
        $display("[%0t] ID PC=0x04: jump=%b branch=%b pred_taken=%b redirect_valid=%b", 
                 $time, id_ctrl_jump, id_ctrl_branch, if_id_pred_taken, id_redirect_valid);
      end
    end

    // ========================================================================
    // DEBUG: Critical Pipeline Checks
    // ========================================================================
    
    // Check 1: Detect "commit bubble" at WB (critical)
    always @(posedge i_clk) begin
        if (o_insn_vld && mem_wb_ctrl_bubble) begin
            $display("ERROR @%0t: o_insn_vld=1 but MEM/WB is a BUBBLE (pc=%h)",
                     $time, o_pc_commit);
        end
    end

    // Check 2: Detect illegal combo: valid=1 AND bubble=1
    always @(posedge i_clk) begin
        if (mem_wb_ctrl_valid && mem_wb_ctrl_bubble) begin
            $display("ERROR @%0t: MEM/WB ctrl_valid=1 but ctrl_bubble=1 (pc=%h)",
                     $time, o_pc_commit);
        end
        
        if (id_ex_ctrl_valid && id_ex_ctrl_bubble) begin
            $display("ERROR @%0t: ID/EX valid=1 but bubble=1 (pc=%h)", 
                     $time, id_ex_pc);
        end
        
        if (ex_mem_ctrl_valid && ex_mem_ctrl_bubble) begin
            $display("ERROR @%0t: EX/MEM valid=1 but bubble=1 (pc=%h)", 
                     $time, ex_mem_pc);
        end
    end

    // Removed PC 0x18 debug - no longer needed

    // Check 4: Detect incorrect stall behavior (pipeline registers not holding)
    reg [31:0] prev_id_pc;
    reg        prev_id_ctrl_valid;
    reg        prev_stall_id;

    always @(posedge i_clk) begin
        if (!i_reset) begin
            prev_id_pc         <= 0;
            prev_id_ctrl_valid <= 0;
            prev_stall_id      <= 0;
        end else begin
            if (prev_stall_id) begin  // Check if stall was ACTIVE in previous cycle
                if (id_pc != prev_id_pc || id_ctrl_valid != prev_id_ctrl_valid) begin
                    $display("ERROR @%0t: stall_id=1 but ID did NOT HOLD (pc=%h->%h valid=%b->%b)",
                             $time, prev_id_pc, id_pc,
                             prev_id_ctrl_valid, id_ctrl_valid);
                end
            end
            
            prev_id_pc         <= id_pc;
            prev_id_ctrl_valid <= id_ctrl_valid;
            prev_stall_id      <= hu_stall_id;
        end
    end

    // Check 5: Track when stalls occur
    always @(posedge i_clk) begin
        if (hu_stall_id && i_reset) begin
            $display("INFO @%0t: stall_id=1 (ID/EX must HOLD)", $time);
        end
        
        if (hu_stall_if && i_reset) begin
            $display("INFO @%0t: stall_if=1 (PC & IF/ID must HOLD)", $time);
        end
    end

    // Check 6: Detect illegal write to x0 (RISC-V rule)
    always @(posedge i_clk) begin
        if (mem_wb_ctrl_wb_en && mem_wb_rd == 5'd0) begin
            $display("ERROR @%0t: Write to x0 detected! (rd=%d data=%h pc=%h)",
                     $time, mem_wb_rd, mem_wb_alu_result, mem_wb_pc);
        end
    end
`endif

endmodule

`endif // PIPELINED_SV
