import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import os

os.makedirs('figures', exist_ok=True)

# ============================================================
# Fig 6: Real per-cell capacitance variation (ASAP7 RVT SIMPLE library)
# Source: parsed directly from asap7sc7p5t_SIMPLE_RVT_TT_nldm_*.lib
# ============================================================
cells = ['NAND2xp33\n(x0.33)', 'NOR2xp33\n(x0.33)', 'AND2x2', 'AND3x1', 'OR2x2',
         'NAND2x1', 'NOR2x1', 'NAND3x1', 'XOR2x1', 'NOR2x2', 'NAND3x2', 'NOR3x2']
caps = [0.342, 0.344, 0.505, 0.565, 0.514, 0.990, 1.009, 1.254, 1.521, 1.991, 2.538, 2.556]
wlm_flat = 0.889

fig, ax = plt.subplots(figsize=(10, 6), dpi=300)
bars = ax.bar(cells, caps, color='#4C72B0', edgecolor='black', linewidth=0.8, width=0.62,
              label='Real per-cell liberty capacitance (ASAP7 RVT)')
ax.axhline(wlm_flat, color='#C44E52', linestyle='--', linewidth=2.0,
           label='Flat WLM-proxy capacitance (0.889fF avg)')
for bar, val in zip(bars, caps):
    ax.text(bar.get_x()+bar.get_width()/2, val+0.04, f'{val:.3f}', ha='center', va='bottom', fontsize=8.5, fontweight='bold')
