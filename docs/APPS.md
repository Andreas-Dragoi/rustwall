# Rustwall als App für iPhone und Android – Anleitung

Diese Anleitung führt Schritt für Schritt von der Web-Version zur App in den Stores. Vieles davon geht nur mit
deinen eigenen Konten (Apple, Google) – das kann niemand für dich anlegen.

**Reihenfolge:** 1. Server aufsetzen (`server/README.md`) → 2. Texte ausfüllen und prüfen lassen (`docs/legal/`) →
3. Android (schneller, günstiger) → 4. iPhone.

## Was schon vorbereitet ist

| Was | Wo |
|---|---|
| Export-Vorlagen „Android“ (APK zum Testen), „Android Play“ (AAB für den Play Store), „iOS“ | `export_presets.cfg` (die Web-Vorlage ist unverändert) |
| App-Symbol in allen Größen, Startbild | `icons/app/` (vom Spiel benutzt), `docs/store/grafik/` (für die Stores); neu erzeugen: `python3 blender/logo.py` |
| Automatischer Bau in GitHub | `.github/workflows/android.yml`, `.github/workflows/ios.yml` |
| Käufe (StoreKit / Google Play Billing) mit Prüfung auf dem Server | `src/store.gd`, `src/net_store.gd`, `server/` |
| Datenschutz, Nutzungsbedingungen, Impressum, Lizenzen | `docs/legal/` und im Spiel unter Einstellungen → Rechtliches |
| Store-Texte | `docs/store/` |

**Paketname / Bundle-ID**: überall `de.rustwall.spiel`. Wenn du eine eigene Domain hast, nimm besser deren umgedrehte Form
(z. B. `de.meinname.rustwall`) und ändere sie in `export_presets.cfg` an beiden Stellen (`package/unique_name`, `application/bundle_identifier`).
**Einmal festgelegt, lässt sie sich im Store nie mehr ändern.**

**Versionsnummer**: vor jedem Hochladen in `export_presets.cfg` erhöhen: Android `version/code` (+1) und `version/name`,
iOS `application/version` (+1) und `application/short_version`.

## Android (Google Play)

1. **Konto**: https://play.google.com/console – einmalig 25 US-Dollar. Identität bestätigen (dauert einige Tage).
   Neue Privatkonten müssen vor der Veröffentlichung 14 Tage lang mit mindestens 12 Testern testen („geschlossener Test“).
2. **Upload-Schlüssel** (einmal, gut aufbewahren – ohne ihn keine Updates!). Am PC mit installiertem Java:
   `keytool -genkeypair -v -keystore upload.keystore -alias rustwall -keyalg RSA -keysize 2048 -validity 10000`
   Passwort merken. Sicherungskopie an einem zweiten Ort ablegen.
