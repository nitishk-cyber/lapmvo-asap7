#!/bin/bash
set -e
WORKDIR="$(pwd)"
STA="$WORKDIR/opensta_src/build/sta"

get_corner_libs() {
  local vt=$1
  local corner=$2
  SIMPLE=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SIMPLE_${vt}_${corner}_nldm_*.lib | head -1)
  INVBUF=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_INVBUF_${vt}_${corner}_nldm_*.lib | head -1)
  SEQ=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SEQ_${vt}_${corner}_nldm_*.lib | head -1)
}

run_corner() {
  local c=$1
  local corner=$2

  get_corner_libs SLVT $corner
  SIMPLE_S=$SIMPLE; INVBUF_S=$INVBUF; SEQ_S=$SEQ
  get_corner_libs RVT $corner
  SIMPLE_R=$SIMPLE; INVBUF_R=$INVBUF; SEQ_R=$SEQ

  # Step 1: baseline critical path at this corner
cat > /tmp/base_${c}_${corner}.tcl << EOF
read_liberty $SIMPLE_S
read_liberty $INVBUF_S
read_liberty $SEQ_S
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]
puts "WORST_SLACK: [expr {[worst_slack -max]}]"
report_power -digits 6
EOF
  out=$($STA -no_init -exit /tmp/base_${c}_${corner}.tcl 2>&1)
  ws=$(echo "$out" | grep "WORST_SLACK" | awk '{print $2}')
  cp=$(python3 -c "print(100000 - $ws)")
  period=$(python3 -c "print(round($cp * 1.15, 2))")
  base_leak=$(echo "$out" | grep "^Total" | awk '{print $4}')

  # Step 2: run LA-PMVO at this corner's own budget
cat > /tmp/opt_${c}_${corner}.tcl << EOF
read_liberty $SIMPLE_S
read_liberty $INVBUF_S
read_liberty $SEQ_S
read_liberty $SIMPLE_R
read_liberty $INVBUF_R
read_liberty $SEQ_R
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period ${period} [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]

set cells [get_cells *]
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
puts "RESULT ${c} ${corner}: swapped=\$swapped rejected=\$rejected"
write_verilog $WORKDIR/run/${c}_final_mvt_${corner}.v
EOF
  $STA -no_init -exit /tmp/opt_${c}_${corner}.tcl 2>&1 | grep "RESULT"

  # Step 3: measure final leakage in a fresh session
cat > /tmp/finalpwr_${c}_${corner}.tcl << EOF
read_liberty $SIMPLE_S
read_liberty $INVBUF_S
read_liberty $SEQ_S
read_liberty $SIMPLE_R
read_liberty $INVBUF_R
read_liberty $SEQ_R
read_verilog $WORKDIR/run/${c}_final_mvt_${corner}.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]
report_power -digits 6
EOF
  final_leak=$($STA -no_init -exit /tmp/finalpwr_${c}_${corner}.tcl 2>&1 | grep "^Total" | awk '{print $4}')

  echo "${c} ${corner}: baseline=${base_leak}W final=${final_leak}W"
}

for c in c432 c880 c1908 c2670 c5315 c7552; do
  run_corner $c SS
  run_corner $c FF
done

echo ""
echo "Done. Expected baseline leakage (nW):"
echo "  c432: SS=1734.91 FF=178.26"
echo "  c880: SS=4745.41 FF=517.04"
echo "  c1908: SS=5555.77 FF=579.94"
echo "  c2670: SS=8223.60 FF=859.39"
echo "  c5315: SS=21361.06 FF=2310.14"
echo "  c7552: SS=23125.03 FF=2473.63"
