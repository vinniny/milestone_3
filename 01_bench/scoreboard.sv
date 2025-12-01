`include "../00_src/pipelined.sv"

module scoreboard(
  input  logic         i_clk     ,
  input  logic         i_reset   ,
  // Input peripherals
  input  logic [31:0]  i_io_sw   ,
  // Output peripherals
  input  logic [31:0]  o_io_ledr ,
  input  logic [31:0]  o_io_ledg ,
  input  logic [ 6:0]  o_io_hex0 ,
  input  logic [ 6:0]  o_io_hex1 ,
  input  logic [ 6:0]  o_io_hex2 ,
  input  logic [ 6:0]  o_io_hex3 ,
  input  logic [ 6:0]  o_io_hex4 ,
  input  logic [ 6:0]  o_io_hex5 ,
  input  logic [ 6:0]  o_io_hex6 ,
  input  logic [ 6:0]  o_io_hex7 ,
  input  logic [31:0]  o_io_lcd  ,
  // Debug
  input  logic         o_ctrl    ,
  input  logic         o_mispred ,
  input  logic [31:0]  o_pc_commit,
  input  logic         o_insn_vld,
  input  logic         o_halt
);

  real num_cycle;      // Number of execution cycles
  real num_insn;       // Number of valid instructions
  real num_ctrl;       // Number of control transfer instructions
  real num_mispred;    // Number of Misprediction
  real ipc;            // Instructino Per Cycle
  real misprd_rate;    // Misprediction Rate

  // Test tracking
  int test_count;
  int pass_count;
  int fail_count;
  int error_count;
  string current_line;
  logic [31:0] prev_ledr;

  // Display test name
  initial begin
    $display("\nPIPELINE - ISA tests\n");
    test_count = 0;
    pass_count = 0;
    fail_count = 0;
    error_count = 0;
    current_line = "";
    prev_ledr = 32'b0;
  end


  always @(negedge i_clk) begin : counters
      if (!i_reset) begin
        num_cycle   <= '0;
        num_ctrl    <= '0;
        num_insn    <= '0;
        num_mispred <= '0;
      end
      else begin
        num_cycle   <=              num_cycle   + 1;
        num_ctrl    <= o_ctrl     ? num_ctrl    + 1 : num_ctrl;
        num_insn    <= o_insn_vld ? num_insn    + 1 : num_insn;
        num_mispred <= o_mispred  ? num_mispred + 1 : num_mispred;
      end
  end


  always @(negedge i_clk) begin : debug
      // verilator lint_off BLKSEQ
      // Testbench code: blocking assignments are intentional for immediate updates
      // Debug: Sample LEDR values at negedge
      if ($time > 200 && $time < 1500) begin
          $display("SCOREBOARD @%0t (negedge): o_io_ledr=0x%08h prev_ledr=0x%08h", 
                   $time, o_io_ledr, prev_ledr);
      end
      
      // Monitor LEDR changes to capture test output
      // Use negedge to sample after posedge register updates
      if (o_io_ledr != prev_ledr) begin
          logic [7:0] char_out;
          
          char_out = o_io_ledr[7:0];
          
          // Accumulate characters into line buffer
          if (char_out == 8'h0A) begin  // newline
              // Process complete line
              string line_buffer;
              line_buffer = current_line;
              
              // Check for PASS/FAIL/ERROR in the line
              if (line_buffer.len() > 4) begin
                  // Look for test result patterns
                  if (line_buffer.substr(line_buffer.len()-4, line_buffer.len()-1) == "PASS") begin
                      pass_count = pass_count + 1;
                      test_count = test_count + 1;
                  end else if (line_buffer.substr(line_buffer.len()-4, line_buffer.len()-1) == "FAIL") begin
                      fail_count = fail_count + 1;
                      test_count = test_count + 1;
                  end else if (line_buffer.len() > 5 && line_buffer.substr(line_buffer.len()-5, line_buffer.len()-1) == "ERROR") begin
                      error_count = error_count + 1;
                      test_count = test_count + 1;
                  end
              end
              
              // Print the line
              $display("%s", current_line);
              current_line = "";
          end else if (char_out >= 8'h20 && char_out < 8'h7F) begin  // printable ASCII
              current_line = {current_line, string'(char_out)};
          end
          
          prev_ledr = o_io_ledr;  // Update with blocking assignment (testbench code)
      end
      // verilator lint_on BLKSEQ
  end


  always @(negedge i_clk) begin : halt
      if (o_halt) begin
        $display("\nResult\n");

        if (num_cycle != 0) $display("IPC          = %1.2f", num_insn/num_cycle);
        else                $display("IPC          = N/A");

        if (num_ctrl != 0)  $display("Mispred Rate = %2.2f %%", num_mispred/num_ctrl*100);
        else                $display("Mispred Rate = N/A");

        $display("\nEND of ISA tests\n");
        
        // Print test summary
        if (test_count > 0) begin
            $display("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            $display("Test Summary:");
            $display("  Total Tests: %0d", test_count);
            $display("  Passed:      %0d", pass_count);
            if (fail_count > 0) 
                $display("  Failed:      %0d", fail_count);
            if (error_count > 0)
                $display("  Errors:      %0d", error_count);
            $display("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            
            if (fail_count == 0 && error_count == 0) begin
                $display("✅ ALL TESTS PASSED");
            end else begin
                $display("❌ SOME TESTS FAILED");
            end
        end
        
        $finish;
      end
  end




endmodule : scoreboard







