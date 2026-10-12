// Rustwall – Selbsttest des Nakama-Moduls OHNE Nakama: führt build/index.js mit einer nachgebauten
// Nakama-Laufzeit (Speicher, Wallet, Ranglisten) aus und spielt dieselben Abläufe wie src/tests_online.gd durch.
// Aufruf:  node server/modules/test/selbsttest.js        (erwartet am Ende "SERVER-SELBSTTEST OK")
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const crypto = require("crypto");

const DIR = path.join(__dirname, "..");
let clock = 0;                                   // verschobene Zeit (Sekunden)
const realNow = Date.now;
const sandbox = { console, Math, JSON, Date: class extends Date { static now() { return realNow() + clock * 1000; } } };
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(DIR, "build", "index.js"), "utf8"), sandbox);

// ----------------------------------------------------------------- nachgebaute Nakama-Laufzeit
const store = {};                                // "coll|key|uid" -> {value, ...}
const wallets = {};
const boards = {};                               // id -> {opts, recs: {owner: rec}}
const purchases = [];
const users = {};
const sk = (c, k, u) => c + "|" + k + "|" + u;
const nk = {
  fileRead: (p) => fs.readFileSync(path.join(DIR, p), "utf8"),
  sha256Hash: (s) => crypto.createHash("sha256").update(s).digest("hex"),
  uuidv4: () => crypto.randomUUID(),
  storageRead: (keys) => keys.map(k => store[sk(k.collection, k.key, k.userId)]).filter(Boolean).map(o => JSON.parse(JSON.stringify(o))),
  storageWrite: (objs) => objs.map(o => { store[sk(o.collection, o.key, o.userId)] = { collection: o.collection, key: o.key, userId: o.userId, value: JSON.parse(JSON.stringify(o.value)) }; return {}; }),
  storageDelete: (keys) => keys.forEach(k => { delete store[sk(k.collection, k.key, k.userId)]; }),
  storageList: (uid, coll, limit, cursor) => {
    const all = Object.values(store).filter(o => o.collection === coll && (uid === null || uid === undefined || uid === "" || o.userId === uid));
    const start = cursor ? parseInt(cursor, 10) : 0;
    const objs = all.slice(start, start + limit).map(o => JSON.parse(JSON.stringify(o)));
    return { objects: objs, cursor: start + limit < all.length ? String(start + limit) : "" };
  },
  accountGetId: (uid) => ({ wallet: wallets[uid] || {} }),
  walletUpdate: (uid, ch) => { const w = wallets[uid] = wallets[uid] || {}; for (const k in ch) w[k] = (w[k] || 0) + ch[k]; if (w.gems < 0) throw new Error("negativ"); return {}; },
  leaderboardCreate: (id, auth, order, op, reset, md) => { if (boards[id]) throw new Error("gibt es"); boards[id] = { order, op, reset, recs: {} }; },
  leaderboardRecordWrite: (id, owner, name, score, sub, md, op) => {
    const b = boards[id]; const r = b.recs[owner];
    if (!r) b.recs[owner] = { leaderboardId: id, ownerId: owner, username: name, score, metadata: md };
    else if (op === "increment") r.score += score;
    else if (op === "best") r.score = b.order === "ascending" ? Math.min(r.score, score) : Math.max(r.score, score);
    else r.score = score;
  },
  leaderboardRecordsList: (id, owners, limit) => {
    const b = boards[id]; const recs = Object.values(b.recs).sort((a, c) => b.order === "ascending" ? a.score - c.score : c.score - a.score);
    return { records: recs.slice(0, limit).map(r => Object.assign({}, r)), nextCursor: "" };
  },
  leaderboardRecordDelete: (id, owner) => { delete boards[id].recs[owner]; },
  purchaseValidateApple: (uid, receipt) => {
    if (receipt.indexOf("APPLE-OK") < 0) throw new Error("ungültig");
    const tid = receipt.split(":")[1]; const seen = purchases.indexOf(tid) >= 0; purchases.push(tid);
    return { validatedPurchases: [{ productId: receipt.split(":")[2], transactionId: tid, seenBefore: seen }] };
  },
  purchaseValidateGoogle: () => { throw new Error("nicht nachgebaut"); },
  purchasesList: () => ({ validatedPurchases: purchases.map(t => ({ productId: "x", purchaseTime: 0 })) }),
  accountDeleteId: (uid) => { delete users[uid]; delete wallets[uid]; for (const k of Object.keys(store)) if (store[k].userId === uid) delete store[k]; },
};
const logger = { info() {}, warn() {}, error(...a) { console.log("LOG-FEHLER", ...a); }, debug() {} };
const rpcs = {};
let resetFn = null;
const init = { registerRpc: (n, f) => { rpcs[n] = f; }, registerLeaderboardReset: (f) => { resetFn = f; } };
sandbox.InitModule({ env: {} }, logger, nk, init);

