#!/usr/bin/env python3
"""Misst die Web-Version im Browser (Paket Q, Kapitel 3.2/12.2): Download, Ladezeit und Speicher.

Startet einen kleinen Webserver im Exportordner und öffnet das Spiel mit Playwright/Chromium im iPhone-13-Profil (quer).
Gemessen werden:
  - Download: Summe aller übertragenen Bytes (index.pck, index.wasm, …)
  - Zeit bis das Spiel läuft (Godot entfernt den Ladebalken), danach 20 s Hauptmenü, ein Tippen, 25 s Basis
  - WASM-Speicher (HEAP8 der Engine), JS-Heap (performance.memory) und der Speicher des Browser-Tabs
    (RSS aller Renderer-Prozesse dieses Browsers aus /proc)

Aufruf:
  python3 tools/web_messung.py build/web [--port 8765] [--wait 60] [--shot bild.png] [--json ergebnis.json]
Nur für Linux mit Chromium unter /opt/pw-browsers/chromium (wie im Prüf-Rechenzentrum); Bildausgabe per SwiftShader.
"""
import asyncio
import json
import os
import subprocess
import sys
import time


def rss_of_tree(root_pid):
    """Summe RSS (MB) aller Prozesse unterhalb root_pid, getrennt nach Renderer und gesamt."""
    kids = {}
    for p in os.listdir("/proc"):
        if not p.isdigit():
            continue
        try:
            with open("/proc/%s/stat" % p) as f:
                st = f.read().split()
            kids.setdefault(int(st[3]), []).append(int(p))
        except Exception:
            pass
    todo = [root_pid]
    seen = []
    while todo:
        x = todo.pop()
        seen.append(x)
        todo.extend(kids.get(x, []))
    total = 0.0
    rend = 0.0
    gpu = 0.0
    for pid in seen:
        try:
            with open("/proc/%d/status" % pid) as f:
                rss = [l for l in f.read().splitlines() if l.startswith("VmRSS")]
            with open("/proc/%d/cmdline" % pid, "rb") as f:
                cmd = f.read().replace(b"\0", b" ").decode(errors="replace")
            mb = int(rss[0].split()[1]) / 1024.0 if rss else 0.0
            total += mb
            if "--type=renderer" in cmd:
                rend = max(rend, mb)
            if "--type=gpu-process" in cmd:
                gpu += mb
        except Exception:
            pass
    return round(total), round(rend), round(gpu)


async def measure(folder, port, wait, shot):
    from playwright.async_api import async_playwright
    srv = subprocess.Popen([sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1"], cwd=folder,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    time.sleep(1.0)
    out = {}
    try:
        async with async_playwright() as p:
            b = await p.chromium.launch(executable_path="/opt/pw-browsers/chromium",
                                        args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                                              "--autoplay-policy=no-user-gesture-required", "--enable-precise-memory-info"])
            dev = p.devices["iPhone 13 landscape"]
            ctx = await b.new_context(**dev)
            pg = await ctx.new_page()
            logs = []
            got = {"bytes": 0, "files": {}}

            def on_req(r):
                # Download = Größe der angefragten Dateien im Exportordner (Daten vom eigenen Server)
                name = r.url.split("?")[0].rsplit("/", 1)[-1]
                fp = os.path.join(folder, name)
                if name and os.path.isfile(fp) and name not in got["files"]:
                    got["files"][name] = os.path.getsize(fp)
                    got["bytes"] += os.path.getsize(fp)
            pg.on("request", on_req)
            pg.on("console", lambda m: logs.append(m.text))
            pg.on("pageerror", lambda e: logs.append("PAGEERROR " + str(e)))
            t0 = time.time()
            await pg.goto("http://127.0.0.1:%d/index.html" % port)
            started = None
            for i in range(int(wait * 2)):
                await asyncio.sleep(0.5)
                gone = await pg.evaluate("() => document.getElementById('status') === null")
                if gone:
                    started = time.time() - t0     # Godot hat den Ladebalken entfernt: das Spiel läuft
                    break
            # ein Tippen (Ton freischalten, Hauptmenü weg) und etwas laufen lassen
            await asyncio.sleep(20)
            await pg.mouse.click(dev["viewport"]["width"] // 2, dev["viewport"]["height"] // 2)
            await asyncio.sleep(25)
            heap = await pg.evaluate("""() => {
                let w = -1;
                try { if (typeof engine !== 'undefined' && engine.rtenv && engine.rtenv.HEAP8) { w = engine.rtenv.HEAP8.length; } } catch (e) {}
                const m = performance.memory || {};
                return {wasm: w, js_used: m.usedJSHeapSize || 0, js_total: m.totalJSHeapSize || 0};
            }""")
            try:
                bp = b.process.pid if hasattr(b, "process") and b.process else None
            except Exception:
                bp = None
            if bp is None:
                # Browser-Prozess über die Kommandozeile finden (jüngster chromium-Prozess mit unseren Schaltern)
                cands = []
                for d in os.listdir("/proc"):
                    if d.isdigit():
                        try:
                            c = open("/proc/%s/cmdline" % d, "rb").read().replace(b"\0", b" ").decode(errors="replace")
                            if "chromium" in c and "--enable-precise-memory-info" in c and "--type=" not in c:
                                cands.append(int(d))
                        except Exception:
                            pass
                bp = max(cands) if cands else None
            tot, rend, gpu = rss_of_tree(bp) if bp else (0, 0, 0)
            if shot:
                try:
                    await pg.screenshot(path=shot, timeout=120000)
                except Exception as e:
                    logs.append("Bildschirmfoto fehlgeschlagen: %s" % str(e)[:80])
            out = {"download_mb": round(got["bytes"] / 1048576.0, 1), "files_mb": {k: round(v / 1048576.0, 2) for k, v in got["files"].items() if v > 100000},
                   "start_s": round(started, 1) if started else None, "wasm_heap_mb": round(heap["wasm"] / 1048576.0) if heap["wasm"] > 0 else None,
                   "js_heap_mb": round(heap["js_used"] / 1048576.0), "tab_rss_mb": rend, "gpu_rss_mb": gpu, "browser_rss_mb": tot,
                   "errors": [l for l in logs if "ERROR" in l or "PAGEERROR" in l][:8]}
            await b.close()
    finally:
        try:
            os.killpg(srv.pid, 15)
        except Exception:
            srv.terminate()
    return out


def main():
    a = sys.argv[1:]
    folder = a[0]
    port = int(a[a.index("--port") + 1]) if "--port" in a else 8765
    wait = float(a[a.index("--wait") + 1]) if "--wait" in a else 120
    shot = a[a.index("--shot") + 1] if "--shot" in a else None
    res = asyncio.run(measure(os.path.abspath(folder), port, wait, shot))
    pck = os.path.join(folder, "index.pck")
    wasm = os.path.join(folder, "index.wasm")
    res["pck_mb"] = round(os.path.getsize(pck) / 1048576.0, 1) if os.path.exists(pck) else None
    res["wasm_file_mb"] = round(os.path.getsize(wasm) / 1048576.0, 1) if os.path.exists(wasm) else None
    print(json.dumps(res, indent=1, ensure_ascii=False))
    if "--json" in a:
        with open(a[a.index("--json") + 1], "w", encoding="utf-8") as f:
            json.dump(res, f, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
