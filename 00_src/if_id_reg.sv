module if_id_reg (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic        i_stall,
    input  logic        i_flush,
    input  logic [31:0] i_pc,
    input  logic [31:0] i_instr,
    input  logic        i_valid, // From IF (usually 1 unless flush/stall logic upstream says otherwise)
    input  logic        i_pred_taken, // 1 if IF predicted taken (BTB hit)
    
    output logic [31:0] o_pc,
    output logic [31:0] o_instr,
    output logic        o_valid,
    output logic        o_pred_taken,
    output logic        o_bubble,
    output logic        o_kill
);

    // ===========================================================================
    // Standard Pipeline Register - ALL signals use Flip-Flops
    // ===========================================================================
    // This register implements standard pipeline behavior with flip-flops for
    // ALL outputs including o_instr. This is crucial to break combinational
    // loops between the ID stage's flush/redirect logic and instruction decode.
    //
    // Architecture with Synchronous i_mem:
    //   Cycle 0:   Reset, r_pc = -4
    //   Cycle 1:   r_pc = 0, pc_next = 4, i_mem reads addr 4 (pre-fetch)
    //   Cycle 2:   r_pc = 4, i_mem outputs instr@4, if_id_reg samples it
    //   Cycle 3:   Instruction@4 available at if_id_reg output to ID stage
    //
    // The pre-fetch in stage_if (using pc_next) compensates for i_mem's 1-cycle
    // latency. This register's flip-flops break any combinational feedback from
    // ID stage (redirect/flush signals) back to instruction decode path.
    // ===========================================================================

    always_ff @(posedge i_clk) begin
        if (!i_reset) begin
            o_pc         <= 32'b0;
            o_instr      <= 32'h00000013;  // NOP (addi x0, x0, 0)
            o_valid      <= 1'b0;
            o_pred_taken <= 1'b0;
            o_bubble     <= 1'b0;
            o_kill       <= 1'b0;
        end else if (i_flush) begin
            // Flush: Insert NOP bubble into pipeline
            o_pc         <= 32'b0;
            o_instr      <= 32'h00000013;  // NOP
            o_valid      <= 1'b0;
            o_pred_taken <= 1'b0;
            o_bubble     <= 1'b1;
            o_kill       <= 1'b0;
        end else if (i_stall) begin
            // Stall: Hold all previous values
            o_pc         <= o_pc;
            o_instr      <= o_instr;
            o_valid      <= o_valid;
            o_pred_taken <= o_pred_taken;
            o_bubble     <= o_bubble;
            o_kill       <= o_kill;
        end else begin
            // Normal operation: Register all inputs
            o_pc         <= i_pc;
            o_instr      <= i_instr;
            o_valid      <= i_valid;
            o_pred_taken <= i_pred_taken;
            o_bubble     <= 1'b0;
            o_kill       <= 1'b0;
        end
    end

endmodule
