# RISC-V Pipelined Processor (RV32I, Model FWD_AT)

5-stage pipelined RV32I core for the Terasic DE10-Standard. The design implements the Forwarding + Always-Taken (BTB-based) model from `04_doc/specification.md`, exposes commit/debug signals, and includes a BCD stopwatch demo plus ISA test programs.

---

## 🎯 Project Overview

Key traits of the current architecture:
- **Pipeline**: IF/ID/EX/MEM/WB with EX→MEM and MEM→WB forwarding; 1-cycle load-use stall and branch data stalls when forwarding cannot cover ID.
- **Branch prediction**: Small BTB drives an always-taken-on-hit policy (Model FWD_AT, `o_model_id = 4'd2`); mispredicts flush and redirect in ID.
- **Memory map**: 64 KiB RAM at `0x0000_0000`–`0x0000_FFFF`, memory-mapped LEDs/HEX/LCD at `0x1000_xxxx`, switches at `0x1001_xxxx`.
- **Peripherals**: Active-low 7-seg outputs, LEDR/LEDG, LCD, switches; halt on store to `0xFFFF_FFFC`.
- **Demo/Tests**: ISA test images (default `isa_test_32bit.hex`), stopwatch demo (fast and hardware-timed variants), and testbenches under `01_bench/`.

---

## 📁 Project Structure

```
riscv/
├── 00_src/               # RTL
│   ├── pipelined.sv      # Top-level core (Model FWD_AT, commit/debug ports)
│   ├── wrapper.sv        # Board wrapper/helper
│   ├── stage_if/id/ex/mem.sv, stage_ex.sv  # Pipeline stages
│   ├── if_id_reg.sv, id_ex_reg.sv, ex_mem_reg.sv, mem_wb_reg.sv
│   ├── hazard_unit.sv, forwarding_unit.sv  # Hazard + forwarding
│   ├── control_unit.sv, imm_gen.sv, alu.sv, brc.sv, regfile.sv
│   ├── i_mem.sv, dmem.sv, lsu.sv           # Memories + LSU
│   ├── input_mux.sv, output_mux.sv, input_buffer.sv, output_buffer.sv
│   └── clock_10M.sv, misc helpers (mux2_1.sv, FA_32bit.sv)
├── 01_bench/             # Testbenches (ISA + HEXLED)
│   ├── tbench.sv, tb_hexled.sv
│   ├── driver.sv
│   └── scoreboard.sv     # Collects PASS/FAIL and IPC/mispredict stats
├── 02_test/              # Program images
│   ├── isa_test_32bit.hex (default IMEM preload), isa_test.hex, isa_1b.hex, isa_4b.hex
│   ├── dmem_init_32bit.hex, dmem_init_file.hex
│   ├── stopwatch.s / stopwatch_fast.hex / stopwatch_hardware.s / stopwatch_hardware.hex
│   └── link.ld, cleanup helpers
├── 03_sim/               # Icarus simulation
│   ├── flist, flist_hexled
│   ├── makefile, run_hexled_test.sh
│   └── sim logs/artifacts (compile.log, sim.vvp, wave.vcd)
├── 04_doc/               # Specs and constraints
│   ├── specification.md  # Pipeline model + top-level contract
│   ├── de10_pin_assign.qsf, DE2_pin_assignments.csv
│   └── timing_constraints.sdc
└── netlist/              # Yosys synthesis scripts, logs, JSON netlists
```

---

## 🚀 Quick Start

Run ISA tests (default IMEM preload `02_test/isa_test_32bit.hex`):
```bash
cd 03_sim
make clean
make create_filelist
make sim          # scoreboard prints PASS/FAIL and stats
```

Run the stopwatch (fast) HEXLED test:
```bash
cd 03_sim
./run_hexled_test.sh
```

---

## 🏗️ Core Architecture

- **Stages**: IF (BTB lookup + PC select), ID (decode, imm_gen, branch compare, predictor resolution), EX (ALU + branch target calc), MEM (LSU, DMEM/I/O decode, byte enables), WB (load sign/zero-extend, writeback).
- **Hazards/Forwarding**: EX/MEM and MEM/WB forwarding for ALU and branch operands; 1-cycle stall on load-use; stalls if branch/JALR needs a value not yet forwardable.
- **Branching**: BTB hit predicts taken; miss predicts sequential. ID resolves and signals mispredict flush; BTB updates on each branch/jump.
- **Halt**: Store to `0xFFFF_FFFC` flushes and freezes the pipeline (`o_halt` high).
- **Instrumentation**: `o_pc_frontend` (IF PC), `o_pc_commit` (WB PC), `o_insn_vld`, `o_ctrl` (branch/jump commit), `o_mispred`, `o_model_id=4'd2`.

