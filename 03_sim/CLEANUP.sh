#!/bin/bash
echo "Cleaning up 03_sim directory..."

# Remove compiled simulation files (can be regenerated)
rm -f sim.vvp sim_hexled.vvp

# Remove log files
rm -f compile.log sim.log

# Keep VCD for debugging but note it can be regenerated
echo "Kept dump.vcd (can be regenerated with 'make' or './run_hexled_test.sh')"

echo ""
echo "Remaining files:"
ls -lh
