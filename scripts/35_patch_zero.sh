#!/bin/bash
cd /work
echo "--- DFF_1421 in the pre-LA-PMVO flat netlist (what was D tied to?) ---"
grep -n -A4 "DFF_1421 *(" run/s38584_flat_SLVT.v | head -8
python3 - << "PY"
import re, shutil, os
for f in ["run/s38584_flatfinal_TT.v","run/s38584_flatfinal_SS.v","run/s38584_flatfinal_FF.v"]:
    t = open(f).read()
    n_use = len(re.findall(r"\bzero_\b", t))
    has_asg = re.search(r"assign\s+zero_\s*=", t) is not None
    has_wire = re.search(r"\bwire\s+zero_\b", t) is not None
    if n_use and not has_asg:
        if not os.path.exists(f + ".prepatch2"): shutil.copy(f, f + ".prepatch2")
        i = t.rfind("endmodule")
        add = ("" if has_wire else " wire zero_;\n") + " assign zero_ = 1'"'"'h0;\n"
        open(f, "w").write(t[:i] + add + t[i:])
        print("%-34s zero_ uses=%d  patched (wire declared before: %s)" % (f, n_use, has_wire))
    else:
        print("%-34s zero_ uses=%d  no patch needed" % (f, n_use))
PY
echo
echo "--- re-measure s38584 on the repaired finals ---"
STA=/work/opensta_src/build/sta
L=/work/asap7_libs
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
  s=$(echo "$out" | grep WNS_SETUP | awk "{print \$2}"); h=$(echo "$out" | grep WNS_HOLD | awk "{print \$2}"); l=$(echo "$out" | grep "^Total" | awk "{print \$4}")
  python3 -c "print('s38584 %-2s setup=%8.2f hold=%6.2f leak=%9.2f nW   (before: %s)' % ('$3',float('$s'),float('$h'),float('$l')*1e9,'$4'))"
}
m run/s38584_flatfinal_TT.v 1911.59 TT "setup 3.24 hold 0.00 leak 669.73"
m run/s38584_flatfinal_SS.v 2847.55 SS "setup 158.37 hold -0.43 leak 8612.22"
m run/s38584_flatfinal_FF.v 1494.93 FF "setup 102.07 hold -1.37 leak 539.63"
echo "#### DONE ####"
