module stage_id (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic        i_stall,
    input  logic        i_flush,

    // Inputs from IF/ID
    input  logic [31:0] i_pc,
    input  logic [31:0] i_instr,
    input  logic        i_pred_taken, // From IF (BTB hit)

    // Inputs from WB (Register Write)
    input  logic        i_wb_reg_write,
    input  logic [4:0]  i_wb_rd,
    input  logic [31:0] i_wb_write_data,

    // Forwarding Inputs
    input  logic [1:0]  i_forward_a_sel, // 00:RF, 01:WB, 10:EX/MEM
    input  logic [1:0]  i_forward_b_sel,
    input  logic [31:0] i_ex_mem_alu_result, // For forwarding from EX/MEM

    // Outputs to ID/EX
    output logic [31:0] o_pc,
    output logic [31:0] o_rs1_val,
    output logic [31:0] o_rs2_val,
    output logic [31:0] o_imm,
    output logic [4:0]  o_rs1,
    output logic [4:0]  o_rs2,
    output logic [4:0]  o_rd,
    
    // Control Bundle Output
    output logic        o_ctrl_valid,
    output logic        o_ctrl_bubble,
    output logic        o_ctrl_kill,
    output logic        o_ctrl_branch,
    output logic        o_ctrl_jump,
    output logic        o_ctrl_mem_read,
    output logic        o_ctrl_mem_write,
    output logic [3:0]  o_ctrl_alu_op,
    output logic        o_ctrl_wb_en,
    output logic        o_ctrl_mispred,
    output logic [2:0]  o_ctrl_funct3,
    output logic [1:0]  o_ctrl_op_a_sel,
    output logic        o_ctrl_op_b_sel,

    // Outputs to IF (Redirect/BTB)
    output logic [31:0] o_redirect_pc,
    output logic        o_redirect_valid,
    output logic        o_btb_update,
    output logic [31:0] o_btb_update_pc,
    output logic [31:0] o_btb_update_target,

    // Outputs to HDU
    output logic        o_use_rs1, // Need to derive this?
    output logic        o_use_rs2,
    output logic        o_is_branch,
    output logic        o_is_jump
);

    // Internal Signals
    logic [31:0] rs1_data_rf, rs2_data_rf;
    logic [31:0] rs1_data_fwd, rs2_data_fwd;
    logic [31:0] imm;
    logic        br_less, br_equal, br_un;
    logic        branch_taken; // Actual outcome
    logic        mispredict;
    logic [31:0] target_pc;
    logic [31:0] jalr_target_pc;
    logic [31:0] final_target_pc;
    
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rs1, rs2, rd;

    assign opcode = i_instr[6:0];
    assign funct3 = i_instr[14:12];
    assign funct7 = i_instr[31:25];
    assign rs1    = i_instr[19:15];
    assign rs2    = i_instr[24:20];
    assign rd     = i_instr[11:7];

    // Register File
    regfile rf (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_rs1_addr(rs1),
        .i_rs2_addr(rs2),
        .i_rd_addr(i_wb_rd),
        .i_rd_data(i_wb_write_data),
        .i_rd_wren(i_wb_reg_write),
        .o_rs1_data(rs1_data_rf),
        .o_rs2_data(rs2_data_rf)
    );

    // Forwarding Muxes (Branch Only)
    always @(*) begin
        case (i_forward_a_sel)
            2'b00: rs1_data_fwd = rs1_data_rf;
            2'b01: rs1_data_fwd = i_wb_write_data; // MEM/WB
            2'b10: rs1_data_fwd = i_ex_mem_alu_result; // EX/MEM
            default: rs1_data_fwd = rs1_data_rf;
        endcase
        
        case (i_forward_b_sel)
            2'b00: rs2_data_fwd = rs2_data_rf;
            2'b01: rs2_data_fwd = i_wb_write_data;
            2'b10: rs2_data_fwd = i_ex_mem_alu_result;
            default: rs2_data_fwd = rs2_data_rf;
        endcase
    end

    // Branch Comparator
    brc br_cmp (
        .i_rs1_data(rs1_data_fwd),
        .i_rs2_data(rs2_data_fwd),
        .i_br_un(br_un), // From Control Unit
        .o_br_less(br_less),
        .o_br_equal(br_equal)
    );

    // Control Unit
    logic ctrl_pc_sel; // This is branch_taken
    logic [1:0] ctrl_wb_sel; // Not used directly in ID/EX, but needed to derive wb_en?
    // Wait, control_unit outputs o_rd_wren (wb_en).
    
    control_unit ctrl (
        .i_instr(i_instr),
        .i_br_less(br_less),
        .i_br_equal(br_equal),
        .o_br_un(br_un),
        .o_rd_wren(o_ctrl_wb_en),
        .o_mem_wren(o_ctrl_mem_write),
        .o_wb_sel(ctrl_wb_sel), // 00=ALU, 01=MEM, 10=PC+4
        .o_pc_sel(ctrl_pc_sel), // 1 if Taken
        .o_opa_sel(o_ctrl_op_a_sel), // 00=rs1, 01=PC, 10=zero
        .o_opb_sel(o_ctrl_op_b_sel),
        .o_insn_vld(o_ctrl_valid),
        .o_alu_op(o_ctrl_alu_op)
    );
    
    // Fix opa_sel mapping
    // logic [1:0] cu_opa_sel;
    // assign cu_opa_sel = ctrl.o_opa_sel; // Access internal signal? No, I need to connect it.
    // I'll reconnect control_unit properly.

    // Immediate Generator
    imm_gen ig (
        .i_instr(i_instr),
        .o_imm_out(imm)
    );

    // Branch Target Calculation
    // Target = PC + Imm (Branch/JAL) or RS1 + Imm (JALR)
    logic [31:0] target_base;
    assign target_base = (opcode == 7'b1100111) ? rs1_data_fwd : i_pc; // JALR uses RS1
    
    logic cout_dummy;
    FA_32bit target_adder (
        .A(target_base),
        .B(imm),
        .Cin(1'b0),
        .Sum(target_pc),
        .Cout(cout_dummy)
    );
    
    assign jalr_target_pc = target_pc & 32'hFFFFFFFE;
    assign final_target_pc = (opcode == 7'b1100111) ? jalr_target_pc : target_pc;

    // Mispredict Logic for Model 2 (Always-Taken)
    // Only conditional branches can mispredict
    // Model 2 predicts TAKEN if BTB hits, NOT-TAKEN if BTB misses
    // Misprediction occurs when actual outcome differs from BTB prediction
    logic is_cond_branch;
    logic actual_taken;
    logic s_is_mispredict;
    
    assign is_cond_branch = (opcode == 7'b1100011); // Branch opcode
    // Use the ACTUAL prediction from IF (BTB hit status), not hard-coded 1
    // i_pred_taken reflects whether BTB predicted this branch as taken
    assign actual_taken = ctrl_pc_sel; // Actual branch outcome from branch comparator
    
    // Misprediction detection:
    // - Only for conditional branches (NOT for JAL/JALR)
    // - Compare actual outcome with BTB prediction (i_pred_taken)
    // - Mispred signal: only assert when NOT stalled
    assign s_is_mispredict = !i_stall && is_cond_branch && (i_pred_taken != actual_taken);
    
    // Redirect logic: CRITICAL - suppress branch resolution during stalls
    always @(*) begin
        o_redirect_pc = 32'b0;
        mispredict = 1'b0;
        
        // Rule: branch SHALL NOT resolve when stall_id=1
        if (i_stall) begin
            mispredict = 1'b0;
            // o_redirect_pc remains 0, no redirect this cycle
        end else if (is_cond_branch) begin
            // Model 2: compare actual outcome with BTB prediction
            if (i_pred_taken != actual_taken) begin
                // Misprediction!
                mispredict = 1'b1;
                if (actual_taken) begin
                    // Predicted NOT-TAKEN (BTB miss), actually TAKEN
                    // Redirect to branch target
                    o_redirect_pc = final_target_pc;
                end else begin
                    // Predicted TAKEN (BTB hit), actually NOT-TAKEN
                    // Redirect to PC+4 (sequential path)
                    o_redirect_pc = i_pc + 4;
                end
            end
            // else: prediction correct, no redirect needed
        end else if ((opcode == 7'b1101111) || (opcode == 7'b1100111)) begin
            // JAL/JALR - unconditional jumps, always redirect
            mispredict = 1'b0; // JAL/JALR never count as mispredicts
            o_redirect_pc = final_target_pc;
        end
    end

    // Per Milestone-3 Spec 6.8.3: Invalid instructions do NOT redirect
    // Only valid branches/jumps can trigger redirects
    assign o_redirect_valid = o_ctrl_valid && !i_stall && (mispredict || (opcode == 7'b1101111) || (opcode == 7'b1100111));
    
    // BTB Update - only update for valid branch/jump instructions
    // Update if Branch/Jump is Taken
    assign o_btb_update = o_ctrl_valid && (actual_taken | ((opcode == 7'b1101111) || (opcode == 7'b1100111)));
    assign o_btb_update_pc = i_pc;
    assign o_btb_update_target = final_target_pc;

    // Outputs to ID/EX
    assign o_pc = i_pc;
    assign o_rs1_val = rs1_data_fwd; // Use forwarded value!
    assign o_rs2_val = rs2_data_fwd;
    assign o_imm = imm;
    assign o_rs1 = rs1;
    assign o_rs2 = rs2;
    assign o_rd = rd;
    
    // Control Outputs
    assign o_ctrl_bubble = !o_ctrl_valid; // If invalid, it's a bubble
    // Per Milestone-3 Spec 6.8.3: Invalid/illegal instructions set ctrl_kill=1
    // This turns them into bubbles WITHOUT triggering flush/redirect
    assign o_ctrl_kill = !o_ctrl_valid; // Kill invalid instructions (X or illegal opcode)
    assign o_ctrl_branch = (opcode == 7'b1100011); // Branch opcode (conditional)
    assign o_ctrl_jump = (opcode == 7'b1101111) || (opcode == 7'b1100111); // JAL or JALR
    assign o_ctrl_mispred = s_is_mispredict; // Misprediction flag (conditional branches only)
    assign o_ctrl_mem_read = (opcode == 7'b0000011); // Load
    // o_ctrl_mem_write is from control_unit
    // o_ctrl_alu_op is from control_unit
    // o_ctrl_wb_en is from control_unit
    assign o_ctrl_funct3 = funct3;
    
    // Op A Sel: 0=rs1, 1=PC.
    // control_unit: 00=rs1, 01=PC, 10=Zero.
    // I need to handle Zero.
    // If LUI (10), I can pass PC (01) and handle it in EX? No.
    // I'll map 10 -> 0 (rs1) and ensure rs1_val is 0?
    // Or I'll change ID/EX to 2 bits.
    // I'll change ID/EX to 2 bits. It's safer.
    
    // Op B Sel: 0=rs2, 1=imm. Matches.
    
    // HDU Outputs
    assign o_use_rs1 = (opcode != 7'b0110111) && (opcode != 7'b0010111) && (opcode != 7'b1101111); // LUI, AUIPC, JAL don't use rs1
    assign o_use_rs2 = (opcode == 7'b0110011) || (opcode == 7'b1100011) || (opcode == 7'b0100011); // R-type, Branch, Store use rs2
    assign o_is_branch = (opcode == 7'b1100011);
    assign o_is_jump = (opcode == 7'b1101111) || (opcode == 7'b1100111);

endmodule
