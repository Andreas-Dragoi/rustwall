#!/usr/bin/env python3
"""Erzeugt src/legal_texts.gd aus den Rechtstexten in docs/legal/*.md (und fonts/OFL.txt).

Die Markdown-Dateien sind die Vorlage zum Bearbeiten (auch für Webseite und Store-Eintrag).
Nach jeder Änderung einmal ausführen:  python3 tools/legal_to_gd.py
(Das Spiel kann .md-Dateien nicht selbst lesen, weil der Export sie ausschließt.)
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = [("datenschutz", "Datenschutz"), ("nutzungsbedingungen", "Nutzungsbedingungen"), ("impressum", "Impressum"), ("mitwirkende", "Mitwirkende und Lizenzen")]
# Paket S: englische Fassung aus docs/legal/en/*.md (gleiche Dateinamen)
DOCS_EN = {"datenschutz": "Privacy", "nutzungsbedingungen": "Terms of Use", "impressum": "Imprint", "mitwirkende": "Credits and Licenses"}


def lit(text):
    return json.dumps(text, ensure_ascii=False)


def main():
    out = ['extends RefCounted', '## Rechtstexte für den Bildschirm „Rechtliches“ (Paket O).',
           '## ERZEUGT von tools/legal_to_gd.py aus docs/legal/*.md – nicht von Hand ändern, sondern die .md-Dateien bearbeiten.', '',
           'const ORDER := %s' % lit([k for k, _ in DOCS]), '', 'const DOCS := {']
    for key, title in DOCS:
        text = open(os.path.join(ROOT, "docs", "legal", key + ".md"), encoding="utf-8").read().rstrip() + "\n"
        out.append('\t%s: {"title": %s, "text": %s},' % (lit(key), lit(title), lit(text)))
    out.append('}')
    out.append('')
    out.append('## Englische Fassung (Paket S), Schlüssel wie oben')
    out.append('const DOCS_EN := {')
    for key, _title in DOCS:
        path = os.path.join(ROOT, "docs", "legal", "en", key + ".md")
        if os.path.exists(path):
            text = open(path, encoding="utf-8").read().rstrip() + "\n"
            out.append('\t%s: {"title": %s, "text": %s},' % (lit(key), lit(DOCS_EN[key]), lit(text)))
    out.append('}')
    out.append('')
    ofl = open(os.path.join(ROOT, "fonts", "OFL.txt"), encoding="utf-8").read().rstrip() + "\n"
    out.append('const FONT_LICENSE := %s' % lit(ofl))
    out.append('')
    with open(os.path.join(ROOT, "src", "legal_texts.gd"), "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print("src/legal_texts.gd geschrieben")


if __name__ == "__main__":
    main()
