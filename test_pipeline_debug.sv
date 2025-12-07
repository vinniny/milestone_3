module test_pipeline_debug;
    logic clk = 0;
    logic rstn;
    
    always #1 clk = ~clk;
    
    initial begin
        rstn = 0;
        #5 rstn = 1;
        #100;
        $display("Test completed");
        $finish;
    end
    
    logic [31:0] pc_debug, pc_frontend;
    logic insn_vld, halt;
    logic [3:0] model_id;
    logic ctrl, mispred;
    
    pipelined dut (
        .i_clk(clk),
        .i_reset(rstn),
        .i_io_sw(32'h0),
        .o_io_lcd(),
        .o_io_ledr(),
        .o_io_ledg(),
        .o_io_hex0(), .o_io_hex1(), .o_io_hex2(), .o_io_hex3(),
        .o_io_hex4(), .o_io_hex5(), .o_io_hex6(), .o_io_hex7(),
        .o_ctrl(ctrl),
        .o_mispred(mispred),
        .o_pc_frontend(pc_frontend),
        .o_pc_debug(pc_debug),
        .o_insn_vld(insn_vld),
        .o_halt(halt),
        .o_model_id(model_id)
    );
    
    always @(posedge clk) begin
        if (rstn) begin
            $display("T=%0t: PC_frontend=%h PC_debug=%h insn_vld=%b halt=%b", 
                     $time, pc_frontend, pc_debug, insn_vld, halt);
        end
    end
    
endmodule
