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

run_wlm() {
  local c=$1

  # Step 1: find the WLM model's OWN critical path (using flat capacitance)
cat > /tmp/wlmbase_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]
set nets [get_nets *]
foreach n \$nets { set_load 0.8889 \$n }
puts "WORST_SLACK: [expr {[worst_slack -max]}]"
EOF
  out=$($STA -no_init -exit /tmp/wlmbase_${c}.tcl 2>&1)
  ws=$(echo "$out" | grep "WORST_SLACK" | awk '{print $2}')
  cp=$(python3 -c "print(100000 - $ws)")
  period=$(python3 -c "print(round($cp * 1.15, 2))")

  # Step 2: run the swap loop under the flat-capacitance WLM model
cat > /tmp/wlmopt_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period ${period} [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]

set nets [get_nets -hierarchical *]
foreach n \$nets { set_load 0.8889 \$n }

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
puts "WLM_RESULT ${c}: swapped=\$swapped rejected=\$rejected"
write_verilog $WORKDIR/run/${c}_final_wlm.v
EOF
  $STA -no_init -exit /tmp/wlmopt_${c}.tcl 2>&1 | grep "WLM_RESULT"

  # Step 3: measure final leakage with REAL liberty data (no override)
cat > /tmp/wlmpwr_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_final_wlm.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]
report_power -digits 6
EOF
  wlm_leak=$($STA -no_init -exit /tmp/wlmpwr_${c}.tcl 2>&1 | grep "^Total" | awk '{print $4}')
  echo "${c} WLM final leakage: ${wlm_leak}W"
}

for c in c432 c880 c1908 c2670 c5315 c7552; do
  run_wlm $c
done

echo ""
echo "Done. Compare against Table 4 LA-PMVO vs WLM-MVt reduction:"
echo "  c432: LA-PMVO=59.6% WLM=62.9%"
echo "  c880: LA-PMVO=89.6% WLM=91.6%"
echo "  c1908: LA-PMVO=70.8% WLM=74.1%"
echo "  c2670: LA-PMVO=95.0% WLM=95.2%"
echo "  c5315: LA-PMVO=95.2% WLM=94.9%"
echo "  c7552: LA-PMVO=97.5% WLM=96.9%"
