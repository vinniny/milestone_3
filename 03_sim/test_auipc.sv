module test_auipc;
    logic [6:0] opcode;
    logic is_branch, is_jal, is_jalr, is_lui, is_auipc;
    logic [1:0] opa_sel;
    
    assign is_branch = (opcode == 7'b1100011);
    assign is_jal    = (opcode == 7'b1101111);
    assign is_jalr   = (opcode == 7'b1100111);
    assign is_lui    = (opcode == 7'b0110111);
    assign is_auipc  = (opcode == 7'b0010111);
    
    assign opa_sel[0] = is_branch | is_jal | is_auipc;
    assign opa_sel[1] = is_lui;
    
    initial begin
        opcode = 7'b0010111; // AUIPC
        #1;
        $display("Opcode=%b AUIPC=%b opa_sel=%b", opcode, is_auipc, opa_sel);
        $finish;
    end
endmodule
