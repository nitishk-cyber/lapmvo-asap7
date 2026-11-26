#!/bin/bash
cd /work
L=/work/asap7_libs
STA=/work/opensta_src/build/sta

cat > /tmp/patch_zero.py << 'PY'
import re, shutil, os
for f in ["run/s38584_flatfinal_TT.v", "run/s38584_flatfinal_SS.v", "run/s38584_flatfinal_FF.v"]:
    t = open(f).read()
    n_use = len(re.findall(r"\bzero_\b", t))
    has_asg = re.search(r"assign\s+zero_\s*=", t) is not None
    has_wire = re.search(r"\bwire\s+zero_\b", t) is not None
    if n_use and not has_asg:
        if not os.path.exists(f + ".prepatch2"):
            shutil.copy(f, f + ".prepatch2")
        i = t.rfind("endmodule")
        add = ("" if has_wire else " wire zero_;\n") + " assign zero_ = 1'h0;\n"
        open(f, "w").write(t[:i] + add + t[i:])
        print("%-30s zero_ uses=%d  PATCHED (wire declared before: %s)" % (f, n_use, has_wire))
    else:
        print("%-30s zero_ uses=%d  no patch needed (assign present: %s)" % (f, n_use, has_asg))
PY

echo "--- DFF_1421 in the pre-LA-PMVO flat netlist ---"
grep -n -E "DFF_1421" run/s38584_flat_SLVT.v | head -6
python3 /tmp/patch_zero.py
echo "--- zero_ lines after patch (TT) ---"
grep -n -E "\bzero_\b" run/s38584_flatfinal_TT.v | head -6

cat > /tmp/mz.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(NETLIST)
link_design $::env(CKT)
create_clock -name clk -period $::env(PERIOD) [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]
puts "WNS_SETUP: [worst_slack -max]"
puts "WNS_HOLD: [worst_slack -min]"
report_power -digits 6
EOF
m() {
  LIBS=""
  for vt in SLVT RVT; do for g in SIMPLE INVBUF SEQ; do LIBS="$LIBS $(ls $L/asap7sc7p5t_${g}_${vt}_$3_nldm_*.lib | head -1)"; done; done
  export LIBS CKT=s38584 NETLIST=$1 PERIOD=$2
  out=$($STA -no_init -exit /tmp/mz.tcl 2>&1)
  s=$(echo "$out" | grep WNS_SETUP | awk '{print $2}'); h=$(echo "$out" | grep WNS_HOLD | awk '{print $2}'); l=$(echo "$out" | grep "^Total" | awk '{print $4}')
  python3 -c "print('s38584 %-2s setup=%8.2f hold=%6.2f leak=%9.2f nW   (before: %s)' % ('$3',float('$s'),float('$h'),float('$l')*1e9,'$4'))"
}
echo "--- re-measure on the repaired finals ---"
m run/s38584_flatfinal_TT.v 1911.59 TT "setup 3.24 hold 0.00 leak 669.73"
m run/s38584_flatfinal_SS.v 2847.55 SS "setup 158.37 hold -0.43 leak 8612.22"
m run/s38584_flatfinal_FF.v 1494.93 FF "setup 102.07 hold -1.37 leak 539.63"

echo
echo "##### bounded sequential equivalence, 8 clock cycles from all-zero state (SEQ models loaded) #####"
SEQ_S=$(ls $L/asap7sc7p5t_SEQ_SLVT_TT_nldm_*.lib | head -1)
SEQ_R=$(ls $L/asap7sc7p5t_SEQ_RVT_TT_nldm_*.lib | head -1)
bmc() {
  cat > /tmp/b_$1.ys << EOF
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_SLVT_TT.lib
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_RVT_TT.lib
read_liberty -ignore_miss_func -ignore_miss_dir $SEQ_S
read_liberty -ignore_miss_func -ignore_miss_dir $SEQ_R
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
awk 'BEGIN{n=0} /NAND2xp33_ASAP7_75t_R/ && n<50 {sub(/NAND2xp33_ASAP7_75t_R/,"NOR2xp33_ASAP7_75t_R"); n++} {print}' run/s38417_flatfinal_TT.v > /tmp/s38417_broken.v
echo "(control netlist: $(diff <(cat run/s38417_flatfinal_TT.v) /tmp/s38417_broken.v | grep -c '^>') lines changed)"
bmc s38417_final   iscas89/ISCAS89/s38417.v run/s38417_flatfinal_TT.v s38417 8
bmc s38417_BROKEN  iscas89/ISCAS89/s38417.v /tmp/s38417_broken.v      s38417 8
bmc s38584_final   iscas89/ISCAS89/s38584.v run/s38584_flatfinal_TT.v s38584 8
echo "#### DONE ####"
