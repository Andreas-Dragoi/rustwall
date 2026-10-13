// Rustwall – Server-Modul für Nakama (TypeScript, wird zu build/index.js übersetzt).
//
// Gleiche Schnittstellen und Regeln wie der Testserver server/mock_server.py (der für die automatischen Tests
// dient). Die Zahlen stehen in regeln.json, der Wortfilter in wortfilter.txt (beide liegen neben build/).
//
// Datenhaltung (Nakama-Speicher):
//   Konto:       Nakama-Konto (Gerät anonym, verknüpfbar mit E-Mail/Apple/Google), Wallet {gems}
//   "acct"/"meta"           (Besitzer: Spieler)  {wallet_init, starter, blocked: [Codes]}
//   "city"/"<Nr>"           (Besitzer: Spieler)  öffentliche Daten einer Stadt, Freunde, Limits, Wochenpunkte, Liga, Clan
//   "save"/"<Nr>"           (Besitzer: Spieler)  Spielstand {rev, saved_at, data}
//   "mail"/"<Nr>"           (Besitzer: Spieler)  Postfach {list: [...]}
//   "codes"/"<CODE>", "names"/"<name klein>", "clans"/"<id>", "reports", "purchases", "telemetry", "crashes" (Besitzer: System)
//   Ranglisten:  flood_L<Liga>, explorer_L<Liga> (wöchentlicher Reset Montag 0:00 UTC), time_A<Gebiet> (Bestzeiten)
//
// Hinweis: Dieses Modul wurde mit den Nakama-Typdefinitionen übersetzt (tsc), aber hier ohne laufenden
// Nakama-Server nicht ausgeführt. Die Spiellogik ist dieselbe wie im getesteten Testserver.

const SYSTEM = "00000000-0000-0000-0000-000000000000";
const LEAGUES_N = 6;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

let RULES: any = {};
let FILTER: string[] = [];

// ================================================================= Hilfen
function now(nk: nkruntime.Nakama): number {
    return Date.now() / 1000;
}

function dayIndex(t: number): number {
    return Math.floor(t / 86400);
}

function weekIndex(t: number): number {
    return Math.floor((dayIndex(t) + 3) / 7);       // Wochen ab Montag (1.1.1970 war ein Donnerstag)
}

function err(msg: string): string {
    return JSON.stringify({ ok: false, why: msg });
}

function parse(payload: string): any {
    if (!payload) return {};
    try { return JSON.parse(payload); } catch (e) { throw new Error("Ungültige Nutzdaten"); }
}

function cityNo(p: any): number {
    const c = parseInt(String(p.city || 1), 10);
    if (isNaN(c) || c < 1 || c > 5) throw new Error("Ungültige Stadt");
    return c;
}

/** Feste UUID je Stadt (für Ranglisten-Einträge): aus sha256(uid:stadt). */
function cityUuid(nk: nkruntime.Nakama, uid: string, city: number): string {
    const h = nk.sha256Hash(uid + ":" + city);
    return h.substr(0, 8) + "-" + h.substr(8, 4) + "-4" + h.substr(13, 3) + "-a" + h.substr(17, 3) + "-" + h.substr(20, 12);
}

function read(nk: nkruntime.Nakama, coll: string, key: string, uid: string): any {
    const r = nk.storageRead([{ collection: coll, key: key, userId: uid }]);
    return r.length > 0 ? r[0].value : null;
}

function write(nk: nkruntime.Nakama, coll: string, key: string, uid: string, value: any, pub?: boolean): void {
    nk.storageWrite([{ collection: coll, key: key, userId: uid, value: value, permissionRead: pub ? 2 : 0, permissionWrite: 0 }]);
}

function del(nk: nkruntime.Nakama, coll: string, key: string, uid: string): void {
    nk.storageDelete([{ collection: coll, key: key, userId: uid }]);
}

// ================================================================= Wortfilter (gleiche Regeln wie mock_server.py)
const LEET: { [k: string]: string } = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s" };
const TOKEN = /[0-9A-Za-zÄÖÜäöüß@$]+/g;

function norm(t: string): string {
    let out = "";
    const low = t.toLowerCase().replace(/ß/g, "ss");
    for (let i = 0; i < low.length; i++) {
        const ch = low.charAt(i);
        out += LEET[ch] !== undefined ? LEET[ch] : ch;
    }
    return out;
}

function tokens(t: string): string[] {
    return t.match(TOKEN) || [];
}

function ruleHit(n: string): boolean {
    for (let i = 0; i < FILTER.length; i++) {
        const w = FILTER[i];
        if (w.indexOf(" ") >= 0) continue;
        if (w.charAt(0) === "~") {
            if (n.indexOf(w.substr(1)) >= 0) return true;
        } else if (w.charAt(w.length - 1) === "*") {
            if (n.indexOf(w.substr(0, w.length - 1)) === 0) return true;
        } else if (n === w) {
            return true;
        }
    }
    return false;
}

function phrases(t: string): string[] {
    const tk = tokens(t);
    const parts: string[] = [];
    for (let i = 0; i < tk.length; i++) parts.push(norm(tk[i]));
    const joined = " " + parts.join(" ") + " ";
    const out: string[] = [];
    for (let i = 0; i < FILTER.length; i++) {
        const w = FILTER[i];
        if (w.indexOf(" ") >= 0 && joined.indexOf(" " + w + " ") >= 0) out.push(w);
    }
    return out;
}

function isBad(t: string): boolean {
    if (phrases(t).length > 0) return true;
    const tk = tokens(t);
    for (let i = 0; i < tk.length; i++) if (ruleHit(norm(tk[i]))) return true;
    return false;
}

function censor(t: string): string {
    const ph: { [w: string]: boolean } = {};
    const pl = phrases(t);
    for (let i = 0; i < pl.length; i++) {
        const ws = pl[i].split(" ");
        for (let j = 0; j < ws.length; j++) ph[ws[j]] = true;
    }
    return t.replace(TOKEN, function (m: string) {
        const n = norm(m);
        if (ruleHit(n) || ph[n]) {
            let s = "";
            for (let i = 0; i < m.length; i++) s += "*";
            return s;
        }
        return m;
    });
}

// ================================================================= Städte
interface City {
    uid: string; city: number; code: string; bunker_name: string; name: string; level: number; bunker: number;
    friends: { [code: string]: number }; limits: { [k: string]: number[] }; points: { week: number; flood: number; explorer: number };
    league: number; clan: string; last_seen: number; times: { [area: string]: number }; hidden?: boolean;
}

function loadCity(nk: nkruntime.Nakama, uid: string, city: number, create: boolean): City | null {
    let c = read(nk, "city", String(city), uid) as City | null;
    if (!c) {
        if (!create) return null;
        c = { uid: uid, city: city, code: "", bunker_name: "", name: "Kommandant", level: 1, bunker: 1, friends: {}, limits: {},
              points: { week: weekIndex(now(nk)), flood: 0, explorer: 0 }, league: 0, clan: "", last_seen: now(nk), times: {} };
    }
    c.last_seen = now(nk);
    const w = weekIndex(now(nk));
    if (c.points.week !== w) c.points = { week: w, flood: 0, explorer: 0 };   // Abrechnung macht der Reset der Rangliste
    return c;
}

function saveCity(nk: nkruntime.Nakama, c: City): void {
    write(nk, "city", String(c.city), c.uid, c, true);
}

function byCode(nk: nkruntime.Nakama, code: string): City | null {
    const ref = read(nk, "codes", String(code).toUpperCase(), SYSTEM);
    if (!ref) return null;
    return loadCity(nk, ref.uid, ref.city, false);
}

function newCode(nk: nkruntime.Nakama): string {
    for (let t = 0; t < 50; t++) {
        let code = "";
        for (let i = 0; i < 8; i++) code += CODE_CHARS.charAt(Math.floor(Math.random() * CODE_CHARS.length));
        if (!read(nk, "codes", code, SYSTEM)) return code;
    }
    throw new Error("Kein freier Code");
}

