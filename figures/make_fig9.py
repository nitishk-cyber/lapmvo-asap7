import matplotlib.pyplot as plt
import numpy as np

circuits = ["c432","c880","c1908","c2670","c5315","c7552","s38417","s38584"]

baseline = {
    "c432":   {"SS":1734.91, "TT":281.10,   "FF":178.26},
    "c880":   {"SS":4745.41, "TT":799.48,   "FF":517.04},
    "c1908":  {"SS":5555.77, "TT":908.68,   "FF":579.94},
    "c2670":  {"SS":8223.60, "TT":1346.13,  "FF":859.39},
    "c5315":  {"SS":21361.06,"TT":3578.28,  "FF":2310.14},
    "c7552":  {"SS":23125.03,"TT":3843.80,  "FF":2473.63},
    "s38417": {"SS":401971.40,"TT":65680.80,"FF":41974.48},
    "s38584": {"SS":377154.90,"TT":63389.40,"FF":41026.60},
}
reduction = {
    "c432":   {"SS":51.6, "TT":59.6, "FF":77.7},
    "c880":   {"SS":88.7, "TT":89.6, "FF":90.7},
    "c1908":  {"SS":65.6, "TT":70.8, "FF":78.3},
    "c2670":  {"SS":93.2, "TT":95.0, "FF":94.7},
    "c5315":  {"SS":91.7, "TT":95.2, "FF":95.4},
    "c7552":  {"SS":94.9, "TT":97.5, "FF":96.4},
    "s38417": {"SS":96.0, "TT":97.8, "FF":97.5},
    "s38584": {"SS":97.7, "TT":98.9, "FF":98.7},
}

x = np.arange(len(circuits))
width = 0.26

fig, axes = plt.subplots(1, 2, figsize=(16, 6.5), dpi=1000)

ax = axes[0]
for i, corner in enumerate(["SS","TT","FF"]):
    vals = [baseline[c][corner] for c in circuits]
    color = {"SS":"#C44E52","TT":"#4C72B0","FF":"#55A868"}[corner]
    label = {"SS":"SS (slow)","TT":"TT (typical)","FF":"FF (fast)"}[corner]
    ax.bar(x + (i-1)*width, vals, width, color=color, edgecolor='black', linewidth=0.6, label=label)
ax.set_yscale('log')
ax.set_xticks(x)
ax.set_xticklabels(circuits, rotation=0, fontsize=10)
ax.set_ylabel('Baseline Leakage Power (nW, log scale)', fontsize=11, fontweight='bold')
ax.set_xlabel('Benchmark Circuit', fontsize=11, fontweight='bold')
ax.set_title('Baseline Leakage by Corner\n(SS > TT > FF holds for all 8 circuits)', fontsize=12, fontweight='bold')
ax.legend(loc='upper left', fontsize=9.5)
ax.grid(axis='y', which='both', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)

ax = axes[1]
for i, corner in enumerate(["SS","TT","FF"]):
    vals = [reduction[c][corner] for c in circuits]
    color = {"SS":"#C44E52","TT":"#4C72B0","FF":"#55A868"}[corner]
    ax.bar(x + (i-1)*width, vals, width, color=color, edgecolor='black', linewidth=0.6, label=corner)
ax.set_xticks(x)
ax.set_xticklabels(circuits, rotation=0, fontsize=10)
ax.set_ylabel('Leakage Reduction (%)', fontsize=11, fontweight='bold')
ax.set_xlabel('Benchmark Circuit', fontsize=11, fontweight='bold')
ax.set_title('LA-PMVO Reduction by Corner\n(highest usually at FF, lowest at SS)', fontsize=12, fontweight='bold')
ax.legend(loc='lower right', fontsize=9.5)
ax.set_ylim(0, 108)
ax.grid(axis='y', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)

fig.suptitle('Multi-Corner Analysis \u2014 All 8 Circuits (Real SS/TT ratio: 5.1\u00d7\u20136.15\u00d7, not the impossible 1,335\u00d7 originally reported)',
             fontsize=13.5, fontweight='bold', y=1.01)

plt.tight_layout()
plt.savefig('fig9_multicorner_fixed.png', dpi=1000, bbox_inches='tight')
print("saved")
