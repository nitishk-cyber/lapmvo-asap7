#!/bin/bash
WORKDIR="$(pwd)"
STA="$WORKDIR/opensta_src/build/sta"
L=$WORKDIR/asap7_libs
export WORKDIR
export LIBS="$(ls $L/asap7sc7p5t_SIMPLE_SLVT_TT_nldm_*.lib | head -1) $(ls $L/asap7sc7p5t_INVBUF_SLVT_TT_nldm_*.lib | head -1) $(ls $L/asap7sc7p5t_SEQ_SLVT_TT_nldm_*.lib | head -1) $(ls $L/asap7sc7p5t_SIMPLE_RVT_TT_nldm_*.lib | head -1) $(ls $L/asap7sc7p5t_INVBUF_RVT_TT_nldm_*.lib | head -1) $(ls $L/asap7sc7p5t_SEQ_RVT_TT_nldm_*.lib | head -1)"

cat > /tmp/constraints.tcl << 'EOF'
if {$::env(CLK) eq "CK"} {
  create_clock -name clk -period $::env(PERIOD) [get_ports CK]
  set_input_delay -clock clk 0 [all_inputs -no_clocks]
} else {
  create_clock -name clk -period $::env(PERIOD) [get_ports {}]
  set_input_delay -clock clk 0 [all_inputs]
}
set_output_delay -clock clk 0 [all_outputs]
EOF

cat > /tmp/allrvt_swap.tcl << 'EOF'
foreach l $::env(LIBS) { read_liberty $l }
read_verilog $::env(WORKDIR)/run/$::env(CKT)_synth_SLVT.v
link_design $::env(CKT)
source /tmp/constraints.tcl
set n 0
set miss 0
foreach c [get_cells -hierarchical *] {
  set ref [get_property $c ref_name]
  if {![string match "*_SL" $ref]} { continue }
  set rname [string map {_SL _R} $ref]
  if {[catch {get_lib_cell $rname} r] || $r eq ""} { incr miss; continue }
  replace_cell $c $r
  incr n
}
puts "SWAPINFO swapped=$n missing_RVT=$miss"
write_verilog $::env(WORKDIR)/run/$::env(CKT)_allRVT.v
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

measure() {
  export CKT=$1 NETLIST=$2 CLK=$3 PERIOD=$4
  out=$($STA -no_init -exit /tmp/measure.tcl 2>&1)
  MS=$(echo "$out" | grep "WNS_SETUP" | awk '{print $2}')
  MH=$(echo "$out" | grep "WNS_HOLD" | awk '{print $2}')
  ML=$(echo "$out" | grep "^Total" | awk '{print $4}')
}

echo "circuit | period | baseline: WNSsetup WNShold leak_nW | allRVT: swapped missing WNSsetup WNShold leak_nW | allRVT_reduction%"
while IFS=: read -r c period; do
  case $c in s38417|s38584) clk="CK" ;; *) clk="{}" ;; esac
  export CKT=$c CLK=$clk PERIOD=$period
  measure $c $WORKDIR/run/${c}_synth_SLVT.v $clk $period
  BS=$MS; BH=$MH; BL=$ML
  info=$($STA -no_init -exit /tmp/allrvt_swap.tcl 2>&1 | grep SWAPINFO)
  measure $c $WORKDIR/run/${c}_allRVT.v $clk $period
  python3 - << PY
bl=float("$BL")*1e9; rl=float("$ML")*1e9
print("$c | $period | base: $BS $BH %.2f | allRVT: $info $MS $MH %.2f | %.1f%%" % (bl, rl, 100*(1-rl/bl)))
PY
done < run/timing_budgets.txt