function pub(c: City, meKey?: string): any {
    return { code: c.code, name: c.name, bunker_name: c.bunker_name, level: c.level, bunker: c.bunker,
             online: Date.now() / 1000 - c.last_seen < 300, own: meKey === c.uid + ":" + c.city };
}

function limit(c: City, key: string, period: string, maxn: number, add?: number): boolean {
    const a = add || 1;
    const idx = period === "d" ? dayIndex(Date.now() / 1000) : weekIndex(Date.now() / 1000);
    let rec = c.limits[key];
    if (!rec || rec[0] !== idx) rec = [idx, 0];
    if (rec[1] + a > maxn) { c.limits[key] = rec; return false; }
    rec[1] += a;
    c.limits[key] = rec;
    return true;
}

function limitLeft(c: City, key: string, period: string, maxn: number): number {
    const idx = period === "d" ? dayIndex(Date.now() / 1000) : weekIndex(Date.now() / 1000);
    const rec = c.limits[key];
    if (!rec || rec[0] !== idx) return maxn;
    return Math.max(0, maxn - rec[1]);
}

function meta(nk: nkruntime.Nakama, uid: string): any {
    return read(nk, "acct", "meta", uid) || { wallet_init: false, starter: false, blocked: [], hello: false };
}

function gems(nk: nkruntime.Nakama, uid: string): number {
    const w = nk.accountGetId(uid).wallet || {};
    return Number(w["gems"] || 0);
}

function addMail(nk: nkruntime.Nakama, c: City, from: string, text: string, res: any, chest: string, item: any, kind: string, fromCode: string): void {
    if (fromCode) {
        const m = meta(nk, c.uid);
        if (m.blocked && m.blocked.indexOf(fromCode) >= 0) return;
    }
    const box = read(nk, "mail", String(c.city), c.uid) || { list: [], next: 1 };
    box.list.push({ id: box.next, from: from, from_code: fromCode, text: text, res: res || {}, chest: chest || "", item: item || {}, kind: kind,
                    expire: Date.now() / 1000 + RULES.mail_keep_days * 86400 });
    box.next += 1;
    while (box.list.length > RULES.mail_max) box.list.shift();
    write(nk, "mail", String(c.city), c.uid, box);
}

// ================================================================= Clans
function loadClan(nk: nkruntime.Nakama, id: string): any {
    if (!id) return null;
    const cl = read(nk, "clans", id, SYSTEM);
    if (cl && cl.week !== weekIndex(now(nk))) {
        cl.week = weekIndex(now(nk));
        for (const k in cl.members) cl.members[k].points = 0;
    }
    return cl;
}

function saveClan(nk: nkruntime.Nakama, cl: any): void {
    write(nk, "clans", cl.id, SYSTEM, cl);
}

function clanPoints(cl: any): number {
    let t = 0;
    for (const k in cl.members) t += cl.members[k].points;
    return t;
}

function clanGoal(cl: any): number {
    return Object.keys(cl.members).length * (260 + 40 * cl.level);
}

function shout(cl: any, who: string, text: string, code: string): void {
    cl.shouts.push({ who: who, code: code, text: censor(text).substr(0, RULES.chat_max_len), t: Date.now() / 1000 });
    while (cl.shouts.length > RULES.chat_keep) cl.shouts.shift();
}

function myClan(nk: nkruntime.Nakama, c: City): any {
    const cl = loadClan(nk, c.clan);
    if (cl && !cl.members[c.uid + ":" + c.city]) { c.clan = ""; return null; }
    return cl;
}

function clanAddPoints(nk: nkruntime.Nakama, c: City, n: number): void {
    const cl = myClan(nk, c);
    if (!cl) return;
    cl.members[c.uid + ":" + c.city].points += n;
    if (cl.chest_week !== weekIndex(now(nk)) && clanPoints(cl) >= clanGoal(cl)) {
        cl.chest_week = weekIndex(now(nk));
        cl.level = Math.min(20, cl.level + 1);
        for (const k in cl.members) {
            if (cl.members[k].points <= 0) continue;
            const parts = k.split(":");
            const o = loadCity(nk, parts[0], parseInt(parts[1], 10), false);
            if (o) addMail(nk, o, "Clan " + cl.name, "Wochenziel erreicht! Clankiste für alle.", {}, "clan", {}, "clan", "");
        }
        shout(cl, "Clan", "Wochenziel erreicht – Clan-Stufe " + cl.level, "");
    }
    saveClan(nk, cl);
}

function clanView(nk: nkruntime.Nakama, cl: any, c: City): any {
    const me = c.uid + ":" + c.city;
    const blocked: string[] = meta(nk, c.uid).blocked || [];
    const members: any[] = [];
    for (const k in cl.members) {
        const parts = k.split(":");
        const o = loadCity(nk, parts[0], parseInt(parts[1], 10), false);
        if (!o) continue;
        const m = cl.members[k];
        members.push({ name: o.name, code: o.code, level: o.level, points: m.points, role: m.role, me: k === me, online: Date.now() / 1000 - o.last_seen < 300 });
    }
    members.sort(function (a, b) { return b.points - a.points; });
    const asks: any[] = [];
    let req: any = {};
    for (let i = 0; i < cl.asks.length; i++) {
        const a = cl.asks[i];
        if (a.key === me) req = { res: a.res, amount: a.amount, filled: a.filled, at: a.at };
        else if (a.filled < a.amount) asks.push({ id: a.id, name: a.name, res: a.res, amount: a.amount, filled: a.filled });
    }
    const shouts: any[] = [];
    for (let i = 0; i < cl.shouts.length; i++) if (blocked.indexOf(cl.shouts[i].code) < 0) shouts.push(cl.shouts[i]);
    return { id: cl.id, name: cl.name, level: cl.level, color: cl.color, members: members, my_role: cl.members[me].role, my_points: cl.members[me].points,
             points: clanPoints(cl), goal: clanGoal(cl), asks: asks, shouts: shouts, request: req, chest_week: cl.chest_week, min_level: cl.min_level };
}

function leaveClan(nk: nkruntime.Nakama, c: City): void {
    const cl = myClan(nk, c);
    c.clan = "";
    if (!cl) return;
    const me = c.uid + ":" + c.city;
    const role = cl.members[me].role;
    delete cl.members[me];
    const rest: any[] = [];
    for (let i = 0; i < cl.asks.length; i++) if (cl.asks[i].key !== me) rest.push(cl.asks[i]);
    cl.asks = rest;
    const keys = Object.keys(cl.members);
    if (keys.length === 0) { del(nk, "clans", cl.id, SYSTEM); return; }
    if (role === "Anführer") {
        keys.sort(function (a, b) {
            const va = cl.members[a].role === "Stellvertreter" ? 0 : 1, vb = cl.members[b].role === "Stellvertreter" ? 0 : 1;
            return va !== vb ? va - vb : cl.members[a].joined - cl.members[b].joined;
        });
        cl.members[keys[0]].role = "Anführer";
    }
    shout(cl, "Clan", c.name + " hat den Clan verlassen", "");
    saveClan(nk, cl);
}

// ================================================================= RPC-Funktionen
type Rpc = (ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string) => string;

function rpcTime(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const t = now(nk);
    return JSON.stringify({ now: t, week: weekIndex(t), day: dayIndex(t) });
}

