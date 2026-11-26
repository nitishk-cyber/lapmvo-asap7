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

> run/trial_results.csv
echo "circuit,seed,leakage_nw" > run/trial_results.csv

get_baseline() {
  local c=$1
cat > /tmp/trialbase_${c}.tcl << EOF
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
  out=$($STA -no_init -exit /tmp/trialbase_${c}.tcl 2>&1)
  ws=$(echo "$out" | grep "WORST_SLACK" | awk '{print $2}')
  BASE_CP=$(python3 -c "print(100000 - $ws)")
  PERIOD=$(python3 -c "print(round($BASE_CP * 1.15, 2))")
  JITTER=$(python3 -c "print(round($PERIOD * 0.01, 4))")
  BASE_LEAK=$(echo "$out" | grep "^Total" | awk '{print $4}')
}

run_trial() {
  local c=$1
  local seed=$2

cat > /tmp/trial_${c}_${seed}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_synth_SLVT.v
link_design ${c}
create_clock -name clk -period ${PERIOD} [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]

expr {srand(${seed})}

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
    set jitter [expr {(rand() - 0.5) * ${JITTER}}]
    lappend ranked [list [expr {\$sl + \$jitter}] \$c]
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
write_verilog $WORKDIR/run/${c}_trial_${seed}.v
EOF
  $STA -no_init -exit /tmp/trial_${c}_${seed}.tcl > /dev/null 2>&1

cat > /tmp/trialpwr_${c}_${seed}.tcl << EOF
read_liberty $SIMPLE_SLVT
read_liberty $INVBUF_SLVT
read_liberty $SEQ_SLVT
read_liberty $SIMPLE_RVT
read_liberty $INVBUF_RVT
read_liberty $SEQ_RVT
read_verilog $WORKDIR/run/${c}_trial_${seed}.v
link_design ${c}
create_clock -name clk -period 100000 [get_ports {}]
set_input_delay -clock clk 0 [all_inputs]
set_output_delay -clock clk 0 [all_outputs]
report_power -digits 6
EOF
  leak=$($STA -no_init -exit /tmp/trialpwr_${c}_${seed}.tcl 2>&1 | grep "^Total" | awk '{print $4}')
  leak_nw=$(python3 -c "print($leak * 1e9)")
  echo "${c},${seed},${leak_nw}" >> run/trial_results.csv
}

for c in c432 c880 c1908 c2670 c5315 c7552; do
  echo "=== $c ==="
  get_baseline $c
  for seed in 1 2 3 4 5 6 7 8 9 10; do
    run_trial $c $seed
    echo "  seed=$seed done"
  done
done

echo ""
echo "=== Computing statistics ==="
python3 << 'PYEOF'
import csv, statistics
from collections import defaultdict

data = defaultdict(list)
with open('run/trial_results.csv') as f:
    reader = csv.DictReader(f)
    for row in reader:
        data[row['circuit']].append(float(row['leakage_nw']))

print(f"{'Circuit':<8}{'Mean(nW)':>11}{'StdDev':>9}{'CV%':>7}")
for c in ['c432','c880','c1908','c2670','c5315','c7552']:
    vals = data[c]
    mean = statistics.mean(vals)
    std = statistics.stdev(vals)
    print(f"{c:<8}{mean:>11.2f}{std:>9.2f}{std/mean*100:>6.1f}%")
PYEOF

echo ""
echo "Expected (manuscript Table 9):"
echo "  c432:  mean=106.16 std=2.44  CV=2.3%"
echo "  c880:  mean=79.08  std=3.24  CV=4.1%"
echo "  c1908: mean=264.36 std=5.92  CV=2.2%"
echo "  c2670: mean=62.83  std=3.88  CV=6.2%"
echo "  c5315: mean=174.89 std=11.82 CV=6.8%"
echo "  c7552: mean=105.01 std=8.64  CV=8.2%"
