`define RESETPERIOD 55
`define TIMEOUT     200_000

`include "../00_src/pipelined.sv"

module tbench;

`include "tlib.svh"

// Clock and reset generator
  logic clk;
  logic rstn;

  // Clock Generation
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // Reset Generation
  initial begin
    rstn = 0;
    #`RESETPERIOD;
    rstn = 1;
  end

  initial tsk_timeout  (`TIMEOUT);

// Wave dumping
  initial begin : proc_dump_wave
    $dumpfile("wave.vcd");
    $dumpvars(0, tbench);
  end

  logic [31:0]  pc_frontend;
  logic [31:0]  pc_commit;
  logic [31:0]  io_sw  ;
  logic [31:0]  io_lcd ;
  logic [31:0]  io_ledr;
  logic [31:0]  io_ledg;
  logic [ 6:0]  io_hex0;
  logic [ 6:0]  io_hex1;
  logic [ 6:0]  io_hex2;
  logic [ 6:0]  io_hex3;
  logic [ 6:0]  io_hex4;
  logic [ 6:0]  io_hex5;
  logic [ 6:0]  io_hex6;
  logic [ 6:0]  io_hex7;
  logic         ctrl    ;
  logic         mispred ;
  logic         insn_vld;
  logic         halt;
  logic [3:0]   model_id;


  pipelined dut (
    .i_clk     (clk      ),
    .i_reset   (rstn     ),
    // Input peripherals
    .i_io_sw   (io_sw    ),
    // Output peripherals
    .o_io_lcd  (io_lcd   ),
    .o_io_ledr (io_ledr  ),
    .o_io_ledg (io_ledg  ),
    .o_io_hex0 (io_hex0  ),
    .o_io_hex1 (io_hex1  ),
    .o_io_hex2 (io_hex2  ),
    .o_io_hex3 (io_hex3  ),
    .o_io_hex4 (io_hex4  ),
    .o_io_hex5 (io_hex5  ),
    .o_io_hex6 (io_hex6  ),
    .o_io_hex7 (io_hex7  ),
    // Commit interface
    .o_pc_frontend(pc_frontend),
    .o_pc_commit  (pc_commit  ),
    .o_insn_vld   (insn_vld   ),
    .o_ctrl       (ctrl       ),
    .o_mispred    (mispred    ),
    .o_halt       (halt       ),
    .o_model_id   (model_id   )
  );

  // Debug: Monitor LEDR at TB level
  always @(posedge clk) begin
    if ($time > 200 && $time < 1500) begin
      $display("TBENCH @%0t (posedge): io_ledr=0x%08h", $time, io_ledr);
    end
  end




  driver driver (
    .i_clk  (clk   ),
    .i_reset(rstn  ),
    .i_io_sw(io_sw )
  );


  scoreboard  scoreboard(
    .i_clk     (clk      ),
    .i_reset   (rstn     ),
    // Input peripherals
    .i_io_sw   (io_sw    ),
    // Output peripherals
    .o_io_lcd  (io_lcd   ),
    .o_io_ledr (io_ledr  ),
    .o_io_ledg (io_ledg  ),
    .o_io_hex0 (io_hex0  ),
    .o_io_hex1 (io_hex1  ),
    .o_io_hex2 (io_hex2  ),
    .o_io_hex3 (io_hex3  ),
    .o_io_hex4 (io_hex4  ),
    .o_io_hex5 (io_hex5  ),
    .o_io_hex6 (io_hex6  ),
    .o_io_hex7 (io_hex7  ),
    // Debug
    .o_ctrl    (ctrl     ),
    .o_mispred (mispred  ),
    .o_pc_commit(pc_commit),
    .o_insn_vld(insn_vld ),
    .o_halt    (halt     )
  );





endmodule : tbench