3. **GitHub-Secrets** (Repository → Settings → Secrets and variables → Actions → New repository secret):
   - `ANDROID_KEYSTORE_BASE64` = Inhalt von `base64 -w0 upload.keystore` (Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload.keystore"))`)
   - `ANDROID_KEYSTORE_ALIAS` = `rustwall`
   - `ANDROID_KEYSTORE_PASSWORD` = dein Passwort
4. **Bauen**: GitHub → Actions → „Android-App bauen“ → „Run workflow“. Nach ca. 15 Minuten unter „Artifacts“: `rustwall.aab` (für Google) und `rustwall.apk`.
   Ohne Secrets kommt eine `rustwall-debug.apk` heraus – die kannst du direkt auf dein Handy laden und installieren (unbekannte Quellen erlauben).
5. **Käufe auf Android** brauchen das Plugin „Godot Google Play Billing“: von https://github.com/godot-sdk-integrations/godot-google-play-billing/releases
   die Fassung für Godot 4.x herunterladen, den Ordner `addons/GodotGooglePlayBilling` ins Projekt legen, im Godot-Editor unter
   Projekt → Projekteinstellungen → Plugins einschalten, committen. Ohne Plugin läuft das Spiel normal, nur ohne echte Käufe.
6. **Play Console**: App anlegen → „Interner Test“ → Release erstellen → `rustwall.aab` hochladen → Tester (E-Mail-Adressen) einladen.
   Unter „Monetarisieren → Produkte → In-App-Produkte“ die Produkte anlegen (IDs siehe `server/modules/regeln.json`: `rustwall.gems_80` …).
   Für den Server ein Dienstkonto einrichten (siehe `server/README.md`, Abschnitt „Käufe einrichten“).
7. **Pflichtangaben** in der Play Console: Datenschutzerklärung (öffentliche Webadresse!), Datensicherheit (siehe unten), Inhaltseinstufung
   (IARC-Fragebogen: Comic-Gewalt gegen Fantasiewesen, In-App-Käufe, Nutzerinteraktion im Clan-Chat), Zielgruppe (wenn Kinder unter 13 dazugehören,
   gelten die „Families“-Richtlinien), Werbung: nein.

## iPhone und iPad (App Store)

1. **Konto**: Apple Developer Program, 99 €/Jahr: https://developer.apple.com/programs/ (für Firmen zusätzlich D-U-N-S-Nummer).
2. **Mac**: Zum ersten Einrichten (Zertifikate) und zum Hochladen ohne GitHub brauchst du einen Mac mit Xcode (kostenlos im Mac App Store).
   Mit den GitHub-Secrets (unten) kann GitHub das Bauen und Hochladen auf einem Mac in der Cloud übernehmen.
3. **App-ID und Zertifikate** (developer.apple.com → Certificates, IDs & Profiles):
   - Identifier → App IDs → `de.rustwall.spiel`, Fähigkeit „In-App Purchase“ (ist immer an).
   - Certificates → „Apple Distribution“ erzeugen, herunterladen, in der Schlüsselbundverwaltung als `.p12` exportieren (mit Passwort).
   - Profiles → „App Store Connect“-Profil für die App-ID erzeugen und herunterladen (`.mobileprovision`).
4. **Käufe auf iOS** brauchen das Plugin „InAppStore“ aus https://github.com/godotengine/godot-ios-plugins (Fassung für Godot 4):
   die Dateien `inappstore.gdip` und die Bibliothek in den Projektordner `ios/plugins/` legen. In der Export-Vorlage „iOS“ ist das Plugin schon angehakt.
5. **App Store Connect** (https://appstoreconnect.apple.com): App anlegen (Name, Bundle-ID, SKU), In-App-Käufe als „Verbrauchsartikel“ mit den IDs aus
   `server/modules/regeln.json` anlegen, das „App-spezifische gemeinsame geheime Passwort“ in die Server-`.env` eintragen.
   Für das automatische Hochladen: Benutzer und Zugriff → Integrationen → App-Store-Connect-API → Schlüssel erzeugen (Rolle „App Manager“).
6. **GitHub-Secrets**: `IOS_TEAM_ID`, `IOS_DIST_P12_BASE64` (`base64 -i zert.p12`), `IOS_DIST_P12_PASSWORD`, `IOS_PROFILE_BASE64` (`base64 -i profil.mobileprovision`),
   optional `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_KEY_P8` (Inhalt der .p8-Datei).
7. **Bauen**: Actions → „iOS-App bauen“ → „Run workflow“. Mit allen Secrets landet der Build nach ca. 30 Minuten in **TestFlight**;
   ohne Secrets gibt es das Xcode-Projekt als Download (auf dem Mac öffnen → Team wählen → Product → Archive → Distribute App → TestFlight).
8. **TestFlight**: In App Store Connect → TestFlight → Tester einladen (bis 100 intern sofort, extern nach kurzer Prüfung).
9. **Veröffentlichen**: Store-Eintrag ausfüllen (Texte aus `docs/store/`, Bildschirmfotos 6,7" und 6,5" sowie iPad 13"), Altersfreigabe-Fragebogen,
   „App-Datenschutz“ (siehe unten), Link zur Datenschutzerklärung und Support-Adresse → zur Prüfung einreichen.
   Apple verlangt: Konto löschen im Spiel (vorhanden: Einstellungen → Konto löschen), Kaufwiederherstellung (Store.restore()), keine Hinweise auf andere Kaufwege.

## Angaben zum Datenschutz in den Stores

Gilt, wenn das Online-Spiel eingeschaltet ist (Server-Adresse eingetragen):

| Datenart | Erhoben | Mit Person verknüpft | Zweck | Tracking |
|---|---|---|---|---|
| Kennungen (Konto-ID, zufällige Geräte-ID) | ja | ja | App-Funktion | nein |
| Spielinhalte (Spielstand, Bunkername, Clan-Nachrichten) | ja | ja | App-Funktion | nein |
| Käufe (Kaufverlauf) | ja | ja | App-Funktion | nein |
| E-Mail (nur wenn verknüpft) | optional | ja | App-Funktion (Konto wiederherstellen) | nein |
| Nutzungsdaten (Spielereignisse) | nur mit Einwilligung | nein | Analyse | nein |
| Diagnose (Absturzberichte, Leistung) | nur mit Einwilligung | nein | App-Funktion | nein |

Kein Tracking über Apps anderer Firmen → **kein** App-Tracking-Transparenz-Dialog nötig. Verschlüsselung: nur Standard-HTTPS
(in App Store Connect „Exportbestimmungen“: nur ausgenommene Verschlüsselung).

## Altersfreigabe und Beutekisten

- Annahme: USK 6 / PEGI 7 / Apple 9+ wegen Comic-Gewalt gegen Schleime und Fantasiewesen; In-App-Käufe und Nutzerinteraktion (Clan-Chat mit Filter) angeben.
- Beutekisten gibt es **nicht für Echtgeld** – deshalb keine Pflicht, Wahrscheinlichkeiten anzuzeigen. Sollte sich das ändern: Wahrscheinlichkeiten im Spiel anzeigen
  (Apple/Google-Pflicht) und Belgien/Niederlande prüfen lassen.
- Kinder: Beim ersten Start fragt das Spiel nach dem Alter. Unter 16: keine Telemetrie, deutlicher Hinweis vor jedem Kauf.

## Leistung auf echten Geräten (noch offen)

Vor der Veröffentlichung auf mindestens 6 Geräten messen (z. B. iPhone 11/13/15, Galaxy A-Klasse, Pixel, ein Tablet):
Bildrate in Basis und Flut, Speicher, Wärme nach 20 Minuten. Mit Einwilligung meldet die Telemetrie Bildrate und Gerätemodell an den Server (`fps`, `session_start`).
