#!/bin/bash
cd /work
echo "##### lines mentioning N3875 #####"
for f in iscas85/c2670.v run/c2670_synth_SLVT.v run/c2670_final_mvt.v; do
  echo "--- $f"; grep -n "N3875" $f | head -6
done
echo
python3 - << "PY"
import re, glob
def scan(path):
    t=open(path).read()
    outs=set()
    for m in re.finditer(r"\boutput\s+(?:\[[^\]]*\]\s*)?([^;]+);", t):
        for n in re.split(r"[,\s]+", m.group(1).strip()):
            if n: outs.add(n)
    drv=set(re.findall(r"\.(?:Y|CON|SN|QN|Q|H|L)\s*\(\s*([^\s()]+)\s*\)", t))
    asg=re.findall(r"assign\s+(\S+)\s*=\s*([^;]+);", t)
    asg_l={a for a,b in asg}
    und=sorted(o for o in outs if o not in drv and o not in asg_l)
    return len(outs), und, len(asg)
files=[]
for c in ["c432","c880","c1908","c2670","c5315","c7552"]:
    files += [f"run/{c}_synth_SLVT.v", f"run/{c}_final_mvt.v", f"run/{c}_final_mvt_SS.v", f"run/{c}_final_mvt_FF.v"]
for c in ["s38417","s38584"]:
    files += [f"run/{c}_flat_SLVT.v", f"run/{c}_flatfinal_TT.v", f"run/{c}_flatfinal_SS.v", f"run/{c}_flatfinal_FF.v"]
print("%-34s %8s %9s %8s" % ("file","outputs","undriven","assigns"))
for f in files:
    try:
        n,u,a=scan(f)
        print("%-34s %8d %9d %8d  %s" % (f,n,len(u),a,u[:3] if u else ""))
    except Exception as e:
        print("%-34s ERROR %s" % (f,e))
PY
echo "#### DONE ####"
