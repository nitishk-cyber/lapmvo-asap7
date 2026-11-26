import matplotlib.pyplot as plt
import numpy as np

methods = [
    ("Dual-Vth\n(NBTI-aware)\nincremental", 3.5, 14.9, "#B39DDB", "Transistor\n(incremental)"),
    ("Dual-Vth\n(variation-\naware) incr.", 20.0, 20.0, "#7E57C2", "Transistor\n(incremental)"),
    ("Dual-Vt\n(Wei et al.\n1998)", 50.0, 50.0, "#DD8452", "Transistor"),
    ("LA-PMVO\n(this work)", 51.6, 98.9, "#4C72B0", "Standard-cell\n/ EDA flow"),
    ("LECTOR\n(Kim & Roy\n2004)", 79.4, 79.4, "#C44E52", "Transistor"),
    ("MTCMOS /\nsleep transistor\n(range)", 70.0, 98.0, "#A1887F", "Transistor\n+ circuit"),
]

fig, ax = plt.subplots(figsize=(11, 7), dpi=1000)
y = np.arange(len(methods))

for i, (name, lo, hi, color, level) in enumerate(methods):
    ax.barh(i, hi - lo, left=lo, height=0.55, color=color, edgecolor='black', linewidth=0.8)
    label = f"{lo:.1f}%" if lo == hi else f"{lo:.1f}\u2013{hi:.1f}%"
    ax.text(hi + 1.5, i, label, va='center', fontsize=11, fontweight='bold')
    ax.text(128, i, level, va='center', fontsize=9.5, style='italic', color='#444444')

ax.set_yticks(y)
ax.set_yticklabels([m[0] for m in methods], fontsize=10.5)
ax.set_xlabel('Reported Leakage Reduction (%)', fontsize=12, fontweight='bold')
ax.set_xlim(0, 145)
ax.set_title('LA-PMVO vs. Real Published Literature\n(Incremental-over-baseline refinements are typically modest; LA-PMVO\'s range spans both regimes)',
             fontsize=12.5, fontweight='bold')
ax.grid(axis='x', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)
ax.text(0.5, -0.15, 'Note: "incremental" values are gains over an already-Vt-optimized baseline, not raw reduction from an unoptimized circuit.\nLA-PMVO is the only entry evaluated at the standard-cell/EDA-flow level with a fully open-source toolchain.',
        transform=ax.transAxes, ha='center', fontsize=8.8, style='italic', color='#555555')

plt.tight_layout()
plt.subplots_adjust(bottom=0.22)
plt.savefig('fig7_literature_comparison_1000dpi.png', dpi=1000)
print("Fig 7 saved")
