import matplotlib.pyplot as plt
import numpy as np

fig, ax = plt.subplots(figsize=(9.5, 6.3), dpi=1000)

categories = ["Baseline\n(all-SLVT)", "Combinational-only\nVt swap", "Full swap\n(incl. flip-flops)"]
totals = [65680.92, 35315.08, 1426.80]
comb = [31414.99, 1049.15, 171.22]
seq = [t - c for t, c in zip(totals, comb)]

x = np.arange(len(categories))
width = 0.55

bars_comb = ax.bar(x, comb, width, label="Combinational leakage", color="#4C72B0", edgecolor="black", linewidth=0.6)
bars_seq = ax.bar(x, seq, width, bottom=comb, label="Sequential (flip-flop) leakage", color="#C44E52", edgecolor="black", linewidth=0.6)

for i in range(len(categories)):
    if comb[i] > 1500:
        ax.text(x[i], comb[i] / 2, f"{comb[i]:,.0f}", ha="center", va="center", color="white", fontsize=11, fontweight="bold")
    if seq[i] > 1500:
        ax.text(x[i], comb[i] + seq[i] / 2, f"{seq[i]:,.0f}", ha="center", va="center", color="white", fontsize=11, fontweight="bold")

for i in range(len(categories)):
    ax.text(x[i], totals[i] + 1500, f"{totals[i]:,.0f} nW", ha="center", va="bottom", fontsize=12, fontweight="bold")

reductions = [None, "46.2%\ntotal reduction", "97.8%\ntotal reduction"]
for i in [1, 2]:
    ax.text(x[i], 55000, reductions[i], ha="center", va="center", fontsize=11, style="italic", color="#444444")

ax.set_xticks(x)
ax.set_xticklabels(categories, fontsize=11)
ax.set_ylabel("Leakage Power (nW)", fontsize=12, fontweight="bold")
ax.set_title("s38417 (10,041 cells, 1,564 real flip-flops): Flip-Flop Leakage\nDominates \u2014 Combinational-Only Optimization Captures a Minority of Savings",
             fontsize=13, fontweight="bold")
ax.set_ylim(0, 78000)
ax.yaxis.grid(True, linestyle="--", alpha=0.5)
ax.set_axisbelow(True)
ax.legend(loc="upper right", fontsize=10, framealpha=0.9)

plt.tight_layout()
plt.savefig("fig6_sequential_dominance_fixed.png", dpi=1000)
print("saved")
