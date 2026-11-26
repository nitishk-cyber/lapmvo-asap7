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

run_naive() {
  local c=$1
  local period=$2
  local clkport=$3
  local cellsel=$4

cat > /tmp/lapmvo_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period ${period} [get_ports ${clkport}]
EOF
  if [ "$clkport" == "CK" ]; then
    echo 'set_input_delay -clock clk 0 [all_inputs -no_clocks]' >> /tmp/lapmvo_${c}.tcl
  else
    echo 'set_input_delay -clock clk 0 [all_inputs]' >> /tmp/lapmvo_${c}.tcl
  fi
  echo 'set_output_delay -clock clk 0 [all_outputs]' >> /tmp/lapmvo_${c}.tcl

cat >> /tmp/lapmvo_${c}.tcl << EOF

set cells [${cellsel}]
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
set swapped 0
set rejected 0
foreach item \$candidates {
    set c \$item
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
puts "NAIVE_RESULT ${c}: candidates=[llength \$candidates] swapped=\$swapped rejected=\$rejected"
write_verilog $WORKDIR/run/${c}_naive.v
EOF

  $STA -no_init -exit /tmp/lapmvo_${c}.tcl 2>&1 | grep "RESULT"

cat > /tmp/finalpwr_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_naive.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports ${clkport}]
EOF
  if [ "$clkport" == "CK" ]; then
    echo 'set_input_delay -clock clk 0 [all_inputs -no_clocks]' >> /tmp/finalpwr_${c}.tcl
  else
    echo 'set_input_delay -clock clk 0 [all_inputs]' >> /tmp/finalpwr_${c}.tcl
  fi
  echo 'set_output_delay -clock clk 0 [all_outputs]' >> /tmp/finalpwr_${c}.tcl
  echo 'report_power -digits 6' >> /tmp/finalpwr_${c}.tcl

  echo -n "${c} final leakage: "
  $STA -no_init -exit /tmp/finalpwr_${c}.tcl 2>&1 | grep "^Total" | awk '{print $4}'
}


while IFS=: read -r circuit period; do
  case $circuit in
    s38417|s38584) continue ;;
    *) run_naive "$circuit" "$period" "{}" "get_cells *" ;;
  esac
done < run/timing_budgets.txt

echo ""
echo "Done. Compare against Table 3 LA-PMVO (ranked) results:"
echo "  c432=59.6% c880=89.6% c1908=70.8% c2670=95.0% c5315=95.2% c7552=97.5%"
