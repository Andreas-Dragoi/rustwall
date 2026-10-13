# Rustwall-Server – Schritt für Schritt

Ohne Server läuft Rustwall wie bisher allein auf dem Gerät (Mitspieler simuliert). Mit Server gibt es echte Freunde,
Clans, Ranglisten, Cloud-Speicher, Gerätewechsel und echte Käufe. Der Server ist **Nakama** (kostenlos, quelloffen,
von Heroic Labs) mit einem eigenen Rustwall-Modul (`modules/`).

## Was liegt hier?

| Datei | Wozu |
|---|---|
| `docker-compose.yml` | startet alles: Datenbank (PostgreSQL), Nakama, Caddy (sorgt für https) |
| `.env.beispiel` | Vorlage für Einstellungen und Geheimnisse → als `.env` kopieren und ausfüllen |
| `modules/src/main.ts` | Spielregeln auf dem Server (TypeScript), fertig übersetzt in `modules/build/index.js` |
| `modules/regeln.json` | alle Zahlen (Limits, Clan-Größe, Juwelen-Pakete …) – hier ändern, Server neu starten |
| `modules/wortfilter.txt` | gesperrte Wörter für Namen und Clan-Chat |
| `modules/test/selbsttest.js` | prüft das Modul ohne Nakama: `node server/modules/test/selbsttest.js` |
| `mock_server.py` | **Testserver** (Attrappe) für Entwicklung und automatische Tests – nicht für echte Spieler |

## Weg A: eigener kleiner Server (empfohlen, ca. 5–10 € im Monat)

Ein „VPS“ (virtueller Server) reicht für einige tausend Spieler, z. B. Hetzner Cloud CX22 (2 Kerne, 4 GB, Standort Deutschland),
netcup oder IONOS. Achte auf einen Standort in der EU (Datenschutz).

1. **Server mieten**: Betriebssystem „Ubuntu 24.04“ wählen. Du bekommst eine IP-Adresse (z. B. `203.0.113.10`) und ein Passwort bzw. SSH-Schlüssel.
2. **Domain**: Bei deinem Domain-Anbieter einen Eintrag anlegen: Typ `A`, Name `rustwall` (ergibt z. B. `rustwall.meinname.de`), Wert = IP des Servers.
   (Ohne eigene Domain geht es nicht mit https – und Handys verlangen https.)
3. **Anmelden** (am PC im Terminal bzw. unter Windows in „PowerShell“): `ssh root@203.0.113.10`
4. **Docker installieren** (eine Zeile, dauert 1–2 Minuten):
   `curl -fsSL https://get.docker.com | sh`
5. **Rustwall-Serverdateien hochladen**: den Ordner `server/` auf den Server kopieren, z. B. vom PC aus:
   `scp -r server root@203.0.113.10:/opt/rustwall-server`
6. **Einstellungen**: `cd /opt/rustwall-server && cp .env.beispiel .env && nano .env`
   - `DOMAIN` = deine Domain, alle „bitte-ersetzen“-Werte durch Zufallswerte ersetzen (`openssl rand -hex 24` erzeugt einen).
   - Speichern mit Strg+O, Eingabe, Strg+X.
7. **Starten**: `docker compose up -d` – nach ca. 1 Minute läuft alles. Prüfen: im Browser `https://deine-domain/healthcheck` öffnen → `{}`.
8. **Im Spiel**: Einstellungen → „Online-Spiel und Konto“ → Adresse `https://deine-domain` eintragen → „Verbinden“.
   Für die Store-Fassung trägst du die Adresse fest ein (siehe unten „Adresse fest ins Spiel“).

**Verwaltung** (Spieler, Speicher, Meldungen ansehen): Vom PC aus `ssh -L 7351:127.0.0.1:7351 root@203.0.113.10`, dann im Browser
`http://127.0.0.1:7351` öffnen, Benutzer `admin`, Passwort = `CONSOLE_PASSWORD` aus `.env`.
Gemeldete Spieler stehen in der Sammlung `reports`; ab drei Meldungen wird ein Bunker/Clan automatisch aus der Suche genommen (`hidden`).

**Aktualisieren** (neue Regeln/Modul): Dateien in `modules/` ersetzen, dann `docker compose restart nakama`.
**Sicherung** der Datenbank (täglich per cron empfohlen):
`docker compose exec -T postgres pg_dump -U postgres nakama | gzip > sicherung-$(date +%F).sql.gz`

