#!/bin/bash
# Run unit tests for verification plan

echo "========================================="
echo "Running Unit Tests (Verification Phase 1)"
echo "========================================="

# Compile
echo "Compiling unit tests..."
iverilog -g2012 -o unit_test.vvp -f flist_unit

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed"
    exit 1
fi

echo "Compilation successful"
echo ""

# Run
echo "Running tests..."
vvp unit_test.vvp

echo ""
echo "Unit tests complete"
