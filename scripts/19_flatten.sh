#!/bin/bash
cd /work
L=asap7_libs
S1=$(ls $L/asap7sc7p5t_SIMPLE_SLVT_TT_nldm_*.lib | head -1)
S2=$(ls $L/asap7sc7p5t_INVBUF_SLVT_TT_nldm_*.lib | head -1)
S3=$(ls $L/asap7sc7p5t_SEQ_SLVT_TT_nldm_*.lib | head -1)
STA=/work/opensta_src/build/sta

for c in s38417 s38584; do
  yosys -q -p "read_verilog run/${c}_synth_SLVT.v; read_liberty -lib $S1; read_liberty -lib $S2; read_liberty -lib $S3; hierarchy -top $c; flatten; write_verilog -noattr -noexpr run/${c}_flat_SLVT.v"
  period=$(grep "^$c:" run/timing_budgets.txt | cut -d: -f2)
  echo "=== $c (period $period) ==="
  echo "modules in flat file : $(grep -c '^module' run/${c}_flat_SLVT.v)"
  echo "assign statements    : $(grep -c '^ *assign' run/${c}_flat_SLVT.v)"
  echo "DFF cells (SL)       : $(grep -c 'DFFHQNx1_ASAP7_75t_SL' run/${c}_flat_SLVT.v)"
  cat > /tmp/flatcheck.tcl << EOF
read_liberty $S1
read_liberty $S2
read_liberty $S3
read_verilog /work/run/${c}_flat_SLVT.v
link_design ${c}
create_clock -name clk -period ${period} [get_ports CK]
set_input_delay -clock clk 0 [all_inputs -no_clocks]
set_output_delay -clock clk 0 [all_outputs]
puts "INSTANCES: [llength [get_cells -hierarchical *]]"
puts "WNS_SETUP: [worst_slack -max]"
puts "WNS_HOLD: [worst_slack -min]"
report_power -digits 6
EOF
  $STA -no_init -exit /tmp/flatcheck.tcl 2>&1 | grep -E "INSTANCES|WNS_|^Total|Error"
done
echo ""
echo "Expected from the hierarchical netlists:"
echo "  s38417: instances 10041, setup 72.30, hold -8.63, leakage 6.568078e-05 W"
echo "  s38584: instances 11538, setup 249.33, hold -2.85, leakage 6.338936e-05 W"
