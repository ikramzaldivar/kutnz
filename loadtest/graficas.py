"""Gráficas de las pruebas (k6 + registro del ASG) para el documento.  Uso:  python loadtest/graficas.py"""
import collections
import csv
import datetime as dt
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt

R = Path(__file__).parent / "resultados"
OUT = Path(__file__).parent.parent / "docs" / "documento"
NAVY, BLUE, SKY, RED = "#273462", "#045490", "#84B7CE", "#d93a4a"
plt.rcParams.update({"font.family": "Arial", "font.size": 10})
DAY = "2026-11-17"


def hhmmss(s):
    return dt.datetime.fromisoformat(f"{DAY}T{s}")


def k6_buckets(name, step=15):
    b = collections.defaultdict(lambda: {"n": 0, "err": 0, "dur": []})
    with open(R / name) as f:
        for r in csv.DictReader(f):
            t = int(r["timestamp"]) // step * step
            if r["metric_name"] == "http_reqs":
                b[t]["n"] += 1
                b[t]["err"] += r["status"] != "302"
            elif r["metric_name"] == "http_req_duration":
                b[t]["dur"].append(float(r["metric_value"]))
    rows = []
    for t in sorted(b)[1:-1]:
        d = sorted(b[t]["dur"]) or [0]
        rows.append((dt.datetime.fromtimestamp(t, dt.timezone.utc).replace(tzinfo=None), b[t]["n"] / step,
                     b[t]["err"], d[int(len(d) * 0.95) - 1]))
    return rows


def asg(name, col=2):
    with open(R / name) as f:
        rows = [r for r in list(csv.reader(f))[1:] if len(r) > col and r[col]]
    return [hhmmss(r[0]) for r in rows], [int(r[col]) for r in rows]


def chart(rows, asg_rows, file, title, events=(), errors=False, asg_label="instancias"):
    t = [r[0] for r in rows]
    fig, ax = plt.subplots(3, 1, figsize=(7.2, 6.4), sharex=True, gridspec_kw={"height_ratios": [1, 1.2, 0.8]})
    if errors:
        ax[0].bar(t, [r[2] / 15 for r in rows], width=15 / 86400, color=RED)
        ax[0].set_ylabel("errores/s")
    else:
        ax[0].plot(t, [r[1] for r in rows], color=BLUE, lw=1.8)
        ax[0].set_ylabel("peticiones/s")
    ax[1].plot(t, [r[3] for r in rows], color=NAVY, lw=1.8)
    ax[1].set_yscale("log")
    ax[1].set_ylabel("p95 total (ms, log)")
    ax[1].axhline(300, color=RED, ls="--", lw=1)
    ax[1].text(t[0], 330, "meta 300 ms (incluye red México → Virginia)", color=RED, fontsize=8)
    at, av = asg_rows
    ax[2].step(at, av, where="post", color=BLUE, lw=2)
    ax[2].set_ylabel(asg_label)
    ax[2].set_ylim(0, 7)
    for e_t, label in events:
        for a in ax:
            a.axvline(e_t, color=RED, lw=1, ls=":")
        ax[1].text(e_t, ax[1].get_ylim()[1] * 0.8, " " + label, color=RED, fontsize=8, va="top")
    for a in ax:
        a.grid(alpha=0.25)
        a.spines[["top", "right"]].set_visible(False)
    ax[2].xaxis.set_major_formatter(mdates.DateFormatter("%H:%M"))
    ax[2].set_xlabel("hora (UTC)")
    fig.suptitle(title, fontsize=11, fontweight="bold", color=NAVY)
    fig.tight_layout()
    fig.savefig(OUT / file, dpi=200)
    print("ok", file)


chart(k6_buckets("carga.csv"), asg("asg.csv"), "grafica_carga.png",
      "Prueba de carga: rampa a 400 req/s (k6)",
      [(hhmmss("06:18:23"), "el ASG pide 6")])

if (R / "caos.csv").exists():
    ev = []
    with open(R / "caos_eventos.csv") as f:
        for r in list(csv.reader(f))[1:]:
            ev.append((hhmmss(r[0]), "zona caída" if r[1].startswith("az") else "failover Valkey"))
    chart(k6_buckets("caos.csv"), asg("caos_asg.csv", col=3), "grafica_caos.png",
          "Prueba de caos con carga constante de 150 req/s", ev,
          errors=True, asg_label="sanas en el ALB")

# ---------- Segunda ronda, con las mejoras (health check 5 s, circuit breaker, escalado programado) ----------
if (R / "v2_carga.csv").exists():
    chart(k6_buckets("v2_carga.csv"), asg("v2_asg.csv"), "grafica_carga_v2.png",
          "Prueba de carga con escalado programado (mínimo 4 antes del pico)")
if (R / "v2_caos.csv").exists():
    ev = []
    with open(R / "v2_caos_eventos.csv") as f:
        for r in list(csv.reader(f))[1:]:
            ev.append((hhmmss(r[0]), "zona caída" if r[1].startswith("az") else "failover Valkey"))
    chart(k6_buckets("v2_caos.csv"), asg("v2_caos_asg.csv", col=3), "grafica_caos_v2.png",
          "Prueba de caos con las mejoras (150 req/s)", ev, errors=True, asg_label="sanas en el ALB")
