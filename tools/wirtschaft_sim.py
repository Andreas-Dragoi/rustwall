#!/usr/bin/env python3
"""Wirtschaftssimulation für Rustwall (Paket Q, Kapitel 9.2 und 12.2).

Rechnet den Spielverlauf eines typischen Spielers Tag für Tag durch (Bauen, Produktion, Lager, Flut,
Expeditionen, Übungsalarm, Tages- und Wochenaufgaben, Login-Kalender, Kisten, Forschung, Spielerstufen,
Juwelen-Einnahmen und -Bedarf) und schreibt docs/balance/wirtschaft.md mit Tabellen und Diagrammen.

Zahlen kommen aus dem Spiel selbst:
  docs/balance/wirtschaft_daten.json     erzeugt mit  godot --headless -- --autotest=econ_dump
  docs/balance/expedition_beute.json     gemessene Beute je Gebiet (Expeditions-Bot), siehe --parse-exp

Aufruf:
  python3 tools/wirtschaft_sim.py                      # Simulation, Bericht und Diagramme
  python3 tools/wirtschaft_sim.py --days 120           # länger rechnen
  python3 tools/wirtschaft_sim.py --parse-exp LOG...   # Bot-Protokolle (RESULT-Zeilen) zu expedition_beute.json
  python3 tools/wirtschaft_sim.py --json               # nur Kennzahlen als JSON ausgeben (für Tests/Flut-Messreihe)

Das Verhalten des Spielers ist bewusst einfach und nachvollziehbar (siehe Abschnitt „Annahmen“ im Bericht).
"""
import json
import math
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "docs", "balance", "wirtschaft_daten.json")
EXPF = os.path.join(ROOT, "docs", "balance", "expedition_beute.json")
OUT_MD = os.path.join(ROOT, "docs", "balance", "wirtschaft.md")
IMG_DIR = os.path.join(ROOT, "docs", "balance", "bilder")

RES = ["coins", "wood", "stone", "metal", "fuel", "cells", "parts", "shards"]
RES_DE = {"coins": "Münzen", "wood": "Holz", "stone": "Stein", "metal": "Metall", "fuel": "Treibstoff", "cells": "Zellen",
          "parts": "Bauteile", "shards": "Splitter", "gems": "Juwelen"}

