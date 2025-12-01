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

    always_ff @(posedge i_clk) begin
        if (!i_reset) begin
            o_pc <= 32'b0;
            o_instr <= 32'b0;
            o_valid <= 1'b0;
            o_pred_taken <= 1'b0;
            o_bubble <= 1'b0;
            o_kill <= 1'b0;
        end else if (i_flush) begin
            o_pc     <= 32'b0;
            o_instr  <= 32'b0;
            o_valid  <= 1'b0;
            o_pred_taken <= 1'b0;
            o_bubble <= 1'b1;
            o_kill   <= 1'b0;
        end else if (i_stall) begin
            // Hold previous value
        end else begin
            o_pc     <= i_pc;
            o_instr  <= i_instr;
            o_valid  <= i_valid;
            o_pred_taken <= i_pred_taken;
            o_bubble <= 1'b0; // Normal operation
            o_kill   <= 1'b0;
        end
    end

endmodule
