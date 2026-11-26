#!/bin/bash
cd /work
L=asap7_libs
echo "##### A: constant-tie nets in the written netlists #####"
for f in run/c2670_final_mvt.v run/s38417_flatfinal_TT.v run/s38584_flatfinal_TT.v run/s38584_flat_SLVT.v; do
  echo "$f : zero_/one_ mentions=$(grep -c -E '\b(zero_|one_)\b' $f)  driven(assign)=$(grep -c -E 'assign +(zero_|one_)' $f)"
done
grep -n -E "\b(zero_|one_)\b" run/s38584_flatfinal_TT.v | head -6
echo

echo "##### B: replay of 04_synthesize_all.sh (no flatten) - dff instances after each step #####"
for c in s38584 s38417; do
  SEQ_LIB=$(ls $L/asap7sc7p5t_SEQ_SLVT_TT_nldm_*.lib | head -1)
  cat > /tmp/replay_$c.ys << EOF
read_verilog -sv iscas89/ISCAS89/$c.v
hierarchy -check -top $c
proc
log ### after proc
select -count t:dff
opt
log ### after opt
select -count t:dff
fsm
opt
log ### after fsm+opt
select -count t:dff
memory
opt
log ### after memory+opt
select -count t:dff
techmap
opt
log ### after techmap+opt
select -count t:dff
dfflibmap -liberty $SEQ_LIB
abc -liberty $L/combined_SLVT_TT.lib
clean
log ### after dfflibmap+abc+clean
select -count t:dff
EOF
  echo "== $c (start: $(grep -c '^ *dff ' iscas89/ISCAS89/$c.v) dff instances in the source)"
  yosys -s /tmp/replay_$c.ys 2>&1 | grep -E "^### |objects\." | paste - - | sed 's/\s\+/ /g'
done
echo "(your real synthesized netlists have 1416 (s38584) and 1564 (s38417) dff instances)"
echo

echo "##### C: bounded sequential equivalence, 8 clock cycles from all-zero state #####"
bmc() {  # tag gold gate top depth
  cat > /tmp/b_$1.ys << EOF
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
sat -seq $5 -set-init-zero -prove trigger 0 -timeout 1500 miter
EOF
  t0=$(date +%s)
  timeout 1800 yosys -s /tmp/b_$1.ys > run/bmc_$1.log 2>&1
  t1=$(date +%s)
  v=$(grep -m1 -E "no model found|model found|[Tt]imeout" run/bmc_$1.log | sed 's/SAT proof finished - //')
  [ -z "$v" ] && v="ERROR: $(grep -m1 -i error run/bmc_$1.log)"
  echo "$1 (depth $5): $v   [$((t1-t0)) s]"
}
cp run/s38417_flatfinal_TT.v /tmp/s38417_broken.v
sed -i '0,/NAND2xp33_ASAP7_75t_R/s//NOR2xp33_ASAP7_75t_R/' /tmp/s38417_broken.v
bmc s38417_final   iscas89/ISCAS89/s38417.v run/s38417_flatfinal_TT.v s38417 8
bmc s38417_BROKEN  iscas89/ISCAS89/s38417.v /tmp/s38417_broken.v      s38417 8
bmc s38584_final   iscas89/ISCAS89/s38584.v run/s38584_flatfinal_TT.v s38584 8
echo "#### DONE ####"
