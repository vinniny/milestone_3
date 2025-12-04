module forwarding_unit (
    // EX Stage Forwarding Inputs
    input  logic [4:0]  i_id_ex_rs1,
    input  logic [4:0]  i_id_ex_rs2,
    
    // ID Stage Forwarding Inputs
    input  logic [4:0]  i_id_rs1,
    input  logic [4:0]  i_id_rs2,

    // Pipeline State Inputs
    input  logic [4:0]  i_ex_mem_rd,
    input  logic        i_ex_mem_reg_write,
    input  logic        i_ex_mem_valid,
    input  logic        i_ex_mem_bubble,
    input  logic        i_ex_mem_kill,
    input  logic [4:0]  i_mem_wb_rd,
    input  logic        i_mem_wb_reg_write,
    input  logic        i_mem_wb_valid,
    input  logic        i_mem_wb_bubble,

    // Outputs
    output logic [1:0]  o_forward_a_sel,    // For EX stage ALU Op A
    output logic [1:0]  o_forward_b_sel,    // For EX stage ALU Op B
    output logic [1:0]  o_forward_id_a_sel, // For ID stage Branch Op A
    output logic [1:0]  o_forward_id_b_sel  // For ID stage Branch Op B
);

    // Forwarding Validity Checks
    // Only forward from stages holding valid, non-bubble, non-killed instructions
    logic can_fwd_ex_mem;
    logic can_fwd_mem_wb;
    
    assign can_fwd_ex_mem = i_ex_mem_valid 
                         && !i_ex_mem_bubble 
                         && !i_ex_mem_kill
                         && i_ex_mem_reg_write
                         && (i_ex_mem_rd != 5'd0);
    
    assign can_fwd_mem_wb = i_mem_wb_valid
                         && !i_mem_wb_bubble
                         && i_mem_wb_reg_write
                         && (i_mem_wb_rd != 5'd0);

    // EX Forwarding Logic
    always @(*) begin
        o_forward_a_sel = 2'b00; // Default: RF
        
        // Priority: EX/MEM > MEM/WB
        if (can_fwd_ex_mem && (i_ex_mem_rd == i_id_ex_rs1)) begin
            o_forward_a_sel = 2'b10; // EX/MEM
        end else if (can_fwd_mem_wb && (i_mem_wb_rd == i_id_ex_rs1)) begin
            o_forward_a_sel = 2'b01; // MEM/WB
        end
    end

    always @(*) begin
        o_forward_b_sel = 2'b00; // Default: RF
        
        if (can_fwd_ex_mem && (i_ex_mem_rd == i_id_ex_rs2)) begin
            o_forward_b_sel = 2'b10; // EX/MEM
        end else if (can_fwd_mem_wb && (i_mem_wb_rd == i_id_ex_rs2)) begin
            o_forward_b_sel = 2'b01; // MEM/WB
        end
    end

    // ID Forwarding Logic (For Branch Comparator)
    always @(*) begin
        o_forward_id_a_sel = 2'b00; // Default: RF
        
        // Priority: EX/MEM > MEM/WB
        if (can_fwd_ex_mem && (i_ex_mem_rd == i_id_rs1)) begin
            o_forward_id_a_sel = 2'b10; // EX/MEM
        end else if (can_fwd_mem_wb && (i_mem_wb_rd == i_id_rs1)) begin
            o_forward_id_a_sel = 2'b01; // MEM/WB
        end
    end

    always @(*) begin
        o_forward_id_b_sel = 2'b00; // Default: RF
        
        if (can_fwd_ex_mem && (i_ex_mem_rd == i_id_rs2)) begin
            o_forward_id_b_sel = 2'b10; // EX/MEM
        end else if (can_fwd_mem_wb && (i_mem_wb_rd == i_id_rs2)) begin
            o_forward_id_b_sel = 2'b01; // MEM/WB
        end
    end


endmodule
