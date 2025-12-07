module stage_mem (
    input  logic        i_clk,
    input  logic        i_reset,
    
    // Inputs from EX/MEM
    input  logic [31:0] i_alu_result,
    input  logic [31:0] i_store_data,
    input  logic        i_mem_write,
    input  logic        i_mem_read,
    input  logic [2:0]  i_funct3,
    input  logic        i_ctrl_kill,
    input  logic        i_ctrl_valid,
    input  logic        i_ctrl_bubble,
    
    // I/O Inputs
    input  logic [31:0] i_io_sw,
    
    // I/O Outputs
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
    
    // Outputs to MEM/WB (pipelined.sv expects these names)
    output logic [31:0] o_dmem_rdata,
    output logic [31:0] o_io_rdata,
    
    // Output to hazard unit
    output logic        o_mem_stall_req
);

    // Internal signal for combined load data from LSU
    logic [31:0] ld_data;
    
    // For synchronous DMEM: We need to stall loads for 1 cycle to allow data to arrive
    // But we must only stall ONCE per load, not forever!
    // Solution: Stall when mem_read is TRUE and we haven't stalled yet for this instruction
    //
    // The tricky part: how do we know if we've already stalled?
    // Answer: If we're stalling (o_mem_stall_req=1), the instruction stays in MEM stage.
    //         Next cycle, we clear the stall (o_mem_stall_req=0), allowing it to proceed.
    //         We use a register to track "did we stall last cycle?"
    
    logic r_stalled_last_cycle;
    
    always_ff @(posedge i_clk) begin
        if (!i_reset) begin
            r_stalled_last_cycle <= 1'b0;
        end else begin
            r_stalled_last_cycle <= o_mem_stall_req;
        end
    end
    
    // Stall if: it's a valid load AND we didn't stall last cycle
    assign o_mem_stall_req = i_mem_read && i_ctrl_valid && !i_ctrl_bubble && !i_ctrl_kill && !r_stalled_last_cycle;

`ifndef SYNTHESIS
    integer load_count = 0;
    always @(posedge i_clk) begin
        if (o_mem_stall_req) begin
            load_count = load_count + 1;
            if (load_count <= 5) begin
                $display("T=%0t [LOAD_%0d] mem_read=%b stall_req=%b", $time, load_count, i_mem_read, o_mem_stall_req);
            end
        end
    end
`endif
    
    // LSU outputs combined dmem/io data - split it for backward compatibility
    // pipelined.sv will mux them based on address
    assign o_dmem_rdata = ld_data;
    assign o_io_rdata   = ld_data;
    
    // Instantiate LSU (handles all memory, I/O, and misaligned access)
    lsu u_lsu(
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_funct3(i_funct3),
        .i_lsu_addr(i_alu_result),
        .i_st_data(i_store_data),
        .i_lsu_wren(i_mem_write),
        .o_ld_data(ld_data),
        .i_ctrl_kill(i_ctrl_kill),
        .i_ctrl_valid(i_ctrl_valid),
        .i_ctrl_bubble(i_ctrl_bubble),
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
        .i_io_sw(i_io_sw)
    );

endmodule
