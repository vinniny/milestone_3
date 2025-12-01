module ex_mem_reg (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic        i_stall,
    input  logic        i_flush,

    // Data Inputs
    input  logic [31:0] i_pc,
    input  logic [31:0] i_alu_result,
    input  logic [31:0] i_store_data,
    input  logic [4:0]  i_rd,

    // Control Inputs
    input  logic        i_ctrl_valid,
    input  logic        i_ctrl_bubble,
    input  logic        i_ctrl_kill,
    input  logic        i_ctrl_mem_read,
    input  logic        i_ctrl_mem_write,
    input  logic        i_ctrl_wb_en,
    input  logic        i_ctrl_mispred,
    input  logic        i_ctrl_is_control, // Branch or Jump
    input  logic [2:0]  i_ctrl_funct3,

    // Data Outputs
    output logic [31:0] o_pc,
    output logic [31:0] o_alu_result,
    output logic [31:0] o_store_data,
    output logic [4:0]  o_rd,

    // Control Outputs
    output logic        o_ctrl_valid,
    output logic        o_ctrl_bubble,
    output logic        o_ctrl_kill, // Should be 0 usually
    output logic        o_ctrl_mem_read,
    output logic        o_ctrl_mem_write,
    output logic        o_ctrl_wb_en,
    output logic        o_ctrl_mispred,
    output logic        o_ctrl_is_control,
    output logic [2:0]  o_ctrl_funct3
);

    always_ff @(posedge i_clk) begin
        if (!i_reset) begin
            o_pc <= 32'b0;
            o_alu_result <= 32'b0;
            o_store_data <= 32'b0;
            o_rd <= 5'b0;
            
            o_ctrl_valid <= 1'b0;
            o_ctrl_bubble <= 1'b0;
            o_ctrl_kill <= 1'b0;
            o_ctrl_mem_read <= 1'b0;
            o_ctrl_mem_write <= 1'b0;
            o_ctrl_wb_en <= 1'b0;
            o_ctrl_mispred <= 1'b0;
            o_ctrl_is_control <= 1'b0;
            o_ctrl_funct3 <= 3'b0;
        end else if (i_flush) begin
            o_ctrl_valid     <= 1'b0;
            o_ctrl_bubble    <= 1'b1;
            o_ctrl_kill      <= 1'b0;
            
            o_ctrl_mem_read  <= 1'b0;
            o_ctrl_mem_write <= 1'b0;
            o_ctrl_wb_en     <= 1'b0;
            o_ctrl_mispred   <= 1'b0;
            o_ctrl_is_control<= 1'b0;
            o_ctrl_funct3    <= 3'b0;
            
            o_pc             <= 32'b0;
            o_alu_result     <= 32'b0;
            o_store_data     <= 32'b0;
            o_rd             <= 5'b0;
        end else if (i_stall) begin
            // Hold
        end else begin
            if (i_ctrl_kill) begin
                // Kill -> Bubble
                o_ctrl_valid     <= 1'b0;
                o_ctrl_bubble    <= 1'b1;
                o_ctrl_kill      <= 1'b0;
                
                o_ctrl_mem_read  <= 1'b0;
                o_ctrl_mem_write <= 1'b0;
                o_ctrl_wb_en     <= 1'b0;
                o_ctrl_mispred   <= 1'b0;
                o_ctrl_is_control<= 1'b0;
                o_ctrl_funct3    <= 3'b0;
                
                o_pc             <= i_pc; 
                o_alu_result     <= 32'b0;
                o_store_data     <= 32'b0;
                o_rd             <= 5'b0;
            end else begin
                o_pc             <= i_pc;
                
                // Defense-in-depth: zero data payloads on bubble
                if (i_ctrl_bubble) begin
                    o_alu_result <= 32'b0;
                    o_store_data <= 32'b0;
`ifndef SYNTHESIS
                    if ($time > 190 && $time < 320) begin
                        $display("EX/MEM @%0t: BUBBLE - zeroing store_data (was %h)", $time, i_store_data);
                    end
`endif
                end else begin
                    o_alu_result <= i_alu_result;
                    o_store_data <= i_store_data;
`ifndef SYNTHESIS
                    if ($time > 190 && $time < 320 && $isunknown(i_store_data)) begin
                        $display("EX/MEM @%0t: NOT BUBBLE but store_data=X! bubble=%b valid=%b kill=%b mem_write=%b",
                                 $time, i_ctrl_bubble, i_ctrl_valid, i_ctrl_kill, i_ctrl_mem_write);
                    end
`endif
                end
                
                o_rd             <= i_rd;
                
                o_ctrl_valid     <= i_ctrl_valid;
                o_ctrl_bubble    <= i_ctrl_bubble;
                o_ctrl_kill      <= i_ctrl_kill; 
                o_ctrl_mem_read  <= i_ctrl_mem_read;
                o_ctrl_mem_write <= i_ctrl_mem_write;
                o_ctrl_wb_en     <= i_ctrl_wb_en;
                o_ctrl_mispred   <= i_ctrl_mispred;
                o_ctrl_is_control<= i_ctrl_is_control;
                o_ctrl_funct3    <= i_ctrl_funct3;
            end
        end
    end
    
    // Diagnostic: Show what's actually IN the EX/MEM register after clock edge
`ifndef SYNTHESIS
    always @(posedge i_clk) begin
        if ($time > 190 && $time < 320 && o_ctrl_valid && !o_ctrl_bubble && o_ctrl_mem_write) begin
            $display("EX/MEM OUT @%0t: pc=%h mem_write=%b store_data=%h", 
                     $time, o_pc, o_ctrl_mem_write, o_store_data);
        end
    end
`endif

endmodule
