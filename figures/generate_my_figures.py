import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import os

os.makedirs('figures', exist_ok=True)

# ============================================================
# Fig 1: Leakage reduction, all 8 circuits, TT corner (Table 3)
# ============================================================
circuits = ['c432', 'c880', 'c1908', 'c2670', 'c5315', 'c7552', 's38417', 's38584']
gates = [119, 199, 198, 399, 1051, 933, 10041, 11538]
reduction = [59.6, 89.6, 70.8, 95.0, 95.2, 97.5, 97.8, 98.9]
is_seq = [False]*6 + [True]*2
colors = ['#4C72B0' if not s else '#C44E52' for s in is_seq]

fig, ax = plt.subplots(figsize=(10, 6), dpi=300)
bars = ax.bar(circuits, reduction, color=colors, edgecolor='black', linewidth=0.8, width=0.62)
for bar, val, g in zip(bars, reduction, gates):
    ax.text(bar.get_x()+bar.get_width()/2, val+1.0, f'{val:.1f}%', ha='center', va='bottom', fontsize=10, fontweight='bold')
    ax.text(bar.get_x()+bar.get_width()/2, 3, f'{g:,}\ngates', ha='center', va='bottom', fontsize=8, color='white', fontweight='bold')
ax.set_ylabel('Leakage Power Reduction (%)', fontsize=12, fontweight='bold')
ax.set_xlabel('Benchmark Circuit', fontsize=12, fontweight='bold')
ax.set_title('LA-PMVO Leakage Reduction — All 8 Benchmarks (TT Corner)\nIndependently reproduced on Apple Silicon / Docker', fontsize=12.5, fontweight='bold')
ax.set_ylim(0, 108)
ax.grid(axis='y', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)
from matplotlib.patches import Patch
ax.legend(handles=[Patch(facecolor='#4C72B0', edgecolor='black', label='Combinational (ISCAS-85)'),
                    Patch(facecolor='#C44E52', edgecolor='black', label='Sequential (ISCAS-89)')],
          loc='upper left', fontsize=10)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('figures/fig1_leakage_reduction.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 1 saved")

# ============================================================
# Fig 2: LA-PMVO vs WLM-MVt, all 8 circuits (Table 4)
# ============================================================
la_pmvo = [59.6, 89.6, 70.8, 95.0, 95.2, 97.5, 97.8, 98.9]
wlm      = [62.9, 91.6, 73.9, 95.2, 94.9, 96.9, 97.3, 99.0]
x = np.arange(len(circuits))
width = 0.36
fig, ax = plt.subplots(figsize=(11, 6), dpi=300)
b1 = ax.bar(x-width/2, la_pmvo, width, label='LA-PMVO (liberty-accurate)', color='#4C72B0', edgecolor='black', linewidth=0.8)
b2 = ax.bar(x+width/2, wlm, width, label='WLM-MVt (flat-capacitance proxy)', color='#DD8452', edgecolor='black', linewidth=0.8)
for bars in (b1,b2):
    for bar in bars:
        h = bar.get_height()
        ax.text(bar.get_x()+bar.get_width()/2, h+0.6, f'{h:.1f}%', ha='center', va='bottom', fontsize=8.5, fontweight='bold')
for i,(l,w) in enumerate(zip(la_pmvo, wlm)):
    marker = 'LA-PMVO' if l>w else 'WLM'
    ax.text(x[i], max(l,w)+3.0, marker, ha='center', fontsize=7, color='#333', style='italic')
avg_la, avg_wlm = np.mean(la_pmvo), np.mean(wlm)
ax.axhline(avg_la, color='#4C72B0', linestyle=':', linewidth=1.2, alpha=0.7)
ax.axhline(avg_wlm, color='#DD8452', linestyle=':', linewidth=1.2, alpha=0.7)
ax.set_ylabel('Leakage Power Reduction (%)', fontsize=12, fontweight='bold')
ax.set_xlabel('Benchmark Circuit', fontsize=12, fontweight='bold')
ax.set_title(f'LA-PMVO vs. WLM-MVt Baseline — All 8 Circuits\navg LA-PMVO={avg_la:.1f}%  avg WLM={avg_wlm:.1f}% (independently reproduced)', fontsize=12, fontweight='bold')
ax.set_xticks(x); ax.set_xticklabels(circuits)
ax.set_ylim(0, 112)
ax.legend(loc='lower right', fontsize=10)
ax.grid(axis='y', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('figures/fig2_wlm_comparison.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 2 saved")

# ============================================================
# Fig 3: Multi-corner analysis, 6 combinational circuits (Table 7)
# ============================================================
mc_circuits = ['c432','c880','c1908','c2670','c5315','c7552']
tt_base = [281.10, 799.48, 908.68, 1346.13, 3578.28, 3843.80]
ss_base = [1734.906, 4745.412, 5555.774, 8223.602, 21361.06, 23125.03]
ff_base = [178.2646, 517.043, 579.9368, 859.3864, 2310.144, 2473.628]
tt_red = [59.6, 89.6, 70.8, 95.0, 95.2, 97.5]
ss_red = [51.6, 88.7, 65.6, 93.2, 91.7, 94.9]
ff_red = [77.7, 90.7, 78.3, 94.7, 95.4, 96.4]

fig, axes = plt.subplots(1, 2, figsize=(13,6), dpi=300)
xm = np.arange(len(mc_circuits))
wm = 0.26
ax = axes[0]
ax.bar(xm-wm, ss_base, wm, label='SS (slow)', color='#C44E52', edgecolor='black', linewidth=0.7)
ax.bar(xm, tt_base, wm, label='TT (typical)', color='#4C72B0', edgecolor='black', linewidth=0.7)
ax.bar(xm+wm, ff_base, wm, label='FF (fast)', color='#55A868', edgecolor='black', linewidth=0.7)
ax.set_yscale('log')
ax.set_ylabel('Baseline Leakage (nW, log scale)', fontsize=11, fontweight='bold')
ax.set_xlabel('Circuit', fontsize=11, fontweight='bold')
ax.set_title('Baseline Leakage by Corner\n(SS > TT > FF for all 6 circuits)', fontsize=11.5, fontweight='bold')
ax.set_xticks(xm); ax.set_xticklabels(mc_circuits, fontsize=9.5)
ax.legend(fontsize=9.5)
ax.grid(axis='y', which='both', linestyle='--', alpha=0.35)
for spine in ['top','right']: ax.spines[spine].set_visible(False)

ax2 = axes[1]
ax2.bar(xm-wm, ss_red, wm, label='SS', color='#C44E52', edgecolor='black', linewidth=0.7)
ax2.bar(xm, tt_red, wm, label='TT', color='#4C72B0', edgecolor='black', linewidth=0.7)
ax2.bar(xm+wm, ff_red, wm, label='FF', color='#55A868', edgecolor='black', linewidth=0.7)
ax2.set_ylabel('Leakage Reduction (%)', fontsize=11, fontweight='bold')
ax2.set_xlabel('Circuit', fontsize=11, fontweight='bold')
ax2.set_title('LA-PMVO Reduction by Corner', fontsize=11.5, fontweight='bold')
ax2.set_xticks(xm); ax2.set_xticklabels(mc_circuits, fontsize=9.5)
ax2.set_ylim(0,105)
ax2.legend(fontsize=9.5, loc='lower right')
ax2.grid(axis='y', linestyle='--', alpha=0.35)
for spine in ['top','right']: ax2.spines[spine].set_visible(False)

fig.suptitle('Multi-Corner Analysis — Independently Reproduced', fontsize=12.5, fontweight='bold', y=1.02)
plt.tight_layout()
plt.savefig('figures/fig3_multicorner.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 3 saved")

# ============================================================
# Fig 4: Sensitivity sweep, all 8 circuits (Table 8)
# ============================================================
margins = [2,5,10,15,20,25,30]
sweep = {
 'c432':   [38.6,46.6,58.4,59.6,69.1,75.6,91.2],
 'c880':   [87.6,88.5,89.3,89.6,90.6,92.8,93.3],
 'c1908':  [51.9,57.3,63.5,70.8,76.4,80.8,83.0],
 'c2670':  [91.0,92.6,94.6,95.0,95.7,96.4,97.3],
 'c5315':  [88.8,89.9,93.3,95.2,96.0,97.4,98.0],
 'c7552':  [95.9,96.2,97.0,97.5,97.7,97.6,97.8],
 's38417': [95.1,96.1,96.9,97.8,98.2,98.3,98.4],
 's38584': [98.9,99.0,99.0,98.9,99.0,99.0,99.0],
}
high_sens = {'c432','c1908'}
fig, ax = plt.subplots(figsize=(10.5,7), dpi=300)
palette = plt.cm.tab10(np.linspace(0,1,10))
for i,(name,vals) in enumerate(sweep.items()):
    if name in high_sens:
        ax.plot(margins, vals, marker='o', linewidth=2.6, markersize=7, label=f'{name} (high-sensitivity)', color=palette[i], zorder=5)
    else:
        ax.plot(margins, vals, marker='o', linewidth=1.4, markersize=5, label=name, color=palette[i], alpha=0.75, linestyle='--', zorder=3)
ax.set_xlabel('Timing Budget Margin (%)', fontsize=12, fontweight='bold')
ax.set_ylabel('Leakage Power Reduction (%)', fontsize=12, fontweight='bold')
ax.set_title('Sensitivity to Timing Budget — All 8 Circuits\nIndependently reproduced (exact match to original)', fontsize=12, fontweight='bold')
ax.set_xticks(margins)
ax.set_ylim(30,102)
ax.legend(fontsize=9, loc='lower right', ncol=2)
ax.grid(True, linestyle='--', alpha=0.35)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('figures/fig4_sensitivity_sweep.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 4 saved")

# ============================================================
# Fig 5: Repeated-trial robustness, 6 combinational circuits (Table 9)
# ============================================================
rt_circuits = ['c432','c880','c1908','c2670','c5315','c7552']
means = [106.16, 79.08, 264.36, 62.83, 174.89, 105.01]
stds  = [2.44, 3.24, 5.93, 3.88, 11.82, 8.64]
cvs   = [2.3, 4.1, 2.2, 6.2, 6.8, 8.2]

fig, ax = plt.subplots(figsize=(10,6.5), dpi=300)
xr = np.arange(len(rt_circuits))
bars = ax.bar(xr, means, yerr=stds, capsize=6, color='#4C72B0', edgecolor='black', linewidth=0.9,
              error_kw={'linewidth':1.8,'ecolor':'#333'})
for i,(m,s,cv) in enumerate(zip(means, stds, cvs)):
    ax.text(xr[i], m+s+max(means)*0.03, f'CV={cv:.1f}%\n(n=10)', ha='center', va='bottom', fontsize=8.5, fontweight='bold')
ax.set_yscale('log')
ax.set_ylabel('Post-Optimization Leakage (nW, log scale)', fontsize=12, fontweight='bold')
ax.set_xlabel('Circuit', fontsize=12, fontweight='bold')
ax.set_title('Repeated-Trial Robustness (10 randomized-tiebreak trials)\nIndependently reproduced — exact match', fontsize=12, fontweight='bold')
ax.set_xticks(xr); ax.set_xticklabels(rt_circuits)
ax.grid(axis='y', which='both', linestyle='--', alpha=0.35)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('figures/fig5_robustness.png', dpi=300, bbox_inches='tight')
plt.close()
print("Fig 5 saved")

print("\nAll figures saved in ./figures/")
print("Files:", os.listdir('figures'))
