import matplotlib.pyplot as plt

cells = ['NAND2xp33\n(x0.33)', 'NOR2xp33\n(x0.33)', 'AND2x2', 'AND3x1', 'OR2x2',
         'NAND2x1', 'NOR2x1', 'NAND3x1', 'XOR2x1', 'NOR2x2', 'NAND3x2', 'NOR3x2']
caps = [0.342, 0.344, 0.505, 0.565, 0.514, 0.990, 1.009, 1.254, 1.521, 1.991, 2.538, 2.556]
wlm_flat = 0.889

fig, ax = plt.subplots(figsize=(10, 6), dpi=1000)
bars = ax.bar(cells, caps, color='#4C72B0', edgecolor='black', linewidth=0.8, width=0.62)
for bar, val in zip(bars, caps):
    ax.text(bar.get_x() + bar.get_width()/2, val + 0.04, f'{val:.3f}', ha='center', va='bottom',
            fontsize=10, fontweight='bold')

ax.axhline(wlm_flat, color='#C44E52', linestyle='--', linewidth=1.8,
           label='Flat WLM-proxy capacitance (0.889fF average, all cells)')
ax.bar([], [], color='#4C72B0', edgecolor='black', linewidth=0.8,
       label='Real per-cell liberty capacitance (ASAP7 asap7sc7p5t RVT)')

ax.set_ylabel('Input Pin Capacitance (fF)', fontsize=12, fontweight='bold')
ax.set_xlabel('ASAP7 asap7sc7p5t_28 Standard Cell (RVT)', fontsize=12, fontweight='bold')
ax.set_title('Real Input Capacitance Variation Across ASAP7 Standard Cells\nvs. Flat Wire-Load-Model Proxy (7.9\u00d7 range: 0.337fF\u20132.663fF full library)',
              fontsize=13, fontweight='bold')
ax.legend(loc='upper left', fontsize=10)
ax.grid(axis='y', linestyle='--', alpha=0.4)
ax.set_axisbelow(True)

plt.tight_layout()
plt.savefig('fig2_capacitance_variation_1000dpi.png', dpi=1000, bbox_inches='tight')
print("Fig 2 saved")
