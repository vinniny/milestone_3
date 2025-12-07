module stage_if (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic        i_stall,
    input  logic        i_flush,
    
    // Redirect from ID
    input  logic [31:0] i_redirect_pc,
    input  logic        i_redirect_valid, // 1 if redirecting (mispredict or jump)
    
    // BTB Update from ID (For Model 2)
    input  logic        i_btb_update,
    input  logic [31:0] i_btb_update_pc,
    input  logic [31:0] i_btb_update_target,
    
    // IMEM Interface
    output logic [31:0] o_imem_addr,
    input  logic [31:0] i_imem_rdata,
    
    // Outputs to IF/ID
    output logic [31:0] o_pc,
    output logic [31:0] o_instr,
    output logic        o_pred_taken
);

    // PC Register
    logic [31:0] r_pc;
    logic [31:0] pc_next;
    logic [31:0] pc_plus4;
    logic [31:0] pc_pred;
    logic        pred_taken;

    // BTB (Simple Direct Mapped)
    localparam BTB_SIZE = 64;
    localparam BTB_INDEX_BITS = 6; // $clog2(64)
    
    logic [31:0] btb_target [BTB_SIZE-1:0];
    logic [31:0] btb_tag    [BTB_SIZE-1:0];
    logic        btb_valid  [BTB_SIZE-1:0];
    
    logic [BTB_INDEX_BITS-1:0] btb_index;
    logic [BTB_INDEX_BITS-1:0] update_index;
    
    assign btb_index = r_pc[BTB_INDEX_BITS+1:2]; // Use bits [7:2] for index
    assign update_index = i_btb_update_pc[BTB_INDEX_BITS+1:2];

    // BTB Read
    always @(*) begin
        pred_taken = 1'b0;
        pc_pred = pc_plus4;
        
        if (btb_valid[btb_index] && (btb_tag[btb_index] == r_pc)) begin
            pred_taken = 1'b1;
            pc_pred = btb_target[btb_index];
        end
    end

    // BTB Write
    always @(posedge i_clk) begin
        if (!i_reset) begin
            for (int i = 0; i < BTB_SIZE; i++) begin
                btb_valid[i] <= 1'b0;
                btb_tag[i]   <= 32'b0;
                btb_target[i]<= 32'b0;
            end
        end else if (i_btb_update) begin
            btb_valid[update_index]  <= 1'b1;
            btb_tag[update_index]    <= i_btb_update_pc;
            btb_target[update_index] <= i_btb_update_target;
        end
    end

    // PC Adder (Using FA_32bit)
    logic cout_dummy;
    FA_32bit pc_adder (
        .A(r_pc),
        .B(32'd4),
        .Cin(1'b0),
        .Sum(pc_plus4),
        .Cout(cout_dummy)
    );

    // Next PC Logic
    always @(*) begin
        if (i_redirect_valid) begin
            pc_next = i_redirect_pc;
        end else if (pred_taken) begin
            pc_next = pc_pred;
        end else begin
            pc_next = pc_plus4;
        end
    end

    // PC Update
    always @(posedge i_clk) begin
        if (!i_reset) begin
            r_pc <= 32'hFFFFFFFC;  // Start at -4 so pc_next = 0 for first fetch
        end else if (i_stall) begin
            // Hold PC
        end else begin
            r_pc <= pc_next;
        end
    end

    // ===========================================================================
    // Outputs - PRE-FETCH for Synchronous Memory
    // ===========================================================================
    // i_mem has 1-cycle latency (synchronous read via always_ff).
    // Send pc_next (combinational next-PC) to memory address so the instruction
    // arrives at i_mem output when PC advances to that value.
    // 
    // Timing Example:
    //   Cycle N:   r_pc = -4,  pc_next = 0,   o_imem_addr = 0   (pre-fetch addr 0)
    //   Cycle N+1: r_pc = 0,   pc_next = 4,   i_mem outputs instr@0
    //   Cycle N+2: r_pc = 4,   pc_next = 8,   instr@0 clocked into if_id_reg
    //
    // Pre-fetch compensates for sync memory latency. if_id_reg flip-flops
    // provide the necessary cycle to break combinational loops with ID stage.
    // Flush is handled by if_id_reg, not here - just pass through instruction.
    assign o_imem_addr = pc_next;  // PRE-FETCH: Use next PC for sync memory
    assign o_pc = r_pc;            // Output current PC
    assign o_instr = i_imem_rdata; // Pass through - flush handled by if_id_reg
    
    assign o_pred_taken = pred_taken;

endmodule
