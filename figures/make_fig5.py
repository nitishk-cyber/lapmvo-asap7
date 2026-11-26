import matplotlib.pyplot as plt
import numpy as np

circuits = ["c432", "c880", "c1908", "c2670", "c5315", "c7552", "s38417", "s38584"]
la_pmvo = [59.6, 89.6, 70.8, 95.0, 95.2, 97.5, 97.8, 98.9]
wlm =     [62.9, 91.6, 74.1, 95.2, 94.9, 96.9, 97.3, 99.0]
winner =  ["WLM", "WLM", "WLM", "WLM", "LA-PMVO", "LA-PMVO", "LA-PMVO", "WLM"]

avg_la = sum(la_pmvo) / len(la_pmvo)
avg_wlm = sum(wlm) / len(wlm)
avg_la_display = 88.1
avg_wlm_display = round(avg_wlm, 1)

x = np.arange(len(circuits))
width = 0.38

fig, ax = plt.subplots(figsize=(11.5, 6.3), dpi=1000)

bars1 = ax.bar(x - width/2, la_pmvo, width, label="LA-PMVO (liberty-accurate)", color="#4C72B0", edgecolor="black", linewidth=0.6)
bars2 = ax.bar(x + width/2, wlm, width, label="WLM-MVt (flat-capacitance proxy)", color="#DD8452", edgecolor="black", linewidth=0.6)

for i in range(len(circuits)):
    ax.text(x[i] - width/2, la_pmvo[i] + 1.0, f"{la_pmvo[i]:.1f}%", ha="center", va="bottom", fontsize=9.5, fontweight="bold")
    ax.text(x[i] + width/2, wlm[i] + 1.0, f"{wlm[i]:.1f}%", ha="center", va="bottom", fontsize=9.5, fontweight="bold")
    label_y = max(la_pmvo[i], wlm[i]) + 4.5
    ax.text(x[i], label_y, f"\u25b2 {winner[i]}", ha="center", va="bottom", fontsize=8.5, style="italic", color="#333333")

ax.axhline(avg_la, color="#4C72B0", linestyle=":", linewidth=1.3)
ax.axhline(avg_wlm, color="#DD8452", linestyle=":", linewidth=1.3)
ax.text(len(circuits) - 0.4, avg_wlm + 1.0, f"{avg_wlm_display:.1f}%", color="#DD8452", fontsize=10, fontweight="bold", ha="left")
ax.text(len(circuits) - 0.4, avg_la - 3.0, f"avg {avg_la_display:.1f}%", color="#4C72B0", fontsize=10, fontweight="bold", ha="left")

n_favor_lapmvo = sum(1 for w in winner if w == "LA-PMVO")
ax.set_title(f"LA-PMVO vs. WLM-MVt Baseline \u2014 Liberty Accuracy Advantage is Small,\n"
             f"Inconsistent in Direction ({n_favor_lapmvo} of {len(circuits)} circuits favor LA-PMVO)",
             fontsize=13, fontweight="bold")
ax.set_xlabel("Benchmark Circuit", fontsize=12, fontweight="bold")
ax.set_ylabel("Leakage Power Reduction (%)", fontsize=12, fontweight="bold")
ax.set_xticks(x)
ax.set_xticklabels(circuits, fontsize=11)
ax.set_ylim(0, 112)
ax.yaxis.grid(True, linestyle="--", alpha=0.5)
ax.set_axisbelow(True)
ax.legend(loc="lower right", fontsize=10, framealpha=0.9)

plt.tight_layout()
plt.savefig("fig5_wlm_comparison_fixed.png", dpi=1000)
print("saved")
