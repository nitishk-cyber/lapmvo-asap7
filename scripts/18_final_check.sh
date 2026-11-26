#!/bin/bash
WORKDIR=/work
STA=$WORKDIR/opensta_src/build/sta
L=$WORKDIR/asap7_libs
export WORKDIR

libs_for() {
  LIBS=""
  for vt in SLVT RVT; do for g in SIMPLE INVBUF SEQ; do
    LIBS="$LIBS $(ls $L/asap7sc7p5t_${g}_${vt}_$1_nldm_*.lib | head -1)"
  done; done
  export LIBS
}

cat > /tmp/constraints.tcl << 'EOF'
if {$::env(CLK) eq "CK"} {
  create_clock -name clk -period $::env(PERIOD) [get_ports CK]
  set_input_delay -clock clk 0 [all_inputs -no_clocks]
} else {
  create_clock -name clk -period $::env(PERIOD) [get_ports {}]
  set_input_delay -clock clk 0 [all_inputs]
}
set_output_delay -clock clk 0 [all_outputs]
EOF

cat > /tmp/measure.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(NETLIST)
link_design $::env(CKT)
source /tmp/constraints.tcl
puts "WNS_SETUP: [worst_slack -max]"
puts "WNS_HOLD: [worst_slack -min]"
report_power -digits 6
EOF

measure() {
  export CKT=$1 NETLIST=$2 CLK=$3 PERIOD=$4
  out=$($STA -no_init -exit /tmp/measure.tcl 2>&1)
  MS=$(echo "$out" | grep "WNS_SETUP" | awk '{print $2}')
  MH=$(echo "$out" | grep "WNS_HOLD" | awk '{print $2}')
  ML=$(echo "$out" | grep "^Total" | awk '{print $4}')
}

while IFS=: read -r c ttperiod; do
  case $c in s38417|s38584) clk="CK" ;; *) clk="{}" ;; esac
  for corner in TT SS FF; do
    libs_for $corner
    base=$WORKDIR/run/${c}_synth_SLVT.v
    case $corner in
      TT) final=$WORKDIR/run/${c}_final_mvt.v ;;
      *)  final=$WORKDIR/run/${c}_final_mvt_${corner}.v ;;
    esac
    measure $c $base $clk 100000
    cp=$(python3 -c "print(100000 - $MS)")
    if [ "$corner" == "TT" ]; then period=$ttperiod; else period=$(python3 -c "print(round($cp*1.15,2))"); fi
    measure $c $base $clk $period
    BS=$MS; BH=$MH
    if [ ! -f "$final" ]; then echo "$c $corner MISSING $final"; continue; fi
    measure $c $final $clk $period
    awk -v c=$c -v k=$corner -v p=$period -v bs=$BS -v bh=$BH -v fs=$MS -v fh=$MH -v fl=$ML 'BEGIN{printf "%-7s %-2s T=%-8s | base setup=%9.2f hold=%8.2f | final setup=%8.2f hold=%8.2f leak=%10.2f nW\n", c,k,p,bs,bh,fs,fh,fl*1e9}'
  done
done < $WORKDIR/run/timing_budgets.txt
