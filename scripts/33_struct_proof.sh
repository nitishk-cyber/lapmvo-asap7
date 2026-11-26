#!/bin/bash
cd /work
echo "##### (1) cell types actually used in the eight final TT netlists #####"
cat run/c432_final_mvt.v run/c880_final_mvt.v run/c1908_final_mvt.v run/c2670_final_mvt.v run/c5315_final_mvt.v run/c7552_final_mvt.v run/s38417_flatfinal_TT.v run/s38584_flatfinal_TT.v | grep -ohE "[A-Za-z0-9_]+_ASAP7_75t_(SL|R)\b" | sed -E "s/_ASAP7_75t_(SL|R)//" | sort | uniq -c | sort -rn | awk '{printf "%s(%s) ", $2, $1} END {print ""}'

echo
echo "##### (2) library check restricted to used cell types #####"
python3 - << "PY"
import re, glob, subprocess
used = set(subprocess.run("cat run/*_final_mvt.v run/s38417_flatfinal_TT.v run/s38584_flatfinal_TT.v | grep -ohE \"[A-Za-z0-9_]+_ASAP7_75t_(SL|R)\\b\"", shell=True, capture_output=True, text=True).stdout.split())
used_base = {u.rsplit("_ASAP7_75t_", 1)[0] for u in used}
def parse(pattern):
    out = {}
    for path in sorted(glob.glob(pattern)):
        t = open(path).read()
        for part in re.split(r"\n\s*cell\s*\(", t)[1:]:
            name = part.split(")")[0].strip().strip(chr(34))
            out[name] = {"pins": tuple(re.findall(r"\bpin\s*\(\s*(\w+)\s*\)", part)),
                         "function": tuple(re.findall(r"function\s*:\s*\"([^\"]*)\"", part)),
                         "next_state": tuple(re.findall(r"next_state\s*:\s*\"([^\"]*)\"", part)),
                         "clocked_on": tuple(re.findall(r"clocked_on\s*:\s*\"([^\"]*)\"", part))}
    return out
S = parse("asap7_libs/asap7sc7p5t_*_SLVT_TT_nldm_*.lib")
R = parse("asap7_libs/asap7sc7p5t_*_RVT_TT_nldm_*.lib")
chk = bad = 0
for b in sorted(used_base):
    s = S.get(b + "_ASAP7_75t_SL"); r = R.get(b + "_ASAP7_75t_R")
    if s is None or r is None:
        print("  %-14s MISSING in library (SLVT: %s, RVT: %s)" % (b, s is not None, r is not None)); bad += 1; continue
    chk += 1
    diff = [k for k in s if s[k] != r[k]]
    if diff:
        bad += 1; print("  %-14s DIFFERS in %s" % (b, diff))
        for k in diff: print("      SLVT:", str(s[k])[:110]); print("      RVT :", str(r[k])[:110])
print("used base cell types: %d   checked pairs: %d   problems: %d" % (len(used_base), chk, bad))
bad_all = [n for n in S if n in S and n.replace("_ASAP7_75t_SL", "_ASAP7_75t_R") in R and S[n] != R[n.replace("_ASAP7_75t_SL", "_ASAP7_75t_R")]]
print("all-library mismatching SLVT cells (%d): %s" % (len(bad_all), [n.split("_ASAP7")[0] for n in bad_all]))
PY

echo
echo "##### (3) alias-aware structural comparison, sequential circuits #####"
python3 - << "PY"
import re
blk = re.compile(r"^\s*(\w+_ASAP7_75t_(?:SL|R|L))\s+(\S+)\s*\((.*?)\)\s*;", re.M | re.S)
def norm(n):
    n = re.sub(r"\s+", "", n).lstrip("\\")
    if re.fullmatch(r"1.[bh]0", n): return "CONST0"
    if re.fullmatch(r"1.[bh]1", n): return "CONST1"
    return n
def load(path):
    t = open(path).read()
    cells = {}
    for m in blk.finditer(t):
        typ, name, body = m.groups()
        cells[name.lstrip("\\")] = (typ, {p: norm(n) for p, n in re.findall(r"\.(\w+)\s*\(([^)]*)\)", body)})
    asg = [(norm(a), norm(b)) for a, b in re.findall(r"assign\s+(\S+)\s*=\s*([^;]+);", t)]
    return cells, asg
for c in ["s38417", "s38584"]:
    A, aA = load(f"run/{c}_flat_SLVT.v")
    B, aB = load(f"run/{c}_flatfinal_TT.v")
    par = {}
    def find(x):
        par.setdefault(x, x)
        while par[x] != x:
            par[x] = par[par[x]]; x = par[x]
        return x
    def union(a, b): par[find(a)] = find(b)
    for a, b in aA: union(a, b)
    for cell in A.values():
        for n in cell[1].values(): find(n)
    diff = unk = chk = 0; ex = []
    for name, (ta, pa) in A.items():
        if name not in B: continue
        tb, pb = B[name]
        if set(pa) != set(pb): diff += 1; ex.append((name, "pin set differs")); continue
        for p in pa:
            chk += 1
            na, nb = pa[p], pb[p]
            if nb not in par and nb not in ("CONST0", "CONST1"): unk += 1; ex.append((name, p, na, nb)); continue
            if find(na) != find(nb): diff += 1; ex.append((name, p, na, nb))
    print("%-7s cells flat=%d final=%d same-names=%d  pins compared=%d  connection mismatches=%d  unknown net names=%d" % (c, len(A), len(B), len(set(A) & set(B)), chk, diff, unk))
    print("   examples:", ex[:3])
PY

echo
echo "##### (4) flop cascade test on the s38584 / s38417 sources (generic Yosys opt only) #####"
for c in s38584 s38417; do
  echo -n "$c  flatten+opt+opt_clean : "
  yosys -q -p "read_verilog -sv iscas89/ISCAS89/$c.v; hierarchy -check -top $c; proc; flatten; opt; opt; opt; opt_clean -purge; tee -o /tmp/cas_$c.txt select -count t:\$dff" >/dev/null 2>&1
  grep -m1 -E "[0-9]+ objects" /tmp/cas_$c.txt || tail -1 /tmp/cas_$c.txt
done
echo "(expected if the cascade explanation is right: s38584 -> 1416 flops, s38417 -> 1564 flops)"
echo "#### DONE ####"
