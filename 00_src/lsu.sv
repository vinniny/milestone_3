//==============================================================================
// Module: lsu (Load-Store Unit)
//==============================================================================
// Description:
//   Load-store unit with **DUAL-PORT SYNCHRONOUS DMEM** for single-cycle
//   misaligned access support using funnel shifter architecture.
//
//   Key Features:
//     - Dual-port RAM allows reading/writing 2 consecutive words simultaneously
//     - Misaligned loads handled in 1 cycle via funnel shifter (no FSM)
//     - Misaligned stores split across Port A and Port B byte enables
//     - Memory-mapped I/O for LEDs, 7-segment displays, LCD, and switches
//
// Memory Map:
//   0x0000_0000 - 0x0000_FFFF: Data memory (64 KiB)
//   0x1000_0000 - 0x1000_0FFF: Red LEDs (LEDR)
//   0x1000_1000 - 0x1000_1FFF: Green LEDs (LEDG)
//   0x1000_2000 - 0x1000_2FFF: 7-segment displays (low 4 digits, HEX0-3)
//   0x1000_3000 - 0x1000_3FFF: 7-segment displays (high 4 digits, HEX4-7)
//   0x1000_4000 - 0x1000_4FFF: LCD display
//   0x1001_0000 - 0x1001_0FFF: Switch inputs
//==============================================================================