function claimName(nk: nkruntime.Nakama, c: City, bn: string): any {
    if (bn.length < RULES.bunker_name_min || bn.length > RULES.bunker_name_max) return { ok: false, why: "Der Bunkername braucht " + RULES.bunker_name_min + " bis " + RULES.bunker_name_max + " Zeichen." };
    if (isBad(bn)) return { ok: false, why: "Dieser Bunkername ist nicht erlaubt." };
    const low = bn.toLowerCase();
    const owner = read(nk, "names", low, SYSTEM);
    if (owner && (owner.uid !== c.uid || owner.city !== c.city)) return { ok: false, why: "Der Bunkername „" + bn + "“ ist schon vergeben." };
    if (c.bunker_name && c.bunker_name.toLowerCase() !== low) {
        const old = read(nk, "names", c.bunker_name.toLowerCase(), SYSTEM);
        if (old && old.uid === c.uid && old.city === c.city) del(nk, "names", c.bunker_name.toLowerCase(), SYSTEM);
    }
    write(nk, "names", low, SYSTEM, { uid: c.uid, city: c.city, name: bn });
    c.bunker_name = bn;
    return { ok: true, why: "" };
}

function rpcHello(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const m = meta(nk, uid);
    if (!m.hello) {                       // neues Konto: Startguthaben
        m.hello = true;
        write(nk, "acct", "meta", uid, m);
        nk.walletUpdate(uid, { gems: RULES.start_gems }, { reason: "Start" }, true);
    }
    const name = String(p.name || c.name).substr(0, 24);
    c.name = isBad(name) ? "Kommandant" : name;
    c.level = parseInt(String(p.level || c.level), 10) || 1;
    c.bunker = parseInt(String(p.bunker || c.bunker), 10) || 1;
    if (!c.code) {
        const want = String(p.code || "").toUpperCase();
        c.code = (want.length === 8 && !read(nk, "codes", want, SYSTEM)) ? want : newCode(nk);
        write(nk, "codes", c.code, SYSTEM, { uid: uid, city: c.city });
    }
    const t = now(nk);
    const out: any = { now: t, week: weekIndex(t), day: dayIndex(t), code: c.code, user_id: uid, gems: gems(nk, uid), league: c.league };
    const bn = String(p.bunker_name || "").replace(/^\s+|\s+$/g, "");
    out.bunker = bn ? claimName(nk, c, bn) : { ok: c.bunker_name !== "", why: "" };
    out.bunker_name = c.bunker_name;
    saveCity(nk, c);
    return JSON.stringify(out);
}

function rpcRename(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const r = claimName(nk, c, String(p.bunker_name || "").replace(/^\s+|\s+$/g, ""));
    saveCity(nk, c);
    return JSON.stringify(r);
}

function summary(d: any): any {
    let b = 1;
    const bl = d.buildings || [];
    for (let i = 0; i < bl.length; i++) if (bl[i].key === "bunker") b = bl[i].level;
    return { level: d.level || 1, bunker: b, bunker_name: d.bunker_name || "", server_time: d.server_time || 0, rev: d.rev || 0 };
}

function rpcSavePut(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    if (payload.length > RULES.save_max_bytes) return err("Spielstand zu groß");
    const p = parse(payload);
    const uid = ctx.userId as string;
    const city = cityNo(p);
    const data = p.data;
    if (!data || typeof data !== "object") return err("Spielstand fehlt");
    const cur = read(nk, "save", String(city), uid);
    const base = parseInt(String(p.base || 0), 10);
    if (cur && cur.rev !== base && !p.force) {
        return JSON.stringify({ ok: false, conflict: true, rev: cur.rev, saved_at: cur.saved_at, summary: summary(cur.data) });
    }
    const rev = (cur ? cur.rev : 0) + 1;
    data.rev = rev;
    if (!data.server_time) data.server_time = now(nk);
    write(nk, "save", String(city), uid, { rev: rev, saved_at: now(nk), data: data });
    const c = loadCity(nk, uid, city, true) as City;
    c.level = data.level || c.level;
    saveCity(nk, c);
    return JSON.stringify({ ok: true, rev: rev, server_time: now(nk) });
}

function rpcSaveGet(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const cur = read(nk, "save", String(cityNo(p)), ctx.userId as string);
    if (!cur) return JSON.stringify({ rev: 0 });
    return JSON.stringify({ rev: cur.rev, saved_at: cur.saved_at, data: cur.data });
}

function rpcSaveList(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const out: any[] = [];
    const list = nk.storageList(ctx.userId as string, "save", 10);
    const objs = list.objects || [];
    for (let i = 0; i < objs.length; i++) {
        const s = summary(objs[i].value.data);
        s.city = parseInt(objs[i].key, 10);
        s.saved_at = objs[i].value.saved_at;
        out.push(s);
    }
    out.sort(function (a, b) { return a.city - b.city; });
    return JSON.stringify({ cities: out });
}

function rpcFind(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const me = uid + ":" + cityNo(p);
    const q = String(p.query || "").replace(/^\s+|\s+$/g, "").toLowerCase();
    const out: any[] = [];
    if (q.length < 2) return JSON.stringify({ results: out });
    const blocked: string[] = meta(nk, uid).blocked || [];
    const exact = byCode(nk, q.toUpperCase());
    if (exact) out.push(pub(exact, me));
    // Bunkernamen durchsuchen (bis 2000 Einträge; für sehr viele Spieler einen Speicher-Index anlegen, siehe README)
    let cursor: string | undefined = undefined;
    for (let page = 0; page < 20 && out.length < 12; page++) {
        const l = nk.storageList(SYSTEM, "names", 100, cursor);
        const objs = l.objects || [];
        for (let i = 0; i < objs.length && out.length < 12; i++) {
            if (objs[i].key.indexOf(q) < 0) continue;
            const o = loadCity(nk, objs[i].value.uid, objs[i].value.city, false);
            if (!o || o.hidden || blocked.indexOf(o.code) >= 0 || (exact && o.code === exact.code)) continue;
            out.push(pub(o, me));
        }
        if (!l.cursor) break;
        cursor = l.cursor;
    }
    return JSON.stringify({ results: out });
}

function rpcSuggest(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const blocked: string[] = meta(nk, uid).blocked || [];
    const cands: City[] = [];
    const l = nk.storageList(null as any, "city", 100);
    const objs = l.objects || [];
    for (let i = 0; i < objs.length; i++) {
        const o = objs[i].value as City;
        if (o.uid === uid || !o.code || c.friends[o.code] !== undefined || blocked.indexOf(o.code) >= 0 || o.hidden) continue;
        if (Date.now() / 1000 - o.last_seen > 7 * 86400) continue;
        cands.push(o);
    }
    cands.sort(function (a, b) { return Math.abs(a.level - c.level) - Math.abs(b.level - c.level); });
    const out: any[] = [];
    for (let i = 0; i < cands.length && i < 5; i++) out.push(pub(cands[i]));
    return JSON.stringify({ results: out });
}

function friendEntry(o: City, since: number): any {
    const e = pub(o);
    e.since = since;
    e.score = o.points.week === weekIndex(Date.now() / 1000) ? o.points.flood : 0;
    return e;
}

function rpcFriends(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const out: any[] = [];
    for (const code in c.friends) {
        const o = byCode(nk, code);
        if (o) out.push(friendEntry(o, c.friends[code]));
        else delete c.friends[code];
    }
    saveCity(nk, c);
    return JSON.stringify({ friends: out, sends_left: limitLeft(c, "send", "d", RULES.send_per_day), helps_left: limitLeft(c, "help", "d", RULES.help_per_day),
                            giftbox_left: limitLeft(c, "giftbox", "w", RULES.giftbox_per_week), item_left: limitLeft(c, "item", "d", RULES.item_per_day) });
}

