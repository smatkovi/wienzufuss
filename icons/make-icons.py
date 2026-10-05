#!/usr/bin/env python3
"""Baut die Startsymbole -- beim Bauen, sie liegen nicht im Repo.

    python3 icons/make-icons.py [APK]

* Mit APK (Vorgabe ~/Downloads/Wien+zu+Fuß_3.3.3_APKPure.apk oder $WZF_APK):
  das Symbol der Android-App, aus deren Vektorgrafik (Adaptive Icon:
  ic_launcher_foreground auf ic_launcher_background, sichtbarer Ausschnitt).
  Das Logo gehoert der Stadt Wien; deshalb wird es nur aus der eigenen APK
  geholt und nie eingecheckt.
* Ohne APK: ein eigenes Symbol (zwei Fussabdruecke auf Blau).

Ausgabe:
  meego/icons/icon-80.png, icon-64.png   N9: in Harmattan-Form (Superellipse)
  sailfish/icons/<n>x<n>/wienzufuss.png  Sailfish: dieselbe Form
"""
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

HIER = os.path.dirname(os.path.abspath(__file__))
WURZEL = os.path.dirname(HIER)
APK = (sys.argv[1] if len(sys.argv) > 1 else
       os.environ.get("WZF_APK", os.path.expanduser("~/Downloads/Wien+zu+Fuß_3.3.3_APKPure.apk")))
BLAU = (0x37, 0x90, 0xad, 255)


def aapt(*args):
    return subprocess.run(["aapt"] + list(args), capture_output=True, text=True).stdout


def ressource(name):
    """Pfad (oder bei Farben den Wert) einer Ressource aus der Tabelle der APK."""
    aktuell = False
    for zeile in aapt("dump", "--values", "resources", APK).splitlines():
        z = zeile.strip()
        if z.startswith("resource ") and ":" in z:
            aktuell = z.split(":")[1].strip() == name
            if aktuell and name.startswith("color/") and "d=0x" in z:
                return z.split("d=0x")[1].split()[0]
        elif aktuell and z.startswith("(string8)"):
            return z.split('"')[1]
    return None


def wert(text):
    """aapt-Attributwert -> float, int oder str."""
    if text.startswith('"'):
        return text.split('"')[1]
    typ = text.split(")")[0].replace("(type ", "")
    bits = int(text.split(")")[1], 16)
    if typ == "0x4":
        return struct.unpack(">f", struct.pack(">I", bits))[0]
    return bits


def logo_aus_apk(ziel_png):
    """Vektor aus der APK -> SVG -> 512er PNG. False, wenn es nicht geht."""
    if not os.path.isfile(APK) or not shutil.which("aapt") or not shutil.which("rsvg-convert"):
        return False
    vorder = ressource("drawable/ic_launcher_foreground")
    hinter = ressource("color/ic_launcher_background")
    if not vorder:
        return False
    hintergrund = "#" + (hinter[-6:] if hinter else "3790ad")
    gruppe, pfade, attrs = {}, [], None
    for zeile in aapt("dump", "xmltree", APK, vorder).splitlines():
        z = zeile.strip()
        if z.startswith("E: path"):
            attrs = {}
            pfade.append(attrs)
        elif z.startswith("A: android:"):
            name = z[len("A: android:"):].split("(")[0]
            text = z.split("=", 1)[1]
            if " (Raw:" in text:
                text = text.split(" (Raw:")[0]
            (attrs if attrs is not None else gruppe)[name] = wert(text)
    if not pfade:
        return False
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="18 18 72 72">',
           '<rect x="0" y="0" width="108" height="108" fill="%s"/>' % hintergrund,
           '<g transform="translate(%f,%f) scale(%f,%f)">' % (
               gruppe.get("translateX", 0), gruppe.get("translateY", 0),
               gruppe.get("scaleX", 1), gruppe.get("scaleY", 1))]
    for p in pfade:
        farbe = p.get("fillColor", 0xffffffff)
        svg.append('<path fill="#%06x" d="%s"/>' % (farbe & 0xffffff, p.get("pathData", "")))
    svg.append("</g></svg>")
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write("".join(svg))
        name = f.name
    try:
        subprocess.check_call(["rsvg-convert", "-w", "512", "-h", "512", name, "-o", ziel_png])
    finally:
        os.unlink(name)
    return True