ax.set_ylabel('Input Pin Capacitance (fF)', fontsize=12, fontweight='bold')
ax.set_xlabel('ASAP7 asap7sc7p5t_28 Standard Cell (RVT)', fontsize=11, fontweight='bold')
ax.set_title('Real Input Capacitance Variation vs. Flat WLM Proxy\n(7.9x range across library: 0.337fF-2.663fF)', fontsize=12.5, fontweight='bold')
ax.set_ylim(0, 2.95)
ax.legend(fontsize=9.5, loc='upper left')
ax.grid(axis='y', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)
plt.setp(ax.get_xticklabels(), fontsize=9)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('figures/fig6_capacitance_variation.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 6 saved")

# ============================================================
# Fig 7: Sequential leakage dominance, s38417
# NOTE: this uses data from the original reproducibility run
# (not re-verified in your container - the full-swap TOTAL number
# WAS confirmed by your script 06/12 runs at 1426.83nW/97.8%, but
# the comb-only-vs-full breakdown itself was not separately re-run
# by you). Flagging this honestly rather than presenting it as
# independently verified.
# ============================================================
scenarios = ['Baseline\n(all-SLVT)', 'Combinational-only\nVt swap', 'Full swap\n(incl. flip-flops)']
seq_leak = [34265.9, 34265.9, 350.8]
comb_leak = [31415.0, 6404.3, 1076.0]

fig, ax = plt.subplots(figsize=(9.5, 6.2), dpi=300)
x = np.arange(len(scenarios))
width = 0.55
b1 = ax.bar(x, comb_leak, width, label='Combinational leakage', color='#4C72B0', edgecolor='black', linewidth=0.8)
b2 = ax.bar(x, seq_leak, width, bottom=comb_leak, label='Sequential (flip-flop) leakage', color='#C44E52', edgecolor='black', linewidth=0.8)
totals = [c+s for c,s in zip(comb_leak, seq_leak)]
reductions = [None, '38.1%\ntotal reduction', '97.8%\ntotal reduction']
for i,(t,r) in enumerate(zip(totals, reductions)):
    ax.text(x[i], t+1500, f'{t:,.0f} nW', ha='center', fontsize=10.5, fontweight='bold')
    if r: ax.text(x[i], t+8000, r, ha='center', fontsize=9.5, color='#333', style='italic')
for i in range(3):
    if comb_leak[i] > 2000: ax.text(x[i], comb_leak[i]/2, f'{comb_leak[i]:,.0f}', ha='center', va='center', fontsize=8.5, color='white', fontweight='bold')
    if seq_leak[i] > 2000: ax.text(x[i], comb_leak[i]+seq_leak[i]/2, f'{seq_leak[i]:,.0f}', ha='center', va='center', fontsize=8.5, color='white', fontweight='bold')
ax.set_ylabel('Leakage Power (nW)', fontsize=12, fontweight='bold')
ax.set_title('s38417 (10,041 cells, 1,564 flip-flops): Flip-Flop Leakage\nDominates Total Power (source: original reproducibility run)', fontsize=12, fontweight='bold')
ax.set_xticks(x); ax.set_xticklabels(scenarios, fontsize=10.5)
ax.set_ylim(0, 78000)
ax.legend(loc='upper right', fontsize=10)
ax.grid(axis='y', linestyle='--', alpha=0.4)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('figures/fig7_sequential_dominance.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 7 saved")

# ============================================================
# Fig 8: Runtime scaling
# NOTE: timings from the ORIGINAL x86_64 Linux sandbox run, not
# your Apple Silicon machine. Your container almost certainly ran
# faster or slower per-circuit - if you want a figure of YOUR
# actual timings, wrap `time bash 06_run_lapmvo_tt.sh` and rerun.
# ============================================================
circuits8 = ['c432','c880','c1908','c2670','c5315','c7552','s38417','s38584']
gates8 = np.array([119,199,198,399,1051,933,10041,11538])
runtime8 = np.array([0.41,0.45,0.50,0.71,1.78,2.37,88.06,187.03])
is_seq8 = [False]*6 + [True]*2

logn = np.log(gates8); logt = np.log(runtime8)
b, loga = np.polyfit(logn, logt, 1)
a = np.exp(loga)

fig, ax = plt.subplots(figsize=(9,6.5), dpi=300)
colors8 = ['#C44E52' if s else '#4C72B0' for s in is_seq8]
ax.scatter(gates8, runtime8, c=colors8, s=90, edgecolor='black', linewidth=1.0, zorder=5)
for g,t,name in zip(gates8, runtime8, circuits8):
    ax.annotate(name, (g,t), textcoords="offset points", xytext=(7,5), fontsize=9.5)
n_fit = np.logspace(np.log10(gates8.min()*0.8), np.log10(gates8.max()*1.2), 100)
t_fit = a * n_fit**b
ax.plot(n_fit, t_fit, '--', color='gray', linewidth=1.6, label=f't = {a:.2e} x n^{b:.2f}')
ax.set_xscale('log'); ax.set_yscale('log')
ax.set_xlabel('Number of Real Synthesized Gates (log scale)', fontsize=12, fontweight='bold')
ax.set_ylabel('Wall-Clock Runtime, seconds (log scale)', fontsize=12, fontweight='bold')
ax.set_title('Runtime Scaling — Original Reference Run\n(single-core x86_64; your machine will differ)', fontsize=12, fontweight='bold')
ax.legend(fontsize=9.5, loc='upper left')
ax.grid(True, which='both', linestyle='--', alpha=0.35)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('figures/fig8_runtime_scaling.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 8 saved")

# ============================================================
# Fig 9: Literature comparison (static citations, not experimental)
# ============================================================
methods = ['Dual-Vth (NBTI-aware)\nincremental', 'Dual-Vth (variation-\naware) incr.', 'Dual-Vt\n(Wei et al. 1998)',
           'LA-PMVO\n(this work)', 'LECTOR\n(Kim & Roy 2004)', 'MTCMOS / sleep\ntransistor (range)']
low  = [3.46, 20, 50, 51.6, 79.4, 70]
high = [14.88, 20, 50, 98.9, 79.4, 98]
colors9 = ['#8172B2','#8172B2','#DD8452','#4C72B0','#C44E52','#937860']

fig, ax = plt.subplots(figsize=(11,6.5), dpi=300)
y = np.arange(len(methods))
for i in range(len(methods)):
    if low[i]==high[i]:
        ax.barh(y[i], high[i], color=colors9[i], edgecolor='black', linewidth=0.8, height=0.6)
        ax.text(high[i]+1.5, y[i], f'{high[i]:.1f}%', va='center', fontsize=9.5, fontweight='bold')
    else:
        ax.barh(y[i], high[i]-low[i], left=low[i], color=colors9[i], edgecolor='black', linewidth=0.8, height=0.6, alpha=0.85)
        ax.text(high[i]+1.5, y[i], f'{low[i]:.1f}-{high[i]:.1f}%', va='center', fontsize=9.5, fontweight='bold')
ax.set_yticks(y); ax.set_yticklabels(methods, fontsize=10)
ax.set_xlabel('Reported Leakage Reduction (%)', fontsize=12, fontweight='bold')
ax.set_title('LA-PMVO vs. Real Published Literature\n(static citations, not an experiment)', fontsize=12, fontweight='bold')
ax.set_xlim(0,120)
ax.grid(axis='x', linestyle='--', alpha=0.4)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('figures/fig9_literature_comparison.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 9 saved")

print("\nAll remaining figures saved in ./figures/")
print("Files:", sorted(os.listdir('figures')))
