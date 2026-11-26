#!/bin/bash
cd /work
python3 - << "PY"
import re
for c in ["s38417","s38584"]:
    src=open(f"iscas89/ISCAS89/{c}.v").read()
    syn=open(f"run/{c}_synth_SLVT.v").read()
    # source: dff NAME(CK,Q,D);
    sf={}
    for m in re.finditer(r"^\s*dff\s+(\S+)\s*\(\s*CK\s*,\s*([^\s,]+)\s*,\s*([^\s,)]+)\s*\)\s*;", src, re.M):
        sf[m.group(2)]=(m.group(1), m.group(3))
    # synthesized: dff NAME ( .CK(CK), .D(x), .Q(y) );
    yf={}
    for m in re.finditer(r"dff\s+(\S+)\s*\((.*?)\);", syn, re.S):
        d=re.search(r"\.D\(([^)]*)\)", m.group(2)); q=re.search(r"\.Q\(([^)]*)\)", m.group(2))
        if d and q: yf[q.group(1).strip()]=(m.group(1), d.group(1).strip())
    missing=[q for q in sf if q not in yf]
    extra=[q for q in yf if q not in sf]
    def occ(text, tok): return len(re.findall(r"(?<![A-Za-z0-9_$\\])"+re.escape(tok)+r"(?![A-Za-z0-9_$])", text))
    gone=[q for q in missing if occ(syn,q)==0]            # Q net vanished entirely
    alive=[q for q in missing if occ(syn,q)>0]            # Q net still referenced in synthesized netlist
    nofan=[q for q in missing if occ(src,q)<=2]           # in source appears only in dff instance (+ maybe decl) -> no fanout
    byD={}
    for q,(n,d) in sf.items(): byD.setdefault(d,[]).append(q)
    dup=sum(len(v)-1 for v in byD.values() if len(v)>1)
    print(f"=== {c} ===")
    print(f"source flops={len(sf)}  synthesized flops={len(yf)}  missing={len(missing)}  extra(in synth only)={len(extra)}")
    print(f"missing flops whose Q net no longer appears anywhere in the synthesized netlist: {len(gone)}")
    print(f"missing flops whose Q net is STILL referenced (merged/aliased?): {len(alive)}  e.g. {alive[:4]}")
    print(f"missing flops with no fanout in the source (Q appears <=2 times): {len(nofan)}")
    print(f"source flops that share a D net with another flop (mergeable duplicates): {dup}")
    print("examples of missing flops:", [(q,sf[q]) for q in missing[:3]])
PY

echo
echo "##### SS/FF equivalence for the other five circuits (validated miter+SAT) #####"
L=asap7_libs
chk() {
  cat > /tmp/q_$1.ys << EOF
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
sat -prove trigger 0 -timeout 600 miter
EOF
  yosys -s /tmp/q_$1.ys > run/q_$1.log 2>&1
  echo "$1 : $(grep -m1 -E 'no model found|model found' run/q_$1.log | sed 's/SAT proof finished - //')"
}
for c in c432 c880 c1908 c5315 c7552; do
  for k in SS FF; do chk ${c}_$k iscas85/$c.v run/${c}_final_mvt_$k.v $c; done
done
echo "#### DONE ####"