def eigenes_logo(ziel_png):
    """Zwei Fussabdruecke auf Blau -- eigenes Motiv, keins aus der App."""
    g = 2048
    bild = Image.new("RGBA", (g, g), BLAU)
    d = ImageDraw.Draw(bild)

    def fuss(cx, cy, winkel, spiegeln):
        # Sohle aus zwei Ellipsen (Ballen, Ferse), dazu fuenf Zehen.
        teile = [(0, -150, 210, 300), (0, 230, 150, 190)]
        zehen = [(-120, -470, 62), (-15, -520, 56), (80, -505, 50), (160, -460, 44), (215, -395, 38)]
        s, c = math.sin(math.radians(winkel)), math.cos(math.radians(winkel))

        def dreh(x, y):
            x = -x if spiegeln else x
            return cx + x * c - y * s, cy + x * s + y * c

        for x, y, rx, ry in teile:
            punkte = [dreh(x + rx * math.cos(t / 48.0 * 2 * math.pi), y + ry * math.sin(t / 48.0 * 2 * math.pi))
                      for t in range(48)]
            d.polygon(punkte, fill="white")
        for x, y, r in zehen:
            mx, my = dreh(x, y)
            d.ellipse([mx - r, my - r, mx + r, my + r], fill="white")

    fuss(760, 1250, -12, True)
    fuss(1290, 820, 12, False)
    bild.resize((512, 512), Image.LANCZOS).save(ziel_png)


def squircle_maske(g):
    """Die Form der Harmattan-Symbole: Superellipse (Exponent ~2,7) mit 1 px
    Rand -- nachgerechnet, nicht aus dem Nokia-Thema kopiert. Sailfish
    bekommt dieselbe Form. Gerechnet wird achtfach und zeilenweise: je
    Zeile liegt die Form zwischen zwei Grenzen, die sich ausrechnen lassen."""
    f = 8
    m = Image.new("L", (g * f, g * f), 0)
    d = ImageDraw.Draw(m)
    halb = (g - 2) * f / 2.0
    mitte = g * f / 2.0
    for y in range(g * f):
        v = abs((y + 0.5 - mitte) / halb) ** 2.7
        if v > 1.0:
            continue
        w = halb * (1.0 - v) ** (1 / 2.7)
        links = math.ceil(mitte - w - 0.5)
        rechts = math.floor(mitte + w - 0.5)
        if rechts >= links:
            d.line([(links, y), (rechts, y)], fill=255)
    return m.resize((g, g), Image.LANCZOS)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        gross = os.path.join(tmp, "symbol-512.png")
        if logo_aus_apk(gross):
            print("Symbol: aus der APK (%s)" % APK)
        else:
            eigenes_logo(gross)
            print("Symbol: eigenes (keine APK)")
        quelle = Image.open(gross).convert("RGBA")

        # N9
        bild = quelle.resize((80, 80), Image.LANCZOS)
        bild.putalpha(squircle_maske(80))
        ordner = os.path.join(WURZEL, "meego", "icons")
        os.makedirs(ordner, exist_ok=True)
        bild.save(os.path.join(ordner, "icon-80.png"))
        bild.resize((64, 64), Image.LANCZOS).save(os.path.join(ordner, "icon-64.png"))

        # Sailfish: dieselbe Form wie am N9
        for g in (86, 108, 128, 172):
            b = quelle.resize((g, g), Image.LANCZOS)
            b.putalpha(squircle_maske(g))
            ziel = os.path.join(WURZEL, "sailfish", "icons", "%dx%d" % (g, g))
            os.makedirs(ziel, exist_ok=True)
            b.save(os.path.join(ziel, "wienzufuss.png"))


if __name__ == "__main__":
    main()
