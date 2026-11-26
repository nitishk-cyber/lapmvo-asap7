#!/bin/bash
cd /work
python3 - << "PY"
import re, shutil, os
def scan(t):
    outs=set()
    for m in re.finditer(r"\boutput\s+(?:\[[^\]]*\]\s*)?([^;]+);", t):
        for n in re.split(r"[,\s]+", m.group(1).strip()):
            if n: outs.add(n)
    drv=set(re.findall(r"\.(?:Y|CON|SN|QN|Q|H|L)\s*\(\s*([^\s()]+)\s*\)", t))
    asg={a for a,b in re.findall(r"assign\s+(\S+)\s*=\s*([^;]+);", t)}
    return sorted(o for o in outs if o not in drv and o not in asg)
jobs = {
 "run/c2670_synth_SLVT.v": ["run/c2670_final_mvt.v","run/c2670_final_mvt_SS.v","run/c2670_final_mvt_FF.v","run/c2670_allRVT.v"],
 "run/s38584_flat_SLVT.v": ["run/s38584_flatfinal_TT.v","run/s38584_flatfinal_SS.v","run/s38584_flatfinal_FF.v"],
}
for ref, files in jobs.items():
    rt = open(ref).read()
    for f in files:
        t = open(f).read()
        und = scan(t)
        add, unres = [], []
        for n in und:
            m = re.search(r"assign\s+"+re.escape(n)+r"\s*=\s*(1.[bh][01]);", rt)
            (add if m else unres).append((n, m.group(1) if m else None))
        if add:
            if not os.path.exists(f+".prepatch"): shutil.copy(f, f+".prepatch")
            i = t.rfind("endmodule")
            t2 = t[:i] + "".join(" assign %s = %s;\n" % (n,v) for n,v in add) + t[i:]
            open(f,"w").write(t2)
        after = scan(open(f).read())
        consts = sorted({v for n,v in add})
        print("%-30s undriven before=%2d  restored=%2d (%s)  unresolved=%d %s  undriven after=%d" % (f, len(und), len(add), ",".join(consts), len(unres), [u[0] for u in unres][:4], len(after)))
PY

echo
echo "##### equivalence (validated miter+SAT), c2670 repaired netlists #####"
L=asap7_libs
chk() {
  cat > /tmp/p_$1.ys << EOF
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
sat -prove trigger 0 -timeout 600 miter
EOF
  yosys -s /tmp/p_$1.ys > run/p_$1.log 2>&1
  echo "$1 : $(grep -m1 -E 'no model found|model found' run/p_$1.log | sed 's/SAT proof finished - //')"
}
chk c2670_TT iscas85/c2670.v run/c2670_final_mvt.v    c2670
chk c2670_SS iscas85/c2670.v run/c2670_final_mvt_SS.v c2670
chk c2670_FF iscas85/c2670.v run/c2670_final_mvt_FF.v c2670

echo
echo "##### re-measure timing and leakage on the repaired netlists #####"
STA=/work/opensta_src/build/sta
cat > /tmp/mm.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(NETLIST)
link_design $::env(CKT)
if {$::env(CLK) eq "CK"} {
  create_clock -name clk -period $::env(PERIOD) [get_ports CK]
  set_input_delay -clock clk 0 [all_inputs -no_clocks]
} else {
  create_clock -name clk -period $::env(PERIOD) [get_ports {}]
  set_input_delay -clock clk 0 [all_inputs]
}
set_output_delay -clock clk 0 [all_outputs]
puts "WNS_SETUP: [worst_slack -max]"
puts "WNS_HOLD: [worst_slack -min]"
report_power -digits 6
EOF
m() { # ckt netlist corner period clk expected
  LIBS=""
  for vt in SLVT RVT; do for g in SIMPLE INVBUF SEQ; do LIBS="$LIBS $(ls $L/asap7sc7p5t_${g}_${vt}_$3_nldm_*.lib | head -1)"; done; done
  export LIBS CKT=$1 NETLIST=$2 PERIOD=$4 CLK=$5
  out=$($STA -no_init -exit /tmp/mm.tcl 2>&1)
  s=$(echo "$out" | grep WNS_SETUP | awk "{print \$2}"); h=$(echo "$out" | grep WNS_HOLD | awk "{print \$2}"); l=$(echo "$out" | grep "^Total" | awk "{print \$4}")
  python3 -c "print('%-7s %-2s setup=%8.2f hold=%7.2f leak=%10.2f nW   (before repair: %s)' % ('$1','$3',float('$s'),float('$h'),float('$l')*1e9,'$6'))"
}
m c2670 run/c2670_final_mvt.v    TT 317.19 "{}" "setup 0.38  leak 66.84"
m c2670 run/c2670_final_mvt_SS.v SS 442.63 "{}" "setup 0.15  leak 559.39"
m c2670 run/c2670_final_mvt_FF.v FF 249.87 "{}" "setup 1.90  leak 45.70"
m s38584 run/s38584_flatfinal_TT.v TT 1911.59 CK "setup 3.24  leak 669.73"
m s38584 run/s38584_flatfinal_SS.v SS 2847.55 CK "setup 158.37 leak 8612.22"
m s38584 run/s38584_flatfinal_FF.v FF 1494.93 CK "setup 102.07 leak 539.63"
echo "#### DONE ####"
