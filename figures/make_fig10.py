import matplotlib.pyplot as plt

margins = [2, 5, 10, 15, 20, 25, 30]
data = {
    'c432':   [38.6, 46.6, 58.4, 59.6, 69.1, 75.6, 91.2],
    'c880':   [87.6, 88.5, 89.3, 89.6, 90.6, 92.8, 93.3],
    'c1908':  [51.9, 57.3, 63.5, 70.8, 76.4, 80.8, 83.0],
    'c2670':  [91.0, 92.6, 94.6, 95.0, 95.7, 96.4, 97.3],
    'c5315':  [88.8, 89.9, 93.3, 95.2, 96.0, 97.4, 98.0],
    'c7552':  [95.9, 96.2, 97.0, 97.5, 97.7, 97.6, 97.8],
    's38417': [95.1, 96.1, 96.9, 97.8, 98.2, 98.3, 98.4],
    's38584': [98.9, 99.0, 99.0, 98.9, 99.0, 99.0, 99.0],
}
high_sensitivity = {'c432', 'c1908'}

fig, ax = plt.subplots(figsize=(9.5, 6.5), dpi=1000)

colors = {'c432': '#4C72B0', 'c1908': '#C44E52', 'c880': '#55A868', 'c2670': '#8172B2',
          'c5315': '#CCB974', 'c7552': '#64B5CD', 's38417': '#DD8452', 's38584': '#937860'}

for name, vals in data.items():
    if name in high_sensitivity:
        ax.plot(margins, vals, marker='o', linewidth=2.5, markersize=7, color=colors[name], label=name, zorder=3)
    else:
        ax.plot(margins, vals, marker='o', linewidth=1.3, markersize=4.5, linestyle='--',
                color=colors[name], alpha=0.85, label=name, zorder=2)

ax.set_xlabel('Timing Budget Margin (%)', fontsize=12, fontweight='bold')
ax.set_ylabel('Leakage Power Reduction (%)', fontsize=12, fontweight='bold')
ax.set_title('Sensitivity to Timing Budget\nTwo Distinct Profiles: High-Sensitivity (c432, c1908) vs. Low-Sensitivity (others)',
             fontsize=12.5, fontweight='bold')
ax.set_xticks(margins)
ax.grid(True, linestyle='--', alpha=0.4)
ax.set_axisbelow(True)
ax.legend(loc='lower right', fontsize=9.5, ncol=2)

plt.tight_layout()
plt.savefig('fig10_sensitivity_sweep_1000dpi.png', dpi=1000, bbox_inches='tight')
print("Fig 10 saved")
