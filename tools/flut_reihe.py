#!/usr/bin/env python3
"""Flut-Messreihe (Paket Q, Kapitel 12.2): Siegquote der Wochenflut bei „normalem Ausbau“.

Für jede Woche 1..16 wird der Stand des normalen Spielers (45 min/Tag) aus der Wirtschaftssimulation genommen
(Bunker-Stufe, Turmstufe, Heldenstufe, Mauerart, Spielerstufe) und der Flut-Bot mehrmals gegen diese Basis
gespielt (--autotest=flood_q). Ergebnis: docs/balance/flut.md (+ flut_roh.json).

Aufruf (dauert: je Lauf 1–3 Minuten):
  python3 tools/flut_reihe.py --godot PFAD/Godot_v4.6.3-stable_linux.x86_64 [--weeks 1-16] [--reps 3] [--minutes 45]
  python3 tools/flut_reihe.py --report            # nur den Bericht aus flut_roh.json neu schreiben
Weitere Schalter: --fdiff 1 (Schwierigkeit Schwer), --weeklist 2,5,8, --passive (Held bleibt am Bunker), --tower +1 (Turmstufe gegenüber der Simulation verschieben), --tag NAME (eigene Rohdaten-Gruppe).
"""
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import wirtschaft_sim as W  # noqa: E402

RAW = os.path.join(ROOT, "docs", "balance", "flut_roh.json")
OUT = os.path.join(ROOT, "docs", "balance", "flut.md")


def plan(minutes, weeks):
    data = W.load(W.DATA)
    exp = W.load(W.EXPF)
    sim = W.Sim(data, exp, minutes, max(weeks) * 7 + 1).run()
    out = {}
    for f in sim.flood_log:
        if f["week"] in weeks:
            out[f["week"]] = f
    return out


def run_one(godot, args, limit=1500):
    t0 = time.time()
    cmd = [godot, "--headless", "--path", ROOT, "--", "--autotest=flood_q", "--fast=8", "--limit=%d" % limit] + args
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=1500)
        txt = p.stdout + p.stderr
    except subprocess.TimeoutExpired as e:
        txt = (e.stdout or "") if isinstance(e.stdout, str) else ""
    m = [l for l in txt.splitlines() if l.startswith("RESULT")]
    res = {"real": round(time.time() - t0, 1), "args": args}
    if not m:
        res["error"] = "kein Ergebnis" + (" (TIMEOUT)" if "TIMEOUT" in txt else "")
        errs = [l for l in txt.splitlines() if "SCRIPT ERROR" in l][:3]
        if errs:
            res["error"] += ": " + " | ".join(errs)
        return res
    l = m[-1]
    res["win"] = "win=true" in l
    for key, rx in [("kills", r"kills=(\d+)"), ("t", r" t=(\d+)s"), ("deaths", r"deaths=(\d+)")]:
        mm = re.search(rx, l)
        if mm:
            res[key] = int(mm.group(1))
    mm = re.search(r'"hp_ratio": ([0-9.]+)', l)
    res["hp"] = round(float(mm.group(1)), 2) if mm else 0.0
    mm = re.search(r'"stars": (\d+)', l)
    res["stars"] = int(mm.group(1)) if mm else 0
    mm = re.search(r'"waves": (\d+)', l)
    res["waves"] = int(mm.group(1)) if mm else 0
    return res