function rpcFriendAdd(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const code = String(p.code || "").toUpperCase();
    if (code.length !== 8) return err("Ein Freundescode hat acht Zeichen.");
    if (code === c.code) return err("Das ist dein eigener Code.");
    if (Object.keys(c.friends).length >= RULES.friends_max) return err("Freundesliste ist voll.");
    if (c.friends[code] !== undefined) return err("Ihr seid schon befreundet.");
    const o = byCode(nk, code);
    if (!o) return err("Zu diesem Code gibt es keinen Bunker.");
    const om = meta(nk, o.uid);
    if (om.blocked && om.blocked.indexOf(c.code) >= 0) return err("Dieser Bunker nimmt keine Anfragen an.");
    if (Object.keys(o.friends).length >= RULES.friends_max) return err("Die Freundesliste des anderen ist voll.");
    if (!limit(c, "friend_add", "d", RULES.friend_adds_per_day)) { saveCity(nk, c); return err("Heute wurden schon genug Freunde hinzugefügt."); }
    const d = dayIndex(now(nk));
    c.friends[code] = d;
    o.friends[c.code] = d;
    saveCity(nk, c);
    saveCity(nk, o);
    addMail(nk, o, c.name, "ist jetzt mit dir befreundet", {}, "", {}, "friend", c.code);
    return JSON.stringify({ ok: true, why: "", friend: friendEntry(o, d) });
}

function rpcFriendRemove(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const code = String(p.code || "").toUpperCase();
    delete c.friends[code];
    saveCity(nk, c);
    const o = byCode(nk, code);
    if (o) { delete o.friends[c.code]; saveCity(nk, o); }
    return JSON.stringify({ ok: true });
}

function rpcSend(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const code = String(p.to || "").toUpperCase();
    const o = byCode(nk, code);
    if (!o || c.friends[code] === undefined) return err("Ihr seid nicht befreundet.");
    const kind = String(p.kind || "");
    let res: any = null;
    if (kind === "res") {
        const r = String(p.res || "");
        const amt = parseInt(String(p.amount || 0), 10);
        if (["wood", "stone", "metal", "fuel"].indexOf(r) < 0 || !(amt > 0) || amt > 100000) return err("Das lässt sich nicht verschicken.");
        if (!limit(c, "send", "d", RULES.send_per_day)) { saveCity(nk, c); return err("Heute sind alle fünf Sendungen verbraucht."); }
        res = {}; res[r] = amt;
        addMail(nk, o, c.name, "schickt dir " + amt, res, "", {}, "send", c.code);
        saveCity(nk, c);
        clanAddPoints(nk, c, 4);
        saveCity(nk, c);
        return JSON.stringify({ ok: true, why: "" });
    }
    if (kind === "giftbox") {
        if (!limit(c, "giftbox", "w", RULES.giftbox_per_week)) { saveCity(nk, c); return err("Diese Woche wurde schon eine Geschenkkiste verschickt."); }
        addMail(nk, o, c.name, "schickt dir eine Geschenkkiste", {}, "gift", {}, "gift", c.code);
    } else if (kind === "help") {
        if (!limit(c, "help", "d", RULES.help_per_day)) { saveCity(nk, c); return err("Heute hast du schon fünfmal geholfen."); }
        addMail(nk, o, c.name, "hat dir beim Bauen geholfen", { coins: 15 }, "", {}, "help", c.code);
    } else if (kind === "item") {
        if (dayIndex(now(nk)) - c.friends[code] < RULES.item_friend_days) return err("Erst nach 7 Tagen Freundschaft.");
        const item = p.item || {};
        if (parseInt(String(item.rarity === undefined ? 9 : item.rarity), 10) > 1) return err("Nur gewöhnliche und seltene Stücke lassen sich verschicken.");
        if (!limit(c, "item", "d", RULES.item_per_day)) { saveCity(nk, c); return err("Heute wurde schon ein Stück verschickt."); }
        addMail(nk, o, c.name, "schickt dir ein Ausrüstungsstück", {}, "", { slot: String(item.slot || ""), key: String(item.key || ""), rarity: item.rarity }, "item", c.code);
    } else {
        return err("?");
    }
    saveCity(nk, c);
    return JSON.stringify({ ok: true, why: "" });
}

function rpcMail(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const city = cityNo(p);
    const box = read(nk, "mail", String(city), uid) || { list: [], next: 1 };
    const t = now(nk);
    const keep: any[] = [];
    for (let i = 0; i < box.list.length; i++) if (box.list[i].expire > t) keep.push(box.list[i]);
    return JSON.stringify({ mail: keep });
}

function rpcMailClaim(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const city = cityNo(p);
    const ids: number[] = p.ids || [];
    const box = read(nk, "mail", String(city), uid) || { list: [], next: 1 };
    const out: any[] = [], keep: any[] = [];
    const t = now(nk);
    for (let i = 0; i < box.list.length; i++) {
        const m = box.list[i];
        if (ids.indexOf(m.id) >= 0 && m.expire > t) out.push(m); else keep.push(m);
    }
    box.list = keep;
    write(nk, "mail", String(city), uid, box);
    return JSON.stringify({ ok: true, claimed: out });
}

function rpcClanList(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const l = nk.storageList(SYSTEM, "clans", 100);
    const out: any[] = [];
    const objs = l.objects || [];
    for (let i = 0; i < objs.length; i++) {
        const cl = objs[i].value;
        if (cl.hidden) continue;
        out.push({ id: cl.id, name: cl.name, level: cl.level, members: Object.keys(cl.members).length, min_level: cl.min_level });
    }
    out.sort(function (a, b) { return b.level !== a.level ? b.level - a.level : b.members - a.members; });
    return JSON.stringify({ clans: out.slice(0, 30) });
}

function rpcClanCreate(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const name = String(p.name || "").replace(/^\s+|\s+$/g, "");
    if (c.level < RULES.clan_min_level) return err("Clans gibt es ab Spielerstufe " + RULES.clan_min_level + ".");
    if (name.length < RULES.clan_name_min || name.length > RULES.clan_name_max) return err("Der Name braucht 3 bis 16 Zeichen.");
    if (isBad(name)) return err("Dieser Clan-Name ist nicht erlaubt.");
    if (read(nk, "clannames", name.toLowerCase(), SYSTEM)) return err("Diesen Clan gibt es schon.");
    leaveClan(nk, c);
    const id = nk.uuidv4();
    const cl: any = { id: id, name: name, level: 1, color: Math.floor(Math.random() * 6), min_level: RULES.clan_min_level, members: {}, asks: [], shouts: [],
                      week: weekIndex(now(nk)), chest_week: -1 };
    cl.members[c.uid + ":" + c.city] = { role: "Anführer", points: 0, joined: now(nk) };
    saveClan(nk, cl);
    write(nk, "clannames", name.toLowerCase(), SYSTEM, { id: id });
    c.clan = id;
    saveCity(nk, c);
    return JSON.stringify({ ok: true, why: "", clan: clanView(nk, cl, c) });
}

function rpcClanJoin(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const cl = loadClan(nk, String(p.id || ""));
    if (!cl) return err("Diesen Clan gibt es nicht mehr.");
    if (c.level < RULES.clan_min_level) return err("Clans gibt es ab Spielerstufe " + RULES.clan_min_level + ".");
    if (c.level < cl.min_level) return err("Dieser Clan nimmt ab Stufe " + cl.min_level + " auf.");
    if (Object.keys(cl.members).length >= RULES.clan_max) return err("Der Clan ist voll (" + RULES.clan_max + " Mitglieder).");
    leaveClan(nk, c);
    const fresh = loadClan(nk, cl.id);
    fresh.members[c.uid + ":" + c.city] = { role: "Mitglied", points: 0, joined: now(nk) };
    shout(fresh, "Clan", c.name + " ist beigetreten", "");
    saveClan(nk, fresh);
    c.clan = fresh.id;
    saveCity(nk, c);
    return JSON.stringify({ ok: true, why: "", clan: clanView(nk, fresh, c) });
}

function rpcClanLeave(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    leaveClan(nk, c);
    saveCity(nk, c);
    return JSON.stringify({ ok: true });
}

function rpcClanGet(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const cl = myClan(nk, c);
    saveCity(nk, c);
    return JSON.stringify({ clan: cl ? clanView(nk, cl, c) : {} });
}

