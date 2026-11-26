#!/bin/bash
cd /work
L=asap7_libs
sed 's/x/x/' /dev/null
chk() {  # tag gold.v gate.v top
  cat > /tmp/f_$1.ys << EOF
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_SLVT_TT.lib
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_RVT_TT.lib
read_verilog -sv $2
rename $4 gold
read_verilog -sv $3
rename $4 gate
proc
flatten
opt_clean
miter -equiv -make_outputs gold gate miter
hierarchy -top miter
flatten
opt_clean
tee -o /tmp/f_$1.stat stat
sat -prove trigger 0 -show-ports -timeout 600 miter
EOF
  yosys -s /tmp/f_$1.ys > run/f_$1.log 2>&1
  cells=$(grep "Number of cells" /tmp/f_$1.stat | tail -1 | awk '{print $NF}')
  imp=$(grep -m1 "Imported" run/f_$1.log)
  verdict=$(grep -m1 -E "no model found|model found" run/f_$1.log)
  err=$(grep -m1 -i "^ERROR" run/f_$1.log)
  echo "$1 | miter cells=$cells | $imp | $verdict $err"
}

echo "##### Method A: miter + SAT (now printing what is inside the miter) #####"
chk c432_final      iscas85/c432.v   run/c432_final_mvt.v    c432
chk c432_BROKEN     iscas85/c432.v   /tmp/c432_broken.v       c432
chk c2670_synth     iscas85/c2670.v  run/c2670_synth_SLVT.v   c2670
chk c2670_final     iscas85/c2670.v  run/c2670_final_mvt.v    c2670
chk c7552_final     iscas85/c7552.v  run/c7552_final_mvt.v    c7552
echo
echo "--- ports compared in the c432 miter (log lines) ---"
grep -i -E "miter|ports|inputs|outputs" run/f_c432_final.log | head -8
echo
echo "##### Method B: yosys equiv_* flow (independent) #####"
eqb() {
  cat > /tmp/g_$1.ys << EOF
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_SLVT_TT.lib
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_RVT_TT.lib
read_verilog -sv $2
rename $4 gold
read_verilog -sv $3
rename $4 gate
proc
flatten
opt_clean
equiv_make gold gate eq
hierarchy -top eq
equiv_simple -undef
equiv_induct
equiv_status
EOF
  yosys -s /tmp/g_$1.ys > run/g_$1.log 2>&1
  echo "$1 | $(grep -E 'Found [0-9]+ \$equiv cells|Of those cells' run/g_$1.log | tr '\n' ' ') | $(grep -m1 -i '^ERROR' run/g_$1.log)"
  grep -E "Equivalence successfully proven|unproven" run/g_$1.log | head -2
}
eqb c432_final   iscas85/c432.v run/c432_final_mvt.v c432
eqb c432_BROKEN  iscas85/c432.v /tmp/c432_broken.v   c432
eqb c2670_final  iscas85/c2670.v run/c2670_final_mvt.v c2670
echo "#### DONE ####"
