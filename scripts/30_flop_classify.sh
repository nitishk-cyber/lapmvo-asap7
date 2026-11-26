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
            inst = cn.split(".")[0].lstrip("\\")
            flops[inst] = cn
    syn = open(f"run/{c}_synth_SLVT.v").read()
    syn_inst = {m.group(1).lstrip("\\") for m in re.finditer(r"^\s*dff\s+(\S+)\s*\(", syn, re.M)}
    removed = sorted(set(flops) - syn_inst)
    added = sorted(syn_inst - set(flops))
    obs = [i for i in removed if flops[i] in vis]
    unobs = [i for i in removed if flops[i] not in vis]
    constD = []
    for i in removed:
        d = cells[flops[i]]["connections"]["D"][0]
        if not isinstance(d, int): constD.append(i)
    all_unobs = [i for i, cn in flops.items() if cn not in vis]
    print(f"=== {c} ===")
    print(f"source flops (flattened): {len(flops)}   synthesized flop instances: {len(syn_inst)}")
    print(f"removed by instance name: {len(removed)}   instances only in synth: {len(added)}")
    print(f"  removed AND unobservable (no path to any primary output): {len(unobs)}")
    print(f"  removed BUT observable (reaches a primary output):        {len(obs)}   e.g. {obs[:5]}")
    print(f"  removed with constant D input:                            {len(constD)}")
    print(f"unobservable flops in the whole source: {len(all_unobs)} ; of those removed: {len(set(all_unobs) & set(removed))}")
PY
echo "#### DONE ####"