function rpcClanChat(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const cl = myClan(nk, c);
    if (!cl) return err("Du bist in keinem Clan.");
    const text = String(p.text || "").replace(/^\s+|\s+$/g, "").substr(0, RULES.chat_max_len);
    if (!text) return err("Leere Nachricht.");
    const hour = Math.floor(now(nk) / 3600);
    let rec = c.limits["chat"];
    if (!rec || rec[0] !== hour) rec = [hour, 0];
    if (rec[1] >= RULES.chat_per_hour) return err("Bitte etwas langsamer.");
    rec[1] += 1;
    c.limits["chat"] = rec;
    shout(cl, c.name, text, c.code);
    saveClan(nk, cl);
    saveCity(nk, c);
    return JSON.stringify({ ok: true, why: "", text: censor(text) });
}

function rpcClanRole(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const cl = myClan(nk, c);
    if (!cl) return err("Du bist in keinem Clan.");
    const me = c.uid + ":" + c.city;
    const my = cl.members[me].role;
    const o = byCode(nk, String(p.code || ""));
    const ok = o ? o.uid + ":" + o.city : "";
    if (!o || !cl.members[ok] || ok === me) return err("Dieses Mitglied gibt es nicht.");
    const act = String(p.action || "");
    const their = cl.members[ok];
    if (act === "kick") {
        if (my === "Anführer" || (my === "Stellvertreter" && their.role === "Mitglied")) {
            leaveClan(nk, o);
            saveCity(nk, o);
            return JSON.stringify({ ok: true, why: "" });
        }
        return err("Dazu fehlt dir das Recht.");
    }
    if (my !== "Anführer") return err("Nur der Anführer darf das.");
    if (act === "promote") their.role = "Stellvertreter";
    else if (act === "demote") their.role = "Mitglied";
    else if (act === "lead") { their.role = "Anführer"; cl.members[me].role = "Stellvertreter"; }
    else return err("?");
    saveClan(nk, cl);
    return JSON.stringify({ ok: true, why: "" });
}

function rpcClanRequest(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const cl = myClan(nk, c);
    if (!cl) return err("Du bist in keinem Clan.");
    const me = c.uid + ":" + c.city;
    const rest: any[] = [];
    for (let i = 0; i < cl.asks.length; i++) {
        const a = cl.asks[i];
        if (a.key === me && now(nk) - a.at < RULES.request_every_h * 3600 && a.filled < a.amount) return err("Du hast schon um etwas gebeten.");
        if (a.key !== me) rest.push(a);
    }
    const amount = Math.max(1, Math.min(parseInt(String(p.amount || 100), 10) || 100, 2000));
    rest.push({ id: nk.uuidv4().substr(0, 8), key: me, name: c.name, res: String(p.res || "wood"), amount: amount, filled: 0, at: now(nk) });
    cl.asks = rest;
    saveClan(nk, cl);
    return JSON.stringify({ ok: true, why: "" });
}

function rpcClanDonate(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const cl = myClan(nk, c);
    if (!cl) return err("Du bist in keinem Clan.");
    for (let i = 0; i < cl.asks.length; i++) {
        const a = cl.asks[i];
        if (a.id !== String(p.ask || "") || a.key === c.uid + ":" + c.city) continue;
        const amt = Math.max(0, Math.min(parseInt(String(p.amount || 0), 10) || 0, a.amount - a.filled));
        if (amt <= 0) return err("Diese Bitte ist schon erfüllt.");
        if (!limit(c, "donate", "d", RULES.donate_per_day)) { saveCity(nk, c); return err("Heute hast du schon genug gespendet."); }
        a.filled += amt;
        const parts = a.key.split(":");
        const o = loadCity(nk, parts[0], parseInt(parts[1], 10), false);
        const res: any = {}; res[a.res] = amt;
        if (o) addMail(nk, o, c.name, "spendet " + amt, res, "", {}, "donate", c.code);
        shout(cl, a.name, "Danke!", "");
        saveClan(nk, cl);
        saveCity(nk, c);
        clanAddPoints(nk, c, Math.floor(amt / 4) + 5);
        return JSON.stringify({ ok: true, why: "", amount: amt });
    }
    return err("Diese Bitte gibt es nicht mehr.");
}

function rpcScore(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const board = String(p.board || "");
    const n = Math.max(0, Math.min(parseInt(String(p.add || 0), 10) || 0, 100000));
    if ((board === "flood" || board === "explorer") && n > 0) {
        (c.points as any)[board] += n;
        nk.leaderboardRecordWrite(board + "_L" + c.league, cityUuid(nk, uid, c.city), c.name, n, 0, { uid: uid, city: c.city }, nkruntime.OverrideOperator.INCREMENTAL);
    }
    if (p.time !== undefined) {
        const area = String(parseInt(String(p.area || 0), 10));
        const t = Number(p.time);
        if (t > 0 && (c.times[area] === undefined || t < c.times[area])) {
            c.times[area] = t;
            nk.leaderboardRecordWrite("time_A" + area, cityUuid(nk, uid, c.city), c.name, Math.round(t * 1000), 0, { uid: uid, city: c.city }, nkruntime.OverrideOperator.BEST);
        }
    }
    saveCity(nk, c);
    if (parseInt(String(p.clan || 0), 10) > 0) clanAddPoints(nk, c, Math.min(parseInt(String(p.clan), 10), 1000));
    return JSON.stringify({ ok: true, points: c.points });
}

function rpcBoard(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const kind = String(p.board || "flood");
    const w = weekIndex(now(nk));
    const out: any[] = [];
    const meId = cityUuid(nk, uid, c.city);
    if (kind === "friends") {
        for (const code in c.friends) {
            const o = byCode(nk, code);
            if (o) out.push({ name: o.name, score: o.points.week === w ? o.points.flood : 0, me: false });
        }
        out.push({ name: c.name, score: c.points.flood, me: true });
    } else if (kind === "clans") {
        const l = nk.storageList(SYSTEM, "clans", 100);
        const objs = l.objects || [];
        for (let i = 0; i < objs.length; i++) {
            const cl = loadClan(nk, objs[i].value.id);
            if (cl) out.push({ name: cl.name, score: clanPoints(cl), me: cl.id === c.clan });
        }
    } else if (kind === "time") {
        const area = String(parseInt(String(p.area || 0), 10));
        const r = nk.leaderboardRecordsList("time_A" + area, [meId], 10);
        const recs = r.records || [];
        for (let i = 0; i < recs.length; i++) out.push({ name: recs[i].username, score: recs[i].score / 1000.0, me: recs[i].ownerId === meId });
        return JSON.stringify({ entries: out, league: c.league, week: w });
    } else if (kind === "flood" || kind === "explorer") {
        const r = nk.leaderboardRecordsList(kind + "_L" + c.league, [meId], RULES.league_size);
        const recs = r.records || [];
        let hasMe = false;
        for (let i = 0; i < recs.length; i++) {
            const me = recs[i].ownerId === meId;
            hasMe = hasMe || me;
            out.push({ name: recs[i].username, score: recs[i].score, me: me });
        }
        if (!hasMe) out.push({ name: c.name, score: (c.points as any)[kind] || 0, me: true });
    }
    out.sort(function (a, b) { return b.score - a.score; });
    saveCity(nk, c);
    return JSON.stringify({ entries: out.slice(0, RULES.league_size), league: c.league, week: w });
}

function rpcReport(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const code = String(p.code || "").toUpperCase();
    const clan = String(p.clan || "");
    write(nk, "reports", nk.uuidv4(), SYSTEM, { from: uid, city: cityNo(p), code: code, clan: clan, reason: String(p.reason || "").substr(0, 40),
                                               text: String(p.text || "").substr(0, 300), t: now(nk) });
    const key = code ? "c:" + code : "k:" + clan;
    const cnt = read(nk, "reportcount", key, SYSTEM) || { n: 0, from: [] };
    if (cnt.from.indexOf(uid) < 0) { cnt.n += 1; cnt.from.push(uid); }
    write(nk, "reportcount", key, SYSTEM, cnt);
    if (cnt.n >= RULES.reports_hide_after) {
        if (code) { const o = byCode(nk, code); if (o) { o.hidden = true; saveCity(nk, o); } }
        if (clan) { const cl = loadClan(nk, clan); if (cl) { cl.hidden = true; saveClan(nk, cl); } }
        logger.warn("Gemeldet und ausgeblendet: %s", key);
    }
    return JSON.stringify({ ok: true });
}

