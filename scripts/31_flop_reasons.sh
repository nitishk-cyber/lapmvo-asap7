#!/bin/bash
cd /work
python3 - << "PY"
import json, re, subprocess
for c in ["s38417","s38584"]:
    subprocess.run(["yosys","-q","-p",
      f"read_verilog -sv iscas89/ISCAS89/{c}.v; hierarchy -check -top {c}; proc; flatten; write_json /tmp/{c}.json"],
      check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    mod = json.load(open(f"/tmp/{c}.json"))["modules"][c]
    cells = mod["cells"]
    drv = {}
    for cn, cell in cells.items():
        pd = cell["port_directions"]
        for p, bits in cell["connections"].items():
            if pd.get(p) == "output":
                for b in bits:
                    if isinstance(b, int): drv[b] = cn
    stack = [b for p, v in mod["ports"].items() if v["direction"] == "output" for b in v["bits"] if isinstance(b, int)]
    seen, vis = set(), set()
    while stack:
        b = stack.pop()
        if b in seen: continue
        seen.add(b)
        cn = drv.get(b)
        if cn is None or cn in vis: continue
        vis.add(cn)
        cell = cells[cn]; pd = cell["port_directions"]
        for p, bits in cell["connections"].items():
            if pd.get(p) == "input" and not (cell["type"] == "$dff" and p == "CLK"):
                for x in bits:
                    if isinstance(x, int) and x not in seen: stack.append(x)
    flops = {}
    for cn, cell in cells.items():
        if cell["type"] in ("$dff", "$_DFF_P_"):
            m = re.search(r"(DFF_\d+)", cn)
            if m: flops[m.group(1)] = cn
    syn = open(f"run/{c}_synth_SLVT.v").read()
    syn_inst = set(re.findall(r"^\s*dff\s+(DFF_\d+)\s*\(", syn, re.M))
    removed = sorted(set(flops) - syn_inst, key=lambda s:int(s.split("_")[1]))
    added = sorted(syn_inst - set(flops))
    unobs = [i for i in removed if flops[i] not in vis]
    obs   = [i for i in removed if flops[i] in vis]
    constD= [i for i in removed if not isinstance(cells[flops[i]]["connections"]["D"][0], int)]
    print(f"=== {c} ===")
    print(f"source flops: {len(flops)}   synthesized flop instances: {len(syn_inst)}   removed: {len(removed)}   only-in-synth: {len(added)}")
    print(f"  removed & unobservable: {len(unobs)}   removed & observable: {len(obs)}   removed with constant D: {len(constD)}")
    print(f"  removed observable examples: {obs[:10]}")
    log = open(f"run/{c}_SLVT_synth.log").read().splitlines()
    tally, ex = {}, {}
    for i in removed:
        pat = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(i) + r"(?![0-9A-Za-z_])")
        lines = [l.strip() for l in log if pat.search(l)]
        reason = "no log line mentions it"
        pick = None
        for key, name in (("identical","merged with an identical cell"),("onstant","constant input/output"),("unused","unused (no fanout)"),("Removing","other removal")):
            for l in lines:
                if key in l: reason, pick = name, l; break
            if pick: break
        tally[reason] = tally.get(reason, 0) + 1
        ex.setdefault(reason, []).append((i, (pick or "")[:170]))
    for r, n in tally.items():
        print(f"  Yosys reason: {r}: {n}")
        for i, l in ex[r][:2]: print(f"      {i}: {l}")
PY
echo "#### DONE ####"
