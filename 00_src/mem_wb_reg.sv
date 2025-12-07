module mem_wb_reg (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic        i_stall,
    input  logic        i_flush,

    // Data Inputs
    input  logic [31:0] i_pc,
    input  logic [31:0] i_alu_result,
    input  logic [31:0] i_rdata, // From DMEM
    input  logic [4:0]  i_rd,

    // Control Inputs
    input  logic        i_ctrl_valid,
    input  logic        i_ctrl_bubble,
    input  logic        i_ctrl_wb_en,
    input  logic        i_ctrl_mem_read, // To know if we need to use rdata or alu_result
    input  logic        i_ctrl_mispred,
    input  logic        i_ctrl_is_control,
    input  logic [2:0]  i_ctrl_funct3,   // For load sign extension

    // Data Outputs
    output logic [31:0] o_pc,
    output logic [31:0] o_alu_result,
    output logic [31:0] o_rdata,
    output logic [4:0]  o_rd,

    // Control Outputs
    output logic        o_ctrl_valid,
    output logic        o_ctrl_bubble,
    output logic        o_ctrl_wb_en,
    output logic        o_ctrl_mem_read,
    output logic        o_ctrl_mispred,
    output logic        o_ctrl_is_control,
    output logic [2:0]  o_ctrl_funct3
);

    // Pass-through rdata (dmem output is already synchronous, no need for double-latency)
    assign o_rdata = i_rdata;

    always @(posedge i_clk) begin
        if (!i_reset) begin
            o_pc <= 32'b0;
            o_alu_result <= 32'b0;
            // o_rdata is pass-through (assigned combinationally)
            o_rd <= 5'b0;
            
            o_ctrl_valid <= 1'b0;
            o_ctrl_bubble <= 1'b0;
            o_ctrl_wb_en <= 1'b0;
            o_ctrl_mem_read <= 1'b0;
            o_ctrl_mispred <= 1'b0;
            o_ctrl_is_control <= 1'b0;
            o_ctrl_funct3 <= 3'b0;
        end else if (i_flush) begin
            o_ctrl_valid     <= 1'b0;
            o_ctrl_bubble    <= 1'b1;
            o_ctrl_wb_en     <= 1'b0;
            o_ctrl_mem_read  <= 1'b0;
            o_ctrl_mispred   <= 1'b0;
            o_ctrl_is_control<= 1'b0;
            o_ctrl_funct3    <= 3'b0;
            
            o_pc             <= 32'b0;
            o_alu_result     <= 32'b0;
            // o_rdata is pass-through (assigned combinationally)
            o_rd             <= 5'b0;
        end else if (i_stall) begin
            // Hold
        end else begin
            o_pc             <= i_pc;
            o_alu_result     <= i_alu_result;
            // o_rdata is pass-through (assigned combinationally)
            o_rd             <= i_rd;
            
            o_ctrl_valid     <= i_ctrl_valid;
            o_ctrl_bubble    <= i_ctrl_bubble;
            o_ctrl_wb_en     <= i_ctrl_wb_en;
            o_ctrl_mem_read  <= i_ctrl_mem_read;
            o_ctrl_mispred   <= i_ctrl_mispred;
            o_ctrl_is_control<= i_ctrl_is_control;
            o_ctrl_funct3    <= i_ctrl_funct3;
        end
    end

endmodule