function rpcBlock(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const m = meta(nk, uid);
    m.blocked = m.blocked || [];
    const code = String(p.code || "").toUpperCase();
    if (p.unblock) {
        const i = m.blocked.indexOf(code);
        if (i >= 0) m.blocked.splice(i, 1);
    } else if (code && m.blocked.indexOf(code) < 0) {
        m.blocked.push(code);
        const c = loadCity(nk, uid, cityNo(p), true) as City;
        delete c.friends[code];
        saveCity(nk, c);
        const o = byCode(nk, code);
        if (o) { delete o.friends[c.code]; saveCity(nk, o); }
    }
    write(nk, "acct", "meta", uid, m);
    return JSON.stringify({ ok: true, blocked: m.blocked });
}

function rpcWallet(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    return JSON.stringify({ gems: gems(nk, ctx.userId as string) });
}

function rpcWalletInit(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const m = meta(nk, uid);
    if (m.wallet_init) return JSON.stringify({ ok: false, gems: gems(nk, uid) });
    m.wallet_init = true;
    write(nk, "acct", "meta", uid, m);
    const want = Math.max(0, Math.min(parseInt(String(p.gems || 0), 10) || 0, RULES.wallet_init_max));
    nk.walletUpdate(uid, { gems: want - gems(nk, uid) }, { reason: "Übernahme Gerät" }, true);
    return JSON.stringify({ ok: true, gems: want });
}

/** Belohnungen bestätigen: Juwelen und Kisten schreibt der Client erst nach dieser Antwort gut. */
function rpcReward(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const rr = RULES.reward;
    const acc: number[] = [], rej: number[] = [], seeds: any[] = [];
    let add = 0;
    const items: any[] = p.items || [];
    for (let i = 0; i < items.length; i++) {
        const it = items[i];
        const n = parseInt(String(it.n || 0), 10) || 0;
        const reason = String(it.reason || "");
        let ok = n > 0;
        if (it.kind === "gems") {
            ok = ok && n <= rr.gems_item_max && limit(c, "gems_day", "d", rr.gems_day_max, n);
            if (ok && rr.flood_reasons.indexOf(reason) >= 0) ok = limit(c, "flood_gems", "w", rr.flood_per_week);
            if (ok) add += n;
        } else if (it.kind === "chest") {
            ok = ok && n <= 5 && limit(c, "chests_day", "d", rr.chests_day_max, n);
            if (ok && rr.flood_chests.indexOf(reason) >= 0) ok = limit(c, "flood_chest", "w", rr.flood_per_week);
            if (ok) for (let k = 0; k < n; k++) seeds.push([reason, 1 + Math.floor(Math.random() * 2147483646)]);
        } else {
            ok = false;
        }
        (ok ? acc : rej).push(i);
    }
    if (add > 0) nk.walletUpdate(uid, { gems: add }, { reason: "Belohnung" }, true);
    saveCity(nk, c);
    return JSON.stringify({ accepted: acc, rejected: rej, gems: gems(nk, uid), seeds: seeds });
}

function rpcSpend(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const n = parseInt(String(p.n || 0), 10) || 0;
    const g = gems(nk, uid);
    if (n <= 0) return JSON.stringify({ ok: true, gems: g });
    if (g < n) return JSON.stringify({ ok: false, gems: g, why: "Zu wenig Juwelen auf dem Konto." });
    nk.walletUpdate(uid, { gems: -n }, { reason: "Ausgabe" }, true);
    return JSON.stringify({ ok: true, gems: g - n });
}

/** Kaufbeleg prüfen (Nakama-eigene Prüfung bei Apple/Google) und Juwelen gutschreiben.
 *  Schlüssel kommen aus Umgebungsvariablen (docker-compose.yml / .env), nie aus dem Spiel:
 *  APPLE_SHARED_SECRET, GOOGLE_CLIENT_EMAIL, GOOGLE_PRIVATE_KEY, ALLOW_TEST_PURCHASES ("1" nur zum Testen). */
function rpcPurchase(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const store = String(p.store || "");
    const product = String(p.product || "");
    const receipt = String(p.receipt || "");
    const prod = RULES.products[product];
    if (!prod) return err("Unbekanntes Produkt.");
    const m = meta(nk, uid);
    if (prod.once && m.starter) return err("Das Startangebot gibt es nur einmal.");
    let tid = String(p.transaction || "");
    let seen = false;
    try {
        if (store === "apple") {
            const r = nk.purchaseValidateApple(uid, receipt, true, ctx.env["APPLE_SHARED_SECRET"] || undefined);
            const vp = r.validatedPurchases || [];
            let found = false;
            for (let i = 0; i < vp.length; i++) {
                if (vp[i].productId === product && (!tid || vp[i].transactionId === tid)) { found = true; seen = vp[i].seenBefore; tid = vp[i].transactionId; }
            }
            if (!found) return err("Der Kaufbeleg ist ungültig.");
        } else if (store === "google") {
            const r = nk.purchaseValidateGoogle(uid, receipt, true, ctx.env["GOOGLE_CLIENT_EMAIL"] || undefined, (ctx.env["GOOGLE_PRIVATE_KEY"] || "").replace(/\\n/g, "\n") || undefined);
            const vp = r.validatedPurchases || [];
            if (vp.length === 0 || vp[0].productId !== product) return err("Der Kaufbeleg ist ungültig.");
            seen = vp[0].seenBefore;
            tid = vp[0].transactionId;
        } else if (store === "test") {
            if (ctx.env["ALLOW_TEST_PURCHASES"] !== "1" || receipt !== "TEST") return err("Testkäufe sind auf diesem Server aus.");
        } else {
            return err("Unbekannter Laden.");
        }
    } catch (e) {
        logger.error("Kaufprüfung fehlgeschlagen: %s", String(e));
        return err("Der Kaufbeleg konnte nicht geprüft werden. Bitte später erneut versuchen.");
    }
    const key = store + ":" + tid;
    if (seen || read(nk, "purchases", key, SYSTEM)) return JSON.stringify({ ok: true, duplicate: true, gems_added: 0, gems: gems(nk, uid) });
    write(nk, "purchases", key, SYSTEM, { uid: uid, product: product, t: now(nk), gems: prod.gems });
    if (prod.once) { m.starter = true; write(nk, "acct", "meta", uid, m); }
    nk.walletUpdate(uid, { gems: prod.gems }, { reason: "Kauf " + product, transaction: key }, true);
    return JSON.stringify({ ok: true, duplicate: false, gems_added: prod.gems, gems: gems(nk, uid) });
}

function rpcRestore(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const uid = ctx.userId as string;
    const out: any[] = [];
    const list = nk.purchasesList(uid, 100);
    const vp = list.validatedPurchases || [];
    for (let i = 0; i < vp.length; i++) out.push({ product: vp[i].productId, t: vp[i].purchaseTime });
    return JSON.stringify({ purchases: out, starter: !!meta(nk, uid).starter });
}

function rpcTelemetry(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const ev: any[] = (p.events || []).slice(0, RULES.telemetry_max_batch);
    // ohne Konto-Bezug: täglich wechselnde, nicht umkehrbare Kennung
    const anon = nk.sha256Hash((ctx.userId as string) + ":" + dayIndex(now(nk)) + ":" + (ctx.env["TELEMETRY_SALT"] || "rustwall")).substr(0, 12);
    const clean: any[] = [];
    for (let i = 0; i < ev.length; i++) clean.push({ e: String(ev[i].e || "").substr(0, 40), p: ev[i].p || {}, t: ev[i].t || now(nk) });
    write(nk, "telemetry", nk.uuidv4(), SYSTEM, { a: anon, day: dayIndex(now(nk)), events: clean });
    return JSON.stringify({ ok: true, n: clean.length });
}

