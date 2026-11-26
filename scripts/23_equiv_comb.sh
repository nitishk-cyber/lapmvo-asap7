#!/bin/bash
cd /work
L=asap7_libs
echo "circuit,result,seconds"
for c in c432 c880 c1908 c2670 c5315 c7552; do
  cat > /tmp/eq_$c.ys << EOF
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_SLVT_TT.lib
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_RVT_TT.lib
read_verilog -sv iscas85/$c.v
rename $c gold
read_verilog run/${c}_final_mvt.v
rename $c gate
proc
miter -equiv -flatten gold gate miter
hierarchy -top miter
opt -fast
sat -verify -prove trigger 0 -timeout 1200 miter
EOF
  t0=$(date +%s)
  timeout 1500 yosys -s /tmp/eq_$c.ys > run/equiv_$c.log 2>&1
  t1=$(date +%s)
  if grep -q "no model found" run/equiv_$c.log; then r=EQUIVALENT
  elif grep -q "model found" run/equiv_$c.log; then r=NOT_EQUIVALENT
  elif grep -qi "timeout\|interrupted" run/equiv_$c.log; then r=TIMEOUT
  else r="ERROR: $(grep -i 'error' run/equiv_$c.log | head -1)"; fi
  echo "$c,$r,$((t1-t0))"
done
echo "#### DONE ####"
