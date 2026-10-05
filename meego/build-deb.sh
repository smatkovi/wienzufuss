#!/bin/sh
# Packt Oberflaeche, Dienste und QML als Harmattan-.deb.
#
#   meego/build-deb.sh [version]     # -> build/wienzufuss_<version>_armel.deb
#
# Keine versionierten Abhaengigkeiten: das installierte Qt ist
# 4.7.4~git20120327, und "~" sortiert unter der leeren Zeichenkette.
set -e
cd "$(dirname "$0")/.."

VERSION=${1:-$(sed -n 's/^version = "\(.*\)"/\1/p' dienst/Cargo.toml | head -1)}
STAGE=build/stage-meego
rm -rf "$STAGE"

for b in wienzufuss wzf-dienst wzf-schritte; do
    [ -x build/meego/$b ] || { echo "build/meego/$b fehlt -- erst tools/build-meego.sh" >&2; exit 1; }
done
[ -f meego/icons/icon-80.png ] || python3 icons/make-icons.py

mkdir -p "$STAGE/opt/wienzufuss/bin" "$STAGE/opt/wienzufuss/qml" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/80x80/apps" \
         "$STAGE/usr/share/dbus-1/services" \
         "$STAGE/etc/init/apps" \
         "$STAGE/DEBIAN"

cp build/meego/wienzufuss build/meego/wzf-dienst build/meego/wzf-schritte "$STAGE/opt/wienzufuss/bin/"
chmod 755 "$STAGE/opt/wienzufuss/bin/"*
cp meego/qml/*.qml meego/qml/*.js "$STAGE/opt/wienzufuss/qml/"
# Schrift und Foto der Einloese-Seiten, falls tools/apk-vorlage.py sie aus
# einer APK geholt hat (nie im Repo).
if [ -d build/vorlage ] && [ -n "$(ls build/vorlage 2>/dev/null)" ]; then
    mkdir -p "$STAGE/opt/wienzufuss/qml/vorlage"
    cp build/vorlage/* "$STAGE/opt/wienzufuss/qml/vorlage/"
fi
cp meego/wienzufuss.desktop "$STAGE/usr/share/applications/"
cp meego/org.smatkovi.WienZuFuss.Schritte.service "$STAGE/usr/share/dbus-1/services/"
cp meego/wienzufuss-schritte.conf "$STAGE/etc/init/apps/"
cp meego/postinst meego/prerm "$STAGE/DEBIAN/"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm"
cp meego/icons/icon-80.png "$STAGE/usr/share/icons/hicolor/80x80/apps/wienzufuss.png"

VERSION="$VERSION" STAGE="$STAGE" python3 - <<'PY'
import base64, io, os, textwrap
icon = base64.b64encode(open("meego/icons/icon-64.png", "rb").read()).decode("ascii")
text = io.open("meego/control.in", encoding="utf-8").read()
text = text.replace("@VERSION@", os.environ["VERSION"])
# Die base64-Zeilen brauchen je ein fuehrendes Leerzeichen, sonst zeigt der
# Programm-Manager kein Bild.
text = text.replace("@ICON@", "\n".join(" " + z for z in textwrap.wrap(icon, 76)))
io.open(os.environ["STAGE"] + "/DEBIAN/control", "w", encoding="utf-8").write(text)
PY

DEB="build/wienzufuss_${VERSION}_armel.deb"
python3 meego/mkdeb.py "$STAGE" "$DEB"
