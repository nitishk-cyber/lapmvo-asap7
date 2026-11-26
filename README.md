# LA-PMVO: scripts, netlists and logs (ASAP7, Yosys, OpenSTA)

Supplementary material for the manuscript on **LA-PMVO**, a liberty-accurate, post-synthesis
Multi-Vt (threshold-voltage) leakage optimization flow built entirely from open-source tools
(Yosys and OpenSTA) on the ASAP7 7 nm predictive PDK.

This repository contains the scripts, the synthesized and optimized gate-level netlists, and the
raw logs behind every number reported in the paper.

## What the flow does
1. Synthesizes ISCAS-85 / ISCAS-89 benchmarks to an all-SLVT ASAP7 netlist (Yosys + ABC).
2. Measures the all-SLVT critical path and sets the clock to 1.15 x that value, per circuit and per corner.
3. Ranks every SLVT cell by output-pin setup slack (OpenSTA) and tries to swap it to its footprint-matched
   RVT version, keeping the swap only if worst setup slack stays non-negative.
4. Writes the optimized netlist and re-measures leakage in a fresh OpenSTA session.

## Repository layout
| Folder | Contents |
|---|---|
| `scripts/` | Numbered shell scripts, in the order they were run |
| `netlists/` | Synthesized (all-SLVT), flattened, and LA-PMVO-optimized netlists (TT/SS/FF) |
| `logs/` | Timing budgets, result tables, sweep and equivalence logs |
| `figures/` | Python scripts that draw the figures |

## Environment used
- Docker image `ubuntu:24.04` (arm64) on an Apple-silicon Mac, single-threaded runs
- Yosys 0.33 (git 2584903a060)
- OpenSTA 3.1.0, commit `9a01c293e7`, built from source with CUDD 3.0.0
- Python 3.12.3, NumPy 1.26.4, SciPy 1.11.4, Matplotlib 3.11.1

## Not included
The ASAP7 liberty files and the OpenSTA / CUDD sources are **not** redistributed here.
`scripts/02_get_pdk.sh` fetches the PDK files and `scripts/01_build_opensta.sh` builds OpenSTA.
Please check the PDK's own license terms before redistributing it.

## Run order
| Scripts | Purpose |
|---|---|
| `00`-`05` | Install tools, build OpenSTA, get PDK and benchmarks, synthesize, baseline measurements |
| `06`-`16` | TT/SS/FF results, WLM baseline, timing-budget sweep, repeated trials, naive ordering. **For the two sequential circuits these used hierarchical netlists and are superseded by `19`-`22`.** |
| `17` | Uniform all-RVT reference (fails the timing budget on every circuit) |
| `18` | Final-netlist setup/hold check at every corner |
| `19`-`22` | Flattened sequential netlists: LA-PMVO at TT/SS/FF, WLM and combinational-only study, sweep and runtime. **These produce the sequential results in the paper.** |
| `23`-`33` | Equivalence, provenance and structural checks |
| `28`, `36` | Repair of constant-tie assignments dropped by OpenSTA `write_verilog` |
| `34`, `36` | Bounded sequential check: found unusable (flip-flop initial-state mismatch); kept for transparency, not used in the paper |

## Main results (TT corner, 1.15 x baseline critical path)
| Circuit | Leakage reduction |
|---|---|
| c432 | 59.6% |
| c880 | 89.6% |
| c1908 | 70.8% |
| c2670 | 95.0% |
| c5315 | 95.2% |
| c7552 | 97.5% |
| s38417 | 97.4% |
| s38584 | 98.9% |

All written netlists meet setup timing at TT, SS and FF (see `logs/` and Table 12 of the paper).
The six combinational final netlists were proven functionally equivalent to their sources by SAT miter checking.

## Known issues and limitations
- OpenSTA `write_verilog` omits constant-tie assignments (`assign x = 1'b0;`). The affected netlists
  were repaired before the equivalence checks; re-measurement showed no change in timing or leakage.
- A hierarchical netlist shares one definition per module, so sequential circuits must be flattened
  (`scripts/19_flatten.sh`) before per-instance Vt assignment.
- Formal equivalence of the synthesized **sequential** netlists to the benchmark sources was **not** established.
- ISCAS-85 sources are Genus-resynthesized gate-level netlists (from `jpsety/verilog_benchmark_circuits`);
  ISCAS-89 sources are from `santoshsmalagi/Benchmarks`.

## Citation
Please cite the manuscript (details to be added after publication) and, if you use these files, this repository
(see `CITATION.cff`).

## License
MIT for the scripts and logs (see `LICENSE`). Third-party tools, benchmarks and the ASAP7 PDK keep their own licenses.
