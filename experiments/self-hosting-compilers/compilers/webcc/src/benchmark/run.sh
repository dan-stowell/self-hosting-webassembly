#!/bin/bash
set -e

# Ensure we are in the benchmark directory
cd "$(dirname "$0")"

echo "========================================"
echo " Building WebCC Benchmark"
echo "========================================"

# Build WebCC benchmark
pushd webcc
../../webcc main.cc --out dist
echo "WebCC Build Complete."
ls -lh dist/app.wasm dist/app.js
popd

echo ""
echo "========================================"
echo " Building Emscripten Benchmark"
echo "========================================"

# Build Emscripten benchmark
pushd emscripten
mkdir -p dist
emcc main.cc -O3 -o dist/index.html --bind -s ALLOW_MEMORY_GROWTH=1 --shell-file shell.html
echo "Emscripten Build Complete."
ls -lh dist/index.wasm dist/index.js
popd

echo ""
echo "========================================"
echo " Running Benchmark"
echo "========================================"
python3 runner.py --no-build
