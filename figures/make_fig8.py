import matplotlib.pyplot as plt
import numpy as np

circuits = ["c432","c880","c1908","c2670","c5315","c7552","s38417","s38584"]
gates    = np.array([119, 199, 198, 399, 1051, 933, 10041, 11538])
times    = np.array([0.55, 0.528, 0.563, 0.697, 1.361, 1.747, 50.767, 113.098])
is_seq   = [False]*6 + [True]*2
colors   = ['#4C72B0' if not s else '#C44E52' for s in is_seq]

ln_n = np.log(gates)
ln_t = np.log(times)
b, loga = np.polyfit(ln_n, ln_t, 1)
a = np.exp(loga)
pred = loga + b*ln_n
ss_res = np.sum((ln_t-pred)**2)
ss_tot = np.sum((ln_t-np.mean(ln_t))**2)
r2 = 1 - ss_res/ss_tot

fig, ax = plt.subplots(figsize=(9.5, 7), dpi=1000)

for g, t, c in zip(gates, times, colors):
    ax.scatter(g, t, s=110, color=c, edgecolor='black', linewidth=0.8, zorder=3)
for name, g, t in zip(circuits, gates, times):
    dx = 1.08
    dy = 1.15 if name not in ("c880", "c1908") else (0.78 if name == "c880" else 1.35)
    ax.annotate(name, (g, t), xytext=(g*dx, t*dy), fontsize=10)

n_line = np.logspace(np.log10(gates.min())-0.05, np.log10(gates.max())+0.05, 100)
t_line = a * n_line**b
ax.plot(n_line, t_line, '--', color='gray', linewidth=1.5)

n0, t0 = gates[0], times[0]
c_ref = t0 / (n0*np.log(n0))
t_ref_line = c_ref * n_line*np.log(n_line)
ax.plot(n_line, t_ref_line, ':', color='green', linewidth=1.8)

ax.set_xscale('log')
ax.set_yscale('log')
ax.set_xlabel('Number of Real Synthesized Gates (log scale)', fontsize=12, fontweight='bold')
ax.set_ylabel('Wall-Clock Runtime, seconds (log scale)', fontsize=12, fontweight='bold')
ax.set_title(f'LA-PMVO Runtime Scaling \u2014 Real Measured Data, All 8 Circuits\n(Apple Silicon; Superlinear O(n^{b:.2f}), not O(n log n) as originally claimed)',
             fontsize=13, fontweight='bold')
ax.grid(True, which='both', linestyle='--', alpha=0.4)

from matplotlib.lines import Line2D
legend_elems = [
    Line2D([0],[0], color='gray', linestyle='--', linewidth=1.5, label=f'Power-law fit: t \u2248 {a:.2e} \u00d7 n^{b:.2f}  (R\u00b2={r2:.2f})'),
    Line2D([0],[0], color='green', linestyle=':', linewidth=1.8, label='O(n log n) reference (anchored at c432)'),
]
leg1 = ax.legend(handles=legend_elems, loc='upper left', fontsize=9.5, framealpha=0.9)
ax.add_artist(leg1)

from matplotlib.patches import Patch
circuit_legend = [
    Patch(facecolor='#4C72B0', edgecolor='black', label='Combinational'),
    Patch(facecolor='#C44E52', edgecolor='black', label='Sequential'),
]
ax.legend(handles=circuit_legend, loc='lower right', fontsize=10, title='Circuit type', framealpha=0.9)
ax.add_artist(leg1)

plt.tight_layout()
plt.savefig('fig8_runtime_scaling_fixed.png', dpi=1000)
print(f"a={a:.4e} b={b:.4f} r2={r2:.4f}")
print("saved")
