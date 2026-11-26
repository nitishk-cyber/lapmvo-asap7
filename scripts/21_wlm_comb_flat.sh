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

cat > /tmp/cp.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(NETLIST)
link_design $::env(CKT)
source /tmp/constraints.tcl
if {$::env(WLM) eq "1"} { foreach n [get_nets -hierarchical *] { set_load 0.8889 $n } }
puts "WNS_SETUP: [worst_slack -max]"
report_power -digits 6
EOF

cat > /tmp/swap2.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(NETLIST)
link_design $::env(CKT)
source /tmp/constraints.tcl
if {$::env(WLM) eq "1"} { foreach n [get_nets -hierarchical *] { set_load 0.8889 $n } }
set candidates {}
foreach c [get_cells -hierarchical *] {
  set ref [get_property $c ref_name]
  if {![string match "*_SL" $ref]} { continue }
  if {$::env(NOFF) eq "1" && [string match "DFF*" $ref]} { continue }
  lappend candidates $c
}
set ranked {}
foreach c $candidates {
  set opins [get_pins -of_objects $c -filter "direction == output"]
  if {[llength $opins] == 0} { continue }
  lappend ranked [list [get_property [lindex $opins 0] slack_max] $c]
}
set ranked [lsort -real -decreasing -index 0 $ranked]
set swapped 0
set rejected 0
foreach item $ranked {
  set c [lindex $item 1]
  set ref [get_property $c ref_name]
  set rvt [get_lib_cell [string map {_SL _R} $ref]]
  if {$rvt eq ""} { continue }
  replace_cell $c $rvt
  if {[expr {[worst_slack -max]}] < 0} { replace_cell $c [get_lib_cell $ref]; incr rejected } else { incr swapped }
}
puts "SWAPRESULT candidates=[llength $candidates] swapped=$swapped rejected=$rejected"
write_verilog $::env(OUTV)
EOF

run_cp() { export CKT=$1 NETLIST=$2 PERIOD=$3 WLM=$4
  out=$($STA -no_init -exit /tmp/cp.tcl 2>&1)
  CPW=$(echo "$out" | grep WNS_SETUP | awk '{print $2}')
  CPL=$(echo "$out" | grep "^Total" | awk '{print $4}')
}

echo "################ PART A: WLM-MVt on flat netlists (TT) ################"
for c in s38417 s38584; do
  base=$WORKDIR/run/${c}_flat_SLVT.v
  tt=$(grep "^$c:" $WORKDIR/run/timing_budgets.txt | cut -d: -f2)
  run_cp $c $base 100000 0; BASEL=$CPL
  run_cp $c $base 100000 1
  period=$(python3 -c "print(round((100000-$CPW)*1.15,2))")
  outv=$WORKDIR/run/${c}_flatwlm.v
  export CKT=$c NETLIST=$base PERIOD=$period WLM=1 NOFF=0 OUTV=$outv
  res=$($STA -no_init -exit /tmp/swap2.tcl 2>&1 | grep SWAPRESULT)
  run_cp $c $outv $period 0
  dffS=$(grep -c "DFFHQNx1_ASAP7_75t_SL " $outv)
  python3 -c "
b=float('$BASEL')*1e9; f=float('$CPL')*1e9
print('%-7s WLM period=%s | %s | DFF_SLVT_left=%s | base=%.2f nW final=%.2f nW | reduction=%.1f%%' % ('$c','$period','$res','$dffS',b,f,100*(1-f/b)))"
done

echo ""
echo "################ PART B: s38417 combinational-only swap (flops excluded) ################"
c=s38417
base=$WORKDIR/run/${c}_flat_SLVT.v
tt=$(grep "^$c:" $WORKDIR/run/timing_budgets.txt | cut -d: -f2)
outv=$WORKDIR/run/${c}_flatcombonly.v
export CKT=$c NETLIST=$base PERIOD=$tt WLM=0 NOFF=1 OUTV=$outv
$STA -no_init -exit /tmp/swap2.tcl 2>&1 | grep SWAPRESULT
cat > /tmp/grp.tcl << EOF
foreach l \$::env(LIBS) { read_liberty \$l }
read_verilog \$::env(NETLIST)
link_design \$::env(CKT)
source /tmp/constraints.tcl
report_power -digits 6
EOF
for tag in baseline combonly; do
  if [ $tag == baseline ]; then export NETLIST=$base; else export NETLIST=$outv; fi
  echo "--- $tag ---"
  $STA -no_init -exit /tmp/grp.tcl 2>&1 | grep -E "^(Sequential|Combinational|Total)"
done
