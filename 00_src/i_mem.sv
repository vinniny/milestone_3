// ============================================================================
// Module: i_mem
// Description: Instruction Memory (IMEM) - 64 KiB Synchronous ROM
//              **SYNCHRONOUS READ** for M10K Block RAM inference
//              Preloaded from hex file via $readmemh
//              1-cycle read latency (compensated by pre-fetch in stage_if)
// ============================================================================
module i_mem (
  input  logic        i_clk,
  input  logic [31:0] i_addr,              // Byte address input
  output logic [31:0] o_data               // 32-bit instruction output (REGISTERED)
);

  // Memory array with FPGA BRAM synthesis attributes
  (* ramstyle = "M10K" *)        // Quartus: Use M10K block RAM
  (* ram_style = "block" *)      // Vivado: Use block RAM
  (* rom_style = "block" *)      // Additional hint for ROM inference
  logic [31:0] mem [0:16383];    // 16384 words × 4 bytes = 64 KiB

  // Load instruction memory from hex file
  // For FPGA synthesis: Quartus supports $readmemh in initial blocks
  // Memory contents are baked into the FPGA bitstream
  // Initialize all memory to NOP (addi x0, x0, 0) to prevent X-propagation
  initial begin
    integer i;
    for (i = 0; i < 16384; i = i + 1) begin
      mem[i] = 32'h00000013;  // NOP instruction (addi x0, x0, 0)
    end
    $readmemh("../02_test/isa_4b.hex", mem);
  end

  // ===========================================================================
  // SYNCHRONOUS READ: Infers M10K Block RAM
  // ===========================================================================
  // Read has 1-cycle latency. Address at cycle N produces data at cycle N+1.
  // stage_if uses pre-fetch (pc_next) to compensate for this latency.
  // if_id_reg uses standard flip-flops to break combinational loops.
  always_ff @(posedge i_clk) begin
    o_data <= mem[i_addr[15:2]];  // Convert byte address to word address
  end

endmodule