module lsu(
  // System signals
  input  logic        i_clk,
  input  logic        i_reset,
  input  logic [2:0]  i_funct3,    // Load/store type (LB/LH/LW/LBU/LHU/SB/SH/SW)
  
  // Load-Store interface from CPU
  input  logic [31:0] i_lsu_addr,  // Memory/IO address
  input  logic [31:0] i_st_data,   // Store data from CPU (rs2)
  input  logic        i_lsu_wren,  // Write enable from control unit
  output logic [31:0] o_ld_data,   // Load data to CPU (to rd)
  
  // Control signals from pipeline (for output_buffer)
  input  logic        i_ctrl_kill,   // Kill signal - prevents flushed stores
  input  logic        i_ctrl_valid,  // Valid signal - prevents bubble stores
  input  logic        i_ctrl_bubble, // Bubble signal - prevents bubble stores
  
  // IO outputs to FPGA peripherals
  output logic [31:0] o_io_ledr,   // Red LEDs
  output logic [31:0] o_io_ledg,   // Green LEDs
  output logic [ 6:0] o_io_hex0,   // 7-segment display digit 0 (rightmost)
  output logic [ 6:0] o_io_hex1,   // 7-segment display digit 1
  output logic [ 6:0] o_io_hex2,   // 7-segment display digit 2
  output logic [ 6:0] o_io_hex3,   // 7-segment display digit 3
  output logic [ 6:0] o_io_hex4,   // 7-segment display digit 4
  output logic [ 6:0] o_io_hex5,   // 7-segment display digit 5
  output logic [ 6:0] o_io_hex6,   // 7-segment display digit 6
  output logic [ 6:0] o_io_hex7,   // 7-segment display digit 7 (leftmost)
  output logic [31:0] o_io_lcd,    // LCD display data
  
  // IO inputs from FPGA peripherals
  input  logic [31:0] i_io_sw      // Switch inputs
);

  //============================================================================
  // Internal Signals
  //============================================================================
  
  // Address decode flags
  logic        f_dmem_valid;   // Address in DMEM range
  logic        f_io_valid;     // Address in I/O range
  logic        f_dmem_wren;    // Write enable for DMEM
  
  // DMEM dual-port interface
  logic [15:0] dmem_addr_a, dmem_addr_b;
  logic [31:0] dmem_data_a, dmem_data_b;
  logic [3:0]  dmem_wren_a, dmem_wren_b;
  logic [31:0] dmem_q_a, dmem_q_b;
  
  // I/O buffers
  logic [31:0] b_io_ledr, b_io_ledg, b_io_hexl, b_io_hexh, b_io_lcd, b_io_sw;
  logic [31:0] b_io_btn;  // Unused
  
  // Load data processing
  logic [31:0] dmem_load_data;      // Processed load data from DMEM
  logic [31:0] processed_read_data; // Final load data after I/O mux
  
  //============================================================================
  // PIPELINED LOAD PATH: Register Control Signals for Synchronous DMEM
  //============================================================================
  // Synchronous DMEM has 1-cycle read latency. When a load instruction is in
  // MEM stage (cycle N), DMEM is addressed but data arrives in cycle N+1.
  // By cycle N+1, the NEXT instruction is in MEM stage, so current i_funct3
  // and i_lsu_addr are for the WRONG instruction!
  // Solution: Register offset and funct3 when load is issued (cycle N),
  // use registered versions when data arrives (cycle N+1).
  
  logic [1:0]  r_offset;      // Registered byte offset
  logic [2:0]  r_funct3;      // Registered load type
  logic        is_load;        // Current instruction is a load
  
  assign is_load = !i_lsu_wren && i_ctrl_valid && !i_ctrl_bubble && !i_ctrl_kill;
  
  always_ff @(posedge i_clk) begin
    if (!i_reset) begin
      r_offset <= 2'b00;
      r_funct3 <= 3'b000;
    end else if (is_load) begin
      // Load operation: capture control signals for use next cycle
      r_offset <= i_lsu_addr[1:0];
      r_funct3 <= i_funct3;
    end
  end
  
  //============================================================================
  // DUAL-PORT ADDRESS GENERATION
  //============================================================================
  // Port A: Word-aligned base address (i_addr[31:2] << 2)
  // Port B: Next consecutive word (i_addr[31:2] + 1) << 2
  // This allows reading/writing two consecutive words for misaligned access
  
  assign dmem_addr_a = {i_lsu_addr[15:2], 2'b00};           // Base word
  assign dmem_addr_b = {i_lsu_addr[15:2] + 14'd1, 2'b00};  // Next word
  
  //============================================================================
  // STORE LOGIC: Byte Enable Generation for Dual Ports
  //============================================================================
  // Split store data across Port A and Port B based on alignment offset.
  // Handle SB, SH, SW for all offset cases (0, 1, 2, 3).
  
  logic [1:0] offset;
  assign offset = i_lsu_addr[1:0];
  
  always_comb begin
    // Default: No writes
    dmem_wren_a = 4'b0000;
    dmem_wren_b = 4'b0000;
    dmem_data_a = 32'h0;
    dmem_data_b = 32'h0;
    
    if (f_dmem_wren) begin  // Write to DMEM only
      case (i_funct3)
        // =====================================================
        // SB - Store Byte (can be at any offset 0,1,2,3)
        // =====================================================
        3'b000: begin
          case (offset)
            2'b00: begin  // Byte at offset 0 -> Port A[7:0]
              dmem_wren_a = 4'b0001;
              dmem_data_a = {24'h0, i_st_data[7:0]};
            end
            2'b01: begin  // Byte at offset 1 -> Port A[15:8]
              dmem_wren_a = 4'b0010;
              dmem_data_a = {16'h0, i_st_data[7:0], 8'h0};
            end
            2'b10: begin  // Byte at offset 2 -> Port A[23:16]
              dmem_wren_a = 4'b0100;
              dmem_data_a = {8'h0, i_st_data[7:0], 16'h0};
            end
            2'b11: begin  // Byte at offset 3 -> Port A[31:24]
              dmem_wren_a = 4'b1000;
              dmem_data_a = {i_st_data[7:0], 24'h0};
            end
          endcase
        end
        
        // =====================================================
        // SH - Store Halfword (offset 0,1,2,3 - may span words)
        // =====================================================
        3'b001: begin
          case (offset)
            2'b00: begin  // Halfword at offset 0 -> Port A[15:0]
              dmem_wren_a = 4'b0011;
              dmem_data_a = {16'h0, i_st_data[15:0]};
            end
            2'b01: begin  // Halfword at offset 1 -> Port A[23:8]
              dmem_wren_a = 4'b0110;
              dmem_data_a = {8'h0, i_st_data[15:0], 8'h0};
            end
            2'b10: begin  // Halfword at offset 2 -> Port A[31:16]
              dmem_wren_a = 4'b1100;
              dmem_data_a = {i_st_data[15:0], 16'h0};
            end
            2'b11: begin  // Halfword spans words: Port A[31:24] + Port B[7:0]
              dmem_wren_a = 4'b1000;
              dmem_wren_b = 4'b0001;
              dmem_data_a = {i_st_data[7:0], 24'h0};        // Low byte to A
              dmem_data_b = {24'h0, i_st_data[15:8]};       // High byte to B
            end
          endcase
        end
        
        // =====================================================
        // SW - Store Word (offset 0,1,2,3 - may span words)
        // =====================================================
        3'b010: begin
          case (offset)
            2'b00: begin  // Word at offset 0 -> Port A[31:0]
              dmem_wren_a = 4'b1111;
              dmem_data_a = i_st_data;
            end
            2'b01: begin  // Word spans: Port A[31:8] + Port B[7:0]
              dmem_wren_a = 4'b1110;
              dmem_wren_b = 4'b0001;
              dmem_data_a = {i_st_data[23:0], 8'h0};
              dmem_data_b = {24'h0, i_st_data[31:24]};
            end
            2'b10: begin  // Word spans: Port A[31:16] + Port B[15:0]
              dmem_wren_a = 4'b1100;
              dmem_wren_b = 4'b0011;
              dmem_data_a = {i_st_data[15:0], 16'h0};
              dmem_data_b = {16'h0, i_st_data[31:16]};
            end
            2'b11: begin  // Word spans: Port A[31:24] + Port B[23:0]
              dmem_wren_a = 4'b1000;
              dmem_wren_b = 4'b0111;
              dmem_data_a = {i_st_data[7:0], 24'h0};
              dmem_data_b = {8'h0, i_st_data[31:8]};
            end
          endcase
        end
        
        default: begin
          dmem_wren_a = 4'b0000;
          dmem_wren_b = 4'b0000;
        end
      endcase
    end
  end
  
  //============================================================================
  // LOAD LOGIC: Funnel Shifter for Misaligned Access (PIPELINED)
  //============================================================================
  // Concatenate Port B (high word) and Port A (low word) into 64-bit vector.
  // Shift right by (r_offset * 8) bits to align the desired data.
  // Extract 32 bits and apply sign/zero extension based on r_funct3.
  // 
  // CRITICAL: Use REGISTERED control signals (r_offset, r_funct3) because
  // dmem_q_a/q_b are delayed by 1 cycle (synchronous RAM output).
  
  logic [63:0] funnel_concat;
  logic [31:0] funnel_shifted;
  logic [31:0] load_extended;
  
  // Step 1: Concatenate dual-port reads into 64-bit
  assign funnel_concat = {dmem_q_b, dmem_q_a};  // [63:32] = B, [31:0] = A
  
  // Step 2: Shift based on byte offset to align data
  always_comb begin
    case (r_offset)  // USE REGISTERED OFFSET (captured when load was issued)
      2'b00: funnel_shifted = funnel_concat[31:0];   // No shift
      2'b01: funnel_shifted = funnel_concat[39:8];   // Shift right 8 bits
      2'b10: funnel_shifted = funnel_concat[47:16];  // Shift right 16 bits
      2'b11: funnel_shifted = funnel_concat[55:24];  // Shift right 24 bits
    endcase
  end
  
  // Step 3: Extract and extend based on load type
  always_comb begin
    case (r_funct3)  // USE REGISTERED FUNCT3 (captured when load was issued)
      3'b000: load_extended = {{24{funnel_shifted[7]}}, funnel_shifted[7:0]};    // LB (sign-extend)
      3'b001: load_extended = {{16{funnel_shifted[15]}}, funnel_shifted[15:0]};  // LH (sign-extend)
      3'b010: load_extended = funnel_shifted;                                     // LW (no extend)
      3'b100: load_extended = {24'h0, funnel_shifted[7:0]};                       // LBU (zero-extend)
      3'b101: load_extended = {16'h0, funnel_shifted[15:0]};                      // LHU (zero-extend)
      default: load_extended = 32'h0;
    endcase
  end
  
  assign dmem_load_data = load_extended;
  
`ifndef SYNTHESIS
  // Debug: Print first few loads to verify timing
  always @(posedge i_clk) begin
    if (is_load && $time < 1000) begin
      $display("[LSU LOAD] Time=%0t | Addr=0x%h offset=%b funct3=%b | NEXT CYCLE r_offset=%b r_funct3=%b", 
               $time, i_lsu_addr, i_lsu_addr[1:0], i_funct3, i_lsu_addr[1:0], i_funct3);
    end
    if ($time < 1000) begin
      $display("[LSU DATA] Time=%0t | q_a=0x%h q_b=0x%h | r_offset=%b r_funct3=%b | shift=0x%h extend=0x%h", 
               $time, dmem_q_a, dmem_q_b, r_offset, r_funct3, funnel_shifted, load_extended);
    end
  end
`endif
  
  //============================================================================
  // Sub-module Instantiations
  //============================================================================

  // Input Buffer: Synchronize external switch inputs
  input_buffer u_input_buffer(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_io_sw(i_io_sw),
    .b_io_sw(b_io_sw)
  );

  // Output Buffer: Handle memory-mapped I/O writes
  output_buffer u_output_buffer(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_st_data(i_st_data),
    .i_io_addr(i_lsu_addr),
    .i_funct3(i_funct3),
    .i_mem_write(i_lsu_wren),
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

  // Data Memory: Dual-Port Synchronous RAM
  dmem u_dmem(
    .i_clk(i_clk),
    .i_reset(i_reset),
    // Port A
    .address_a(dmem_addr_a),
    .data_a(dmem_data_a),
    .wren_a(dmem_wren_a),
    .q_a(dmem_q_a),
    // Port B
    .address_b(dmem_addr_b),
    .data_b(dmem_data_b),
    .wren_b(dmem_wren_b),
    .q_b(dmem_q_b)
  );

  // Input Mux: Address decoder
  input_mux u_input_mux(
    .i_lsu_addr(i_lsu_addr),
    .i_lsu_wren(i_lsu_wren),
    .f_dmem_valid(f_dmem_valid),
    .f_io_valid(f_io_valid),
    .f_dmem_wren(f_dmem_wren)
  );

  // Output Mux: Select load data from DMEM or I/O
  output_mux u_output_mux(
    .i_clk(i_clk),
    .b_dmem_data(dmem_load_data),
    .b_io_ledr(b_io_ledr),
    .b_io_ledg(b_io_ledg),
    .b_io_hexl(b_io_hexl),
    .b_io_hexh(b_io_hexh),
    .b_io_lcd(b_io_lcd),
    .b_io_sw(b_io_sw),
    .b_io_btn(b_io_btn),
    .f_dmem_valid(f_dmem_valid),
    .f_io_valid(f_io_valid),
    .i_ld_addr(i_lsu_addr),
    .o_ld_data(o_ld_data),
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
    .o_io_lcd(o_io_lcd)
  );

`ifndef SYNTHESIS
`endif

endmodule
