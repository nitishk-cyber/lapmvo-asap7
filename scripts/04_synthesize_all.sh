#!/bin/bash
set -e
WORKDIR="$(pwd)"
mkdir -p run

for vt in SLVT RVT; do
  for c in c432 c880 c1908 c2670 c5315 c7552; do
    echo "=== Synthesizing $c to $vt ==="
    cat > /tmp/synth_${c}_${vt}.ys << EOF
read_verilog -sv $WORKDIR/iscas85/${c}.v
hierarchy -check -top ${c}
proc; opt; fsm; opt; memory; opt
techmap; opt
abc -liberty $WORKDIR/asap7_libs/combined_${vt}_TT.lib
clean
stat -liberty $WORKDIR/asap7_libs/combined_${vt}_TT.lib
write_verilog -noattr $WORKDIR/run/${c}_synth_${vt}.v
EOF
    yosys -s /tmp/synth_${c}_${vt}.ys > run/${c}_${vt}_synth.log 2>&1
    grep "Number of cells" run/${c}_${vt}_synth.log | tail -1
  done

  for c in s38417 s38584; do
    echo "=== Synthesizing $c (sequential) to $vt ==="
    SEQ_LIB=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SEQ_${vt}_TT_nldm_*.lib | head -1)
    cat > /tmp/synth_${c}_${vt}.ys << EOF
read_verilog -sv $WORKDIR/iscas89/ISCAS89/${c}.v
hierarchy -check -top ${c}
proc; opt; fsm; opt; memory; opt
techmap; opt
dfflibmap -liberty $SEQ_LIB
abc -liberty $WORKDIR/asap7_libs/combined_${vt}_TT.lib
clean
stat -liberty $WORKDIR/asap7_libs/combined_${vt}_TT.lib
write_verilog -noattr $WORKDIR/run/${c}_synth_${vt}.v
EOF
    yosys -s /tmp/synth_${c}_${vt}.ys > run/${c}_${vt}_synth.log 2>&1
    grep "Number of cells" run/${c}_${vt}_synth.log | tail -1
  done
done

echo ""
echo "Done. Expected real gate counts (SLVT/RVT should match):"
echo "  c432=119  c880=199  c1908=198  c2670=399  c5315=1051  c7552=933"
echo "  s38417=10041 (incl. 1564 DFFs)  s38584=11538 (incl. 1426 DFFs)"
