module hazard_unit (
    // Model ID (Optional, but good for verification if we wanted to support multiple, but we hardcode)
    // We assume Model 2 (Forwarding + AT)

    // ID Stage Inputs
    input  logic [4:0]  i_rs1,
    input  logic [4:0]  i_rs2,
    input  logic        i_use_rs1,
    input  logic        i_use_rs2,
    input  logic        i_is_branch,
    input  logic        i_is_jump, // JALR uses rs1

    // ID/EX Stage Inputs
    input  logic [4:0]  i_id_ex_rd,
    input  logic        i_id_ex_mem_read,
    input  logic        i_id_ex_reg_write,

    // EX/MEM Stage Inputs
    input  logic [4:0]  i_ex_mem_rd,
    input  logic        i_ex_mem_mem_read,

    // Outputs
    output logic        o_stall_if,
    output logic        o_stall_id,
    output logic        o_flush_id_ex, // Insert bubble in ID/EX
    output logic        o_flush_if_id  // Only if needed, usually stall implies holding IF/ID
);

    logic stall;
    logic stall_load_use;
    logic stall_branch_load;
    logic stall_branch_alu;

    // Load-Use Hazard (ALU consumer or Branch consumer)
    // If instruction in EX is a load and writes to rs1 or rs2 used by ID
    always_comb begin
        stall_load_use = 1'b0;
        if (i_id_ex_mem_read && i_id_ex_rd != 5'b0) begin
            if ((i_use_rs1 && i_rs1 == i_id_ex_rd) || 
                (i_use_rs2 && i_rs2 == i_id_ex_rd)) begin
                stall_load_use = 1'b1;
            end
        end
    end

    // Branch Hazard (Load to Branch)
    // If instruction in MEM is a load and writes to rs1 or rs2 used by Branch in ID
    // Note: If it was in EX, stall_load_use would catch it.
    // But if it moved to MEM, stall_load_use is 0. We need to catch it here.
    always_comb begin
        stall_branch_load = 1'b0;
        if (i_is_branch || i_is_jump) begin // JALR also needs rs1
             if (i_ex_mem_mem_read && i_ex_mem_rd != 5'b0) begin
                if ((i_use_rs1 && i_rs1 == i_ex_mem_rd) || 
                    (i_use_rs2 && i_rs2 == i_ex_mem_rd)) begin
                    stall_branch_load = 1'b1;
                end
             end
        end
    end

    // Branch-ALU Hazard
    // If instruction in EX writes to a register that Branch in ID needs
    // We can't forward from EX to ID (only from EX/MEM or MEM/WB)
    // So we must stall until the producing instruction reaches EX/MEM
    always_comb begin
        stall_branch_alu = 1'b0;
        if (i_is_branch || i_is_jump) begin
            // Check if ID/EX stage has an instruction writing to rs1 or rs2
            // Must be a register-writing instruction (not a load, not a branch)
            if (!i_id_ex_mem_read && i_id_ex_reg_write && i_id_ex_rd != 5'b0) begin
                if ((i_use_rs1 && i_rs1 == i_id_ex_rd) || 
                    (i_use_rs2 && i_rs2 == i_id_ex_rd)) begin
                    stall_branch_alu = 1'b1;
                end
            end
        end
    end

    assign stall = stall_load_use | stall_branch_load | stall_branch_alu;

    assign o_stall_if     = stall;
    assign o_stall_id     = stall;
    assign o_flush_id_ex  = stall; // Insert bubble into ID/EX when stalling
    assign o_flush_if_id  = 1'b0;  // We hold IF/ID, not flush it

endmodule
