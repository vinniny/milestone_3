module id_ex_reg (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic        i_stall,
    input  logic        i_flush,

    // Data Inputs
    input  logic [31:0] i_pc,
    input  logic [31:0] i_rs1_val,
    input  logic [31:0] i_rs2_val,
    input  logic [31:0] i_imm,
    input  logic [4:0]  i_rs1,
    input  logic [4:0]  i_rs2,
    input  logic [4:0]  i_rd,

    // Control Inputs
    input  logic        i_ctrl_valid,
    input  logic        i_ctrl_bubble,
    input  logic        i_ctrl_kill,
    input  logic        i_ctrl_branch,
    input  logic        i_ctrl_jump,
    input  logic        i_ctrl_mem_read,
    input  logic        i_ctrl_mem_write,
    input  logic [3:0]  i_ctrl_alu_op,
    input  logic        i_ctrl_wb_en,
    input  logic        i_ctrl_mispred,
    input  logic [2:0]  i_ctrl_funct3,
    input  logic [1:0]  i_ctrl_op_a_sel, // 00: rs1, 01: pc, 10: zero
    input  logic        i_ctrl_op_b_sel, // 0: rs2, 1: imm

    // Data Outputs
    output logic [31:0] o_pc,
    output logic [31:0] o_rs1_val,
    output logic [31:0] o_rs2_val,
    output logic [31:0] o_imm,
    output logic [4:0]  o_rs1,
    output logic [4:0]  o_rs2,
    output logic [4:0]  o_rd,

    // Control Outputs
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
    output logic        o_ctrl_op_b_sel
);

    always @(posedge i_clk) begin
        if (!i_reset) begin
            o_pc <= 32'b0;
            o_rs1_val <= 32'b0;
            o_rs2_val <= 32'b0;
            o_imm <= 32'b0;
            o_rs1 <= 5'b0;
            o_rs2 <= 5'b0;
            o_rd <= 5'b0;
            
            o_ctrl_valid <= 1'b0;
            o_ctrl_bubble <= 1'b0;
            o_ctrl_kill <= 1'b0;
            o_ctrl_branch <= 1'b0;
            o_ctrl_jump <= 1'b0;
            o_ctrl_mem_read <= 1'b0;
            o_ctrl_mem_write <= 1'b0;
            o_ctrl_alu_op <= 4'b0;
            o_ctrl_wb_en <= 1'b0;
            o_ctrl_mispred <= 1'b0;
            o_ctrl_funct3 <= 3'b0;
            o_ctrl_op_a_sel <= 2'b0;
            o_ctrl_op_b_sel <= 1'b0;
        end else if (i_flush) begin
            // Flush: bubble
            o_ctrl_valid     <= 1'b0;
            o_ctrl_bubble    <= 1'b1;
            o_ctrl_kill      <= 1'b0;
            
            // Zero side-effecting fields
            o_ctrl_branch    <= 1'b0;
            o_ctrl_jump      <= 1'b0;
            o_ctrl_mem_read  <= 1'b0;
            o_ctrl_mem_write <= 1'b0;
            o_ctrl_wb_en     <= 1'b0;
            o_ctrl_mispred   <= 1'b0;
            
            // Others can be anything, but zeroing is safer
            o_pc             <= 32'b0;
            o_rs1_val        <= 32'b0;
            o_rs2_val        <= 32'b0;
            o_imm            <= 32'b0;
            o_rs1            <= 5'b0;
            o_rs2            <= 5'b0;
            o_rd             <= 5'b0;
            o_ctrl_alu_op    <= 4'b0;
            o_ctrl_funct3    <= 3'b0;
            o_ctrl_op_a_sel  <= 2'b0;
            o_ctrl_op_b_sel  <= 1'b0;
        end else if (i_stall) begin
            // Hold
        end else begin
            o_pc             <= i_pc;
            
            // Defense-in-depth: zero register values on bubble
            if (i_ctrl_bubble) begin
                o_rs1_val    <= 32'b0;
                o_rs2_val    <= 32'b0;
            end else begin
                o_rs1_val    <= i_rs1_val;
                o_rs2_val    <= i_rs2_val;
            end
            
            o_imm            <= i_imm;
            o_rs1            <= i_rs1;
            o_rs2            <= i_rs2;
            o_rd             <= i_rd;
            
            o_ctrl_valid     <= i_ctrl_valid;
            o_ctrl_bubble    <= i_ctrl_bubble;
            o_ctrl_kill      <= i_ctrl_kill;
            o_ctrl_branch    <= i_ctrl_branch;
            o_ctrl_jump      <= i_ctrl_jump;
            o_ctrl_mem_read  <= i_ctrl_mem_read;
            o_ctrl_mem_write <= i_ctrl_mem_write;
            o_ctrl_alu_op    <= i_ctrl_alu_op;
            o_ctrl_wb_en     <= i_ctrl_wb_en;
            o_ctrl_mispred   <= i_ctrl_mispred;
            o_ctrl_funct3    <= i_ctrl_funct3;
            o_ctrl_op_a_sel  <= i_ctrl_op_a_sel;
            o_ctrl_op_b_sel  <= i_ctrl_op_b_sel;
        end
    end

endmodule