function rpcCrash(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    write(nk, "crashes", nk.uuidv4(), SYSTEM, { t: now(nk), event: p.event || {} });
    logger.warn("Fehlerbericht: %s", JSON.stringify(p.event || {}).substr(0, 500));
    return JSON.stringify({ ok: true });
}

/** Konto löschen (Apple-Pflicht): Städte, Spielstände, Post, Clan, Ranglisten, Namen, Codes, Konto. */
function rpcAccountDelete(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const uid = ctx.userId as string;
    for (let city = 1; city <= 5; city++) {
        const c = loadCity(nk, uid, city, false);
        if (!c) continue;
        leaveClan(nk, c);
        if (c.code) {
            del(nk, "codes", c.code, SYSTEM);
            for (const code in c.friends) {
                const o = byCode(nk, code);
                if (o) { delete o.friends[c.code]; saveCity(nk, o); }
            }
        }
        if (c.bunker_name) del(nk, "names", c.bunker_name.toLowerCase(), SYSTEM);
        const cu = cityUuid(nk, uid, city);
        for (let l = 0; l < LEAGUES_N; l++) {
            try { nk.leaderboardRecordDelete("flood_L" + l, cu); } catch (e) { /* kein Eintrag */ }
            try { nk.leaderboardRecordDelete("explorer_L" + l, cu); } catch (e) { /* kein Eintrag */ }
        }
        for (let a = 0; a < 10; a++) { try { nk.leaderboardRecordDelete("time_A" + a, cu); } catch (e) { /* kein Eintrag */ } }
    }
    nk.accountDeleteId(uid, false);              // löscht Konto und alle eigenen Speicher-Objekte
    logger.info("Konto gelöscht: %s", uid);
    return JSON.stringify({ ok: true });
}

// ================================================================= Live-Betrieb (Paket L): Ereignis-Zeitplan, Saison-Pass, Rangliste, Weltboss
// Gleiche Regeln wie im Testserver (mock_server.py, rpc_liveops ...). Zahlen in regeln.json unter "liveops".
function live(): any { return RULES.liveops || {}; }

function loEvent(w: number): string {
    const ov = (live().events_override || {})[String(w)];
    const ev: string[] = live().events || ["schleimregen"];
    const i = ((w - (live().epoch_week || 0)) % ev.length + ev.length) % ev.length;
    return ov || ev[i];
}

function loSeason(w: number): number {
    return Math.max(1, Math.floor((w - (live().epoch_week || 0)) / (live().season_weeks || 8)) + 1);
}

function loBossDmg(nk: nkruntime.Nakama, w: number): number {
    const rec = read(nk, "liveops", "boss_" + w, SYSTEM) || { dmg: 0 };
    const frac = Math.min(1, Math.max(0, (now(nk) - (w * 7 - 3) * 86400) / (7 * 86400)));
    return Number(rec.dmg || 0) + Math.floor((live().boss_hp || 1) * (live().boss_sim_pace || 0) * Math.pow(frac, 0.9));
}

function rpcLiveops(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const w = weekIndex(now(nk));
    const out: any = { week: w, event: loEvent(w), event_end: ((w + 1) * 7 - 3) * 86400, season: loSeason(w), news: live().news || [] };
    if (out.event === "weltboss") { out.boss_hp = live().boss_hp || 1; out.boss_dmg = loBossDmg(nk, w); }
    return JSON.stringify(out);
}

function seasonBoard(nk: nkruntime.Nakama, n: number): string {
    const id = "season_S" + n;
    try { nk.leaderboardCreate(id, true, nkruntime.SortOrder.DESCENDING, nkruntime.Operator.INCREMENTAL, null, { season: n }, true); } catch (e) { /* gibt es schon */ }
    return id;
}

function rpcSeasonAdd(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const n = loSeason(weekIndex(now(nk)));
    if (parseInt(String(p.season || n), 10) !== n) return err("Andere Saison");
    const add = Math.max(0, Math.min(parseInt(String(p.add || 0), 10) || 0, live().season_add_max || 5000));
    const cs: any = c as any;
    if (!cs.season || cs.season.n !== n) cs.season = { n: n, pts: 0 };
    cs.season.pts += add;
    saveCity(nk, c);
    nk.leaderboardRecordWrite(seasonBoard(nk, n), cityUuid(nk, uid, c.city), c.name, add, 0, { uid: uid, city: c.city }, nkruntime.OverrideOperator.INCREMENTAL);
    return JSON.stringify({ ok: true, pts: cs.season.pts });
}

function rpcSeasonBoard(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const n = loSeason(weekIndex(now(nk)));
    const id = seasonBoard(nk, n);
    const me = cityUuid(nk, uid, c.city);
    const r = nk.leaderboardRecordsList(id, [me], 50, undefined, 0);
    const out: any[] = [];
    let rank = 0;
    const recs = r.records || [];
    for (let i = 0; i < recs.length; i++) {
        const isMe = recs[i].ownerId === me;
        if (isMe) rank = i + 1;
        out.push({ name: recs[i].username || "?", score: recs[i].score, me: isMe });
    }
    if (rank === 0 && r.ownerRecords && r.ownerRecords.length > 0) {
        rank = Number(r.ownerRecords[0].rank);
        out.push({ name: c.name, score: r.ownerRecords[0].score, me: true });
    }
    return JSON.stringify({ entries: out, rank: rank, season: n });
}

function rpcBossHit(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const w = weekIndex(now(nk));
    if (loEvent(w) !== "weltboss") return err("Kein Weltboss in dieser Woche");
    const dmg = Math.max(0, Math.min(parseInt(String(p.dmg || 0), 10) || 0, live().boss_hit_max || 0));
    if (dmg > 0 && limit(c, "boss_hits", "d", live().boss_hits_per_day || 3)) {
        const rec = read(nk, "liveops", "boss_" + w, SYSTEM) || { dmg: 0 };
        rec.dmg = Number(rec.dmg || 0) + dmg;
        write(nk, "liveops", "boss_" + w, SYSTEM, rec);
        saveCity(nk, c);
    }
    return JSON.stringify({ ok: true, boss_dmg: loBossDmg(nk, w), boss_hp: live().boss_hp || 1 });
}

// ================================================================= Spielmodi (V6 Paket M): Wochen-Ranglisten, Clan-Raid
// Gleiche Regeln wie im Testserver (mock_server.py, rpc_modi_score ...). Zahlen in regeln.json unter "modi".
function modi(): any { return RULES.modi || {}; }

function modiBoard(nk: nkruntime.Nakama, kind: string): string {
    const id = "modi_" + kind;
    try { nk.leaderboardCreate(id, true, nkruntime.SortOrder.DESCENDING, nkruntime.Operator.BEST, "0 0 * * 1", { modi: kind }, true); } catch (e) { /* gibt es schon */ }
    return id;
}

function rpcModiScore(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const kind = String(p.board || "");
    if (kind !== "tower" && kind !== "surv") return err("Unbekannte Rangliste");
    const mx = Number((modi().score_max || {})[kind] || 0);
    const score = Math.max(0, Math.min(parseInt(String(p.score || 0), 10) || 0, mx));
    nk.leaderboardRecordWrite(modiBoard(nk, kind), cityUuid(nk, uid, c.city), c.name, score, 0, { uid: uid, city: c.city }, nkruntime.OverrideOperator.BEST);
    return JSON.stringify({ ok: true, best: score });
}

