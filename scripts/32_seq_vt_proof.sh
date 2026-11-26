#!/bin/bash
cd /work
echo "##### (a) final netlist vs pre-LA-PMVO netlist, after renaming _R -> _SL #####"
python3 - << "PY"
import re
pairs = [(c, f"run/{c}_synth_SLVT.v", f"run/{c}_final_mvt.v") for c in ["c432","c880","c1908","c2670","c5315","c7552"]]
pairs += [(c, f"run/{c}_flat_SLVT.v", f"run/{c}_flatfinal_TT.v") for c in ["s38417","s38584"]]
blk = re.compile(r"^\s*(\w+_ASAP7_75t_(?:SL|R|L))\s+(\S+)\s*\((.*?)\)\s*;", re.M | re.S)
def cells(path):
    t = open(path).read()
    d = {}
    for m in blk.finditer(t):
        typ, name, body = m.groups()
        pins = tuple(sorted((p, re.sub(r"\s+", "", n)) for p, n in re.findall(r"\.(\w+)\s*\(([^)]*)\)", body)))
        d[name] = (typ, pins)
    return d
print("%-7s %8s %8s %8s %10s %10s %10s" % ("circuit","cells_A","cells_B","missing","type_chg","conn_diff","swapped"))
for c, a, b in pairs:
    A, B = cells(a), cells(b)
    missing = len(set(A) ^ set(B))
    tchg = cdiff = swapped = 0
    for n in set(A) & set(B):
        ta, pa = A[n]; tb, pb = B[n]
        if pa != pb: cdiff += 1
        if ta != tb:
            tchg += 1
            if tb == ta.replace("_SL", "_R"): swapped += 1
    print("%-7s %8d %8d %8d %10d %10d %10d" % (c, len(A), len(B), missing, tchg, cdiff, swapped))
print("(expected: missing=0, conn_diff=0, type_chg == swapped)")
PY

echo
echo "##### (b) SLVT vs RVT cell pairs: identical logic function strings? #####"
python3 - << "PY"
import re, glob
tot = bad = 0; ex = []
for grp in ["SIMPLE", "INVBUF", "SEQ", "AO", "OA"]:
    fs = sorted(glob.glob(f"asap7_libs/asap7sc7p5t_{grp}_SLVT_TT_nldm_*.lib"))
    fr = sorted(glob.glob(f"asap7_libs/asap7sc7p5t_{grp}_RVT_TT_nldm_*.lib"))
    if not fs or not fr: continue
    def parse(path):
        t = open(path).read()
        out = {}
        for part in re.split(r"\n\s*cell\s*\(", t)[1:]:
            name = part.split(")")[0].strip().strip(chr(34))
            sig = (tuple(re.findall(r"\bpin\s*\(\s*(\w+)\s*\)", part)),
                   tuple(re.findall(r"function\s*:\s*\"([^\"]*)\"", part)),
                   tuple(re.findall(r"next_state\s*:\s*\"([^\"]*)\"", part)),
                   tuple(re.findall(r"clocked_on\s*:\s*\"([^\"]*)\"", part)))
            out[name] = sig
        return out
    S, R = parse(fs[0]), parse(fr[0])
    n = b = 0
    for name, sig in S.items():
        rn = name.replace("_ASAP7_75t_SL", "_ASAP7_75t_R")
        if rn in R:
            n += 1
            if R[rn] != sig:
                b += 1; ex.append(name)
    print("%-7s SLVT cells=%3d RVT cells=%3d paired=%3d  function/pin mismatches=%d" % (grp, len(S), len(R), n, b))
    tot += n; bad += b
print("TOTAL paired=%d mismatches=%d %s" % (tot, bad, ex[:5]))
PY

echo
echo "##### (c) s38584: the 10 removed flops - what do they connect to? #####"
python3 - << "PY"
import json, re, subprocess
c = "s38584"
subprocess.run(["yosys","-q","-p", f"read_verilog -sv iscas89/ISCAS89/{c}.v; hierarchy -check -top {c}; proc; flatten; write_json /tmp/{c}.json"],
               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
mod = json.load(open(f"/tmp/{c}.json"))["modules"][c]
cells = mod["cells"]
drv, cons = {}, {}
for cn, cell in cells.items():
    pd = cell["port_directions"]
    for p, bits in cell["connections"].items():
        for b in bits:
            if not isinstance(b, int): continue
            if pd.get(p) == "output": drv[b] = cn
            else: cons.setdefault(b, []).append((cn, p))
portout = {b for p, v in mod["ports"].items() if v["direction"] == "output" for b in v["bits"] if isinstance(b, int)}
flops = {}
for cn, cell in cells.items():
    if cell["type"] in ("$dff", "$_DFF_P_"):
        m = re.search(r"(DFF_\d+)", cn)
        if m: flops[m.group(1)] = cn
syn = open(f"run/{c}_synth_SLVT.v").read()
syn_inst = set(re.findall(r"^\s*dff\s+(DFF_\d+)\s*\(", syn, re.M))
removed = sorted(set(flops) - syn_inst, key=lambda s: int(s.split("_")[1]))
def ctype(cn): return cells[cn]["type"] if cn in cells else "?"
for i in removed:
    cell = cells[flops[i]]
    d = cell["connections"]["D"][0]; q = cell["connections"]["Q"][0]
    dd = "CONST %s" % d if not isinstance(d, int) else ("own Q" if d == q else "%s" % ctype(drv.get(d, "?")))
    cl = cons.get(q, [])
    types = sorted({ctype(x[0]) for x in cl})
    print("%-9s D<-%-18s Q fanout=%d types=%s  Q_is_primary_output=%s" % (i, dd, len(cl), types[:4], q in portout))
PY
echo "#### DONE ####"