## Weg B: Heroic Cloud (gehostet, ohne eigene Serverpflege)

Heroic Labs bietet Nakama als Dienst an (https://heroiclabs.com/heroic-cloud/). Dort ein Projekt anlegen, als „Runtime“
den Inhalt von `modules/` hochladen (Einstiegsdatei `build/index.js`, dazu `regeln.json` und `wortfilter.txt`),
die Umgebungsvariablen aus `.env.beispiel` (ab `ALLOW_TEST_PURCHASES`) im Projekt eintragen und die angezeigte Adresse im Spiel verwenden.
Teurer als ein VPS, dafür kümmert sich Heroic um Datenbank, Sicherungen und Updates.

## Adresse fest ins Spiel

Für die Store-Fassung soll niemand eine Adresse eintippen müssen: in `src/net.gd` bei `_load_cfg()` den Vorgabewert
`"url": ""` durch `"url": "https://deine-domain"` ersetzen. Spieler können in den Einstellungen trotzdem „Trennen“.

## Käufe einrichten

- **Apple**: In App Store Connect die In-App-Käufe anlegen (Typ „Verbrauchsartikel“) mit den Produkt-IDs aus `modules/regeln.json`
  (`rustwall.gems_80` … `rustwall.gems_14000`, `rustwall.starter`). Unter „App-spezifisches gemeinsames geheimes Passwort“ ein Passwort
  erzeugen und als `APPLE_SHARED_SECRET` in `.env` eintragen.
- **Google**: In der Play Console dieselben Produkt-IDs als „In-App-Produkte“ anlegen. In der Google Cloud Console ein Dienstkonto anlegen,
  in der Play Console unter „Nutzer und Berechtigungen“ einladen (Recht „Finanzdaten ansehen / Bestellungen verwalten“),
  JSON-Schlüssel herunterladen: `client_email` → `GOOGLE_CLIENT_EMAIL`, `private_key` → `GOOGLE_PRIVATE_KEY`.
- Der Server prüft jeden Beleg bei Apple/Google, schreibt die Juwelen gut und merkt sich die Transaktion (keine doppelte Gutschrift).

## Schnittstellen (für Entwickler)

REST wie Nakama: `POST /v2/account/authenticate/device`, `POST /v2/account/session/refresh`, `GET /v2/account`,
`POST /v2/account/link/{email|apple|google}`, `POST /v2/rpc/<name>` mit den Serverfunktionen
`rw_time, rw_hello, rw_rename, rw_save_put, rw_save_get, rw_save_list, rw_find, rw_suggest, rw_friends, rw_friend_add, rw_friend_remove,
rw_send, rw_mail, rw_mail_claim, rw_clan_list, rw_clan_create, rw_clan_join, rw_clan_leave, rw_clan_get, rw_clan_chat, rw_clan_role,
rw_clan_request, rw_clan_donate, rw_score, rw_board, rw_report, rw_block, rw_wallet, rw_wallet_init, rw_reward, rw_spend, rw_purchase,
rw_restore, rw_telemetry, rw_crash, rw_account_delete, rw_modi_score, rw_modi_board, rw_raid_hit, rw_raid_get`
(die letzten vier: Spielmodi aus Paket M – Wochenranglisten für Turm/Überleben und der Clan-Raid).
Der Testserver `mock_server.py` bedient dieselben Schnittstellen (`python3 server/mock_server.py --port 7350 --allow-test-purchases`)
und wird von `src/tests_online.gd` automatisch gestartet.

Modul neu übersetzen (nur nach Änderungen an `main.ts`): `cd server/modules && npm install && npx tsc` → `build/index.js`.

## Grenzen dieser Fassung

- Suche nach Bunkernamen und Vorschläge lesen die Speicherliste durch (gut bis einige tausend Spieler). Für mehr Spieler einen
  Nakama-Speicherindex anlegen.
- Wochenwechsel der Ranglisten: Montag 0:00 Uhr UTC (Nakama-Ranglisten mit Zurücksetzen).
- Das Modul ist gegen eine nachgebaute Nakama-Laufzeit getestet (`test/selbsttest.js`), nicht gegen einen echten Nakama-Server.
  Vor dem Start einmal mit `ALLOW_TEST_PURCHASES=1` durchspielen (Konto, Freund, Clan, Testkauf), dann wieder auf 0.
