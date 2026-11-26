#!/bin/bash
set -e
WORKDIR="$(pwd)"
STA="$WORKDIR/opensta_src/build/sta"
SIMPLE_SLVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SIMPLE_SLVT_TT_nldm_*.lib | head -1)
INVBUF_SLVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_INVBUF_SLVT_TT_nldm_*.lib | head -1)
SEQ_SLVT=$(ls $WORKDIR/asap7_libs/asap7sc7p5t_SEQ_SLVT_TT_nldm_*.lib | head -1)
> run/timing_budgets.txt
> run/baseline_power.txt

measure_comb() {
  local c=$1
cat > /tmp/base_${c}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]
puts "WORST_SLACK: [expr {[worst_slack -max]}]"
report_power -digits 6
EOF
  out=$($STA -no_init -exit /tmp/base_${c}.tcl 2>&1)
  ws=$(echo "$out" | grep "WORST_SLACK" | awk '{print $2}')
  cp=$(python3 -c "print(100000 - $ws)")
  period=$(python3 -c "print(round($cp * 1.15, 2))")
  leak=$(echo "$out" | grep "^Total" | awk '{print $4}')
  echo "${c}:${period}" >> run/timing_budgets.txt
  echo "${c}: baseline_leak=${leak}W  critical_path=${cp}ps  budget_1.15x=${period}ps"
  echo "${c},${leak}" >> run/baseline_power.txt
}

measure_seq() {
  local c=$1
cat > /tmp/base_${c}.tcl << EOF
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
  out=$($STA -no_init -exit /tmp/base_${c}.tcl 2>&1)
  ws=$(echo "$out" | grep "WORST_SLACK" | awk '{print $2}')
  cp=$(python3 -c "print(100000 - $ws)")
  period=$(python3 -c "print(round($cp * 1.15, 2))")
  leak=$(echo "$out" | grep "^Total" | awk '{print $4}')
  echo "${c}:${period}" >> run/timing_budgets.txt
  echo "${c}: baseline_leak=${leak}W  critical_path=${cp}ps  budget_1.15x=${period}ps"
  echo "${c},${leak}" >> run/baseline_power.txt
}

for c in c432 c880 c1908 c2670 c5315 c7552; do
  measure_comb $c
done
for c in s38417 s38584; do
  measure_seq $c
done

echo ""
echo "Done. Expected leakage (nW): c432=281.10 c880=799.48 c1908=908.68 c2670=1346.13"
echo "  c5315=3578.28 c7552=3843.80 s38417=65680.80 s38584=63389.40"
