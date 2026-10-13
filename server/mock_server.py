#!/usr/bin/env python3
"""Rustwall – Testserver (Attrappe) mit denselben HTTP-Schnittstellen wie der echte Nakama-Server.

Nur Python-Standardbibliothek. Dient zum Entwickeln und für die automatischen Tests (src/tests_online.gd),
solange kein echter Server läuft. Die Spielregeln stehen in modules/regeln.json und gelten hier wie auf dem
echten Server (modules/rustwall.ts). NICHT für den echten Betrieb gedacht: keine echte Sicherheit,
Passwörter nur einfach gehasht, alles liegt im Speicher (oder mit --state in einer JSON-Datei).

Start:   python3 server/mock_server.py --port 7350
         python3 server/mock_server.py --port 7350 --state /tmp/rustwall_state.json --allow-test-purchases

Schnittstellen (wie Nakama, REST):
  GET  /healthcheck
  POST /v2/account/authenticate/device?create=true      (Basic-Auth mit Server-Schlüssel, Body {"id": Geräte-ID})
  POST /v2/account/authenticate/email?create=false      (Basic-Auth, Body {"email","password"})
  POST /v2/account/session/refresh                      (Basic-Auth, Body {"token": refresh_token})
  GET  /v2/account                                      (Bearer)
  POST /v2/account/link/email | link/apple | link/google (Bearer)
  POST /v2/rpc/<name>                                   (Bearer, Body = JSON-Text, der das JSON der Nutzdaten enthält)
  POST /api/<projekt>/store/  und  /api/<projekt>/envelope/   (Sentry-kompatible Fehlerberichte)
Nur in der Attrappe (für Tests):
  POST /mock/time {"offset": Sekunden}   verschiebt die Serverzeit
  GET  /mock/state                        gibt den ganzen Zustand aus
"""
import argparse
import base64
import hashlib
import hmac
import json
import os
import random
import re
import string
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
RULES = json.load(open(os.path.join(HERE, "modules", "regeln.json"), encoding="utf-8"))
SECRET = b"mock-session-secret"
SERVER_KEY = "defaultkey"
TOKEN_LIFE = 7200
REFRESH_LIFE = 3600 * 24 * 60
LOCK = threading.RLock()
TIME_OFFSET = [0.0]
ALLOW_TEST_PURCHASES = [False]
STATE_FILE = [None]
CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


# ================================================================= Wortfilter
def _load_filter():
    words = []
    for line in open(os.path.join(HERE, "modules", "wortfilter.txt"), encoding="utf-8"):
        line = line.strip().lower()
        if not line or line.startswith("#"):
            continue
        words.append(line)
    return words


FILTER = _load_filter()
LEET = str.maketrans({"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"})


def norm(text):
    return text.lower().replace("ß", "ss").translate(LEET)


TOKEN = re.compile(r"[0-9A-Za-zÄÖÜäöüß@$]+")


def _rule_hit(n):
    """Trifft eine Regel auf ein (normalisiertes) Wort zu? Gleiche Regeln wie modules/rustwall.ts."""
    for w in FILTER:
        if " " in w:
            continue
        if w.startswith("~"):
            if w[1:] in n:
                return True
        elif w.endswith("*"):
            if n.startswith(w[:-1]):
                return True
        elif n == w:
            return True
    return False


def _phrases(text):
    joined = " " + " ".join(norm(t) for t in TOKEN.findall(text)) + " "
    return [w for w in FILTER if " " in w and (" " + w + " ") in joined]


def is_bad(text):
    return len(_phrases(text)) > 0 or any(_rule_hit(norm(t)) for t in TOKEN.findall(text))


def censor(text):
    ph = set(x for p in _phrases(text) for x in p.split(" "))

    def sub(m):
        t = m.group(0)
        n = norm(t)
        return "*" * len(t) if _rule_hit(n) or n in ph else t
    return TOKEN.sub(sub, text)


# ================================================================= Zustand
def empty_state():
    return {"users": {}, "devices": {}, "emails": {}, "cities": {}, "codes": {}, "names": {}, "clans": {},
            "boards": {}, "reports": [], "telemetry": [], "crashes": [], "purchases": {}, "next_mail": 1, "next_clan": 1}


S = empty_state()


def save_state():
    if STATE_FILE[0]:
        with open(STATE_FILE[0], "w", encoding="utf-8") as f:
            json.dump(S, f)


def now():
    return time.time() + TIME_OFFSET[0]