let fails = 0;
function check(c, what) { if (!c) { fails++; console.log("FAIL:", what); } }
function call(uid, name, p) { return JSON.parse(rpcs[name]({ userId: uid, env: { ALLOW_TEST_PURCHASES: "1" } }, logger, nk, JSON.stringify(Object.assign({ city: 1 }, p)))); }
function weekReset() {
  for (const id of Object.keys(boards)) if (boards[id].reset) { resetFn({ env: {} }, logger, nk, { id }, 0); boards[id].recs = {}; }
}

// ----------------------------------------------------------------- Abläufe
const A = "11111111-1111-4111-8111-111111111111", B = "22222222-2222-4222-8222-222222222222";
check(Object.keys(rpcs).length === 40, "40 Serverfunktionen registriert (" + Object.keys(rpcs).length + ")");
const ha = call(A, "rw_hello", { bunker_name: "Rostburg", name: "Anna", level: 10, code: "ANNA2345" });
check(ha.code === "ANNA2345" && ha.bunker.ok && ha.gems === 100, "Anmeldung, Code, Startjuwelen");
let hb = call(B, "rw_hello", { bunker_name: "Rostburg", name: "Ben", level: 9 });
check(!hb.bunker.ok, "Bunkername eindeutig");
check(!call(B, "rw_rename", { bunker_name: "Arschburg" }).ok, "Wortfilter für Namen");
hb = call(B, "rw_hello", { bunker_name: "Benfeste", name: "Ben", level: 9 });
check(hb.bunker.ok && hb.code.length === 8, "zweiter Spieler");
check(call(A, "rw_find", { query: "benf" }).results.length === 1, "Suche nach Bunkername");
check(call(A, "rw_find", { query: hb.code }).results[0].code === hb.code, "Suche nach Code");
check(call(A, "rw_friend_add", { code: hb.code }).ok, "Freund hinzufügen");
check(call(A, "rw_friends", {}).friends.length === 1 && call(B, "rw_friends", {}).friends.length === 1, "Freundschaft beidseitig");
for (let i = 0; i < 5; i++) check(call(A, "rw_send", { to: hb.code, kind: "res", res: "wood", amount: 50 }).ok, "Senden " + i);
check(!call(A, "rw_send", { to: hb.code, kind: "res", res: "wood", amount: 50 }).ok, "Tageslimit Senden");
const mb = call(B, "rw_mail", {}).mail;
check(mb.length === 6, "Post: Freundschaft + 5 Sendungen");
check(call(B, "rw_mail_claim", { ids: mb.map(m => m.id) }).claimed.length === 6 && call(B, "rw_mail", {}).mail.length === 0, "Post abholen");
// Speichern
check(call(A, "rw_save_put", { base: 0, data: { level: 10, server_time: 5 } }).rev === 1, "Speichern rev 1");
const cf = call(A, "rw_save_put", { base: 0, data: { level: 12 } });
check(cf.conflict && cf.summary.level === 10, "Konflikt erkannt");
check(call(A, "rw_save_put", { base: 0, data: { level: 12 }, force: true }).rev === 2, "erzwungen");
check(call(A, "rw_save_get", {}).data.level === 12 && call(A, "rw_save_list", {}).cities.length === 1, "Laden und Liste");
// Clan
const cc = call(A, "rw_clan_create", { name: "Talwacht" });
check(cc.ok && cc.clan.my_role === "Anführer", "Clan gründen");
check(!call(B, "rw_clan_create", { name: "Talwacht" }).ok, "Clan-Name eindeutig");
check(call(B, "rw_clan_join", { id: call(B, "rw_clan_list", {}).clans[0].id }).ok, "Clan beitreten");
check(call(B, "rw_clan_chat", { text: "du Arschloch" }).text.indexOf("*") >= 0, "Chat-Filter");
check(call(B, "rw_clan_request", { res: "stone", amount: 40 }).ok, "Spendenbitte");
const asks = call(A, "rw_clan_get", {}).clan.asks;
check(asks.length === 1 && call(A, "rw_clan_donate", { ask: asks[0].id, amount: 40 }).ok, "Spenden");
check(call(B, "rw_mail", {}).mail.some(m => m.res.stone === 40), "Spende kommt an");
check(call(A, "rw_clan_role", { code: hb.code, action: "promote" }).ok && call(B, "rw_clan_get", {}).clan.my_role === "Stellvertreter", "Rollen");
// Ranglisten und Wochen-Reset
call(A, "rw_score", { board: "flood", add: 500, clan: 40 });
const bd = call(A, "rw_board", { board: "flood" });
check(bd.entries[0].me && bd.entries[0].score === 500, "Flut-Rangliste");
check(call(A, "rw_board", { board: "friends" }).entries.length === 2 && call(A, "rw_board", { board: "clans" }).entries.length === 1, "Freunde- und Clan-Rangliste");
weekReset();
check(call(A, "rw_mail", {}).mail.some(m => m.text.indexOf("Aufstieg") >= 0) && call(A, "rw_hello", {}).league === 1, "Wochen-Reset mit Aufstieg");
// Belohnungen und Juwelen
const rw = call(A, "rw_reward", { items: [{ kind: "gems", n: 20, reason: "Flut gewonnen" }, { kind: "gems", n: 20, reason: "Flut gewonnen" }, { kind: "gems", n: 9999, reason: "x" }, { kind: "chest", n: 1, reason: "flood_gold" }] });
check(rw.accepted.join() === "0,3" && rw.gems === 120 && rw.seeds.length === 1, "Belohnungen bestätigen");
check(call(A, "rw_spend", { n: 20 }).gems === 100 && !call(A, "rw_spend", { n: 1000 }).ok, "Juwelen ausgeben");
check(call(B, "rw_wallet_init", { gems: 777 }).gems === 777 && !call(B, "rw_wallet_init", { gems: 9999 }).ok, "Guthaben einmalig übernehmen");
// Käufe
check(call(A, "rw_purchase", { store: "test", product: "rustwall.gems_500", receipt: "TEST", transaction: "t1" }).gems_added === 500, "Testkauf");
check(call(A, "rw_purchase", { store: "test", product: "rustwall.gems_500", receipt: "TEST", transaction: "t1" }).duplicate, "Testkauf nicht doppelt");
check(call(A, "rw_purchase", { store: "apple", product: "rustwall.gems_80", receipt: "APPLE-OK:tx9:rustwall.gems_80", transaction: "tx9" }).gems_added === 80, "Apple-Beleg");
check(call(A, "rw_purchase", { store: "apple", product: "rustwall.gems_80", receipt: "APPLE-OK:tx9:rustwall.gems_80", transaction: "tx9" }).duplicate, "Apple-Beleg nicht doppelt");
check(!call(A, "rw_purchase", { store: "apple", product: "rustwall.gems_80", receipt: "FALSCH" }).ok, "falscher Beleg");
// Live-Betrieb (Paket L): Zeitplan, Saison-Pass, Rangliste, Weltboss
const lv = call(A, "rw_liveops", {});
check(typeof lv.event === "string" && lv.event.length > 0 && lv.season >= 1 && lv.news.length >= 1, "Live-Betrieb: Zeitplan und Nachrichten");
check(call(A, "rw_season_add", { season: lv.season, add: 700 }).pts === 700 && call(A, "rw_season_add", { season: lv.season, add: 99999 }).pts === 5700, "Saisonpunkte mit Obergrenze");
call(B, "rw_season_add", { season: lv.season, add: 300 });
const sb = call(A, "rw_season_board", {});
check(sb.entries.length === 2 && sb.entries[0].me && sb.rank === 1, "Saison-Rangliste");
const bh = call(A, "rw_boss_hit", { dmg: 5000 });
check(lv.event === "weltboss" ? bh.boss_dmg >= 5000 : !bh.ok, "Weltboss-Treffer nur in der Weltboss-Woche");
// Telemetrie, Melden, Sperren, Löschen
check(call(A, "rw_telemetry", { events: [{ e: "tutorial", p: { step: 1 } }] }).n === 1, "Telemetrie");
check(call(A, "rw_crash", { event: { message: "x" } }).ok, "Fehlerbericht");
check(call(A, "rw_report", { code: hb.code, reason: "Name" }).ok, "Melden");
check(call(A, "rw_block", { code: hb.code }).blocked.length === 1 && !call(B, "rw_send", { to: ha.code, kind: "giftbox" }).ok, "Sperren beendet Freundschaft");
check(call(A, "rw_account_delete", {}).ok, "Konto löschen");
check(Object.values(store).every(o => o.userId !== A) && !store[sk("codes", "ANNA2345", "00000000-0000-0000-0000-000000000000")] && !store[sk("names", "rostburg", "00000000-0000-0000-0000-000000000000")], "alle Daten des Kontos entfernt");
check(call(B, "rw_clan_get", {}).clan.my_role === "Anführer", "Clan bekommt neuen Anführer");
console.log(fails === 0 ? "SERVER-SELBSTTEST OK" : "SERVER-SELBSTTEST FEHLER (" + fails + ")");
process.exit(fails === 0 ? 0 : 1);