function rpcModiBoard(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const uid = ctx.userId as string;
    const c = loadCity(nk, uid, cityNo(p), true) as City;
    const kind = String(p.board || "");
    if (kind !== "tower" && kind !== "surv") return err("Unbekannte Rangliste");
    const me = cityUuid(nk, uid, c.city);
    const r = nk.leaderboardRecordsList(modiBoard(nk, kind), [me], modi().board_size || 50, undefined, 0);
    const out: any[] = [];
    let rank = 0;
    const recs = r.records || [];
    for (let i = 0; i < recs.length; i++) {
        const isMe = recs[i].ownerId === me;
        if (isMe) rank = i + 1;
        out.push({ name: recs[i].username || "?", score: recs[i].score, me: isMe });
    }
    if (rank === 0) {
        if (r.ownerRecords && r.ownerRecords.length > 0) {
            rank = Number(r.ownerRecords[0].rank);
            out.push({ name: c.name, score: r.ownerRecords[0].score, me: true });
        } else {
            out.push({ name: c.name, score: 0, me: true });
            rank = out.length;
        }
    }
    return JSON.stringify({ entries: out, rank: rank, week: weekIndex(now(nk)) });
}

function raidView(nk: nkruntime.Nakama, cl: any, c: City): any {
    const w = weekIndex(now(nk));
    if (!cl.raid || cl.raid.week !== w) cl.raid = { week: w, dmg: {} };
    const me = c.uid + ":" + c.city;
    const members: any[] = [];
    let total = 0;
    for (const k in cl.members) {
        const parts = k.split(":");
        const o = loadCity(nk, parts[0], parseInt(parts[1], 10), false);
        if (!o) continue;
        const d = Number(cl.raid.dmg[k] || 0);
        total += d;
        members.push({ name: o.name, level: o.level, dmg: d, me: k === me });
    }
    members.sort(function (a, b) { return b.dmg - a.dmg; });
    const hp = Math.max(1, Object.keys(cl.members).length) * Number(modi().raid_hp_per_member || 1);
    return { ok: true, week: w, hp: hp, dmg: total, members: members };
}

function rpcRaidHit(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const cl = myClan(nk, c);
    if (!cl) return err("Du bist in keinem Clan.");
    raidView(nk, cl, c);
    const dmg = Math.max(0, Math.min(parseInt(String(p.dmg || 0), 10) || 0, Number(modi().raid_hit_max || 0)));
    if (dmg > 0 && limit(c, "raid_hits", "d", Number(modi().raid_hits_per_day || 3))) {
        const me = c.uid + ":" + c.city;
        cl.raid.dmg[me] = Number(cl.raid.dmg[me] || 0) + dmg;
        saveClan(nk, cl);
        saveCity(nk, c);
    }
    return JSON.stringify(raidView(nk, cl, c));
}

function rpcRaidGet(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, payload: string): string {
    const p = parse(payload);
    const c = loadCity(nk, ctx.userId as string, cityNo(p), true) as City;
    const cl = myClan(nk, c);
    if (!cl) return err("Du bist in keinem Clan.");
    return JSON.stringify(raidView(nk, cl, c));
}

// ================================================================= Wochen-Reset der Ranglisten
function onReset(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, lb: nkruntime.Leaderboard, reset: number): void {
    const parts = lb.id.split("_L");
    if (parts.length !== 2) return;
    const kind = parts[0];
    const league = parseInt(parts[1], 10);
    let cursor: string | undefined = undefined;
    let rank = 0;
    for (let page = 0; page < 50; page++) {
        const r = nk.leaderboardRecordsList(lb.id, [], 100, cursor, reset);
        const recs = r.records || [];
        for (let i = 0; i < recs.length; i++) {
            rank += 1;
            const md = recs[i].metadata || {};
            const c = loadCity(nk, String(md.uid), parseInt(String(md.city), 10), false);
            if (!c) continue;
            if (kind === "flood") {
                const shards = Math.max(1, 6 - Math.floor(rank / 10)) + league;
                let text = "Flut-Rangliste: Platz " + rank + " in Liga " + RULES.leagues[league] + ".";
                if (rank <= RULES.promote_top && league < LEAGUES_N - 1 && recs[i].score > 0) { c.league = league + 1; text += " Aufstieg!"; }
                else if (rank > RULES.demote_below && league > 0) { c.league = league - 1; text += " Abstieg."; }
                addMail(nk, c, "Rangliste", text, { shards: shards }, "", {}, "board", "");
                saveCity(nk, c);
            } else if (kind === "explorer" && rank <= 25) {
                addMail(nk, c, "Rangliste", "Entdecker-Rangliste: Platz " + rank + ".", {}, "find", {}, "board", "");
            }
        }
        if (!r.nextCursor) break;
        cursor = r.nextCursor;
    }
    logger.info("Wochen-Reset %s: %d Einträge abgerechnet", lb.id, rank);
}

// ================================================================= Start
function parseFilter(text: string): string[] {
    const out: string[] = [];
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
        const l = lines[i].replace(/^\s+|\s+$/g, "").toLowerCase();
        if (l && l.charAt(0) !== "#") out.push(l);
    }
    return out;
}

function InitModule(ctx: nkruntime.Context, logger: nkruntime.Logger, nk: nkruntime.Nakama, initializer: nkruntime.Initializer): void {
    RULES = JSON.parse(nk.fileRead("regeln.json"));
    FILTER = parseFilter(nk.fileRead("wortfilter.txt"));
    for (let l = 0; l < LEAGUES_N; l++) {
        for (const kind of ["flood", "explorer"]) {
            try {
                nk.leaderboardCreate(kind + "_L" + l, true, nkruntime.SortOrder.DESCENDING, nkruntime.Operator.INCREMENTAL, "0 0 * * 1", { league: l }, true);
            } catch (e) { /* gibt es schon */ }
        }
    }
    for (let a = 0; a < 10; a++) {
        try { nk.leaderboardCreate("time_A" + a, true, nkruntime.SortOrder.ASCENDING, nkruntime.Operator.BEST, null, { area: a }, true); } catch (e) { /* gibt es schon */ }
    }
    const rpcs: { [name: string]: Rpc } = {
        rw_time: rpcTime, rw_hello: rpcHello, rw_rename: rpcRename, rw_save_put: rpcSavePut, rw_save_get: rpcSaveGet, rw_save_list: rpcSaveList,
        rw_find: rpcFind, rw_suggest: rpcSuggest, rw_friends: rpcFriends, rw_friend_add: rpcFriendAdd, rw_friend_remove: rpcFriendRemove, rw_send: rpcSend,
        rw_mail: rpcMail, rw_mail_claim: rpcMailClaim, rw_clan_list: rpcClanList, rw_clan_create: rpcClanCreate, rw_clan_join: rpcClanJoin,
        rw_clan_leave: rpcClanLeave, rw_clan_get: rpcClanGet, rw_clan_chat: rpcClanChat, rw_clan_role: rpcClanRole, rw_clan_request: rpcClanRequest,
        rw_clan_donate: rpcClanDonate, rw_score: rpcScore, rw_board: rpcBoard, rw_report: rpcReport, rw_block: rpcBlock, rw_wallet: rpcWallet,
        rw_wallet_init: rpcWalletInit, rw_reward: rpcReward, rw_spend: rpcSpend, rw_purchase: rpcPurchase, rw_restore: rpcRestore,
        rw_telemetry: rpcTelemetry, rw_crash: rpcCrash, rw_account_delete: rpcAccountDelete,
        rw_liveops: rpcLiveops, rw_season_add: rpcSeasonAdd, rw_season_board: rpcSeasonBoard, rw_boss_hit: rpcBossHit,     // Paket L
        rw_modi_score: rpcModiScore, rw_modi_board: rpcModiBoard, rw_raid_hit: rpcRaidHit, rw_raid_get: rpcRaidGet,     // V6 Paket M
    };
    for (const name in rpcs) initializer.registerRpc(name, rpcs[name]);
    initializer.registerLeaderboardReset(onReset);
    logger.info("Rustwall-Modul geladen: %d Serverfunktionen", Object.keys(rpcs).length);
}

// Nakama sucht die Funktion InitModule im globalen Bereich.
!InitModule && InitModule.bind(null);
