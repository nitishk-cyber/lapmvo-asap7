#!/bin/bash
cd /work
L=asap7_libs
chk() {
  cat > /tmp/h_$1.ys << EOF
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_SLVT_TT.lib
read_liberty -ignore_miss_func -ignore_miss_dir $L/combined_RVT_TT.lib
read_verilog -sv $2
rename $4 gold
read_verilog -sv $3
rename $4 gate
proc
flatten
opt_clean
miter -equiv -make_outputs gold gate miter
hierarchy -top miter
flatten
opt_clean
sat -prove trigger 0 -show-ports -timeout 600 miter
EOF
  yosys -s /tmp/h_$1.ys > run/h_$1.log 2>&1
  v=$(grep -m1 -E "no model found|model found" run/h_$1.log | sed 's/SAT proof finished - //')
  echo "$1 : $v"
}
echo "##### remaining final netlists (validated method) #####"
for c in c880 c1908 c5315; do chk ${c}_final iscas85/$c.v run/${c}_final_mvt.v $c; done
echo
echo "##### c2670: where does the difference come from? #####"
chk c2670_src_vs_synth   iscas85/c2670.v          run/c2670_synth_SLVT.v  c2670
chk c2670_synth_vs_final run/c2670_synth_SLVT.v   run/c2670_final_mvt.v   c2670
chk c2670_src_vs_final   iscas85/c2670.v          run/c2670_final_mvt.v   c2670
chk c2670_src_vs_allRVT  iscas85/c2670.v          run/c2670_allRVT.v      c2670
echo
echo "##### counterexample: ports that differ (from the SAT model) #####"
python3 - << "PY"
import re
t=open("run/h_c2670_src_vs_final.log").read()
rows=re.findall(r"^\s*(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s*$", t, re.M)
vals={n:b for n,d,h,b in rows}
gold={n[len("gold_"):] if n.startswith("gold_") else n[len("\\gold_"):]:v for n,v in vals.items() if "gold_" in n}
gate={n[len("gate_"):] if n.startswith("gate_") else n[len("\\gate_"):]:v for n,v in vals.items() if "gate_" in n}
diff=[k for k in gold if k in gate and gold[k]!=gate[k]]
print("ports in model:", len(vals), " gold outputs:", len(gold), " gate outputs:", len(gate))
print("outputs that differ:", diff[:20])
for k in diff[:6]: print("  ", k, "gold=",gold[k], "gate=",gate[k])
PY
echo
echo "##### structure: outputs with no driver, and assign statements #####"
python3 - << "PY"
import re
def scan(path, top="c2670"):
    t=open(path).read()
    outs=set()
    for m in re.finditer(r"\boutput\s+(?:\[[^\]]*\]\s*)?([^;]+);", t):
        for n in re.split(r"[,\s]+", m.group(1).strip()):
            if n: outs.add(n)
    drv=set(re.findall(r"\.(?:Y|CON|SN|QN|Q|H|L)\s*\(\s*([^\s()]+)\s*\)", t))
    asg=re.findall(r"assign\s+(\S+)\s*=\s*([^;]+);", t)
    asg_l={a for a,b in asg}
    und=sorted(o for o in outs if o not in drv and o not in asg_l)
    return len(outs), len(und), und[:12], len(asg), asg[:4]
for name,p in [("source ","iscas85/c2670.v"),("synth  ","run/c2670_synth_SLVT.v"),("final  ","run/c2670_final_mvt.v"),("allRVT ","run/c2670_allRVT.v")]:
    n,u,l,na,sa=scan(p)
    print(name,"outputs=",n," undriven=",u,l," assigns=",na,sa)
PY
echo "#### DONE ####"