def report():
    raw = json.load(open(RAW, encoding="utf-8"))
    L = ["# Flut-Schwierigkeit (Paket Q)", ""]
    L.append("Messreihe mit dem Flut-Bot (`--autotest=flood_q`, Tempo 8) auf einer Basis, die dem **normalen Spieler (45 min/Tag)** der")
    L.append("Wirtschaftssimulation (`wirtschaft.md`) in dieser Woche entspricht: Bunker-Stufe, Ø Turmstufe, Heldenstufe, Mauerart und")
    L.append("Spielerstufe. Aufstellung der Türme wie die Testbasis (`P.debug_setup`): Ring um den Bunker, Mauerring außen.")
    L.append("Ziel (Kapitel 12.2): **70–85 % Siege** bei normalem Ausbau.")
    L.append("")
    L.append("Neu messen: `python3 tools/flut_reihe.py --godot <Godot> --weeks 1-16 --reps 3`")
    L.append("")
    for tag, grp in raw.items():
        L.append("## %s" % grp.get("title", tag))
        L.append("")
        if grp.get("text"):
            L.append(grp["text"])
            L.append("")
        L.append("| Woche | Bunker | Türme | Held | Mauer | Gegner | Läufe | Siege | Quote | Ø Bunker-Leben | Ø Sterne |")
        L.append("|---|---|---|---|---|---|---|---|---|---|---|")
        tot_w = 0
        tot_n = 0
        for wk in sorted(grp["weeks"], key=int):
            e = grp["weeks"][wk]
            runs = [r for r in e["runs"] if "win" in r]
            n = len(runs)
            w = sum(1 for r in runs if r["win"])
            tot_w += w
            tot_n += n
            hp = sum(r.get("hp", 0) for r in runs) / n if n else 0
            st = sum(r.get("stars", 0) for r in runs) / n if n else 0
            q = 100.0 * w / n if n else 0
            mark = "" if 70 <= q <= 85 else (" ▲" if q > 85 else " ▼")
            p = e["plan"]
            L.append("| %s | %d | %d | %d | %s | %d | %d | %d | %d %%%s | %d %% | %.1f |" % (wk, p["bunker"], p["tower"], p["hero"],
                     ["", "Holz", "Stein", "Metall"][p["wall"]], p.get("total", 0), n, w, q, mark, hp * 100, st))
        if tot_n:
            L.append("| **gesamt** | | | | | | %d | %d | **%d %%** | | |" % (tot_n, tot_w, 100.0 * tot_w / tot_n))
        L.append("")
    L.append("▲ = leichter als das Ziel, ▼ = schwerer als das Ziel.")
    L.append("")
    if os.path.exists(os.path.join(ROOT, "docs", "balance", "flut_text.md")):
        L.append(open(os.path.join(ROOT, "docs", "balance", "flut_text.md"), encoding="utf-8").read())
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    print("geschrieben:", OUT)


def main():
    a = sys.argv[1:]
    if "--report" in a:
        report()
        return
    godot = a[a.index("--godot") + 1]
    wk = a[a.index("--weeks") + 1] if "--weeks" in a else "1-16"
    lo, hi = (int(x) for x in wk.split("-")) if "-" in wk else (int(wk), int(wk))
    weeks = list(range(lo, hi + 1))
    if "--weeklist" in a:
        weeks = [int(x) for x in a[a.index("--weeklist") + 1].split(",")]
    reps = int(a[a.index("--reps") + 1]) if "--reps" in a else 3
    minutes = int(a[a.index("--minutes") + 1]) if "--minutes" in a else 45
    dtower = int(a[a.index("--tower") + 1]) if "--tower" in a else 0
    tag = a[a.index("--tag") + 1] if "--tag" in a else "normal"
    passive = "--passive" in a
    fdiff = a[a.index("--fdiff") + 1] if "--fdiff" in a else ""
    wl = a[a.index("--weeklist") + 1] if "--weeklist" in a else ""
    title = a[a.index("--title") + 1] if "--title" in a else "Normaler Ausbau (Simulation, %d min/Tag)" % minutes
    raw = json.load(open(RAW, encoding="utf-8")) if os.path.exists(RAW) else {}
    grp = raw.setdefault(tag, {"title": title, "weeks": {}})
    grp["title"] = title
    pl = plan(minutes, weeks)
    for w in weeks:
        f = pl[w]
        tower = max(1, min(f["bunker"], int(round(f["def_lv"])) + dtower))
        p = {"bunker": f["bunker"], "tower": tower, "hero": f["hero"], "wall": f["wall"], "level": f["level"], "total": f["total"]}
        args = ["--bunker=%d" % p["bunker"], "--week=%d" % w, "--tower=%d" % tower, "--herolv=%d" % p["hero"], "--wall=%d" % p["wall"],
                "--plevel=%d" % p["level"]] + (["--passive=1"] if passive else []) + (["--fdiff=" + fdiff] if fdiff else [])
        e = grp["weeks"].setdefault(str(w), {"plan": p, "runs": []})
        e["plan"] = p
        e["runs"] = [r for r in e["runs"] if r.get("args") == args]
        while len(e["runs"]) < reps:
            r = run_one(godot, args)
            e["runs"].append(r)
            print("Woche %d %s -> %s" % (w, " ".join(args), {k: r.get(k) for k in ("win", "hp", "stars", "kills", "real", "error")}), flush=True)
            with open(RAW, "w", encoding="utf-8") as fh:
                json.dump(raw, fh, indent=1, ensure_ascii=False)
    report()


if __name__ == "__main__":
    main()
