`timescale 1ns/1ps

// Simple test to verify synchronous i_mem with pre-fetch works correctly
module test_sync_fetch;

logic clk, rst;
logic [31:0] pc, instr, imem_addr, imem_data;

// Clock
initial begin
  clk = 0;
  forever #5 clk = ~clk;
end

// Test sequence
initial begin
  $display("\n=== Testing Synchronous i_mem with Pre-fetch ===\n");
  rst = 0;
  #20;
  rst = 1;
  #300;
  $display("\n=== Test Complete ===");
  $finish;
end

// Monitor
initial begin
  $monitor("T=%0t rst=%b PC=%h imem_addr=%h imem_data=%h instr=%h", 
           $time, rst, pc, imem_addr, imem_data, instr);
end

// Synchronous i_mem
i_mem imem (
  .i_clk(clk),
  .i_addr(imem_addr),
  .o_data(imem_data)
);

// Simple PC simulation
logic [31:0] pc_next;
assign pc_next = pc + 4;

always @(posedge clk) begin
  if (!rst) pc <= 32'hFFFFFFFC;  // Start at -4
  else pc <= pc_next;
end

// Pre-fetch: send next PC to memory
assign imem_addr = pc_next;

// IF/ID register simulation
always @(posedge clk) begin
  if (!rst) instr <= 32'h00000013;
  else instr <= imem_data;
end

endmodule
