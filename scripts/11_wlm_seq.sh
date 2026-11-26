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

echo "circuit,baseline_nw,wlm_final_nw,reduction_pct" > run/wlm_seq_results.csv

run_wlm_seq() {
  local c=$1

  # baseline leakage (real, for reduction calc)
cat > /tmp/wlmseqbase0_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]
report_power -digits 6
EOF
  base_leak=$($STA -no_init -exit /tmp/wlmseqbase0_${c}.tcl 2>&1 | grep "^Total" | awk '{print $4}')

  # WLM model's own critical path under flat capacitance
cat > /tmp/wlmseqbase_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]
set nets [get_nets -hierarchical *]
foreach n \$nets { set_load 0.8889 \$n }
puts "WORST_SLACK: [expr {[worst_slack -max]}]"
EOF
  ws=$($STA -no_init -exit /tmp/wlmseqbase_${c}.tcl 2>&1 | grep "WORST_SLACK" | awk '{print $2}')
  cp=$(python3 -c "print(100000 - $ws)")
  period=$(python3 -c "print(round($cp * 1.15, 2))")

  # swap loop under flat-capacitance WLM model
cat > /tmp/wlmseqopt_${c}.tcl << EOF
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

set nets [get_nets -hierarchical *]
foreach n \$nets { set_load 0.8889 \$n }

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
puts "WLM_SEQ_RESULT ${c}: swapped=\$swapped rejected=\$rejected"
write_verilog $WORKDIR/run/${c}_final_wlm.v
EOF
  $STA -no_init -exit /tmp/wlmseqopt_${c}.tcl 2>&1 | grep "WLM_SEQ_RESULT"

  # final leakage with real liberty data (fresh session)
cat > /tmp/wlmseqpwr_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_final_wlm.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]
report_power -digits 6
EOF
  wlm_leak=$($STA -no_init -exit /tmp/wlmseqpwr_${c}.tcl 2>&1 | grep "^Total" | awk '{print $4}')
  reduction=$(python3 -c "print(round((($base_leak - $wlm_leak) / $base_leak) * 100, 1))")
  echo "${c}: baseline=${base_leak}W wlm_final=${wlm_leak}W reduction=${reduction}%"
  echo "${c},$(python3 -c "print($base_leak*1e9)"),$(python3 -c "print($wlm_leak*1e9)"),${reduction}" >> run/wlm_seq_results.csv
}

for c in s38417 s38584; do
  echo "=== $c (this will take a few minutes) ==="
  run_wlm_seq $c
done

echo ""
echo "Done. Results saved to run/wlm_seq_results.csv"
cat run/wlm_seq_results.csv