### Top-Level Ports (`pipelined`)
```systemverilog
module pipelined (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic [31:0] i_io_sw,
    output logic [31:0] o_io_ledr,
    output logic [31:0] o_io_ledg,
    output logic [6:0]  o_io_hex0, o_io_hex1, o_io_hex2, o_io_hex3,
    output logic [6:0]  o_io_hex4, o_io_hex5, o_io_hex6, o_io_hex7,
    output logic [31:0] o_io_lcd,
    output logic [31:0] o_pc_frontend,
    output logic [31:0] o_pc_commit,
    output logic        o_insn_vld,
    output logic        o_ctrl,
    output logic        o_mispred,
    output logic        o_halt,
    output logic [3:0]  o_model_id
);
```

### Memory Map

| Region        | Address Range             | Description                 |
|---------------|---------------------------|-----------------------------|
| RAM           | 0x0000_0000–0x0000_FFFF   | 64 KiB DMEM / IMEM preload |
| LEDR          | 0x1000_0000–0x1000_0FFF   | Red LEDs                   |
| LEDG          | 0x1000_1000–0x1000_1FFF   | Green LEDs                 |
| HEX0–HEX3     | 0x1000_2000–0x1000_2FFF   | 7-seg lower digits         |
| HEX4–HEX7     | 0x1000_3000–0x1000_3FFF   | 7-seg upper digits         |
| LCD           | 0x1000_4000–0x1000_4FFF   | LCD register               |
| Switches      | 0x1001_0000–0x1001_0FFF   | Switch input               |

---

## 🔧 Program Images

- **ISA**: `isa_test_32bit.hex` (default IMEM load), plus legacy `isa_test.hex`, `isa_1b.hex`, `isa_4b.hex`.
- **Stopwatch (fast)**: `stopwatch_fast.hex` — quick sim version.
- **Stopwatch (hardware)**: `stopwatch_hardware.hex` — real-time delay for FPGA.
- **DMEM init**: `dmem_init_32bit.hex` (default), `dmem_init_file.hex` (legacy).

To swap IMEM contents, change the `$readmemh` path in `00_src/i_mem.sv` and rerun simulation/synthesis.

---

## 🛠️ Build & Modify

Prereqs: `iverilog`, `vvp`, optional RISC-V binutils for assembling new programs.

Simulation workflow:
```bash
cd 03_sim
make clean
make sim              # ISA tests
./run_hexled_test.sh  # Stopwatch demo
```

Assemble a new stopwatch (fast):
```bash
cd 02_test
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o stopwatch.o stopwatch.s
riscv64-unknown-elf-objcopy -O binary stopwatch.o stopwatch.bin
hexdump -v -e '1/4 "%08x\n"' stopwatch.bin > stopwatch_fast.hex
```
Then point `i_mem.sv` at the new hex and rerun `make sim`.

---

## 🐛 Debugging Tips

- Monitor `o_pc_frontend`/`o_pc_commit`, `o_insn_vld`, `o_ctrl`, `o_mispred`, `o_halt` in waveforms to spot pipeline/control issues.
- Branch behavior lives in `stage_if.sv` (BTB/predict) and `stage_id.sv` (resolution/flush). Data hazards are handled by `hazard_unit.sv` and `forwarding_unit.sv`.
- LSU/IO path is in `stage_mem.sv` with decode helper `input_mux.sv`.

---

## 📚 Documentation

- `04_doc/specification.md` — authoritative pipeline model (Model FWD_AT) and port contract.
- `04_doc/de10_pin_assign.qsf`, `04_doc/timing_constraints.sdc` — board constraints.
- `netlist/*.ys` + `.json` — Yosys synthesis scripts/artifacts.

---

**Project Status**: Pipelined RV32I core with forwarding + BTB prediction; simulation flow exercises ISA and stopwatch programs. Run `03_sim/make sim` to validate locally.
