#!/usr/bin/env python3
"""Holt Schrift und Bestaetigungsfoto der Einloese-Seiten aus der Android-APK.

    python3 tools/apk-vorlage.py [APK] [ZIEL]

Die Seiten "Einloesen" und "Eingeloest" sehen aus wie in der Android-App
(fragment_coupon_gastronomy_redeem, fragment_coupon_redeemed) -- dazu
gehoeren die Schrift Neo Sans Pro und das Foto voucher_redeemed. Beides ist
urheberrechtlich geschuetzt und liegt deshalb NICHT im Repo: es wird beim
Bauen aus der eigenen APK geholt und nur ins Paket gelegt. Fehlt die APK,
fallen die Seiten auf die Systemschrift und eine Flaeche zurueck.

APK: Vorgabe ~/Downloads/Wien+zu+Fuß_3.3.3_APKPure.apk oder $WZF_APK.
ZIEL: Vorgabe build/vorlage/.
"""
import io
import os
import subprocess
import sys
import zipfile

HIER = os.path.dirname(os.path.abspath(__file__))
WURZEL = os.path.dirname(HIER)
APK = (sys.argv[1] if len(sys.argv) > 1 else
       os.environ.get("WZF_APK", os.path.expanduser("~/Downloads/Wien+zu+Fuß_3.3.3_APKPure.apk")))
ZIEL = sys.argv[2] if len(sys.argv) > 2 else os.path.join(WURZEL, "build", "vorlage")

GESUCHT = {
    "font/neo_sans_pro_regular": "neo_sans_pro_regular.otf",
    "font/neo_sans_pro_medium": "neo_sans_pro_medium.otf",
    "drawable/voucher_redeemed": "voucher_redeemed.jpg",
}


def pfade():
    """Ressourcenname -> [(Konfiguration, Pfad in der APK)] aus der
    Ressourcentabelle; die Dateinamen in der APK sind verschleiert."""
    aus = subprocess.run(["aapt", "dump", "--values", "resources", APK],
                         capture_output=True, text=True).stdout
    treffer = {}
    aktuell = None
    konfig = ""
    for zeile in aus.splitlines():
        z = zeile.strip()
        if z.startswith("config "):
            konfig = z
        if z.startswith("resource ") and ":" in z:
            name = z.split(":")[1].strip()
            aktuell = name if name in GESUCHT else None
        elif aktuell and z.startswith("(string8)"):
            pfad = z.split('"')[1]
            treffer.setdefault(aktuell, []).append((konfig, pfad))
            aktuell = None
    return treffer


def main():
    # Erst leeren: sonst laege nach einem Bau ohne APK noch die Schrift eines
    # frueheren Laufs im Ordner und kaeme ins Paket.
    for datei in GESUCHT.values():
        try:
            os.remove(os.path.join(ZIEL, datei))
        except OSError:
            pass
    if not os.path.isfile(APK):
        print("apk-vorlage: keine APK (%s) -- Einloese-Seiten ohne Originalschrift und -foto" % APK)
        return 0
    os.makedirs(ZIEL, exist_ok=True)
    treffer = pfade()
    with zipfile.ZipFile(APK) as z:
        for name, datei in GESUCHT.items():
            kandidaten = treffer.get(name, [])
            if not kandidaten:
                print("apk-vorlage: %s nicht gefunden" % name)
                continue
            # Vom Foto die xxhdpi-Fassung (1125x600): scharf genug fuer
            # 1080 Pixel Breite, halb so gross wie xxxhdpi.
            wahl = next((p for k, p in kandidaten if "xxhdpi" in k and "xxxhdpi" not in k), kandidaten[-1][1])
            daten = z.read(wahl)
            ausgabe = os.path.join(ZIEL, datei)
            if datei.endswith(".jpg"):
                # Qt 4.7 auf dem N9 kann kein WebP.
                from PIL import Image
                Image.open(io.BytesIO(daten)).convert("RGB").save(ausgabe, "JPEG", quality=88)
            else:
                open(ausgabe, "wb").write(daten)
            print("apk-vorlage: %s <- %s (%d B)" % (datei, wahl, os.path.getsize(ausgabe)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
