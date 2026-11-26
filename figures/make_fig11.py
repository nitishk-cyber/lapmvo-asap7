import matplotlib.pyplot as plt
import numpy as np

circuits = ['c432', 'c880', 'c1908', 'c2670', 'c5315', 'c7552', 's38417', 's38584']
trials =   [10, 10, 10, 10, 10, 10, 5, 5]
mean =     [106.16, 79.08, 264.36, 62.83, 174.89, 105.01, 1582.09, 661.41]
std =      [2.44, 3.24, 5.92, 3.88, 11.82, 8.64, 114.10, 0.00]
cv =       ['2.3%', '4.1%', '2.2%', '6.2%', '6.8%', '8.2%', '7.2%', '0.0%']
is_seq = [False]*6 + [True]*2
colors = ['#4C72B0' if not s else '#C44E52' for s in is_seq]

fig, ax = plt.subplots(figsize=(10, 6.5), dpi=1000)
x = np.arange(len(circuits))
bars = ax.bar(x, mean, yerr=std, capsize=5, color=colors, edgecolor='black', linewidth=0.8,
              error_kw={'linewidth': 1.5, 'ecolor': 'black'})

for i, (m, s, c, n) in enumerate(zip(mean, std, cv, trials)):
    ax.text(i, m + s + m*0.15, f'CV={c}\n(n={n})', ha='center', fontsize=9, fontweight='bold')

ax.set_yscale('log')
ax.set_xticks(x)
ax.set_xticklabels(circuits)
ax.set_ylabel('Post-Optimization Leakage Power (nW, log scale)', fontsize=11.5, fontweight='bold')
ax.set_xlabel('Benchmark Circuit', fontsize=12, fontweight='bold')
ax.set_title('Repeated-Trial Robustness: Mean \u00b1 Std. Dev. Across Randomized\nTie-Breaking Trials (10 trials, combinational; 5 trials, sequential)',
              fontsize=12.5, fontweight='bold')
ax.grid(axis='y', which='both', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)
from matplotlib.patches import Patch
ax.legend(handles=[Patch(facecolor='#4C72B0', edgecolor='black', label='Combinational (ISCAS-85), 10 trials'),
                    Patch(facecolor='#C44E52', edgecolor='black', label='Sequential (ISCAS-89), 5 trials')],
          loc='upper left', fontsize=9.5)

plt.tight_layout()
plt.savefig('fig11_repeated_trial_robustness_1000dpi.png', dpi=1000, bbox_inches='tight')
print("Fig 11 saved")
