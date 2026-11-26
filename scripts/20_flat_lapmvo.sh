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
create_clock -name clk -period $::env(PERIOD) [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
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

cat > /tmp/swap.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(NETLIST)
link_design $::env(CKT)
source /tmp/constraints.tcl
set candidates {}
foreach c [get_cells -hierarchical *] {
  set ref [get_property $c ref_name]
  if {[string match "*_SL" $ref]} { lappend candidates $c }
}
set ranked {}
foreach c $candidates {
  set opins [get_pins -of_objects $c -filter "direction == output"]
  if {[llength $opins] == 0} { continue }
  set sl [get_property [lindex $opins 0] slack_max]
  lappend ranked [list $sl $c]
}
set ranked [lsort -real -decreasing -index 0 $ranked]
set swapped 0
set rejected 0
foreach item $ranked {
  set c [lindex $item 1]
  set ref [get_property $c ref_name]
  set rvt_name [string map {_SL _R} $ref]
  set rvt_lib_cell [get_lib_cell $rvt_name]
  if {$rvt_lib_cell eq ""} { continue }
  replace_cell $c $rvt_lib_cell
  if {[expr {[worst_slack -max]}] < 0} {
    replace_cell $c [get_lib_cell $ref]
    incr rejected
  } else { incr swapped }
}
puts "SWAPRESULT candidates=[llength $candidates] swapped=$swapped rejected=$rejected"
write_verilog $::env(OUTV)
EOF

measure() {
  export CKT=$1 NETLIST=$2 PERIOD=$3
  out=$($STA -no_init -exit /tmp/measure.tcl 2>&1)
  MS=$(echo "$out" | grep "WNS_SETUP" | awk '{print $2}')
  MH=$(echo "$out" | grep "WNS_HOLD" | awk '{print $2}')
  ML=$(echo "$out" | grep "^Total" | awk '{print $4}')
}

> $WORKDIR/run/flat_results.txt
for c in s38417 s38584; do
  ttperiod=$(grep "^$c:" $WORKDIR/run/timing_budgets.txt | cut -d: -f2)
  base=$WORKDIR/run/${c}_flat_SLVT.v
  for corner in TT SS FF; do
    libs_for $corner
    measure $c $base 100000
    cp=$(python3 -c "print(100000 - $MS)")
    if [ "$corner" == "TT" ]; then period=$ttperiod; else period=$(python3 -c "print(round($cp*1.15,2))"); fi
    measure $c $base $period
    BS=$MS; BH=$MH; BL=$ML
    outv=$WORKDIR/run/${c}_flatfinal_${corner}.v
    export CKT=$c NETLIST=$base PERIOD=$period OUTV=$outv
    res=$($STA -no_init -exit /tmp/swap.tcl 2>&1 | grep SWAPRESULT)
    measure $c $outv $period
    dffR=$(grep -c "DFFHQNx1_ASAP7_75t_R " $outv)
    dffS=$(grep -c "DFFHQNx1_ASAP7_75t_SL " $outv)
    line=$(python3 -c "
bl=float('$BL')*1e9; fl=float('$ML')*1e9
print('%-7s %-2s T=%-8s | %s | DFF_RVT=%s DFF_SLVT=%s | base leak=%.2f nW setup=%.2f hold=%.2f | final setup=%.2f hold=%.2f leak=%.2f nW | reduction=%.1f%%' % ('$c','$corner','$period','$res','$dffR','$dffS',bl,float('$BS'),float('$BH'),float('$MS'),float('$MH'),fl,100*(1-fl/bl)))")
    echo "$line" | tee -a $WORKDIR/run/flat_results.txt
  done
done