def day_index(t=None):
    return int((now() if t is None else t) // 86400)


def week_index(t=None):
    # Wochen beginnen am Montag 0:00 UTC (1.1.1970 war ein Donnerstag)
    return (day_index(t) + 3) // 7


# ================================================================= Sitzungen (Token wie bei Nakama: JWT mit uid, usn, exp)
def _b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def _unb64(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def make_token(uid, life, kind="s"):
    user = S["users"][uid]
    head = _b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    body = _b64(json.dumps({"tid": str(uuid.uuid4()), "uid": uid, "usn": user["username"], "exp": int(now()) + life, "k": kind}).encode())
    sig = _b64(hmac.new(SECRET, (head + "." + body).encode(), hashlib.sha256).digest())
    return head + "." + body + "." + sig


def read_token(tok, kind="s"):
    try:
        head, body, sig = tok.split(".")
        want = _b64(hmac.new(SECRET, (head + "." + body).encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(want, sig):
            return None
        data = json.loads(_unb64(body))
        if data.get("k") != kind or data["exp"] < now() or data["uid"] not in S["users"]:
            return None
        if S["users"][data["uid"]].get("banned"):
            return None
        return data["uid"]
    except Exception:
        return None


def session(uid, created):
    return {"token": make_token(uid, TOKEN_LIFE), "refresh_token": make_token(uid, REFRESH_LIFE, "r"), "created": created}


def new_user():
    uid = str(uuid.uuid4())
    S["users"][uid] = {"id": uid, "username": "rw" + uid[:10].replace("-", ""), "created": now(), "devices": [], "email": "",
                       "pw": "", "apple": "", "google": "", "wallet": {"gems": RULES["start_gems"]}, "blocked": [], "banned": False,
                       "starter": False, "rewards": {}, "spent": {}}
    return uid


class ApiError(Exception):
    def __init__(self, status, msg, code=3):
        super().__init__(msg)
        self.status = status
        self.msg = msg
        self.code = code


# ================================================================= Hilfen für Städte
def ckey(uid, city):
    return "%s:%d" % (uid, int(city))


def city_of(uid, payload, create=True):
    k = ckey(uid, payload.get("city", 1))
    if k not in S["cities"]:
        if not create:
            raise ApiError(404, "Stadt unbekannt", 5)
        S["cities"][k] = {"key": k, "uid": uid, "city": int(payload.get("city", 1)), "code": "", "bunker_name": "", "name": "Kommandant",
                          "level": 1, "bunker": 1, "save": None, "friends": {}, "mail": [], "limits": {}, "points": {"week": week_index(), "flood": 0, "explorer": 0},
                          "league": 0, "clan": "", "last_seen": now(), "times": {}}
    c = S["cities"][k]
    c["last_seen"] = now()
    _week_check(c)
    return c


def new_code():
    while True:
        code = "".join(random.choice(CODE_CHARS) for _ in range(8))
        if code not in S["codes"]:
            return code


def public(c, me_key=""):
    online = now() - float(c.get("last_seen", 0)) < 300
    return {"code": c["code"], "name": c["name"], "bunker_name": c["bunker_name"], "level": c["level"], "bunker": c["bunker"],
            "online": online, "own": c["key"] == me_key}


def limit(c, key, period, maxn, add=1):
    """Zähler je Tag ('d') oder Woche ('w'). Liefert False, wenn das Limit erreicht ist (dann wird nichts gezählt)."""
    idx = day_index() if period == "d" else week_index()
    rec = c["limits"].get(key)
    if not rec or rec[0] != idx:
        rec = [idx, 0]
    if rec[1] + add > maxn:
        c["limits"][key] = rec
        return False
    rec[1] += add
    c["limits"][key] = rec
    return True


def limit_left(c, key, period, maxn):
    idx = day_index() if period == "d" else week_index()
    rec = c["limits"].get(key)
    if not rec or rec[0] != idx:
        return maxn
    return max(0, maxn - rec[1])


def mail(c, frm, text, res=None, chest="", item=None, kind="", from_code=""):
    if from_code and from_code in S["users"].get(c["uid"], {}).get("blocked", []):
        return
    mid = S["next_mail"]
    S["next_mail"] += 1
    c["mail"].append({"id": mid, "from": frm, "from_code": from_code, "text": text, "res": res or {}, "chest": chest, "item": item or {},
                      "kind": kind, "expire": now() + RULES["mail_keep_days"] * 86400})
    while len(c["mail"]) > RULES["mail_max"]:
        c["mail"].pop(0)


def by_code(code):
    k = S["codes"].get(str(code).upper())
    return S["cities"].get(k) if k else None


# ================================================================= Ranglisten und Wochenwechsel
def board_add(board, week, key, n):
    b = S["boards"].setdefault("%s:%d" % (board, week), {})
    b[key] = int(b.get(key, 0)) + int(n)


def board_get(board, week):
    return S["boards"].get("%s:%d" % (board, week), {})


def _league_rank(c, week):
    """Platz in der eigenen Liga der vergangenen Woche (1 = bester)."""
    b = board_get("flood", week)
    mine = int(b.get(c["key"], 0))
    better = 0
    for k, v in b.items():
        o = S["cities"].get(k)
        if o and o["league"] == c["league"] and int(v) > mine:
            better += 1
    return better + 1


def _week_check(c):
    w = week_index()
    old = int(c["points"].get("week", w))
    if old == w:
        return
    if int(c["points"].get("flood", 0)) > 0 or int(c["points"].get("explorer", 0)) > 0:
        rank = _league_rank(c, old)
        lg = int(c["league"])
        shards = max(1, 6 - rank // 10) + lg
        text = "Flut-Rangliste: Platz %d in Liga %s." % (rank, RULES["leagues"][lg])
        if rank <= RULES["promote_top"] and lg < len(RULES["leagues"]) - 1 and int(c["points"]["flood"]) > 0:
            c["league"] = lg + 1
            text += " Aufstieg!"
        elif rank > RULES["demote_below"] and lg > 0:
            c["league"] = lg - 1
            text += " Abstieg."
        mail(c, "Rangliste", text, {"shards": shards}, kind="board")
    c["points"] = {"week": w, "flood": 0, "explorer": 0}


# ================================================================= Clans
def clan_of(c):
    cl = S["clans"].get(c.get("clan", ""))
    if cl and c["key"] not in cl["members"]:
        c["clan"] = ""
        return None
    if cl:
        _clan_week(cl)
    return cl


def _clan_week(cl):
    w = week_index()
    if cl.get("week") != w:
        cl["week"] = w
        for m in cl["members"].values():
            m["points"] = 0


def clan_points(cl):
    return sum(int(m["points"]) for m in cl["members"].values())


def clan_goal(cl):
    return len(cl["members"]) * (260 + 40 * int(cl["level"]))


def clan_add_points(c, n):
    cl = clan_of(c)
    if not cl:
        return
    cl["members"][c["key"]]["points"] += int(n)
    if cl.get("chest_week") != week_index() and clan_points(cl) >= clan_goal(cl):
        cl["chest_week"] = week_index()
        cl["level"] = min(20, int(cl["level"]) + 1)
        for k, m in cl["members"].items():
            o = S["cities"].get(k)
            if o and int(m["points"]) > 0:
                mail(o, "Clan " + cl["name"], "Wochenziel erreicht! Clankiste für alle.", chest="clan", kind="clan")
        shout(cl, "Clan", "Wochenziel erreicht – Clan-Stufe %d" % cl["level"])


def shout(cl, who, text, code=""):
    cl["shouts"].append({"who": who, "code": code, "text": censor(text)[:RULES["chat_max_len"]], "t": now()})
    while len(cl["shouts"]) > RULES["chat_keep"]:
        cl["shouts"].pop(0)


def clan_view(cl, c):
    me = c["key"]
    blocked = S["users"][c["uid"]].get("blocked", [])
    members = []
    for k, m in cl["members"].items():
        o = S["cities"].get(k)
        if not o:
            continue
        members.append({"name": o["name"], "code": o["code"], "level": o["level"], "points": m["points"], "role": m["role"], "me": k == me,
                        "online": now() - float(o.get("last_seen", 0)) < 300})
    members.sort(key=lambda m: -int(m["points"]))
    asks = [dict(a) for a in cl["asks"] if a["key"] != me and a["filled"] < a["amount"]]
    for a in asks:
        a.pop("key", None)
    shouts = [s for s in cl["shouts"] if s.get("code", "") not in blocked]
    req = {}
    for a in cl["asks"]:
        if a["key"] == me:
            req = {"res": a["res"], "amount": a["amount"], "filled": a["filled"], "at": a["at"]}
    return {"id": cl["id"], "name": cl["name"], "level": cl["level"], "color": cl["color"], "members": members, "my_role": cl["members"][me]["role"],
            "my_points": cl["members"][me]["points"], "points": clan_points(cl), "goal": clan_goal(cl), "asks": asks, "shouts": shouts, "request": req,
            "chest_week": cl.get("chest_week", -1), "min_level": cl["min_level"], "hidden": cl.get("hidden", False)}


def leave(c):
    cl = clan_of(c)
    if not cl:
        return
    role = cl["members"][c["key"]]["role"]
    del cl["members"][c["key"]]
    cl["asks"] = [a for a in cl["asks"] if a["key"] != c["key"]]
    c["clan"] = ""
    if not cl["members"]:
        del S["clans"][cl["id"]]
        return
    if role == "Anführer":
        cands = sorted(cl["members"].items(), key=lambda kv: (kv[1]["role"] != "Stellvertreter", kv[1]["joined"]))
        cands[0][1]["role"] = "Anführer"
    shout(cl, "Clan", "%s hat den Clan verlassen" % c["name"])


# ================================================================= RPC-Funktionen
def rpc_time(uid, p):
    return {"now": now(), "week": week_index(), "day": day_index()}


def rpc_hello(uid, p):
    c = city_of(uid, p)
    c["name"] = str(p.get("name", c["name"]))[:24] or "Kommandant"
    if is_bad(c["name"]):
        c["name"] = "Kommandant"
    c["level"] = int(p.get("level", c["level"]))
    c["bunker"] = int(p.get("bunker", c["bunker"]))
    if not c["code"]:
        want = str(p.get("code", "")).upper()
        code = want if (len(want) == 8 and want not in S["codes"]) else new_code()
        c["code"] = code
        S["codes"][code] = c["key"]
    out = rpc_time(uid, p)
    out.update({"code": c["code"], "user_id": uid, "gems": S["users"][uid]["wallet"]["gems"], "league": c["league"]})
    bn = str(p.get("bunker_name", "")).strip()
    if bn:
        out["bunker"] = _claim_name(c, bn)
    else:
        out["bunker"] = {"ok": c["bunker_name"] != "", "why": ""}
    out["bunker_name"] = c["bunker_name"]
    return out


def _claim_name(c, bn):
    if len(bn) < RULES["bunker_name_min"] or len(bn) > RULES["bunker_name_max"]:
        return {"ok": False, "why": "Der Bunkername braucht %d bis %d Zeichen." % (RULES["bunker_name_min"], RULES["bunker_name_max"])}
    if is_bad(bn):
        return {"ok": False, "why": "Dieser Bunkername ist nicht erlaubt."}
    low = bn.lower()
    owner = S["names"].get(low)
    if owner and owner != c["key"]:
        return {"ok": False, "why": "Der Bunkername „%s“ ist schon vergeben." % bn}
    if c["bunker_name"] and S["names"].get(c["bunker_name"].lower()) == c["key"]:
        del S["names"][c["bunker_name"].lower()]
    S["names"][low] = c["key"]
    c["bunker_name"] = bn
    return {"ok": True, "why": ""}


def rpc_rename(uid, p):
    c = city_of(uid, p)
    return _claim_name(c, str(p.get("bunker_name", "")).strip())


def rpc_save_put(uid, p):
    c = city_of(uid, p)
    data = p.get("data")
    if not isinstance(data, dict):
        raise ApiError(400, "Spielstand fehlt")
    if len(json.dumps(data)) > RULES["save_max_bytes"]:
        raise ApiError(400, "Spielstand zu groß")
    cur = c["save"]
    base = int(p.get("base", 0))
    if cur and int(cur["rev"]) != base and not p.get("force"):
        return {"ok": False, "conflict": True, "rev": cur["rev"], "saved_at": cur["saved_at"], "summary": _summary(cur["data"])}
    rev = (int(cur["rev"]) if cur else 0) + 1
    data["rev"] = rev
    if not data.get("server_time"):
        data["server_time"] = now()          # sonst gilt die (serverkorrigierte) Speicherzeit des Geräts
    c["save"] = {"rev": rev, "saved_at": now(), "data": data}
    c["level"] = int(data.get("level", c["level"]))
    return {"ok": True, "rev": rev, "server_time": now()}


def _summary(d):
    b = 1
    for x in d.get("buildings", []):
        if x.get("key") == "bunker":
            b = int(x.get("level", 1))
    return {"level": int(d.get("level", 1)), "bunker": b, "bunker_name": d.get("bunker_name", ""), "server_time": float(d.get("server_time", 0)),
            "rev": int(d.get("rev", 0))}


def rpc_save_get(uid, p):
    c = city_of(uid, p)
    if not c["save"]:
        return {"rev": 0}
    return {"rev": c["save"]["rev"], "saved_at": c["save"]["saved_at"], "data": c["save"]["data"]}


def rpc_save_list(uid, p):
    out = []
    for c in S["cities"].values():
        if c["uid"] == uid and c["save"]:
            s = _summary(c["save"]["data"])
            s.update({"city": c["city"], "saved_at": c["save"]["saved_at"]})
            out.append(s)
    out.sort(key=lambda x: x["city"])
    return {"cities": out}


def rpc_find(uid, p):
    me = ckey(uid, p.get("city", 1))
    q = str(p.get("query", "")).strip().lower()
    out = []
    if len(q) < 2:
        return {"results": out}
    blocked = S["users"][uid].get("blocked", [])
    exact = by_code(q.upper())
    if exact:
        out.append(public(exact, me))
    for c in S["cities"].values():
        if len(out) >= 12:
            break
        if c is exact or not c["bunker_name"] or c.get("hidden") or c["code"] in blocked:
            continue
        if q in c["bunker_name"].lower():
            out.append(public(c, me))
    return {"results": out}


def _friend_entry(c, o, since):
    e = public(o)
    e["since"] = since
    e["score"] = int(board_get("flood", week_index()).get(o["key"], 0))
    return e


def rpc_friends(uid, p):
    c = city_of(uid, p)
    out = []
    for code, since in list(c["friends"].items()):
        o = by_code(code)
        if o:
            out.append(_friend_entry(c, o, since))
        else:
            del c["friends"][code]
    return {"friends": out, "sends_left": limit_left(c, "send", "d", RULES["send_per_day"]), "helps_left": limit_left(c, "help", "d", RULES["help_per_day"]),
            "giftbox_left": limit_left(c, "giftbox", "w", RULES["giftbox_per_week"]), "item_left": limit_left(c, "item", "d", RULES["item_per_day"])}


def rpc_friend_add(uid, p):
    c = city_of(uid, p)
    code = str(p.get("code", "")).strip().upper()
    if len(code) != 8:
        return {"ok": False, "why": "Ein Freundescode hat acht Zeichen."}
    if code == c["code"]:
        return {"ok": False, "why": "Das ist dein eigener Code."}
    if len(c["friends"]) >= RULES["friends_max"]:
        return {"ok": False, "why": "Freundesliste ist voll."}
    if code in c["friends"]:
        return {"ok": False, "why": "Ihr seid schon befreundet."}
    o = by_code(code)
    if not o:
        return {"ok": False, "why": "Zu diesem Code gibt es keinen Bunker."}
    if c["code"] in S["users"][o["uid"]].get("blocked", []):
        return {"ok": False, "why": "Dieser Bunker nimmt keine Anfragen an."}
    if len(o["friends"]) >= RULES["friends_max"]:
        return {"ok": False, "why": "Die Freundesliste des anderen ist voll."}
    if not limit(c, "friend_add", "d", RULES["friend_adds_per_day"]):
        return {"ok": False, "why": "Heute wurden schon genug Freunde hinzugefügt."}
    c["friends"][code] = day_index()
    o["friends"][c["code"]] = day_index()
    mail(o, c["name"], "ist jetzt mit dir befreundet", kind="friend", from_code=c["code"])
    return {"ok": True, "why": "", "friend": _friend_entry(c, o, day_index())}


def rpc_friend_remove(uid, p):
    c = city_of(uid, p)
    code = str(p.get("code", "")).upper()
    c["friends"].pop(code, None)
    o = by_code(code)
    if o:
        o["friends"].pop(c["code"], None)
    return {"ok": True}


def rpc_send(uid, p):
    """Verschicken an Freunde: Rohstoffe, Geschenkkiste, Hilfe, Ausrüstungsstück – Limits prüft der Server."""
    c = city_of(uid, p)
    code = str(p.get("to", "")).upper()
    kind = str(p.get("kind", ""))
    o = by_code(code)
    if not o or code not in c["friends"]:
        return {"ok": False, "why": "Ihr seid nicht befreundet."}
    if kind == "res":
        r = str(p.get("res", ""))
        amt = int(p.get("amount", 0))
        if r not in ["wood", "stone", "metal", "fuel"] or amt <= 0 or amt > 100000:
            return {"ok": False, "why": "Das lässt sich nicht verschicken."}
        if not limit(c, "send", "d", RULES["send_per_day"]):
            return {"ok": False, "why": "Heute sind alle fünf Sendungen verbraucht."}
        mail(o, c["name"], "schickt dir %d" % amt, {r: amt}, kind="send", from_code=c["code"])
        clan_add_points(c, 4)
        return {"ok": True, "why": ""}
    if kind == "giftbox":
        if not limit(c, "giftbox", "w", RULES["giftbox_per_week"]):
            return {"ok": False, "why": "Diese Woche wurde schon eine Geschenkkiste verschickt."}
        mail(o, c["name"], "schickt dir eine Geschenkkiste", chest="gift", kind="gift", from_code=c["code"])
        return {"ok": True, "why": ""}
    if kind == "help":
        if not limit(c, "help", "d", RULES["help_per_day"]):
            return {"ok": False, "why": "Heute hast du schon fünfmal geholfen."}
        mail(o, c["name"], "hat dir beim Bauen geholfen", {"coins": 15}, kind="help", from_code=c["code"])
        return {"ok": True, "why": ""}
    if kind == "item":
        if day_index() - int(c["friends"][code]) < RULES["item_friend_days"]:
            return {"ok": False, "why": "Erst nach 7 Tagen Freundschaft."}
        item = p.get("item") or {}
        if int(item.get("rarity", 9)) > 1:
            return {"ok": False, "why": "Nur gewöhnliche und seltene Stücke lassen sich verschicken."}
        if not limit(c, "item", "d", RULES["item_per_day"]):
            return {"ok": False, "why": "Heute wurde schon ein Stück verschickt."}
        mail(o, c["name"], "schickt dir ein Ausrüstungsstück", item=item, kind="item", from_code=c["code"])
        return {"ok": True, "why": ""}
    return {"ok": False, "why": "?"}


def rpc_mail(uid, p):
    c = city_of(uid, p)
    t = now()
    c["mail"] = [m for m in c["mail"] if m["expire"] > t]
    return {"mail": c["mail"]}


def rpc_mail_claim(uid, p):
    """Post abholen: der Server streicht die Nachricht und meldet, was gutgeschrieben werden darf."""
    c = city_of(uid, p)
    ids = [int(x) for x in p.get("ids", [])]
    out = []
    keep = []
    for m in c["mail"]:
        if int(m["id"]) in ids and m["expire"] > now():
            out.append(m)
        else:
            keep.append(m)
    c["mail"] = keep
    return {"ok": True, "claimed": out}


def rpc_clan_list(uid, p):
    out = []
    for cl in S["clans"].values():
        if cl.get("hidden"):
            continue
        out.append({"id": cl["id"], "name": cl["name"], "level": cl["level"], "members": len(cl["members"]), "min_level": cl["min_level"]})
    out.sort(key=lambda x: (-x["level"], -x["members"]))
    return {"clans": out[:30]}


def rpc_clan_create(uid, p):
    c = city_of(uid, p)
    name = str(p.get("name", "")).strip()
    if c["level"] < RULES["clan_min_level"]:
        return {"ok": False, "why": "Clans gibt es ab Spielerstufe %d." % RULES["clan_min_level"]}
    if len(name) < RULES["clan_name_min"] or len(name) > RULES["clan_name_max"]:
        return {"ok": False, "why": "Der Name braucht 3 bis 16 Zeichen."}
    if is_bad(name):
        return {"ok": False, "why": "Dieser Clan-Name ist nicht erlaubt."}
    for cl in S["clans"].values():
        if cl["name"].lower() == name.lower():
            return {"ok": False, "why": "Diesen Clan gibt es schon."}
    leave(c)
    cid = "c%d" % S["next_clan"]
    S["next_clan"] += 1
    S["clans"][cid] = {"id": cid, "name": name, "level": 1, "color": random.randint(0, 5), "min_level": RULES["clan_min_level"],
                       "members": {c["key"]: {"role": "Anführer", "points": 0, "joined": now()}}, "asks": [], "shouts": [], "week": week_index(),
                       "chest_week": -1, "reports": []}
    c["clan"] = cid
    return {"ok": True, "why": "", "clan": clan_view(S["clans"][cid], c)}


def rpc_clan_join(uid, p):
    c = city_of(uid, p)
    cl = S["clans"].get(str(p.get("id", "")))
    if not cl:
        return {"ok": False, "why": "Diesen Clan gibt es nicht mehr."}
    if c["level"] < RULES["clan_min_level"]:
        return {"ok": False, "why": "Clans gibt es ab Spielerstufe %d." % RULES["clan_min_level"]}
    if c["level"] < cl["min_level"]:
        return {"ok": False, "why": "Dieser Clan nimmt ab Stufe %d auf." % cl["min_level"]}
    if len(cl["members"]) >= RULES["clan_max"]:
        return {"ok": False, "why": "Der Clan ist voll (%d Mitglieder)." % RULES["clan_max"]}
    leave(c)
    cl["members"][c["key"]] = {"role": "Mitglied", "points": 0, "joined": now()}
    c["clan"] = cl["id"]
    shout(cl, "Clan", "%s ist beigetreten" % c["name"])
    return {"ok": True, "why": "", "clan": clan_view(cl, c)}


def rpc_clan_leave(uid, p):
    leave(city_of(uid, p))
    return {"ok": True}


def rpc_clan_get(uid, p):
    c = city_of(uid, p)
    cl = clan_of(c)
    return {"clan": clan_view(cl, c) if cl else {}}


def rpc_clan_chat(uid, p):
    c = city_of(uid, p)
    cl = clan_of(c)
    if not cl:
        return {"ok": False, "why": "Du bist in keinem Clan."}
    text = str(p.get("text", "")).strip()[:RULES["chat_max_len"]]
    if not text:
        return {"ok": False, "why": "Leere Nachricht."}
    hour = int(now() // 3600)
    rec = c["limits"].get("chat")
    if not rec or rec[0] != hour:
        rec = [hour, 0]
    if rec[1] >= RULES["chat_per_hour"]:
        return {"ok": False, "why": "Bitte etwas langsamer."}
    rec[1] += 1
    c["limits"]["chat"] = rec
    shout(cl, c["name"], text, c["code"])
    return {"ok": True, "why": "", "text": censor(text)}


def rpc_clan_role(uid, p):
    """Anführer: befördern/zurückstufen/entfernen/Führung abgeben. Stellvertreter: Mitglieder entfernen."""
    c = city_of(uid, p)
    cl = clan_of(c)
    if not cl:
        return {"ok": False, "why": "Du bist in keinem Clan."}
    my = cl["members"][c["key"]]["role"]
    o = by_code(str(p.get("code", "")))
    if not o or o["key"] not in cl["members"] or o["key"] == c["key"]:
        return {"ok": False, "why": "Dieses Mitglied gibt es nicht."}
    act = str(p.get("action", ""))
    their = cl["members"][o["key"]]
    if act == "kick":
        if my == "Anführer" or (my == "Stellvertreter" and their["role"] == "Mitglied"):
            leave(o)
            return {"ok": True, "why": ""}
        return {"ok": False, "why": "Dazu fehlt dir das Recht."}
    if my != "Anführer":
        return {"ok": False, "why": "Nur der Anführer darf das."}
    if act == "promote":
        their["role"] = "Stellvertreter"
    elif act == "demote":
        their["role"] = "Mitglied"
    elif act == "lead":
        their["role"] = "Anführer"
        cl["members"][c["key"]]["role"] = "Stellvertreter"
    else:
        return {"ok": False, "why": "?"}
    return {"ok": True, "why": ""}


def rpc_clan_request(uid, p):
    c = city_of(uid, p)
    cl = clan_of(c)
    if not cl:
        return {"ok": False, "why": "Du bist in keinem Clan."}
    for a in cl["asks"]:
        if a["key"] == c["key"] and now() - a["at"] < RULES["request_every_h"] * 3600 and a["filled"] < a["amount"]:
            return {"ok": False, "why": "Du hast schon um etwas gebeten."}
    cl["asks"] = [a for a in cl["asks"] if a["key"] != c["key"]]
    r = str(p.get("res", "wood"))
    amount = max(1, min(int(p.get("amount", 100)), 2000))
    cl["asks"].append({"id": str(uuid.uuid4())[:8], "key": c["key"], "name": c["name"], "res": r, "amount": amount, "filled": 0, "at": now()})
    return {"ok": True, "why": ""}


def rpc_clan_donate(uid, p):
    c = city_of(uid, p)
    cl = clan_of(c)
    if not cl:
        return {"ok": False, "why": "Du bist in keinem Clan."}
    for a in cl["asks"]:
        if a["id"] == str(p.get("ask", "")) and a["key"] != c["key"]:
            amt = max(0, min(int(p.get("amount", 0)), a["amount"] - a["filled"]))
            if amt <= 0:
                return {"ok": False, "why": "Diese Bitte ist schon erfüllt."}
            if not limit(c, "donate", "d", RULES["donate_per_day"]):
                return {"ok": False, "why": "Heute hast du schon genug gespendet."}
            a["filled"] += amt
            o = S["cities"].get(a["key"])
            if o:
                mail(o, c["name"], "spendet %d" % amt, {a["res"]: amt}, kind="donate", from_code=c["code"])
            clan_add_points(c, amt // 4 + 5)
            shout(cl, a["name"], "Danke!")
            return {"ok": True, "why": "", "amount": amt}
    return {"ok": False, "why": "Diese Bitte gibt es nicht mehr."}


def rpc_score(uid, p):
    c = city_of(uid, p)
    board = str(p.get("board", ""))
    n = max(0, min(int(p.get("add", 0)), 100000))
    if board in ("flood", "explorer"):
        c["points"][board] = int(c["points"].get(board, 0)) + n
        board_add(board, week_index(), c["key"], n)
    if int(p.get("clan", 0)) > 0:
        clan_add_points(c, min(int(p["clan"]), 1000))
    if "time" in p:
        k = str(int(p.get("area", 0)))
        t = float(p["time"])
        if t > 0 and (k not in c["times"] or t < c["times"][k]):
            c["times"][k] = t
    return {"ok": True, "points": c["points"]}


def rpc_board(uid, p):
    c = city_of(uid, p)
    kind = str(p.get("board", "flood"))
    out = []
    w = week_index()
    if kind == "friends":
        b = board_get("flood", w)
        for code in c["friends"]:
            o = by_code(code)
            if o:
                out.append({"name": o["name"], "score": int(b.get(o["key"], 0)), "me": False})
        out.append({"name": c["name"], "score": int(b.get(c["key"], 0)), "me": True})
    elif kind == "clans":
        mine = c.get("clan", "")
        for cl in S["clans"].values():
            out.append({"name": cl["name"], "score": clan_points(cl), "me": cl["id"] == mine})
    elif kind.startswith("time"):
        area = str(int(p.get("area", 0)))
        for o in S["cities"].values():
            if area in o["times"]:
                out.append({"name": o["name"], "score": o["times"][area], "me": o is c})
        out.sort(key=lambda e: float(e["score"]))
        return {"entries": out[:10], "league": c["league"], "week": w}
    else:
        b = board_get(kind, w)
        for k, v in b.items():
            o = S["cities"].get(k)
            if o and o["league"] == c["league"] and k != c["key"]:
                out.append({"name": o["name"], "score": int(v), "me": False})
        out.append({"name": c["name"], "score": int(b.get(c["key"], 0)), "me": True})
    out.sort(key=lambda e: -int(e["score"]))
    return {"entries": out[:RULES["league_size"]], "league": c["league"], "week": w}


def rpc_report(uid, p):
    c = city_of(uid, p)
    target = str(p.get("code", "")).upper()
    clan = str(p.get("clan", ""))
    S["reports"].append({"from": c["key"], "code": target, "clan": clan, "reason": str(p.get("reason", ""))[:40],
                         "text": str(p.get("text", ""))[:300], "t": now()})
    n = len([r for r in S["reports"] if (target and r["code"] == target) or (clan and r["clan"] == clan)])
    if n >= RULES["reports_hide_after"]:
        if target:
            o = by_code(target)
            if o:
                o["hidden"] = True          # bis zur Prüfung nicht mehr in der Suche
        if clan in S["clans"]:
            S["clans"][clan]["hidden"] = True
    return {"ok": True}


def rpc_block(uid, p):
    u = S["users"][uid]
    code = str(p.get("code", "")).upper()
    if p.get("unblock"):
        if code in u["blocked"]:
            u["blocked"].remove(code)
    elif code and code not in u["blocked"]:
        u["blocked"].append(code)
        c = city_of(uid, p)
        c["friends"].pop(code, None)
        o = by_code(code)
        if o:
            o["friends"].pop(c["code"], None)      # Freundschaft endet für beide
    return {"ok": True, "blocked": u["blocked"]}


def rpc_suggest(uid, p):
    """Vorschläge: zuletzt aktive Bunker ähnlicher Stufe, die noch keine Freunde sind."""
    c = city_of(uid, p)
    blocked = S["users"][uid].get("blocked", [])
    cands = [o for o in S["cities"].values() if o["uid"] != uid and o["code"] and o["code"] not in c["friends"]
             and o["code"] not in blocked and not o.get("hidden") and now() - float(o.get("last_seen", 0)) < 7 * 86400]
    cands.sort(key=lambda o: (abs(int(o["level"]) - int(c["level"])), -float(o.get("last_seen", 0))))
    return {"results": [public(o) for o in cands[:5]]}


def rpc_wallet_init(uid, p):
    """Einmalig beim ersten Verbinden: bisheriges Juwelen-Guthaben des Geräts übernehmen (gedeckelt)."""
    u = S["users"][uid]
    if u.get("wallet_init"):
        return {"ok": False, "gems": u["wallet"]["gems"]}
    u["wallet_init"] = True
    u["wallet"]["gems"] = max(0, min(int(p.get("gems", 0)), RULES["wallet_init_max"]))
    return {"ok": True, "gems": u["wallet"]["gems"]}


def rpc_wallet(uid, p):
    return {"gems": S["users"][uid]["wallet"]["gems"]}


def rpc_reward(uid, p):
    """Belohnungen bestätigen: Juwelen und Kisten schreibt der Client erst nach dieser Antwort gut."""
    c = city_of(uid, p)
    u = S["users"][uid]
    rr = RULES["reward"]
    acc = []
    rej = []
    seeds = []
    for i, it in enumerate(p.get("items", [])):
        kind = str(it.get("kind", ""))
        n = int(it.get("n", 0))
        reason = str(it.get("reason", ""))
        ok = n > 0
        if kind == "gems":
            ok = ok and n <= rr["gems_item_max"] and limit(c, "gems_day", "d", rr["gems_day_max"], n)
            if ok and reason in rr["flood_reasons"]:
                ok = limit(c, "flood_gems", "w", rr["flood_per_week"])
            if ok:
                u["wallet"]["gems"] += n
        elif kind == "chest":
            ok = ok and n <= 5 and limit(c, "chests_day", "d", rr["chests_day_max"], n)
            if ok and reason in rr["flood_chests"]:
                ok = limit(c, "flood_chest", "w", rr["flood_per_week"])
            if ok:
                for _ in range(n):
                    seeds.append([reason, random.randint(1, 2 ** 31 - 1)])
        else:
            ok = False
        (acc if ok else rej).append(i)
    return {"accepted": acc, "rejected": rej, "gems": u["wallet"]["gems"], "seeds": seeds}


def rpc_spend(uid, p):
    u = S["users"][uid]
    n = int(p.get("n", 0))
    if n <= 0:
        return {"ok": True, "gems": u["wallet"]["gems"]}
    if u["wallet"]["gems"] < n:
        return {"ok": False, "gems": u["wallet"]["gems"], "why": "Zu wenig Juwelen auf dem Konto."}
    u["wallet"]["gems"] -= n
    return {"ok": True, "gems": u["wallet"]["gems"]}


def _verify_receipt(store, product, receipt):
    """Attrappe: echte Prüfung siehe modules/rustwall.ts (Apple App Store Server API / Google Play Developer API).
    Gültig sind hier Belege, die mit MOCK-APPLE-OK bzw. MOCK-GOOGLE-OK beginnen, und im Testbetrieb 'TEST'."""
    if store == "apple":
        return receipt.startswith("MOCK-APPLE-OK")
    if store == "google":
        return receipt.startswith("MOCK-GOOGLE-OK")
    if store == "test":
        return ALLOW_TEST_PURCHASES[0] and receipt == "TEST"
    return False


def rpc_purchase(uid, p):
    u = S["users"][uid]
    store = str(p.get("store", ""))
    product = str(p.get("product", ""))
    receipt = str(p.get("receipt", ""))
    tid = str(p.get("transaction", "")) or hashlib.sha256(receipt.encode()).hexdigest()[:24]
    prod = RULES["products"].get(product)
    if not prod:
        return {"ok": False, "why": "Unbekanntes Produkt."}
    key = "%s:%s" % (store, tid)
    if key in S["purchases"]:
        return {"ok": True, "duplicate": True, "gems_added": 0, "gems": u["wallet"]["gems"]}
    if not _verify_receipt(store, product, receipt):
        return {"ok": False, "why": "Der Kaufbeleg ist ungültig."}
    if prod.get("once") and u.get("starter"):
        return {"ok": False, "why": "Das Startangebot gibt es nur einmal."}
    if prod.get("once"):
        u["starter"] = True
    S["purchases"][key] = {"uid": uid, "product": product, "t": now(), "gems": prod["gems"]}
    u["wallet"]["gems"] += int(prod["gems"])
    return {"ok": True, "duplicate": False, "gems_added": int(prod["gems"]), "gems": u["wallet"]["gems"]}


def rpc_restore(uid, p):
    out = [{"product": v["product"], "t": v["t"]} for v in S["purchases"].values() if v["uid"] == uid]
    return {"purchases": out, "starter": S["users"][uid].get("starter", False)}


def rpc_telemetry(uid, p):
    ev = p.get("events", [])[:RULES["telemetry_max_batch"]]
    anon = hashlib.sha256(("%s:%d" % (uid, day_index())).encode()).hexdigest()[:12]
    for e in ev:
        S["telemetry"].append({"a": anon, "e": str(e.get("e", ""))[:40], "p": e.get("p", {}), "t": e.get("t", now())})
    return {"ok": True, "n": len(ev)}


def rpc_crash(uid, p):
    S["crashes"].append({"t": now(), "event": p.get("event", {})})
    return {"ok": True}


def rpc_account_delete(uid, p):
    u = S["users"].get(uid)
    if not u:
        return {"ok": True}
    for k in [k for k, c in S["cities"].items() if c["uid"] == uid]:
        c = S["cities"][k]
        leave(c)
        S["codes"].pop(c["code"], None)
        if c["bunker_name"]:
            S["names"].pop(c["bunker_name"].lower(), None)
        for o in S["cities"].values():
            o["friends"].pop(c["code"], None)
        for b in S["boards"].values():
            b.pop(k, None)
        del S["cities"][k]
    for d in u["devices"]:
        S["devices"].pop(d, None)
    if u["email"]:
        S["emails"].pop(u["email"], None)
    for v in S["purchases"].values():
        if v["uid"] == uid:
            v["uid"] = "geloescht"        # Kaufbelege bleiben anonym erhalten (Aufbewahrungspflicht)
    del S["users"][uid]
    return {"ok": True}


# ================================================================= Live-Betrieb (Paket L): Ereignis-Zeitplan, Saison-Pass, Rangliste, Weltboss
LIVE = RULES.get("liveops", {})


def lo_event(w):
    ov = LIVE.get("events_override", {}).get(str(w))
    ev = LIVE.get("events", ["schleimregen"])
    return ov or ev[(w - int(LIVE.get("epoch_week", 0))) % len(ev)]


def lo_season(w=None):
    w = week_index() if w is None else w
    return max(1, (w - int(LIVE.get("epoch_week", 0))) // int(LIVE.get("season_weeks", 8)) + 1)


def lo_boss_dmg(w):
    """Gemeinschaftsschaden: echte Treffer aller Spieler plus simulierte Gemeinschaft (bis echte Spielerzahlen reichen)."""
    real = int(S.setdefault("boss", {}).get(str(w), 0))
    frac = min(1.0, max(0.0, (now() - (w * 7 - 3) * 86400.0) / (7 * 86400.0)))
    return real + int(float(LIVE.get("boss_hp", 1)) * float(LIVE.get("boss_sim_pace", 0.0)) * frac ** 0.9)


def rpc_liveops(uid, p):
    w = week_index()
    out = {"week": w, "event": lo_event(w), "event_end": ((w + 1) * 7 - 3) * 86400.0, "season": lo_season(w), "news": LIVE.get("news", [])}
    if out["event"] == "weltboss":
        out["boss_hp"] = int(LIVE.get("boss_hp", 1))
        out["boss_dmg"] = lo_boss_dmg(w)
    return out


def _season_of(c):
    n = lo_season()
    s = c.setdefault("season", {"n": n, "pts": 0})
    if s.get("n") != n:
        s.clear()
        s.update({"n": n, "pts": 0})
    return s


def rpc_season_add(uid, p):
    c = city_of(uid, p)
    s = _season_of(c)
    if int(p.get("season", s["n"])) != s["n"]:
        return {"ok": False, "why": "Andere Saison", "pts": s["pts"]}
    s["pts"] += max(0, min(int(p.get("add", 0)), int(LIVE.get("season_add_max", 5000))))
    return {"ok": True, "pts": s["pts"]}


def rpc_season_board(uid, p):
    c = city_of(uid, p)
    me = _season_of(c)
    out = []
    for o in S["cities"].values():
        so = o.get("season", {})
        if so.get("n") == me["n"] and (so.get("pts", 0) > 0 or o is c):
            out.append({"name": o["name"], "score": int(so.get("pts", 0)), "me": o is c})
    out.sort(key=lambda e: -int(e["score"]))
    rank = next((i + 1 for i, e in enumerate(out) if e["me"]), len(out))
    return {"entries": out[:50], "rank": rank, "season": me["n"]}


def rpc_boss_hit(uid, p):
    c = city_of(uid, p)
    w = week_index()
    if lo_event(w) != "weltboss":
        return {"ok": False, "why": "Kein Weltboss in dieser Woche"}
    dmg = max(0, min(int(p.get("dmg", 0)), int(LIVE.get("boss_hit_max", 0))))
    if dmg > 0 and limit(c, "boss_hits", "d", int(LIVE.get("boss_hits_per_day", 3))):
        S.setdefault("boss", {})[str(w)] = int(S["boss"].get(str(w), 0)) + dmg
    return {"ok": True, "boss_dmg": lo_boss_dmg(w), "boss_hp": int(LIVE.get("boss_hp", 1))}


# ================================================================= Spielmodi (V6 Paket M): Wochen-Ranglisten, Clan-Raid
MODI = RULES.get("modi", {})


def rpc_modi_score(uid, p):
    """Wochenwert eines Modus (tower: Summe der besten Läufe je Stockwerk, surv: bester Lauf). Der Server hält das Beste der Woche."""
    c = city_of(uid, p)
    kind = str(p.get("board", ""))
    if kind not in ("tower", "surv"):
        return {"ok": False, "why": "Unbekannte Rangliste"}
    score = max(0, min(int(p.get("score", 0)), int(MODI.get("score_max", {}).get(kind, 0))))
    b = S["boards"].setdefault("modi_%s:%d" % (kind, week_index()), {})
    b[c["key"]] = max(int(b.get(c["key"], 0)), score)
    return {"ok": True, "best": b[c["key"]]}


def rpc_modi_board(uid, p):
    c = city_of(uid, p)
    kind = str(p.get("board", ""))
    w = week_index()
    b = S["boards"].get("modi_%s:%d" % (kind, w), {})
    out = []
    for k, sc in b.items():
        o = S["cities"].get(k)
        if o:
            out.append({"name": o["name"], "score": int(sc), "me": k == c["key"]})
    if not any(e["me"] for e in out):
        out.append({"name": c["name"], "score": 0, "me": True})
    out.sort(key=lambda e: (-int(e["score"]), not e["me"]))
    rank = next((i + 1 for i, e in enumerate(out) if e["me"]), len(out))
    return {"entries": out[:int(MODI.get("board_size", 50))], "rank": rank, "week": w}


def _raid_view(cl, c):
    w = week_index()
    rec = cl.setdefault("raid", {})
    if rec.get("week") != w:
        rec.clear()
        rec.update({"week": w, "dmg": {}})
    members = []
    for k in cl["members"]:
        o = S["cities"].get(k)
        if o:
            members.append({"name": o["name"], "level": o["level"], "dmg": int(rec["dmg"].get(k, 0)), "me": k == c["key"]})
    members.sort(key=lambda m: -m["dmg"])
    hp = max(1, len(cl["members"])) * int(MODI.get("raid_hp_per_member", 1))
    return {"week": w, "hp": hp, "dmg": sum(m["dmg"] for m in members), "members": members}


def rpc_raid_hit(uid, p):
    """Clan-Raid: Schaden eines Angriffs eintragen (höchstens raid_hits_per_day je Tag und Stadt, gedeckelt)."""
    c = city_of(uid, p)
    cl = clan_of(c)
    if not cl:
        return {"ok": False, "why": "Du bist in keinem Clan."}
    view = _raid_view(cl, c)
    dmg = max(0, min(int(p.get("dmg", 0)), int(MODI.get("raid_hit_max", 0))))
    if dmg > 0 and limit(c, "raid_hits", "d", int(MODI.get("raid_hits_per_day", 3))):
        rec = cl["raid"]["dmg"]
        rec[c["key"]] = int(rec.get(c["key"], 0)) + dmg
        view = _raid_view(cl, c)
    view["ok"] = True
    return view


def rpc_raid_get(uid, p):
    c = city_of(uid, p)
    cl = clan_of(c)
    if not cl:
        return {"ok": False, "why": "Du bist in keinem Clan."}
    view = _raid_view(cl, c)
    view["ok"] = True
    return view


RPC = {name[4:]: fn for name, fn in globals().items() if name.startswith("rpc_")}


# ================================================================= HTTP
class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        if os.environ.get("MOCK_LOG"):
            super().log_message(fmt, *args)

    def _send(self, status, obj):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length", 0) or 0)
        raw = self.rfile.read(n) if n > 0 else b""
        if not raw:
            return None
        return json.loads(raw.decode("utf-8"))

    def _basic_ok(self):
        h = self.headers.get("Authorization", "")
        if not h.startswith("Basic "):
            return False
        try:
            return base64.b64decode(h[6:]).decode().split(":")[0] == SERVER_KEY
        except Exception:
            return False

    def _bearer(self):
        h = self.headers.get("Authorization", "")
        if not h.startswith("Bearer "):
            raise ApiError(401, "Auth token invalid", 16)
        uid = read_token(h[7:])
        if not uid:
            raise ApiError(401, "Auth token invalid", 16)
        return uid

    def do_OPTIONS(self):
        self._send(204, {})

    def do_GET(self):
        self._route("GET")

    def do_POST(self):
        self._route("POST")

    def do_DELETE(self):
        self._route("DELETE")

    def _route(self, method):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        try:
            with LOCK:
                body = self._body() if method != "GET" else None
                out = self._dispatch(method, u.path, q, body)
                save_state()
            self._send(200, out)
        except ApiError as e:
            self._send(e.status, {"error": e.msg, "message": e.msg, "code": e.code})
        except Exception as e:      # noqa: BLE001 – Attrappe: Fehler als 500 melden
            self._send(500, {"error": repr(e), "message": repr(e), "code": 13})

    def _dispatch(self, method, path, q, body):
        if path == "/healthcheck":
            return {}
        if path == "/mock/time" and method == "POST":
            TIME_OFFSET[0] = float((body or {}).get("offset", 0.0))
            return {"now": now()}
        if path == "/mock/state":
            return S
        m = re.match(r"^/api/([^/]+)/(store|envelope)/?$", path)
        if m:
            S["crashes"].append({"t": now(), "sentry": body if isinstance(body, dict) else str(body)[:2000]})
            return {"id": uuid.uuid4().hex}
        if path.startswith("/v2/account/authenticate/"):
            if not self._basic_ok():
                raise ApiError(401, "Server key invalid", 16)
            kind = path.rsplit("/", 1)[1]
            create = q.get("create", ["true"])[0] != "false"
            body = body or {}
            if kind == "device":
                did = str(body.get("id", ""))
                if len(did) < 10 or len(did) > 128:
                    raise ApiError(400, "Device ID invalid", 3)
                uid = S["devices"].get(did)
                created = False
                if not uid:
                    if not create:
                        raise ApiError(404, "User account not found", 5)
                    uid = new_user()
                    S["devices"][did] = uid
                    S["users"][uid]["devices"].append(did)
                    created = True
                return session(uid, created)
            if kind == "email":
                em = str(body.get("email", "")).lower()
                uid = S["emails"].get(em)
                if not uid or S["users"][uid]["pw"] != hashlib.sha256(str(body.get("password", "")).encode()).hexdigest():
                    raise ApiError(401, "Invalid credentials", 16)
                return session(uid, False)
            raise ApiError(400, "Nicht unterstützt", 3)
        if path == "/v2/account/session/refresh":
            uid = read_token(str((body or {}).get("token", "")), "r")
            if not uid:
                raise ApiError(401, "Refresh token invalid or expired", 16)
            return session(uid, False)
        uid = self._bearer()
        user = S["users"][uid]
        if path == "/v2/account" and method == "GET":
            return {"user": {"id": uid, "username": user["username"], "create_time": user["created"]}, "email": user["email"],
                    "devices": [{"id": d} for d in user["devices"]], "wallet": json.dumps(user["wallet"]),
                    "linked": {"apple": bool(user["apple"]), "google": bool(user["google"]), "email": bool(user["email"])}}
        if path.startswith("/v2/account/link/"):
            kind = path.rsplit("/", 1)[1]
            body = body or {}
            if kind == "email":
                em = str(body.get("email", "")).lower()
                pw = str(body.get("password", ""))
                if "@" not in em or len(pw) < 8:
                    raise ApiError(400, "Invalid email address or password too short (min 8)", 3)
                if em in S["emails"] and S["emails"][em] != uid:
                    raise ApiError(409, "Email is already in use.", 6)
                S["emails"][em] = uid
                user["email"] = em
                user["pw"] = hashlib.sha256(pw.encode()).hexdigest()
                return {}
            if kind in ("apple", "google"):
                tok = str(body.get("token", ""))
                if not tok.startswith("MOCK-"):
                    raise ApiError(401, "Could not authenticate %s profile." % kind, 16)
                user[kind] = tok
                return {}
            raise ApiError(400, "Nicht unterstützt", 3)
        m = re.match(r"^/v2/rpc/([a-z_]+)$", path)
        if m and method == "POST":
            name = m.group(1)
            if not name.startswith("rw_") or name[3:] not in RPC:
                raise ApiError(404, "RPC function not found", 5)
            payload = {}
            if isinstance(body, str) and body:
                payload = json.loads(body)
            elif isinstance(body, dict):
                payload = body
            res = RPC[name[3:]](uid, payload)
            return {"id": name, "payload": json.dumps(res)}
        raise ApiError(404, "Not found", 5)


def main():
    ap = argparse.ArgumentParser(description="Rustwall-Testserver (Attrappe)")
    ap.add_argument("--port", type=int, default=7350)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--state", default="", help="Zustand in dieser JSON-Datei halten")
    ap.add_argument("--allow-test-purchases", action="store_true", help="Testkäufe (Beleg 'TEST') annehmen")
    ap.add_argument("--quit-after", type=float, default=0.0, help="nach so vielen Sekunden beenden (Tests)")
    a = ap.parse_args()
    ALLOW_TEST_PURCHASES[0] = a.allow_test_purchases
    if a.state:
        STATE_FILE[0] = a.state
        if os.path.exists(a.state):
            S.update(json.load(open(a.state, encoding="utf-8")))
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    print("Rustwall-Testserver läuft auf http://%s:%d" % (a.host, a.port), flush=True)
    if a.quit_after > 0:
        threading.Timer(a.quit_after, srv.shutdown).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
