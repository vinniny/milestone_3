module wrapper (
    input  logic        CLOCK_50,
    input  logic [9:0]  SW,          // DE10-Standard: 10 switches (SW[0] = pause/resume)
    input  logic [3:0]  KEY,         // DE10-Standard: 4 buttons (KEY[0] = reset, active-low)
    output logic [9:0]  LEDR,        // 10 red LEDs
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5  // 7-segment displays (HEX5=leftmost, HEX0=rightmost)
);

    // -------------------------------------------------------------------------
    // Clock & Reset
    // -------------------------------------------------------------------------
    logic clk_25;
    logic reset_n;            // active-low reset as expected by single_cycle
    assign reset_n = KEY[0];  // KEY[0] is system reset (active-low)

    // 50MHz -> 10MHz clock divider
    clock_10M u_clkdiv (
        .clk50   (CLOCK_50),
        .i_reset (reset_n),
        .o_clk   (clk_25)
    );

    // -------------------------------------------------------------------------
    // Interconnect to pipelined processor
    // -------------------------------------------------------------------------
    logic        insn_vld;
    logic [31:0] ledr32;

    // Unused 7-seg from core (the core outputs 8 digits, board has 6)
    logic [6:0] hex6_nc, hex7_nc;
    
    // Unused outputs
    logic [31:0] unused_ledg;
    logic [31:0] unused_lcd;
    logic        unused_ctrl;
    logic        unused_mispred;
    logic [31:0] unused_pc_frontend;
    logic [31:0] unused_pc_debug;
    logic        unused_halt;
    logic [3:0]  unused_model_id;

    pipelined dut (
        .i_clk      (clk_25),
        .i_reset    (reset_n),

        // Map switches and KEY buttons to 32-bit input
        // KEYs are active-low (pressed=0), invert to active-high for software
        // SWs: ON=1, OFF=0 (no inversion needed)
        // SW[0]=1 means running, SW[0]=0 means paused in the program logic
        .i_io_sw    ({18'd0, ~KEY, SW}),

        // Debug/commit interface (unused on board)
        .o_pc_frontend (unused_pc_frontend),
        .o_pc_debug   (unused_pc_debug),
        .o_insn_vld    (insn_vld),
        .o_ctrl        (unused_ctrl),
        .o_mispred     (unused_mispred),
        .o_halt        (unused_halt),
        .o_model_id    (unused_model_id),

        // Map LEDRs (core drives 32; board shows 10)
        .o_io_ledr  (ledr32),
        .o_io_ledg  (unused_ledg),           // not brought to the board
        
        // 7-segment displays: HEX5(leftmost) to HEX0(rightmost)
        .o_io_hex0  (HEX0),
        .o_io_hex1  (HEX1),
        .o_io_hex2  (HEX2),
        .o_io_hex3  (HEX3),
        .o_io_hex4  (HEX4),
        .o_io_hex5  (HEX5),
        .o_io_hex6  (hex6_nc),    // tie off extra digits
        .o_io_hex7  (hex7_nc),
        .o_io_lcd   (unused_lcd)  // not used on DE10-Standard
    );

    // -------------------------------------------------------------------------
    // Board LED assignments
    // -------------------------------------------------------------------------
    // Show core LEDR[8:0] on board, and use LEDR[9] as "instruction valid" pulse
    always @(*) begin
        LEDR[8:0] = ledr32[8:0];
        LEDR[9]   = insn_vld;
    end

endmodule
