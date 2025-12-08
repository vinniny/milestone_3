// ============================================================================
// Module: dmem
// Description: Data Memory (DMEM) - 64 KiB True Dual-Port Synchronous RAM
//              **SYNCHRONOUS READ/WRITE** on both ports for M10K Block RAM
//              Pure synchronous design for simulation and synthesis
// ============================================================================
module dmem(
  input  logic        i_clk,        // Clock
  input  logic        i_reset,      // Active-low reset (unused, memory persists)
  
  // Port A - Synchronous Read/Write
  input  logic [13:0] address_a,    // Word index [13:0] (16K words = 64 KiB)
  input  logic [31:0] data_a,       // Write data (32-bit word)
  input  logic [3:0]  wren_a,       // Byte write enables [3:0]
  output logic [31:0] q_a,          // Read data (32-bit word, REGISTERED)
  
  // Port B - Synchronous Read/Write
  input  logic [13:0] address_b,    // Word index [13:0] (16K words = 64 KiB)
  input  logic [31:0] data_b,       // Write data (32-bit word)
  input  logic [3:0]  wren_b,       // Byte write enables [3:0]
  output logic [31:0] q_b           // Read data (32-bit word, REGISTERED)
);

  localparam DEPTH = 16384;           // 16384 words × 4 bytes = 64 KiB

  // Memory array with FPGA BRAM synthesis attributes
  (* ramstyle = "M10K" *)             // Quartus: Force M10K block RAM
  (* ram_style = "block" *)           // Vivado: Force block RAM  
  logic [31:0] mem [0:DEPTH-1];

`ifndef SYNTHESIS
  // Initialize memory to 0 for simulation (synthesis tools ignore initial blocks)
  // This prevents X (unknown) values during simulation which cause undefined behavior
  initial begin
    integer i;
    for (i = 0; i < DEPTH; i = i + 1) begin
      mem[i] = 32'h0;
    end
  end
`endif

  // Addresses are already word indices, use directly
  logic [13:0] word_addr_a, word_addr_b;
  assign word_addr_a = address_a;   // Already a word index
  assign word_addr_b = address_b;   // Already a word index

  // ===========================================================================
  // Port A: Synchronous Read + Synchronous Write with byte enables
  // ===========================================================================
  always_ff @(posedge i_clk) begin
    // Write (per-byte enables)
    if (wren_a[0]) mem[word_addr_a][7:0]   <= data_a[7:0];    // Byte 0
    if (wren_a[1]) mem[word_addr_a][15:8]  <= data_a[15:8];   // Byte 1
    if (wren_a[2]) mem[word_addr_a][23:16] <= data_a[23:16];  // Byte 2
    if (wren_a[3]) mem[word_addr_a][31:24] <= data_a[31:24];  // Byte 3
    
    // Read (always registered, independent of write)
    q_a <= mem[word_addr_a];
  end

  // ===========================================================================
  // Port B: Synchronous Read + Synchronous Write with byte enables
  // ===========================================================================
  always_ff @(posedge i_clk) begin
    // Write (per-byte enables)
    if (wren_b[0]) mem[word_addr_b][7:0]   <= data_b[7:0];    // Byte 0
    if (wren_b[1]) mem[word_addr_b][15:8]  <= data_b[15:8];   // Byte 1
    if (wren_b[2]) mem[word_addr_b][23:16] <= data_b[23:16];  // Byte 2
    if (wren_b[3]) mem[word_addr_b][31:24] <= data_b[31:24];  // Byte 3
    
    // Read (always registered, independent of write)
    q_b <= mem[word_addr_b];
  end



endmodule
