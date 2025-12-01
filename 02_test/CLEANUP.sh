#!/bin/bash
# Clean up project - remove intermediate files

echo "Cleaning up 02_test directory..."

# Remove all compiled binaries and object files
rm -f *.bin *.o

# Remove old/experimental Python generators
rm -f create_fast_counter.py gen_bcd_counter.py gen_bcd_simple.py gen_counter.py

# Remove intermediate assembly versions (keep only final working one)
rm -f counter_bcd_simple.s counter_minimal.s counter_pause.s stopwatch_full.s test_static.s test_hexled_init.s

# Remove intermediate hex versions (keep only final and ISA tests)
rm -f counter_bcd_simple.hex counter_minimal.hex counter_pause.hex stopwatch_full.hex test_static.hex test_counter_simple.hex counter_v3.hex counter_v3_hardware.hex

# Rename final working version to have clear name
mv stopwatch_inline.hex stopwatch_fast.hex 2>/dev/null || true
mv stopwatch_inline.s stopwatch.s 2>/dev/null || true

# Create symbolic link for compatibility
ln -sf stopwatch_fast.hex counter_v3_fast.hex

echo "Cleanup complete!"
echo ""
echo "Remaining files:"
ls -lh