# ---------------------------------------------------------------- Spielerprofile
# minutes: Spielzeit je Tag; sessions: Uhrzeiten der Sitzungen (Minuten ab Tagesbeginn 4:00 Uhr)
PROFILES = {
    15: {"name": "Gelegenheitsspieler (15 min/Tag)", "sessions": [3 * 60 + 30, 15 * 60]},
    45: {"name": "Normaler Spieler (45 min/Tag)", "sessions": [3 * 60, 9 * 60, 16 * 60]},
    120: {"name": "Vielspieler (120 min/Tag)", "sessions": [3 * 60, 8 * 60, 13 * 60, 17 * 60]},
}
EXP_MIN = 11.0          # Minuten je Expedition (Bot: 610–800 s Spielzeit)
PRACTICE_MIN = 4.0      # Übungsalarm
FLOOD_MIN = 10.0        # Wochenflut
BASE_MIN = 2.0          # je Sitzung: einsammeln, bauen, Kisten öffnen
DECO_BONUS = 0.04       # angenommene Schmuck-Punkte (≈ 20 Punkte → +4 % Produktion)
KILLS_EXP = 260         # besiegte Gegner je Expedition (Bot-Messung)
COIN_PER_KILL = 1.15    # Münzen je besiegtem Gegner in Flut und Übung (Schleimling 1, größere mehr; Bot-Messung)


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# ================================================================= Spielstand
class Sim:
    def __init__(self, data, exp, minutes, days, seed=1, spend_drones=True, tweaks=None):
        self.D = data
        self.EXP = exp
        self.minutes = minutes
        self.prof = PROFILES[minutes]
        self.days = days
        self.rng = random.Random(seed)
        self.spend_drones = spend_drones
        self.tw = tweaks or {}
        self.res = {r: float(data["start_res"].get(r, 0)) for r in RES}
        self.gems = float(data["start_res"]["gems"])
        self.level = 1
        self.xp = 0.0
        self.hero_lv = 1
        self.hero_xp = 0.0
        self.bunker = 1
        self.bunker_busy = 0.0          # Bunker-Ausbau fertig um (Minute)
        self.blds = []                  # {"key", "lvl", "until", "new"}
        self.walls = 6                  # Startstück (6 Mauern + Tor)
        self.wall_tier = 1              # gebaute Mauerart (1 Holz, 2 Stein, 3 Metall)
        self.wall_busy = 0.0
        self.extra_drones = 0
        self.research_done = []
        self.research_cur = None
        self.research_until = 0.0
        self.chests = {}
        self.counters = {k: 0 for k in ["kills", "floods_won", "expeditions", "chests", "walls", "builds", "collected", "obstacles"]}
        self.ach_claimed = {}
        self.cal_idx = 0
        self.week = 1
        self.t = 0.0
        self.quests = []
        self.quest_all_claimed = False
        self.weekly = {"day0": 0, "done": 0}
        self.heroes = 1
        self.auto_until = -1.0
        self.auto_area = 0
        self.log = []                   # Tageswerte
        self.events = []                # (Tag, Text)
        self.bunker_day = {1: 0.0}
        self.gem_in = {}
        self.gem_out = {}
        self.wait_res = {}              # Engpass: fehlender Rohstoff für den nächsten Bunker (Sitzungen)
        self.wait_drone = 0
        self.wait_cap = 0
        self.idle_sessions = 0
        self.flood_log = []
        self.cap_block = {}
        self.obstacles = 4
        self.src = "Start"
        self.flow_in = {}               # Rohstoff -> Quelle -> Menge
        self.flow_out = {}              # Rohstoff -> Zweck -> Menge
        for k in ["quartier", "kistenlager"]:
            self.blds.append({"key": k, "lvl": 1, "until": 0.0})

    # ------------------------------------------------------------ Regeln (wie profile.gd)
    def B(self, k):
        return self.D["buildings"][k]

    def rb(self, stat):
        s = 0.0
        for k in self.research_done:
            n = self.D["research"][k]
            if n["stat"] == stat:
                s += n["val"]
        return s

    def lager_sum(self):
        return sum(b["lvl"] for b in self.blds if b["key"] == "lager" and not (b.get("new") and b["until"] > self.t))

    def cap(self, r):
        bl = self.bunker
        if r == "coins":
            return 4000.0 * 1.9 ** (bl - 1) * self.tw.get("coin_cap", 1.0)
        if r not in self.D["cap_base"]:
            return 1e12
        k = self.tw.get("cap_lager", 0.6)
        kb = self.tw.get("cap_bunker", 0.5)
        return self.D["cap_base"][r] * (1.0 + k * self.lager_sum() + kb * (bl - 1)) * (1.0 + self.rb("cap"))

    def add(self, r, n):
        if r == "gems":
            self.add_gems(n, "Sonstiges")
            return n
        before = self.res[r]
        self.res[r] = min(self.cap(r), self.res[r] + n) if n > 0 else self.res[r] + n
        got = self.res[r] - before
        if n > 0:
            fl = self.flow_in.setdefault(r, {})
            fl[self.src] = fl.get(self.src, 0.0) + got
        if n > 0 and got < n - 0.5:
            self.cap_block[r] = self.cap_block.get(r, 0) + (n - got)
        return got

    def add_gems(self, n, why):
        self.gems += n
        self.gem_in[why] = self.gem_in.get(why, 0) + n

    def spend_gems(self, n, why):
        self.gems -= n
        self.gem_out[why] = self.gem_out.get(why, 0) + n

    def can_pay(self, cost):
        return all(self.res.get(r, 0) >= v for r, v in cost.items())

    def pay(self, cost, why="Sonstiges"):
        for r, v in cost.items():
            self.res[r] -= v
            fo = self.flow_out.setdefault(r, {})
            fo[why] = fo.get(why, 0.0) + v

    def count(self, key):
        return sum(1 for b in self.blds if b["key"] == key)

    def max_count(self, key):
        m = self.B(key)["max"]
        return int(m[min(self.bunker, 10) - 1])

    def max_level(self, key):
        cat = self.B(key)["cat"]
        if cat in ("trap", "special"):
            return min(5, self.bunker)
        return self.bunker

    def drones(self):
        return int(self.D["drones"][self.bunker - 1]) + self.extra_drones

    def busy(self):
        n = sum(1 for b in self.blds if b["until"] > self.t)
        if self.bunker_busy > self.t:
            n += 1
        if self.wall_busy > self.t:
            n += 1
        return n

    def build_time(self, key, lvl):
        t = float(self.B(key)["time"][min(lvl, 10) - 1]) if key != "bunker" else float(self.B("bunker")["time"][min(lvl, 10) - 1])
        return t / 60.0 * (1.0 - self.rb("build_time")) * self.tw.get("build_time", 1.0)

    def cost(self, key, lvl):
        if key == "bunker":
            c = dict(self.D["bunker_cost"][str(lvl)])
            if "bunker_fn" in self.tw:
                c = self.tw["bunker_fn"](lvl, c)
            k = self.tw.get("bunker_cost", 1.0)
            kr = self.tw.get("bunker_res", {})
            return {r: v * k * kr.get(r, 1.0) for r, v in c.items()}
        return dict(self.B(key)["cost"][min(lvl, 10) - 1])

    def prod_rate(self, b):
        d = self.B(b["key"])
        if not d["prod"]:
            return 0.0
        res = d["prod"]
        bonus = self.rb("prod_all") + (self.rb("prod_basic") if res in ("wood", "stone") else self.rb("prod_adv"))
        return d["rate"] * 1.3 ** (b["lvl"] - 1) * (1.0 + DECO_BONUS) * (1.0 + bonus) * self.tw.get("prod", 1.0)

    # ------------------------------------------------------------ Erfahrung, Erfolge, Aufträge
    def add_xp(self, n):
        n *= 1.0 + self.rb("xp")
        self.xp += n
        while self.level < self.D["max_level"] and self.xp >= self.D["xp_need"][self.level - 1]:
            self.xp -= self.D["xp_need"][self.level - 1]
            self.level += 1
            self.chest("level")
            self.add_gems(self.D["gem_reward"]["level"], "Spielerstufe")
            old_src = self.src
            self.src = "Spielerstufe"
            for r in self.D["cap_base"]:
                self.add(r, self.cap(r) * 0.25)
            self.src = old_src

    def add_hero_xp(self, n):
        self.hero_xp += n
        need = self.D["hero_xp_need"]
        while self.hero_lv < self.D["hero_max_level"] and self.hero_xp >= need[self.hero_lv - 1]:
            self.hero_xp -= need[self.hero_lv - 1]
            self.hero_lv += 1
            if self.hero_lv % 5 == 0:
                self.add_gems(self.D["gem_reward"]["hero5"], "Heldenstufe")

    def chest(self, tp, n=1):
        self.chests[tp] = self.chests.get(tp, 0) + n

    def open_chests(self):
        self.src = "Kisten"
        tab = self.D["chests"][str(min(self.bunker, 10))]
        for tp, n in list(self.chests.items()):
            for _ in range(n):
                for r, v in tab[tp].items():
                    if r == "gems":
                        continue
                    got = self.add(r, v)
                    if r == "coins":
                        self.quest("coins", got)
                self.counters["chests"] += 1
                self.quest("chests", 1)
                self.add_xp(15)
            self.chests[tp] = 0

    def stat(self, key):
        if key == "bunker":
            return self.bunker
        if key == "level":
            return self.level
        if key == "heroes":
            return self.heroes
        if key == "hero_level":
            return self.hero_lv
        if key == "hero_levels":
            return self.hero_lv + (self.heroes - 1) * max(1, self.hero_lv // 2)
        if key == "vehicles":
            return sum(1 for v in self.D["vehicles"] if v["bunker"] <= self.bunker) if self.bunker >= 3 else 0
        return self.counters.get(key, 0)

    def claim_achievements(self):
        for a in self.D["achievements"]:
            k = a["key"]
            got = self.ach_claimed.get(k, 0)
            v = self.stat(k)
            while got < len(a["tiers"]) and v >= a["tiers"][got]:
                self.add_gems(a["gems"][got], "Erfolge")
                got += 1
            self.ach_claimed[k] = got

    def new_quests(self):
        pool = list(self.D["quests"])
        self.rng.shuffle(pool)
        self.quests = []
        for q in pool[:3]:
            amt = q["amount"]
            if q["key"] in ("kills", "wood", "coins"):
                amt = int(amt * (1.0 + 0.08 * self.level))
            self.quests.append({"key": q["key"], "amount": amt, "p": 0, "done": False})
        self.quest_all_claimed = False

    def quest(self, key, n):
        for q in self.quests:
            if q["key"] == key and not q["done"]:
                q["p"] += n
                if q["p"] >= q["amount"]:
                    q["done"] = True
                    self.add_gems(self.D["gem_reward"]["quest"], "Tagesaufträge")
        if all(q["done"] for q in self.quests) and self.quests and not self.quest_all_claimed:
            self.quest_all_claimed = True
            self.add_gems(self.D["gem_reward"]["quests_all"], "Tagesaufträge")
            self.chest("quest")
            self.add_xp(60)
            self.weekly_progress("daily_all")

    def weekly_progress(self, key):
        self.weekly.setdefault("p", {})
        self.weekly["p"][key] = self.weekly["p"].get(key, 0) + 1

    # ------------------------------------------------------------ Bauen
    def finish_jobs(self):
        for b in self.blds:
            if b.get("pending") and b["until"] <= self.t:
                b["pending"] = False
                if b.get("up"):
                    b["lvl"] += 1
                    b["up"] = False
                b["new"] = False
                b["last"] = b["until"]
                self.add_xp(10 + 6 * b["lvl"])
                self.counters["builds"] += 1
                self.quest("builds", 1)
        if self.bunker_busy and self.bunker_busy <= self.t:
            self.bunker_busy = 0.0
            self.bunker += 1
            self.bunker_day[self.bunker] = self.t / 1440.0
            self.add_xp(10 + 6 * self.bunker)
            self.counters["builds"] += 1
            self.quest("builds", 1)
            self.events.append((int(self.t // 1440) + 1, "Bunker Stufe %d" % self.bunker))
        if self.research_cur and self.research_until <= self.t:
            self.research_done.append(self.research_cur)
            self.research_cur = None

    def collect(self):
        self.src = "Produktion"
        for b in self.blds:
            rate = self.prod_rate(b)
            if rate <= 0 or (b.get("new") and b["until"] > self.t):
                continue
            last = b.get("last", 0.0)
            hours = min((self.t - last) / 60.0, self.D["prod_store_hours"])
            amt = rate * hours
            r = self.B(b["key"])["prod"]
            got = self.add(r, amt)
            b["last"] = self.t - (amt - got) / max(rate, 0.01) * 60.0 if got < amt else self.t
            self.counters["collected"] += got
            if r == "wood":
                self.quest("wood", got)

    def econ_ready(self):
        """Wirtschaft so weit, dass der nächste Bunker sinnvoll ist (typischer Spieler)."""
        for b in self.blds:
            d = self.B(b["key"])
            if d["cat"] == "prod" and b["lvl"] < self.bunker - 1 and self.needs_prod(b["key"]):
                return False
        for k in ["saege", "steinbruch", "presse", "raffinerie", "generator", "lager"]:
            if self.B(k)["unlock"] <= self.bunker and self.count(k) < self.max_count(k):
                return False
        return True

    def needs_prod(self, key):
        """Lohnt sich mehr Produktion? Nicht, wenn das Lager dieses Rohstoffs ohnehin voll ist (typischer Spieler)."""
        r = self.B(key)["prod"]
        if not r:
            return True             # Lager
        return self.res[r] < 0.6 * self.cap(r)

    def def_level(self):
        lv = [b["lvl"] for b in self.blds if self.B(b["key"])["cat"] == "def"]
        return sum(lv) / len(lv) if lv else 0.0

    def actions(self):
        """Mögliche Bauaufträge mit Vorrang (kleiner = wichtiger)."""
        acts = []
        bl = self.bunker
        bcost = self.cost("bunker", bl + 1) if bl < 10 else None
        bunker_prio = 2.5 if self.econ_ready() else 4.0
        if bl < 10 and not self.bunker_busy:
            acts.append((bunker_prio, "bunker", None, bcost))
        for k, d in self.D["buildings"].items():
            cat = d["cat"]
            if cat in ("deco", "core", "wall") or d.get("story"):
                continue
            if d["unlock"] > bl:
                continue
            if self.count(k) < self.max_count(k):
                pr = {"prod": 1.0, "def": 1.5, "special": 1.8, "trap": 3.5}.get(cat, 5)
                if k in ("clanhalle", "training", "funkturm", "garage"):
                    pr = 3.0
                acts.append((pr, "new", k, self.cost(k, 1)))
        for b in self.blds:
            if b["until"] > self.t:
                continue
            k = b["key"]
            d = self.B(k)
            if b["lvl"] >= self.max_level(k) or d["cat"] in ("deco",):
                continue
            nl = b["lvl"] + 1
            cat = d["cat"]
            if cat == "prod":
                if not self.needs_prod(k):
                    continue
                pr = 2.0
                if k == "lager" and bcost and any(bcost.get(r, 0) > self.cap(r) * 0.9 for r in bcost if r != "coins"):
                    pr = 0.5
            elif cat == "def":
                pr = 3.0 if b["lvl"] < bl - 1 else 5.0
            elif cat == "trap":
                if b["lvl"] >= max(1, bl - 3):
                    continue
                pr = 6.0
            else:
                # besondere Gebäude: Labor so weit, wie die Forschung es braucht, sonst höchstens Stufe 3
                if k == "labor":
                    pr = 2.8
                elif b["lvl"] >= 3:
                    continue
                else:
                    pr = 5.5
            acts.append((pr + nl * 0.01, "up", b, self.cost(k, nl)))
        # Mauern: auf die erlaubte Anzahl bringen und auf die beste Art verbessern
        if not self.wall_busy or self.wall_busy <= self.t:
            mx = self.max_count("wall")
            if self.walls < mx:
                n = min(25, mx - self.walls)
                acts.append((3.2, "walls", n, {"wood": 12 * n}))
            tier = 1 + (1 if bl >= 4 else 0) + (1 if bl >= 7 else 0)
            if self.wall_tier < tier:
                n = self.walls
                c = {"stone": 20 * n} if self.wall_tier == 1 else {"metal": 20 * n}
                acts.append((3.4, "wall_up", n, c))
        acts.sort(key=lambda a: a[0])
        return acts, bunker_prio, bcost

    def build_loop(self):
        guard = 0
        while guard < 60:
            guard += 1
            acts, bprio, bcost = self.actions()
            free = self.drones() - self.busy()
            done = False
            for pr, kind, obj, cost in acts:
                if free <= 0 and kind != "research":
                    break
                if not self.can_pay(cost):
                    continue
                # Sparen: ist die Wirtschaft bereit für den nächsten Bunker, gehen Münzen nur noch in Wichtigeres
                if bcost and pr > bprio and kind != "bunker" and bprio < 3.0:
                    if cost.get("coins", 0) > 0 and self.res["coins"] - cost.get("coins", 0) < bcost.get("coins", 0):
                        continue
                why = {"bunker": "Bunker", "walls": "Mauern", "wall_up": "Mauern"}.get(kind)
                if why is None:
                    why = {"prod": "Produktion/Lager", "def": "Türme", "trap": "Fallen", "special": "Besondere Gebäude"}.get(self.B(obj if kind == "new" else obj["key"])["cat"], "Sonstiges")
                self.pay(cost, why)
                if kind == "bunker":
                    self.bunker_busy = self.t + max(self.build_time("bunker", self.bunker + 1), 1.0)
                elif kind == "new":
                    tm = self.build_time(obj, 1)
                    self.blds.append({"key": obj, "lvl": 1, "until": self.t + tm, "new": True, "pending": True, "last": self.t + tm})
                elif kind == "up":
                    obj["up"] = True
                    obj["pending"] = True
                    obj["until"] = self.t + max(self.build_time(obj["key"], obj["lvl"] + 1), 1.0)
                elif kind == "walls":
                    self.walls += obj
                    self.counters["walls"] += obj
                    self.wall_busy = self.t + obj * 4.0 / 60.0
                    self.add_xp(obj)
                elif kind == "wall_up":
                    self.wall_tier += 1
                    per = [30.0, 180.0][self.wall_tier - 2]
                    self.wall_busy = self.t + min(obj, 25) * per / 60.0 * math.ceil(obj / 25.0)
                done = True
                break
            if not done:
                break
        # Engpass merken: woran hängt der nächste Bunker?
        if self.bunker < 10 and not self.bunker_busy:
            bcost = self.cost("bunker", self.bunker + 1)
            miss = [r for r, v in bcost.items() if self.res[r] < v]
            over = [r for r, v in bcost.items() if v > self.cap(r)]
            if over:
                self.wait_cap += 1
                for r in over:
                    self.wait_res["Lager zu klein: " + RES_DE[r]] = self.wait_res.get("Lager zu klein: " + RES_DE[r], 0) + 1
            elif miss:
                for r in miss:
                    self.wait_res[RES_DE[r]] = self.wait_res.get(RES_DE[r], 0) + 1
            elif self.busy() >= self.drones():
                self.wait_drone += 1
        self.research()

    def research(self):
        if self.research_cur:
            return
        has_lab = self.count("labor") > 0
        has_ws = self.count("werkstatt") > 0
        best = None
        for k, n in self.D["research"].items():
            if k in self.research_done:
                continue
            if any(r not in self.research_done for r in n["req"]):
                continue
            if n["tier"] == 0 and not (has_ws or has_lab):
                continue
            if n["tier"] > 0:
                lab = [b for b in self.blds if b["key"] == "labor"]
                if not lab or lab[0]["lvl"] < n["lab"]:
                    continue
            c = n["cost"]
            if not self.can_pay(c):
                continue
            # Forschung nur aus Überschuss (nicht aus dem Geld für den Bunker)
            if self.bunker < 10:
                bc = self.cost("bunker", self.bunker + 1)
                if self.res["coins"] - c.get("coins", 0) < 0.6 * bc.get("coins", 0) and c.get("coins", 0) > 300:
                    continue
            key = (n["tier"], c.get("coins", 0))
            if best is None or key < best[0]:
                best = (key, k, c, n)
        if best:
            _, k, c, n = best
            self.pay(c, "Forschung")
            lab = [b for b in self.blds if b["key"] == "labor"]
            lv = lab[0]["lvl"] if lab else 1
            tm = n["time"] * (max(0.4, 1.0 - self.D["lab_speed"] * (lv - 1)) if lv > 1 else 1.0)
            self.research_cur = k
            self.research_until = self.t + tm / 60.0

    def speed_up(self, minutes):
        for b in self.blds:
            if b["until"] > self.t:
                b["until"] = max(self.t, b["until"] - minutes)
        if self.bunker_busy > self.t:
            self.bunker_busy = max(self.t + 0.01, self.bunker_busy - minutes)

    # ------------------------------------------------------------ Aktivitäten
    def best_area(self):
        areas = self.D["areas"]
        best = 0
        for i, a in enumerate(areas):
            if self.level >= a["level"] and self.res["fuel"] >= self.fuel_cost(i):
                best = i
        return best

    def fuel_cost(self, i):
        return math.ceil(self.D["areas"][i]["fuel"] * (1.0 - self.rb("fuel")))

    def expedition(self, first_today, frac=1.0):
        i = self.best_area()
        fc = self.fuel_cost(i)
        if self.res["fuel"] < fc:
            return False
        self.res["fuel"] -= fc
        self.src = "Expeditionen"
        loot = self.EXP.get(str(i)) or self.EXP.get(str(max(int(k) for k in self.EXP)))
        k = (1.0 + self.rb("loot")) * (1.0 + self.rb("carry") * 0.5) * self.tw.get("exp_loot", 1.0)
        for r, v in loot["kept"].items():
            got = self.add(r, v * k * frac)
            if r == "coins":
                self.quest("coins", got)
            if r == "wood":
                self.quest("wood", got)
        for r, v in loot.get("loot", {}).items():
            self.add(r, v)
        lvl = self.D["areas"][i]["level"]
        self.add_xp(60 + 8 * lvl)
        self.add_hero_xp(80 + 12 * lvl)
        if first_today:
            self.chest("daily")
        self.counters["expeditions"] += 1
        self.counters["kills"] += int(KILLS_EXP * frac)
        self.quest("expeditions", 1)
        self.quest("kills", int(KILLS_EXP * frac))
        self.quest("skills", 10)
        self.weekly_progress("expeditions")
        self.speed_up(self.D["expedition_build_skip"] / 60.0)
        # Gebiete hinter Bossen: nach der ersten Expedition gilt der Boss als besiegt (Annahme)
        if i + 1 < len(self.D["areas"]):
            pass
        # zweiter Held: Rettung im ersten Gebiet (Annahme: nach 3 Expeditionen)
        if self.heroes == 1 and self.counters["expeditions"] >= 3:
            self.heroes = 2
        if self.heroes < 7 and self.counters["expeditions"] >= 3 + 6 * (self.heroes - 1) and i >= self.heroes - 1:
            self.heroes += 1
        return True

    def practice(self):
        kills = int(self.D["flood_def"][min(self.week, 30) - 1][self.bunker - 1]["total"] * 0.4)
        coins = 40 + 15 * self.bunker + kills * COIN_PER_KILL
        self.src = "Übungsalarm"
        self.add("coins", coins)
        self.quest("coins", coins)
        self.add_xp(40)
        self.quest("practice", 1)
        self.add_gems(self.D["gem_reward"]["practice"], "Übungsalarm")
        self.counters["kills"] += kills
        self.quest("kills", kills)
        self.weekly_progress("practice")

    def flood(self):
        wk = self.week
        stars = 2
        win = True
        # Die Simulation nimmt an, dass ein normal ausgebauter Spieler die Flut hält (Messreihe: docs/balance/flut.md)
        total = self.D["flood_def"][min(wk, 30) - 1][self.bunker - 1]["total"]
        self.src = "Flut"
        self.add("coins", (100 * wk + 50 * stars) * (1.0 + self.rb("flood_loot")) + total * COIN_PER_KILL)
        self.add_gems(self.D["gem_reward"]["flood"], "Flut")
        self.chest("flood_silver")
        self.add_xp(120 + 40 * wk)
        self.counters["floods_won"] += 1
        self.counters["kills"] += int(self.D["flood_def"][min(wk, 30) - 1][self.bunker - 1]["total"])
        self.weekly_progress("flood_win")
        self.flood_log.append({"week": wk, "day": int(self.t // 1440) + 1, "bunker": self.bunker, "def_lv": round(self.def_level(), 1),
                               "hero": self.hero_lv, "wall": self.wall_tier, "level": self.level,
                               "total": self.D["flood_def"][min(wk, 30) - 1][self.bunker - 1]["total"]})

    def clear_obstacles(self):
        while self.obstacles > 0 and self.res["wood"] >= 40:
            self.res["wood"] -= 30
            self.obstacles -= 1
            g = self.rng.choice([1, 2, 2, 3])
            if self.rng.random() < 0.12 * 0.4:
                g += self.rng.randint(5, 12)
            self.add_gems(g, "Hindernisse")
            self.counters["obstacles"] += 1

    def auto_exp(self):
        if self.heroes < 2 or self.auto_until > self.t:
            return
        i = self.best_area()
        fc = self.fuel_cost(i)
        if self.res["fuel"] < fc + 10:
            return
        self.res["fuel"] -= fc
        self.auto_until = self.t + 8 * 60
        self.auto_area = i

    def collect_auto(self):
        if self.auto_until < 0 or self.auto_until > self.t:
            return
        a = self.D["areas"][self.auto_area]
        self.src = "Auto-Expedition"
        tot = sum(a["res"].values())
        runs = 8 * 1.6
        for r, w in a["res"].items():
            base = 260.0 * (1.0 + 0.1 * a["level"]) / float(self.D["res_weight"].get(r, 1.0))
            self.add(r, base * w / tot * self.D["auto_share"] * runs)
        self.auto_until = -1.0

    # ------------------------------------------------------------ Ablauf
    def run(self):
        sessions = self.prof["sessions"]
        per = self.minutes / len(sessions)
        for day in range(self.days):
            day0 = day * 1440.0
            wd = day % 7 + 1
            self.new_quests()
            if wd == 1 and day > 0:
                self.week += 1
                # Wochenaufgaben der Vorwoche
                p = self.weekly.get("p", {})
                done = 0
                for wq in self.D["weekly_pool"][:]:
                    pass
                frac = {15: 0.6, 45: 1.0, 120: 1.0}[self.minutes]
                n = int(round(self.D["weekly"]["n"] * frac))
                self.add_gems(self.D["weekly"]["reward"]["gems"] * n, "Wochenaufgaben")
                self.chest("quest", n)
                if n >= self.D["weekly"]["n"]:
                    self.add_gems(self.D["weekly"]["all"]["gems"], "Wochenaufgaben")
                    self.chest("level")
                self.weekly = {"p": {}}
            self.obstacles = min(12, self.obstacles + 2)
            # Tagesplan: Restzeit nach den Basis-Besuchen geht in Flut, Expeditionen und Übung
            budget = self.minutes - BASE_MIN * len(sessions)
            acts = []
            if wd == 7:
                acts.append(("flood", 1.0))
                budget -= FLOOD_MIN
            n_exp = int(budget // EXP_MIN)
            rem = budget - n_exp * EXP_MIN
            if rem >= PRACTICE_MIN and wd != 7:
                acts.append(("practice", 1.0))
                rem -= PRACTICE_MIN
            acts += [("exp", 1.0)] * n_exp
            if rem >= 6.0:
                acts.append(("exp", rem / EXP_MIN))
            plan = [[] for _ in sessions]
            for i, a in enumerate(acts):
                plan[(len(sessions) - 1) if a[0] == "flood" else i % len(sessions)].append(a)
            first_exp = True
            for si, sm in enumerate(sessions):
                self.t = day0 + sm
                self.finish_jobs()
                self.collect()
                self.collect_auto()
                if si == 0:
                    self.src = "Login-Kalender"
                    c = self.D["calendar"][self.cal_idx % len(self.D["calendar"])]
                    self.cal_idx += 1
                    for r, v in c.items():
                        if r == "gems":
                            self.add_gems(v, "Login-Kalender")
                        elif r == "chest":
                            self.chest(v)
                        elif r == "boost":
                            self.speed_up(self.D["boost_seconds"] / 60.0 * v)
                        elif r in RES:
                            self.add(r, v)
                self.open_chests()
                self.clear_obstacles()
                self.build_loop()
                for kind, frac in plan[si]:
                    if kind == "flood":
                        self.t += FLOOD_MIN
                        self.finish_jobs()
                        self.flood()
                    elif kind == "practice":
                        self.t += PRACTICE_MIN
                        self.finish_jobs()
                        self.practice()
                    else:
                        self.t += EXP_MIN * frac
                        self.finish_jobs()
                        if not self.expedition(first_exp, frac):
                            continue
                        first_exp = False
                    self.collect()
                    self.open_chests()
                    self.build_loop()
                if self.spend_drones:
                    i = self.extra_drones
                    if i < len(self.D["gem_drone_cost"]) and self.gems >= self.D["gem_drone_cost"][i] + 50:
                        self.spend_gems(self.D["gem_drone_cost"][i], "Baudrohne")
                        self.extra_drones += 1
                        self.build_loop()
                if si == len(sessions) - 1:
                    self.auto_exp()
                self.claim_achievements()
            # Tagesende: Werte merken
            self.t = day0 + 1439
            self.finish_jobs()
            self.log.append({"day": day + 1, "bunker": self.bunker, "level": self.level, "hero": self.hero_lv, "gems": round(self.gems),
                             "res": {r: round(self.res[r]) for r in RES}, "cap": {r: round(self.cap(r)) for r in ["coins", "wood", "stone", "metal"]},
                             "def_lv": round(self.def_level(), 2), "research": len(self.research_done), "walls": self.walls, "wall_tier": self.wall_tier,
                             "drones": self.drones(), "exps": self.counters["expeditions"]})
        return self


# ================================================================= Bericht
def parse_exp(paths):
    """Bot-Protokolle → mittlere Beute je Gebiet (kept = heimgebracht, loot = Sonderfunde)."""
    acc = {}
    for p in paths:
        m = re.search(r"_(\d+)_\d+\.log$", p)
        if not m:
            continue
        area = m.group(1)
        txt = open(p, encoding="utf-8", errors="replace").read()
        line = [l for l in txt.splitlines() if l.startswith("RESULT")]
        if not line:
            continue
        l = line[-1]
        kept = re.search(r'"kept": \{([^}]*)\}', l)
        loot = re.search(r'"loot": \{([^}]*)\}', l)
        tsec = re.search(r" t=(\d+)s", l)
        win = "win=true" in l
        def kv(s):
            out = {}
            if s:
                for k, v in re.findall(r'"(\w+)": (\d+)', s.group(1)):
                    out[k] = int(v)
            return out
        a = acc.setdefault(area, {"n": 0, "kept": {}, "loot": {}, "t": 0, "wins": 0})
        a["n"] += 1
        a["wins"] += 1 if win else 0
        a["t"] += int(tsec.group(1)) if tsec else 0
        for k, v in kv(kept).items():
            a["kept"][k] = a["kept"].get(k, 0) + v
        for k, v in kv(loot).items():
            a["loot"][k] = a["loot"].get(k, 0) + v
    out = {}
    for area, a in sorted(acc.items(), key=lambda x: int(x[0])):
        n = a["n"]
        out[area] = {"runs": n, "wins": a["wins"], "minutes": round(a["t"] / n / 60.0, 1),
                     "kept": {k: round(v / n) for k, v in a["kept"].items()}, "loot": {k: round(v / n, 1) for k, v in a["loot"].items()}}
    return out


def fmt_day(d):
    return "–" if d is None else ("%.1f" % d)


def summarize(sim):
    s = {"minutes": sim.minutes, "bunker_day": {str(k): round(v, 1) for k, v in sim.bunker_day.items()},
         "final": sim.log[-1], "gems_in": sim.gem_in, "gems_out": sim.gem_out, "floods": sim.flood_log,
         "wait_res": sim.wait_res, "wait_drone": sim.wait_drone, "wait_cap": sim.wait_cap}
    return s


def charts(results, days):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except Exception:
        return []
    os.makedirs(IMG_DIR, exist_ok=True)
    files = []
    cols = {15: "#2F8DEB", 45: "#E0812E", 120: "#3FA35A"}
    # Bunker-Stufe über die Tage
    fig, ax = plt.subplots(figsize=(8, 4.2), dpi=110)
    for m, sim in results.items():
        ax.step([l["day"] for l in sim.log], [l["bunker"] for l in sim.log], where="post", color=cols[m], label=PROFILES[m]["name"], lw=2)
    ax.axvline(7, color="#999", ls="--", lw=1)
    ax.axvline(90, color="#999", ls="--", lw=1)
    ax.plot([7], [5], "o", color="#C33", ms=7)
    ax.plot([90], [10], "o", color="#C33", ms=7)
    ax.text(7.5, 5.1, "Ziel: Bunker 5\nnach ~1 Woche", fontsize=8, color="#C33")
    ax.text(72, 9.3, "Ziel: Bunker 10\nnach ~3 Monaten", fontsize=8, color="#C33")
    ax.set_xlabel("Tag")
    ax.set_ylabel("Bunker-Stufe")
    ax.set_ylim(0.5, 10.5)
    ax.set_xlim(0, days)
    ax.grid(alpha=0.25)
    ax.legend(loc="lower right", fontsize=8)
    ax.set_title("Fortschrittskurve: Bunker-Stufe")
    fig.tight_layout()
    f = os.path.join(IMG_DIR, "bunker_kurve.png")
    fig.savefig(f)
    plt.close(fig)
    files.append(f)
    # Juwelen-Kontostand
    fig, ax = plt.subplots(figsize=(8, 3.6), dpi=110)
    for m, sim in results.items():
        ax.plot([l["day"] for l in sim.log], [l["gems"] for l in sim.log], color=cols[m], label=PROFILES[m]["name"], lw=2)
    ax.set_xlabel("Tag")
    ax.set_ylabel("Juwelen (Kontostand)")
    ax.grid(alpha=0.25)
    ax.legend(fontsize=8)
    ax.set_title("Juwelen ohne Käufe (Baudrohnen werden gekauft, sobald genug da ist)")
    fig.tight_layout()
    f = os.path.join(IMG_DIR, "juwelen.png")
    fig.savefig(f)
    plt.close(fig)
    files.append(f)
    # Rohstoffe und Lager (45 min)
    sim = results[45]
    fig, axs = plt.subplots(2, 2, figsize=(9, 5.4), dpi=110, sharex=True)
    for ax, r in zip(axs.flat, ["coins", "wood", "stone", "metal"]):
        ax.plot([l["day"] for l in sim.log], [l["res"][r] for l in sim.log], color="#2F8DEB", lw=1.6, label="Bestand")
        ax.plot([l["day"] for l in sim.log], [l["cap"][r] for l in sim.log], color="#C33", lw=1, ls="--", label="Lager")
        ax.set_title(RES_DE[r], fontsize=9)
        ax.grid(alpha=0.25)
        ax.set_yscale("log")
    axs[0][0].legend(fontsize=7)
    fig.suptitle("Normaler Spieler (45 min/Tag): Bestand am Tagesende und Lagergrenze", fontsize=10)
    fig.tight_layout()
    f = os.path.join(IMG_DIR, "rohstoffe_45.png")
    fig.savefig(f)
    plt.close(fig)
    files.append(f)
    return files


def report(results, days, base_results=None, changes=None, exp=None):
    L = []
    L.append("# Wirtschaftssimulation (Paket Q)")
    L.append("")
    L.append("Erzeugt von `tools/wirtschaft_sim.py` aus den Zahlen des Spiels (`--autotest=econ_dump` → `docs/balance/wirtschaft_daten.json`)")
    L.append("und der gemessenen Expeditions-Beute (`docs/balance/expedition_beute.json`, Expeditions-Bot je Gebiet). Neu erzeugen:")
    L.append("")
    L.append("```")
    L.append("godot --headless -- --autotest=econ_dump")
    L.append("python3 tools/wirtschaft_sim.py")
    L.append("```")
    L.append("")
    L.append("Gerechnet werden %d Tage für drei Spielertypen. Ziel (Kapitel 12.2): **Bunker 5 nach etwa 1 Woche, Bunker 10 nach etwa 3 Monaten**." % days)
    L.append("")
    L.append("## Fortschritt: Tag, an dem die Bunker-Stufe erreicht ist")
    L.append("")
    hdr = "| Spieler | " + " | ".join("B%d" % b for b in range(2, 11)) + " |"
    L.append(hdr)
    L.append("|" + "---|" * 10)
    for m, sim in results.items():
        row = [PROFILES[m]["name"]]
        for b in range(2, 11):
            row.append(fmt_day(sim.bunker_day.get(b)))
        L.append("| " + " | ".join(row) + " |")
    if base_results:
        L.append("")
        L.append("Zum Vergleich **vor** den Anpassungen dieses Pakets (gleiche Simulation, alte Zahlen):")
        L.append("")
        L.append(hdr)
        L.append("|" + "---|" * 10)
        for m, sim in base_results.items():
            row = [PROFILES[m]["name"]]
            for b in range(2, 11):
                row.append(fmt_day(sim.bunker_day.get(b)))
            L.append("| " + " | ".join(row) + " |")
    L.append("")
    L.append("![Bunker-Kurve](bilder/bunker_kurve.png)")
    L.append("")
    L.append("## Stand nach 7, 14, 30 und %d Tagen" % days)
    L.append("")
    L.append("| Spieler | Tag | Bunker | Spielerstufe | Heldenstufe | Ø Turmstufe | Mauer | Forschung | Expeditionen | Juwelen |")
    L.append("|---|---|---|---|---|---|---|---|---|---|")
    for m, sim in results.items():
        for d in [7, 14, 30, days]:
            if d - 1 < len(sim.log):
                l = sim.log[d - 1]
                L.append("| %s | %d | %d | %d | %d | %.1f | %s | %d | %d | %d |" % (PROFILES[m]["name"].split(" (")[0], d, l["bunker"], l["level"], l["hero"], l["def_lv"],
                         ["", "Holz", "Stein", "Metall"][l["wall_tier"]], l["research"], l["exps"], l["gems"]))
    L.append("")
    L.append("## Juwelen")
    L.append("")
    L.append("Einnahmen ohne Käufe in %d Tagen (Ausgaben: Baudrohnen 500/1200, sobald genug da ist):" % days)
    L.append("")
    keys = sorted(set(k for sim in results.values() for k in sim.gem_in))
    L.append("| Quelle | " + " | ".join(PROFILES[m]["name"].split(" (")[0] for m in results) + " |")
    L.append("|---|" + "---|" * len(results))
    for k in keys:
        L.append("| %s | %s |" % (k, " | ".join(str(int(sim.gem_in.get(k, 0))) for sim in results.values())))
    L.append("| **Summe** | %s |" % " | ".join(str(int(sum(sim.gem_in.values()))) for sim in results.values()))
    L.append("| je Tag | %s |" % " | ".join("%.1f" % (sum(sim.gem_in.values()) / days) for sim in results.values()))
    L.append("| ausgegeben (Drohnen) | %s |" % " | ".join(str(int(sum(sim.gem_out.values()))) for sim in results.values()))
    L.append("")
    gc = [[60, 1], [3600, 20], [86400, 260]]
    L.append("Zum Vergleich der **Bedarf**: Beschleunigen kostet 20 Juwelen je Stunde, 260 je Tag (`GEM_CURVE`). Der Bunker-Ausbau auf Stufe 8")
    L.append("dauert 24 h (260 Juwelen), auf 10 dann 48 h (460). Ein Normalspieler verdient also etwa einen „gesparten Tag“ Bauzeit je")
    L.append("%d Spieltage – Beschleunigen bleibt ein Komfort, der Fortschritt hängt nicht daran." % max(1, round(260 / max(1.0, sum(results[45].gem_in.values()) / days))))
    L.append("")
    L.append("![Juwelen](bilder/juwelen.png)")
    L.append("")
    L.append("## Engpässe")
    L.append("")
    L.append("Gezählt wird bei jeder Sitzung, woran der **nächste Bunker-Ausbau** scheitert (fehlender Rohstoff, zu kleines Lager oder alle")
    L.append("Baudrohnen beschäftigt):")
    L.append("")
    L.append("| Spieler | " + " | ".join(["Grund", "Sitzungen"]) + " |")
    L.append("|---|---|---|")
    for m, sim in results.items():
        items = sorted(sim.wait_res.items(), key=lambda x: -x[1])[:6]
        items.append(("Drohnen beschäftigt", sim.wait_drone))
        for k, v in items:
            L.append("| %s | %s | %d |" % (PROFILES[m]["name"].split(" (")[0], k, v))
    L.append("")
    L.append("Verluste durch volle Lager (über %d Tage, Normalspieler): %s." % (days, ", ".join("%s %d" % (RES_DE[r], v) for r, v in sorted(results[45].cap_block.items(), key=lambda x: -x[1])[:5]) or "keine"))
    L.append("")
    L.append("![Rohstoffe](bilder/rohstoffe_45.png)")
    L.append("")
    if exp:
        L.append("## Gemessene Expeditions-Beute (Bot, je Gebiet)")
        L.append("")
        L.append("| Gebiet | Läufe | Sieg | Minuten | heimgebracht |")
        L.append("|---|---|---|---|---|")
        names = [a["name"] for a in results[45].D["areas"]]
        for a, e in exp.items():
            L.append("| %s | %d | %d | %.1f | %s |" % (names[int(a)], e["runs"], e["wins"], e["minutes"], ", ".join("%s %d" % (RES_DE.get(k, k), v) for k, v in e["kept"].items())))
        L.append("")
    if changes:
        L.append("## Anpassungen (begründet durch die Simulation)")
        L.append("")
        for c in changes:
            L.append("- " + c)
        L.append("")
    L.append("## Annahmen")
    L.append("")
    L.append("- Sitzungen: 15 min → 2, 45 min → 3, 120 min → 4 Sitzungen am Tag. Je Sitzung 2 min Basis (einsammeln, bauen, Kisten),")
    L.append("  einmal am Tag ein Übungsalarm (%d min), am Fluttag die Wochenflut (%d min), der Rest geht in Expeditionen (%d min je Expedition)." % (PRACTICE_MIN, FLOOD_MIN, EXP_MIN))
    L.append("- Expeditionen gehen ins höchste freie Gebiet (Spielerstufe), soweit der Treibstoff reicht; Beute = Mittel der Bot-Läufe")
    L.append("  (inkl. Fundteile), Forschung „Spürnase“/„Tragegurte“ eingerechnet. Jede Expedition zieht 15 min von laufenden Bauten ab.")
    L.append("- Bauen: neue Gebäude zuerst, dann Produktion und Lager, Bunker sobald die Wirtschaft nachgezogen ist (alle Produktions-")
    L.append("  gebäude höchstens eine Stufe unter dem Bunker), Türme bis eine Stufe unter dem Bunker; teure Nebenaufträge warten, solange")
    L.append("  für den Bunker gespart wird. Mauern auf die erlaubte Anzahl und die beste Art.")
    L.append("- Die Wochenflut wird gewonnen (2 Sterne) – die Messreihe in `flut.md` prüft, ob das beim simulierten Ausbau stimmt.")
    L.append("- Schmuck: +%d %% Produktion; Außenbasen, Händler, Clans, Ereignisse und Saison-Pass sind **nicht** eingerechnet (sie" % int(DECO_BONUS * 100))
    L.append("  beschleunigen eher) – die Kurve ist also eher vorsichtig.")
    L.append("- Kisten: Mittelwert aus 400 echten Öffnungen je Art und Bunker-Stufe (im Spiel gezogen, Waffen/Module/Eier nicht als Rohstoff).")
    L.append("- Juwelen: Login-Kalender, Tagesaufträge (zufällig 3 von 8), Wochenaufgaben (15 min: 3 von 5), Flut, Übung, Spielerstufen,")
    L.append("  Heldenstufen, Erfolge, Hindernisse (2 am Tag). Keine Käufe.")
    L.append("")
    return "\n".join(L)


def run_all(data, exp, days, tweaks=None, seed=1):
    return {m: Sim(data, exp, m, days, seed=seed, tweaks=tweaks).run() for m in PROFILES}


def main():
    args = sys.argv[1:]
    if "--parse-exp" in args:
        logs = args[args.index("--parse-exp") + 1:]
        out = parse_exp(logs)
        with open(EXPF, "w", encoding="utf-8") as f:
            json.dump(out, f, indent=1, ensure_ascii=False)
        print(json.dumps(out, indent=1, ensure_ascii=False))
        return
    days = 100
    if "--days" in args:
        days = int(args[args.index("--days") + 1])
    data = load(DATA)
    exp = load(EXPF)
    res = run_all(data, exp, days)
    if "--json" in args:
        print(json.dumps({m: summarize(s) for m, s in res.items()}, indent=1, ensure_ascii=False))
        return
    base = None
    changes = None
    if os.path.exists(os.path.join(ROOT, "docs", "balance", "wirtschaft_vorher.json")):
        bd = load(os.path.join(ROOT, "docs", "balance", "wirtschaft_vorher.json"))
        base = run_all(bd, exp, days)
    chg = os.path.join(ROOT, "docs", "balance", "wirtschaft_aenderungen.json")
    if os.path.exists(chg):
        changes = load(chg)
    charts(res, days)
    md = report(res, days, base, changes, exp)
    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write(md + "\n")
    for m, s in res.items():
        print(m, "Bunker-Tage:", {k: round(v, 1) for k, v in s.bunker_day.items()}, "Juwelen/Tag %.1f" % (sum(s.gem_in.values()) / days))
    print("geschrieben:", OUT_MD)


if __name__ == "__main__":
    main()
