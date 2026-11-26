#!/bin/bash
cd /work
L=asap7_libs
eq() {  # name, gold.v, gate.v, top
  cat > /tmp/e_$1.ys << EOF
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_SLVT_TT.lib
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_RVT_TT.lib
read_verilog -sv $2
rename $4 gold
read_verilog -sv $3
rename $4 gate
proc
miter -equiv -flatten gold gate miter
hierarchy -top miter
opt -fast
sat -verify -prove trigger 0 -timeout 600 miter
EOF
  yosys -s /tmp/e_$1.ys > run/diag_$1.log 2>&1
  if grep -q "SUCCESS" run/diag_$1.log; then r=EQUIVALENT
  elif grep -q "FAIL" run/diag_$1.log; then r=DIFFERENT
  else r="ERROR: $(grep -i -m1 error run/diag_$1.log)"; fi
  echo "$1 : $r"
}

echo "##### c2670 diagnosis #####"
eq c2670_src_vs_synth  iscas85/c2670.v           run/c2670_synth_SLVT.v  c2670
eq c2670_synth_vs_final run/c2670_synth_SLVT.v   run/c2670_final_mvt.v   c2670
eq c2670_src_vs_synthRVT iscas85/c2670.v         run/c2670_synth_RVT.v   c2670
echo
echo "--- warnings when reading the c2670 source (first 8) ---"
yosys -q -p "read_verilog -sv iscas85/c2670.v" 2>&1 | grep -i -E "warning|undriven|multiple" | head -8
echo "--- count of x / z constants in the source ---"
grep -c -i -E "1.bx|1.bz|.bx|'bx" iscas85/c2670.v
echo "--- last lines of the failing proof log ---"
tail -14 run/equiv_c2670.log

echo
echo "##### negative control: deliberately break one gate in c432 #####"
cp run/c432_final_mvt.v /tmp/c432_broken.v
sed -i '0,/NAND2xp33_ASAP7_75t_/s//NOR2xp33_ASAP7_75t_/' /tmp/c432_broken.v
diff <(cat run/c432_final_mvt.v) /tmp/c432_broken.v | head -4
eq c432_control iscas85/c432.v /tmp/c432_broken.v c432
echo "(expected: DIFFERENT)"
echo "#### DONE ####"
