#!/bin/sh
# Baut die Sailfish-RPMs fuer armv7hl und aarch64 nach build/.
#
#   tools/build-sailfish.sh                # beide Ziele
#   tools/build-sailfish.sh aarch64        # nur eines
#
# Erst der Netzdienst (Rust, statisch) je Architektur nach
# sailfish/prebuilt/<arch>/, dann Oberflaeche und Schrittdienst mit mb2 in
# der Platform-SDK-Chroot. Gebaut wird gegen SailfishOS 5.1.0.11 -- das
# aelteste Ziel hier, und genau das, was auf dem kugo laeuft. Anderes Ziel:
# SFOS_ZIEL=SailfishOS-5.2.0.15 (ohne Architektur).
set -e
cd "$(dirname "$0")/.."
WURZEL=$(pwd)
SDK=${SFOS_SDK:-/srv/sailfishos/sdks/sfossdk/sdk-chroot}
ZIEL=${SFOS_ZIEL:-SailfishOS-5.1.0.11}
ARCHS=${1:-"armv7hl aarch64"}
VERSION=$(sed -n 's/^Version: *//p' sailfish/rpm/wienzufuss.spec | head -1)
mkdir -p build

# Symbole und die Vorlagen der Einloese-Seiten (siehe tools/build-meego.sh).
python3 icons/make-icons.py
python3 tools/apk-vorlage.py
sh tools/sfos-original.sh
rm -rf sailfish/qml/vorlage
if [ -d build/vorlage ] && [ -n "$(ls build/vorlage 2>/dev/null)" ]; then
    mkdir -p sailfish/qml/vorlage
    cp build/vorlage/* sailfish/qml/vorlage/
fi

for arch in $ARCHS; do
    if [ ! -x "sailfish/prebuilt/$arch/wzf-dienst" ] || \
       [ -n "$(find dienst/src dienst/Cargo.toml -newer "sailfish/prebuilt/$arch/wzf-dienst" 2>/dev/null)" ]; then
        sh tools/build-dienst.sh "$arch"
    fi
    # In-place-Bau: die Makefiles des vorigen Ziels zeigen auf dessen qmake.
    ( cd sailfish && rm -rf Makefile* .obj-* .moc-* .qmake.stash wienzufuss wzf-schritte installroot RPMS )
    echo "== mb2 $ZIEL-$arch"
    "$SDK" bash -c "cd '$WURZEL/sailfish' && mb2 -t '$ZIEL-$arch' build" > "build/mb2-$arch.log" 2>&1 || {
        tail -30 "build/mb2-$arch.log" >&2
        echo "== mb2 fuer $arch gescheitert, Protokoll: build/mb2-$arch.log" >&2
        exit 1
    }
    cp "sailfish/RPMS/wienzufuss-$VERSION-1.$arch.rpm" build/
    echo "== build/wienzufuss-$VERSION-1.$arch.rpm ($(stat -c %s "build/wienzufuss-$VERSION-1.$arch.rpm") B)"
done
( cd sailfish && rm -rf Makefile* .obj-* .moc-* .qmake.stash wienzufuss wzf-schritte installroot RPMS )
