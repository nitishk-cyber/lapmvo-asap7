#!/bin/bash
set -e
WORKDIR="$(pwd)"
STA="$WORKDIR/opensta_src/build/sta"
SIMPLE_SLVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SIMPLE_SLVT_TT_nldm_*.lib | head -1)
INVBUF_SLVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_INVBUF_SLVT_TT_nldm_*.lib | head -1)
SEQ_SLVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SEQ_SLVT_TT_nldm_*.lib | head -1)
SIMPLE_RVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SIMPLE_RVT_TT_nldm_*.lib | head -1)
INVBUF_RVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_INVBUF_RVT_TT_nldm_*.lib | head -1)
SEQ_RVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SEQ_RVT_TT_nldm_*.lib | head -1)

echo "circuit,margin,reduction_pct" > run/sweep_seq_results.csv

get_baseline_seq() {
  local c=$1
cat > /tmp/sweepbaseseq_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]
puts "WORST_SLACK: [expr {[worst_slack -max]}]"
report_power -digits 6
EOF
  out=$($STA -no_init -exit /tmp/sweepbaseseq_${c}.tcl 2>&1)
  ws=$(echo "$out" | grep "WORST_SLACK" | awk '{print $2}')
  BASE_CP=$(python3 -c "print(100000 - $ws)")
  BASE_LEAK=$(echo "$out" | grep "^Total" | awk '{print $4}')
}

run_sweep_point_seq() {
  local c=$1
  local margin=$2
  local period=$(python3 -c "print(round($BASE_CP * (1 + $margin/100), 2))")

cat > /tmp/sweepseq_${c}_${margin}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period ${period} [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]

set cells [get_cells -hierarchical *]
set candidates {}
foreach c \$cells {
    set ref [get_property \$c ref_name]
    if {[string match "*_SL" \$ref]} { lappend candidates \$c }
}
set ranked {}
foreach c \$candidates {
    set opins [get_pins -of_objects \$c -filter "direction == output"]
    if {[llength \$opins] == 0} { continue }
    set sl [get_property [lindex \$opins 0] slack_max]
    lappend ranked [list \$sl \$c]
}
set ranked [lsort -real -decreasing -index 0 \$ranked]
set swapped 0
set rejected 0
foreach item \$ranked {
    set c [lindex \$item 1]
    set ref [get_property \$c ref_name]
    set rvt_name [string map {_SL _R} \$ref]
    set rvt_lib_cell [get_lib_cell \$rvt_name]
    if {\$rvt_lib_cell eq ""} { continue }
    replace_cell \$c \$rvt_lib_cell
    if {[expr {[worst_slack -max]}] < 0} {
        replace_cell \$c [get_lib_cell \$ref]
        incr rejected
    } else { incr swapped }
}
write_verilog $WORKDIR/run/${c}_sweepseq_${margin}.v
EOF
  $STA -no_init -exit /tmp/sweepseq_${c}_${margin}.tcl > /dev/null 2>&1

cat > /tmp/sweepseqpwr_${c}_${margin}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_sweepseq_${margin}.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]
report_power -digits 6
EOF
  final_leak=$($STA -no_init -exit /tmp/sweepseqpwr_${c}_${margin}.tcl 2>&1 | grep "^Total" | awk '{print $4}')
  reduction=$(python3 -c "print(round((($BASE_LEAK - $final_leak) / $BASE_LEAK) * 100, 1))")
  echo "${c} margin=${margin}%: reduction=${reduction}%"
  echo "${c},${margin},${reduction}" >> run/sweep_seq_results.csv
}

for c in s38417 s38584; do
  echo "=== $c (each margin takes 1.5-3 min, this will take a while) ==="
  get_baseline_seq $c
  for margin in 2 5 10 15 20 25 30; do
    run_sweep_point_seq $c $margin
  done
done

echo ""
echo "Done. Expected reduction % (margin: 2/5/10/15/20/25/30):"
echo "  s38417: 95.1/96.1/96.9/97.8/98.2/98.3/98.4"
echo "  s38584: 98.9/99.0/99.0/98.9/99.0/99.0/99.0"
