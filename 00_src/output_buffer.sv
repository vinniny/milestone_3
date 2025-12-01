// ============================================================================
// Module: output_buffer
// Description: Memory-Mapped I/O Output Buffer
//              Handles store operations to LED, 7-segment, and LCD peripherals
//              Supports byte, halfword, and word writes with masking
// ============================================================================
module output_buffer(
  input  logic        i_clk,         // Clock
  input  logic        i_reset,       // Active-low reset
  input  logic [31:0] i_st_data,     // Store data
  input  logic [31:0] i_io_addr,     // I/O address
  input  logic [2:0]  i_funct3,      // Function code (SB/SH/SW)
  input  logic        i_mem_write,   // Memory write signal from pipeline
  input  logic        i_io_valid,    // Address is in I/O range
  input  logic        i_ctrl_kill,   // Kill signal - prevents flushed stores
  input  logic        i_ctrl_valid,  // Valid signal - prevents bubble stores
  input  logic        i_ctrl_bubble, // Bubble signal - prevents bubble stores
  output logic [31:0] b_io_ledr,     // Red LED buffer
  output logic [31:0] b_io_ledg,     // Green LED buffer
  output logic [31:0] b_io_hexl,     // 7-segment low (HEX3-0)
  output logic [31:0] b_io_hexh,     // 7-segment high (HEX7-4)
  output logic [31:0] b_io_lcd       // LCD buffer
);

  // Local variables for write mask computation (combinational)
  logic [31:0] write_mask_comb;
  logic [31:0] write_data_comb;
  logic [1:0]  addr_offset_comb;
  logic        io_write_enable_comb;

  // Combinational logic: compute write mask and data
  always_comb begin
    // Compute write enable from inputs
    io_write_enable_comb = i_mem_write && i_io_valid && i_ctrl_valid && !i_ctrl_bubble && !i_ctrl_kill;
    addr_offset_comb = i_io_addr[1:0];
    
    // Default values
    write_mask_comb = 32'h0000_0000;
    write_data_comb = 32'h0000_0000;
    
    // Only compute write mask and data when writing to I/O
    if (io_write_enable_comb) begin
      // Generate write mask and align data based on store type
      case (i_funct3)
      3'b000: begin // SB (Store Byte)
        case (addr_offset_comb)
          2'b00: begin
            write_mask_comb = 32'h0000_00FF;
            write_data_comb = {24'h000000, i_st_data[7:0]};
          end
          2'b01: begin
            write_mask_comb = 32'h0000_FF00;
            write_data_comb = {16'h0000, i_st_data[7:0], 8'h00};
          end
          2'b10: begin
            write_mask_comb = 32'h00FF_0000;
            write_data_comb = {8'h00, i_st_data[7:0], 16'h0000};
          end
          2'b11: begin
            write_mask_comb = 32'hFF00_0000;
            write_data_comb = {i_st_data[7:0], 24'h000000};
          end
          default: begin
            write_mask_comb = 32'h0000_0000;
            write_data_comb = 32'h0000_0000;
          end
        endcase
      end
      
      3'b001: begin // SH (Store Halfword)
        if (addr_offset_comb[1] == 1'b0) begin
          write_mask_comb = 32'h0000_FFFF;
          write_data_comb = {16'h0000, i_st_data[15:0]};
        end else begin
          write_mask_comb = 32'hFFFF_0000;
          write_data_comb = {i_st_data[15:0], 16'h0000};
        end
      end
      
      3'b010: begin // SW (Store Word)
        write_mask_comb = 32'hFFFF_FFFF;
        write_data_comb = i_st_data;
      end
      
      default: begin
        write_mask_comb = 32'h0000_0000;
        write_data_comb = 32'h0000_0000;
      end
      endcase
    end
  end

  // Sequential logic: update registers synchronously
  always_ff @(posedge i_clk) begin
    if (~i_reset) begin  // Active-low reset: reset when i_reset=0
      b_io_ledr <= 32'b0;
      b_io_ledg <= 32'b0;
      // Initialize 7-segment displays to 0x7F (all segments OFF for common-anode)
      b_io_hexl <= 32'h7F7F7F7F;  // All digits show blank (segments off)
      b_io_hexh <= 32'h7F7F7F7F;  // All digits show blank (segments off)
      b_io_lcd  <= 32'b0;
    end else begin
      // Update registers when writing to I/O
      if (io_write_enable_comb) begin
        
        // Update addressed I/O register
        case (i_io_addr[15:12])  // Use bits [15:12] to decode device (4KB blocks)
        4'h0: b_io_ledr <= (b_io_ledr & ~write_mask_comb) | (write_data_comb & write_mask_comb);
        4'h1: b_io_ledg <= (b_io_ledg & ~write_mask_comb) | (write_data_comb & write_mask_comb);
        4'h2: b_io_hexl <= (b_io_hexl & ~write_mask_comb) | (write_data_comb & write_mask_comb);
        4'h3: b_io_hexh <= (b_io_hexh & ~write_mask_comb) | (write_data_comb & write_mask_comb);
        4'h4: b_io_lcd  <= (b_io_lcd  & ~write_mask_comb) | (write_data_comb & write_mask_comb);
        default: begin
          // No update for other addresses
        end
        endcase
      end // if (io_write_enable)
    end // else (not reset)
  end // always_ff

endmodule
