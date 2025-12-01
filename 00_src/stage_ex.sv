module stage_ex (
    // Inputs from ID/EX
    input  logic [31:0] i_pc,
    input  logic [31:0] i_rs1_val,
    input  logic [31:0] i_rs2_val,
    input  logic [31:0] i_imm,
    input  logic [3:0]  i_alu_op,
    input  logic [1:0]  i_op_a_sel,
    input  logic        i_op_b_sel,

    // Forwarding Inputs
    input  logic [1:0]  i_forward_a_sel, // 00:RF, 01:WB, 10:EX/MEM
    input  logic [1:0]  i_forward_b_sel,
    input  logic [31:0] i_ex_mem_alu_result,
    input  logic [31:0] i_wb_write_data,

    // Outputs to EX/MEM
    output logic [31:0] o_alu_result,
    output logic [31:0] o_store_data
);

    logic [31:0] rs1_fwd;
    logic [31:0] rs2_fwd;
    logic [31:0] op_a;
    logic [31:0] op_b;

    // Forwarding Muxes
    always_comb begin
        case (i_forward_a_sel)
            2'b00: rs1_fwd = i_rs1_val;
            2'b01: rs1_fwd = i_wb_write_data;
            2'b10: rs1_fwd = i_ex_mem_alu_result;
            default: rs1_fwd = i_rs1_val;
        endcase

        case (i_forward_b_sel)
            2'b00: rs2_fwd = i_rs2_val;
            2'b01: rs2_fwd = i_wb_write_data;
            2'b10: rs2_fwd = i_ex_mem_alu_result;
            default: rs2_fwd = i_rs2_val;
        endcase

`ifndef SYNTHESIS
        // Debug X-values in rs2 forwarding (simulation only)
        if ($isunknown(rs2_fwd)) begin
            $display("EX STAGE X @%0t: fwd_b_sel=%b rs2_val=%h wb_data=%h ex_mem_alu=%h -> rs2_fwd=%h",
                     $time, i_forward_b_sel, i_rs2_val, i_wb_write_data, i_ex_mem_alu_result, rs2_fwd);
        end
`endif
    end

    // Operand Muxes
    always_comb begin
        case (i_op_a_sel)
            2'b00: op_a = rs1_fwd;
            2'b01: op_a = i_pc;
            2'b10: op_a = 32'b0; // Zero
            default: op_a = rs1_fwd;
        endcase

        case (i_op_b_sel)
            1'b0: op_b = rs2_fwd;
            1'b1: op_b = i_imm;
        endcase
    end

    // ALU
    alu ex_alu (
        .i_op_a(op_a),
        .i_op_b(op_b),
        .i_alu_op(i_alu_op),
        .o_alu_data(o_alu_result)
    );

    // Store Data (Forwarded rs2)
    assign o_store_data = rs2_fwd;

endmodule
