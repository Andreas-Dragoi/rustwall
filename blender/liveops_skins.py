"""Paket L (Live-Betrieb): Helden-Skins – je Held zwei Farb- und Kleidungsvarianten über den bestehenden Figuren-Aufbau
aus heroes.py (gleiches Skelett rw_human, gleiche Voxel-Teile, andere Farben, Kopfbedeckung und Rucksack).
Erzeugt models/hero_<skin>.glb und icons/hero_<skin>.png.
Aufruf: python3 blender/liveops_skins.py [skin ...]   (ohne Namen: alle zwölf)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import heroes

# Skin-Schlüssel -> (Held, Änderungen am Grund-Bauplan aus heroes.SPECS)
SKINS = {
    # Jona
    "jona_wuestenfuchs": ("jona", dict(cloth=["D9B47A", "C9A066", "E3C48E", "B88A52", "A8794A"], cloth2=["B88A52", "9C7444", "C9A066"],
                                       helm=["C9A066", "B88A52", "D9B47A", "A8794A"], mask="E8DCC0", goggles="FF7043", boots="7A5232", belt="5A4028")),
    "jona_marine": ("jona", dict(cloth=["2C4F8A", "23417A", "355E9C", "4A72B0", "1C3566"], cloth2=["1C3566", "23417A", "2C4F8A"],
                                 helm=["F4F6FA", "E2E6EE", "D5DAE4", "F4F6FA"], mask=None, goggles="2E3340", boots="1E2028", belt="E0A82E", head="cap")),
    # Mika
    "mika_glutwehr": ("mika", dict(cloth=["2E3340", "262A36", "363C4C"], cloth2=["FF7A1E", "E8661A"], helm=["1E2028", "2A2D3A"], hair="FFD23E",
                                   boots="FF7A1E", gloves="FF7A1E", belt="FF7A1E")),
    "mika_frostwehr": ("mika", dict(cloth=["DDEBFA", "CFE2F6", "E8F2FC"], cloth2=["3C8CE0", "347CCC"], helm=["7FD4FF", "66C4F2"], hair="F4F6FA",
                                    boots="3C8CE0", gloves="F4F6FA", belt="3C8CE0", goggles="66DBFF")),
    # Bruno
    "bruno_rostschmied": ("bruno", dict(cloth=["B8582E", "A64C28", "C86638"], cloth2=["5A4028", "4E3622"], helm=["D54144", "C2383C"],
                                        boots="2E3340", gloves="7A4522", belt="2E3340", back="none")),
    "bruno_goldgraeber": ("bruno", dict(cloth=["6B4A2E", "5E4028", "785436"], cloth2=["E0A82E", "CC9628"], helm=["FFD23E", "F2C230"],
                                        boots="3A2A1E", gloves="FFD23E", belt="FFD23E", hair="E06A2A")),
    # Ada
    "ada_neon": ("ada", dict(cloth=["3A2A5E", "322452", "44326C"], cloth2=["1E2028", "2A2D3A"], helm=["42E07A", "36CC6C"], goggles="FF4FD8",
                             boots="42E07A", gloves="42E07A", belt="FF4FD8", hair="FF4FD8")),
    "ada_mitternacht": ("ada", dict(cloth=["1E2433", "182030", "262E40"], cloth2=["66DBFF", "52C8EE"], helm=["2E3340", "262A36"], goggles="66DBFF",
                                    boots="1E2028", gloves="66DBFF", belt="66DBFF")),
    # Yuki
    "yuki_schneeeule": ("yuki", dict(cloth=["E8EEF6", "DCE4EE", "F4F6FA"], cloth2=["9AA8BE", "8A98AE"], helm=["F4F6FA", "E2E8F0", "D2DAE6"],
                                     mask="9AA8BE", boots="6F7C96", gloves="E8EEF6", hair="E6E6EA")),
    "yuki_herbstlaub": ("yuki", dict(cloth=["B8582E", "C86A2E", "9C4A26"], cloth2=["6B4A2E", "5E4028"], helm=["E8902E", "D57A22", "F2A63C"],
                                     mask="8A2E22", boots="3A2A1E", gloves="6B4A2E")),
    # Greta
    "greta_rosengarten": ("greta", dict(cloth=["F07AB4", "E46AA6", "F890C2"], cloth2=["FFF2F8", "F6E2EE"], helm=["FFFFFF", "F4F6FA"],
                                        boots="C93F8E", belt="42C95E", goggles="FFD23E")),
    "greta_sternennacht": ("greta", dict(cloth=["2C3F80", "263670", "34498E"], cloth2=["FFD23E", "F2C230"], helm=["8C5DF2", "7A4FE0"],
                                         boots="1E2028", gloves="FFD23E", belt="FFD23E", goggles="FFD23E", hair="C9CED8")),
    # Nele (Paket H)
    "nele_korallenriff": ("nele", dict(cloth=["FF7A6A", "F06A5A", "FF8C7C"], cloth2=["2E86A0", "267890"], helm=["F4F6FA", "E2E6EE"], hair="F2C230",
                                       boots="2E86A0", gloves="FF7A6A", belt="F4F6FA", goggles="FFB0E8")),
    "nele_eismeer": ("nele", dict(cloth=["DCEAF6", "CFE2F2", "E8F2FC"], cloth2=["3C6CB8", "345EA4"], helm=["7FD4FF", "66C4F2"], hair="E6E6EA",
                                  boots="3C6CB8", gloves="DCEAF6", belt="7FD4FF", goggles="CFF6FF")),
}


def build_skin(skin):
    base, changes = SKINS[skin]
    keep = heroes.SPECS[base]
    spec = dict(keep)
    spec.update(changes)
    heroes.SPECS[base] = spec           # build() liest den Bauplan über den Schlüssel des Helden (Schild, Begleiter)
    try:
        heroes.build(base)
    finally:
        heroes.SPECS[base] = keep
    save_rigged("hero_" + skin)
    icon("hero_" + skin, 384, yaw=28, pitch=14)


if __name__ == "__main__":
    keys = sys.argv[1:] or list(SKINS.keys())
    for k in keys:
        build_skin(k)
        print("ok", k, flush=True)
