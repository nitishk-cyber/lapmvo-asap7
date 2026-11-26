#!/bin/bash
set -e

echo "=== Cloning ISCAS-85 netlists (pre-synthesized Genus gate-level) ==="
if [ ! -d iscas85 ]; then
  git clone --depth 1 https://github.com/jpsety/verilog_benchmark_circuits.git iscas85
fi

echo "=== Cloning ISCAS-89 netlists (behavioral, incl. real DFF cells) ==="
if [ ! -d iscas89 ]; then
  git clone --depth 1 https://github.com/santoshsmalagi/Benchmarks.git iscas89
fi

echo "=== Verifying required circuits are present ==="
for c in c432 c880 c1908 c2670 c5315 c7552; do
  test -f iscas85/${c}.v && echo "OK: iscas85/${c}.v" || echo "MISSING: ${c}.v"
done
for c in s38417 s38584; do
  test -f iscas89/ISCAS89/${c}.v && echo "OK: iscas89/ISCAS89/${c}.v" || echo "MISSING: ${c}.v"
done

echo "Done."
