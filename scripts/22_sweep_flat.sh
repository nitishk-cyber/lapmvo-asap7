#!/bin/bash
WORKDIR=/work
STA=$WORKDIR/opensta_src/build/sta
L=$WORKDIR/asap7_libs
LIBS=""
for vt in SLVT RVT; do for g in SIMPLE INVBUF SEQ; do
  LIBS="$LIBS $(ls $L/asap7sc7p5t_${g}_${vt}_TT_nldm_*.lib | head -1)"
done; done
export LIBS

cat > /tmp/constraints.tcl << 'EOF'
create_clock -name clk -period $::env(PERIOD) [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]
EOF
cat > /tmp/m.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(NETLIST)
link_design $::env(CKT)
source /tmp/constraints.tcl
puts "WNS_SETUP: [worst_slack -max]"
report_power -digits 6
EOF
cat > /tmp/sw.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(NETLIST)
link_design $::env(CKT)
source /tmp/constraints.tcl
set candidates {}
foreach c [get_cells -hierarchical *] {
  if {[string match "*_SL" [get_property $c ref_name]]} { lappend candidates $c }
}
set ranked {}
foreach c $candidates {
  set o [get_pins -of_objects $c -filter "direction == output"]
  if {[llength $o] == 0} { continue }
  lappend ranked [list [get_property [lindex $o 0] slack_max] $c]
}
set ranked [lsort -real -decreasing -index 0 $ranked]
set sw 0
set rj 0
foreach it $ranked {
  set c [lindex $it 1]
  set ref [get_property $c ref_name]
  set r [get_lib_cell [string map {_SL _R} $ref]]
  if {$r eq ""} { continue }
  replace_cell $c $r
  if {[expr {[worst_slack -max]}] < 0} { replace_cell $c [get_lib_cell $ref]; incr rj } else { incr sw }
}
puts "SWAPRESULT swapped=$sw rejected=$rj"
write_verilog $::env(OUTV)
EOF

echo "#### s38417 full-swap TT netlist: leakage by group ####"
export CKT=s38417 NETLIST=$WORKDIR/run/s38417_flatfinal_TT.v PERIOD=554.25
$STA -no_init -exit /tmp/m.tcl 2>&1 | grep -E "^(Sequential|Combinational|Total)"
echo ""
echo "#### sweep on flat netlists ####"
echo "circuit,margin,period,swapped,rejected,dff_slvt_left,final_setup_ps,reduction_pct,swap_session_s"
for c in s38417 s38584; do
  base=$WORKDIR/run/${c}_flat_SLVT.v
  export CKT=$c NETLIST=$base PERIOD=100000
  out=$($STA -no_init -exit /tmp/m.tcl 2>&1)
  ws=$(echo "$out" | grep WNS_SETUP | awk '{print $2}')
  bl=$(echo "$out" | grep "^Total" | awk '{print $4}')
  cp=$(python3 -c "print(100000 - $ws)")
  for m in 2 5 10 15 20 25 30; do
    period=$(python3 -c "print(round($cp*(1+$m/100),2))")
    outv=$WORKDIR/run/${c}_flatsweep_${m}.v
    export CKT=$c NETLIST=$base PERIOD=$period OUTV=$outv
    t0=$(date +%s.%N)
    res=$($STA -no_init -exit /tmp/sw.tcl 2>&1 | grep SWAPRESULT)
    t1=$(date +%s.%N)
    export NETLIST=$outv
    out=$($STA -no_init -exit /tmp/m.tcl 2>&1)
    fs=$(echo "$out" | grep WNS_SETUP | awk '{print $2}')
    fl=$(echo "$out" | grep "^Total" | awk '{print $4}')
    dff=$(grep -c "DFFHQNx1_ASAP7_75t_SL " $outv)
    python3 -c "
sw=[x.split('=')[1] for x in '$res'.split()[1:]]
print('%s,%s,%s,%s,%s,%s,%.2f,%.1f,%.1f' % ('$c',$m,'$period',sw[0],sw[1],'$dff',float('$fs'),100*(1-float('$fl')/float('$bl')),float('$t1')-float('$t0')))"
  done
done
echo "#### DONE ####"
