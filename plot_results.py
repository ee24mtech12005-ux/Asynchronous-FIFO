# Generates PNG plots from the simulation traces in results/
import csv, re, glob, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# --- 1. occupancy / flags during fill-then-drain (fast writer, slow reader) ---
t, occ, full, empty, wa, ra = [], [], [], [], [], []
with open("results/fast_w_slow_r_trace.csv") as f:
    for r in csv.DictReader(f):
        if "x" in r.values() or "z" in r.values(): continue   # skip pre-reset unknowns
        t.append(int(r["time_ps"]) / 1000.0)          # ns
        occ.append(int(r["occupancy"])); full.append(int(r["wfull"])); empty.append(int(r["rempty"]))
        wa.append(int(r["write_acc"])); ra.append(int(r["read_acc"]))
t0 = t[0]; t = [x - t0 for x in t]

fig, ax = plt.subplots(4, 1, figsize=(11, 8), sharex=True, gridspec_kw={"height_ratios": [3, 1, 1, 1]})
ax[0].step(t, occ, where="post", color="tab:blue"); ax[0].axhline(16, ls="--", color="gray", lw=0.8)
ax[0].set_ylabel("Words in FIFO"); ax[0].set_title("Async FIFO: fill to FULL, then drain to EMPTY  (wclk=100 MHz, rclk=40 MHz, depth=16)")
ax[1].step(t, full, where="post", color="tab:red");   ax[1].set_ylabel("wfull")
ax[2].step(t, empty, where="post", color="tab:green"); ax[2].set_ylabel("rempty")
ax[3].step(t, wa, where="post", label="write accepted", color="tab:orange")
ax[3].step(t, [x * 0.5 for x in ra], where="post", label="read accepted", color="tab:purple")
ax[3].set_ylabel("accepted"); ax[3].set_xlabel("time (ns)"); ax[3].legend(loc="upper right", fontsize=8)
for a in ax: a.grid(alpha=0.3)
plt.tight_layout(); plt.savefig("results/fill_drain_occupancy.png", dpi=130); plt.close()

# --- 2. summary of all clock-ratio runs ---
rows = []
for fn in sorted(glob.glob("results/*.log")):
    if fn.endswith("summary.log"): continue
    s = open(fn).read()
    g = lambda p: int(re.search(p, s).group(1))
    name = os.path.basename(fn)[:-4]
    m = re.search(r"wclk=(\d+) ps\s+rclk=(\d+) ps", s)
    rows.append((name, int(m.group(1)), int(m.group(2)), g(r"total words written\s*:\s*(\d+)"),
                 g(r"data mismatches/errors\s*:\s*(\d+)"), g(r"max occupancy observed\s*:\s*(\d+)"),
                 "PASS" if "*** PASS ***" in s else "FAIL"))
with open("results/summary_table.md", "w") as f:
    f.write("| Config | wclk (MHz) | rclk (MHz) | Words transferred | Errors | Max occupancy | Result |\n|---|---|---|---|---|---|---|\n")
    for n, w, r, wr, e, mo, res in rows:
        f.write(f"| {n} | {1e6/w:.1f} | {1e6/r:.1f} | {wr} | {e} | {mo}/16 | {res} |\n")
print(open("results/summary_table.md").read())

fig, ax = plt.subplots(figsize=(10, 3 + 0.4 * len(rows))); ax.axis("off")
cells = [[n, f"{1e6/w:.1f}", f"{1e6/r:.1f}", wr, e, f"{mo}/16", res] for n, w, r, wr, e, mo, res in rows]
tb = ax.table(cellText=cells, colLabels=["Config", "wclk MHz", "rclk MHz", "Words", "Errors", "Max occ.", "Result"],
              loc="center", cellLoc="center"); tb.auto_set_font_size(False); tb.set_fontsize(10); tb.scale(1, 1.6)
for i, r in enumerate(rows, start=1):
    tb[(i, 6)].set_facecolor("#c8f7c5" if r[6] == "PASS" else "#f7c5c5")
ax.set_title("Async FIFO regression summary", pad=10)
plt.savefig("results/regression_summary.png", dpi=130, bbox_inches="tight"); plt.close()
