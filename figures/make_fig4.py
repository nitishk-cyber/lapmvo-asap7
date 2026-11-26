import matplotlib.pyplot as plt

circuits = ['c432', 'c880', 'c1908', 'c2670', 'c5315', 'c7552', 's38417', 's38584']
gates = [119, 199, 198, 399, 1051, 933, 10041, 11538]
reduction = [59.6, 89.6, 70.8, 95.0, 95.2, 97.5, 97.8, 98.9]
is_seq = [False]*6 + [True]*2
colors = ['#4C72B0' if not s else '#C44E52' for s in is_seq]

fig, ax = plt.subplots(figsize=(10, 6), dpi=1000)
bars = ax.bar(circuits, reduction, color=colors, edgecolor='black', linewidth=0.8, width=0.62)
for bar, val, g in zip(bars, reduction, gates):
    ax.text(bar.get_x()+bar.get_width()/2, val+1.0, f'{val:.1f}%', ha='center', va='bottom', fontsize=10, fontweight='bold')
    ax.text(bar.get_x()+bar.get_width()/2, 3, f'{g:,}\ngates', ha='center', va='bottom', fontsize=8, color='white', fontweight='bold')

ax.set_ylabel('Leakage Power Reduction (%)', fontsize=12, fontweight='bold')
ax.set_xlabel('Benchmark Circuit', fontsize=12, fontweight='bold')
ax.set_title('LA-PMVO Real Leakage Reduction \u2014 All 8 Circuits, TT Corner\n(Open-source tools: Yosys, OpenSTA)', fontsize=12.5, fontweight='bold')
ax.set_ylim(0, 108)
ax.grid(axis='y', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)
from matplotlib.patches import Patch
ax.legend(handles=[Patch(facecolor='#4C72B0', edgecolor='black', label='Combinational (ISCAS-85)'),
                    Patch(facecolor='#C44E52', edgecolor='black', label='Sequential (ISCAS-89, incl. real flip-flops)')],
          loc='upper left', fontsize=10)
for spine in ['top','right']: ax.spines[spine].set_visible(False)
plt.tight_layout()
plt.savefig('fig4_leakage_reduction_1000dpi.png', dpi=1000, bbox_inches='tight')
print("Fig 4 saved")
