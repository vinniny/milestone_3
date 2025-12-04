module stage_mem (
    input  logic        i_clk,
    input  logic        i_reset,
    
    // Inputs from EX/MEM
    input  logic [31:0] i_alu_result, // Address
    input  logic [31:0] i_store_data,
    input  logic        i_mem_write,
    input  logic        i_mem_read,
    input  logic [2:0]  i_funct3,
    input  logic        i_ctrl_kill,  // Kill signal for flushed instructions
    input  logic        i_ctrl_valid, // Valid signal (not a bubble)
    input  logic        i_ctrl_bubble, // Bubble signal
    
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
    
    // Outputs to MEM/WB
    output logic [31:0] o_dmem_rdata, // From DMEM (sync)
    output logic [31:0] o_io_rdata    // From I/O (registered)
);

    // Internal Signals
    logic f_dmem_valid, f_io_valid;
    logic f_dmem_wren;
    logic [3:0] dmem_byte_enable;
    logic [31:0] dmem_write_data;
    logic misaligned_access;
    logic lsu_store_en; // Strict gating: valid & ~bubble & ~kill & mem_write
    
    logic [31:0] b_io_ledr, b_io_ledg, b_io_hexl, b_io_hexh, b_io_lcd, b_io_sw;
    logic [31:0] io_rdata_comb;

    // LSU Store Enable - Strict Gating
    // Only allow stores from valid, non-bubble, non-killed instructions
    assign lsu_store_en = i_ctrl_valid && !i_ctrl_bubble && !i_ctrl_kill && i_mem_write;

    // Address Decode (Input Mux)
    input_mux u_mux (
        .i_lsu_addr(i_alu_result),
        .i_lsu_wren(i_mem_write), // Pass raw signal; gating happens at DMEM and I/O write
        .f_dmem_valid(f_dmem_valid),
        .f_io_valid(f_io_valid),
        .f_dmem_wren(f_dmem_wren)
    );
    
`ifndef SYNTHESIS
    // Debug: Monitor I/O write conditions
    always @(posedge i_clk) begin
        if ($time > 200 && $time < 1500) begin

        end
        // Diagnostic: Show what MEM actually sees

    end
`endif

    // Misalignment Detection
    always @(*) begin
        misaligned_access = 1'b0;
        case (i_funct3)
            3'b001, 3'b101: misaligned_access = i_alu_result[0];        // SH/LH
            3'b010:         misaligned_access = |i_alu_result[1:0];     // SW/LW
            default:        misaligned_access = 1'b0;
        endcase
    end

    // Store Data Prep
    always @(*) begin
        dmem_byte_enable = 4'b0000;
        dmem_write_data = i_store_data;
        
        // Gate DMEM writes with validity/bubble/kill checks
        if (lsu_store_en && f_dmem_wren && !misaligned_access) begin
            case (i_funct3)
                3'b000: begin // SB
                    case (i_alu_result[1:0])
                        2'b00: dmem_byte_enable = 4'b0001;
                        2'b01: dmem_byte_enable = 4'b0010;
                        2'b10: dmem_byte_enable = 4'b0100;
                        2'b11: dmem_byte_enable = 4'b1000;
                    endcase
                    dmem_write_data = {4{i_store_data[7:0]}};
                end
                3'b001: begin // SH
                    if (!i_alu_result[0]) begin
                        case (i_alu_result[1])
                            1'b0: dmem_byte_enable = 4'b0011;
                            1'b1: dmem_byte_enable = 4'b1100;
                        endcase
                        dmem_write_data = {2{i_store_data[15:0]}};
                    end
                end
                3'b010: begin // SW
                    if (i_alu_result[1:0] == 2'b00) begin
                        dmem_byte_enable = 4'b1111;
                        dmem_write_data = i_store_data;
                    end
                end
                default: dmem_byte_enable = 4'b0000;
            endcase
        end
    end

    // DMEM
    dmem dmem_inst (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .address(i_alu_result[15:0]),
        .data(dmem_write_data),
        .wren(dmem_byte_enable),
        .q(o_dmem_rdata)
    );

    // Input Buffer
    input_buffer u_in_buf (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_io_sw(i_io_sw),
        .b_io_sw(b_io_sw)
    );

    // Output Buffer
    output_buffer u_out_buf (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_st_data(i_store_data),
        .i_io_addr(i_alu_result),
        .i_funct3(i_funct3),
        .i_mem_write(i_mem_write),
        .i_io_valid(f_io_valid),
        .i_ctrl_kill(i_ctrl_kill),
        .i_ctrl_valid(i_ctrl_valid),
        .i_ctrl_bubble(i_ctrl_bubble),
        .b_io_ledr(b_io_ledr),
        .b_io_ledg(b_io_ledg),
        .b_io_hexl(b_io_hexl),
        .b_io_hexh(b_io_hexh),
        .b_io_lcd(b_io_lcd)
    );

    // I/O Read Mux
    always @(*) begin
        io_rdata_comb = 32'd0;
        if (f_io_valid) begin
            if (i_alu_result[31:16] == 16'h1001) begin
                io_rdata_comb = b_io_sw;
            end else begin
                case (i_alu_result[15:12])
                    4'h0: io_rdata_comb = b_io_ledr;
                    4'h1: io_rdata_comb = b_io_ledg;
                    4'h2: io_rdata_comb = b_io_hexl;
                    4'h3: io_rdata_comb = b_io_hexh;
                    4'h4: io_rdata_comb = b_io_lcd;
                    default: io_rdata_comb = 32'd0;
                endcase
            end
        end
    end

    // Register I/O Read Data
    always @(posedge i_clk) begin
        if (i_reset) begin
            o_io_rdata <= 32'b0;
        end else begin
            o_io_rdata <= io_rdata_comb;
        end
    end

    // I/O Output Routing
    assign o_io_ledr = b_io_ledr;
    assign o_io_ledg = b_io_ledg;
    assign o_io_lcd  = b_io_lcd;
    
`ifndef SYNTHESIS
    // Debug: Monitor b_io_ledr register
    always @(posedge i_clk) begin

    end
`endif
    assign o_io_hex0 = b_io_hexl[ 6: 0];
    assign o_io_hex1 = b_io_hexl[14: 8];
    assign o_io_hex2 = b_io_hexl[22:16];
    assign o_io_hex3 = b_io_hexl[30:24];
    assign o_io_hex4 = b_io_hexh[ 6: 0];
    assign o_io_hex5 = b_io_hexh[14: 8];
    assign o_io_hex6 = b_io_hexh[22:16];
    assign o_io_hex7 = b_io_hexh[30:24];

endmodule
