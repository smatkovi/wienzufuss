#!/bin/sh
# Baut alles fuer das N9/N950 nach build/meego/:
#
#   wzf-dienst    Netzdienst (Rust, statisch gegen musl)
#   wzf-schritte  Schrittdienst (Qt 4.7 + QtMobility Sensors)
#   wienzufuss    Oberflaeche (Qt 4.7, QML 1, Harmattan-Komponenten)
#
#   tools/build-meego.sh
#
# Die C++-Teile mit MADDEs GCC 4.4.1 gegen den Harmattan-Sysroot: das ist der
# Compiler, mit dem das Qt auf dem Geraet gebaut ist, also passt die
# C++-Laufzeit. Der Preis ist C++98. moc kommt aus dem Simulator-Qt
# desselben SDK (4.7.4, gleiche moc-Revision wie auf dem Geraet).
set -e
cd "$(dirname "$0")/.."
WURZEL=$(pwd)
mkdir -p build/meego

# Symbole und die Vorlagen der Einloese-Seiten (Schrift, Foto) -- aus der
# eigenen APK, wenn sie da ist; sonst eigenes Symbol und Systemschrift.
python3 icons/make-icons.py
python3 tools/apk-vorlage.py

if [ ! -x build/meego/wzf-dienst ] || [ -n "$(find dienst/src dienst/Cargo.toml -newer build/meego/wzf-dienst 2>/dev/null)" ]; then
    sh tools/build-dienst.sh meego
fi

MADDE=${MADDE:-$HOME/QtSDK/Madde}
CXX=${CXX_HARMATTAN:-$MADDE/toolchains/arm-2009q3-67-arm-none-linux-gnueabi-x86_64-unknown-linux-gnu/arm-2009q3-67/bin/arm-none-linux-gnueabi-g++}
SYSROOT=${SYSROOT:-$MADDE/sysroots/harmattan_sysroot_10.2011.34-1_slim}
MOC=${MOC:-$HOME/QtSDK/Simulator/Qt/gcc/bin/moc}
if [ ! -x "$CXX" ]; then
    echo "== Harmattan-C++ fehlt ($CXX) -- nur der Dienst wurde gebaut" >&2
    exit 0
fi
QTINC=$SYSROOT/usr/include/qt4
# GStreamer 0.10 aus demselben Sysroot, fuer den QR-Sucher (meego/src/Sucher.h).
# pkg-config wuerde auf den Bauwirt zeigen statt ins Sysroot.
GSTINC="-I$SYSROOT/usr/include/gstreamer-0.10 -I$SYSROOT/usr/include/glib-2.0 \
 -I$SYSROOT/usr/lib/glib-2.0/include -I$SYSROOT/usr/include/libxml2"
CC=${CC_HARMATTAN:-$(dirname "$CXX")/arm-none-linux-gnueabi-gcc}
CXXFLAGS="--sysroot=$SYSROOT -O2 -Wall -DQT_NO_DEBUG -I$QTINC"
for m in QtCore QtGui QtNetwork QtDeclarative QtDBus QtSensors QtMobility; do
    CXXFLAGS="$CXXFLAGS -I$QTINC/$m"
done
LDFLAGS="--sysroot=$SYSROOT -Wl,-O1 -Wl,--as-needed -s -L$SYSROOT/usr/lib"

OBJ=/tmp/wzf-meego-obj
mkdir -p "$OBJ"

# --- Schrittdienst -----------------------------------------------------------
"$MOC" schritte/Schrittdienst.h -o "$OBJ/moc_Schrittdienst.cpp"
"$MOC" schritte/meego/main.cpp -o "$OBJ/main.moc"
for q in schritte/Tagebuch.cpp schritte/Schrittdienst.cpp "$OBJ/moc_Schrittdienst.cpp"; do
    "$CXX" $CXXFLAGS -I"$WURZEL/schritte" -c "$q" -o "$OBJ/$(basename "$q" .cpp).o"
done
"$CXX" $CXXFLAGS -I"$WURZEL/schritte" -I"$OBJ" -DNETZDIENST='"/opt/wienzufuss/bin/wzf-dienst"' \
    -c schritte/meego/main.cpp -o "$OBJ/schritte-main.o"
"$CXX" $LDFLAGS -o build/meego/wzf-schritte \
    "$OBJ/schritte-main.o" "$OBJ/Tagebuch.o" "$OBJ/Schrittdienst.o" "$OBJ/moc_Schrittdienst.o" \
    -lQtSensors -lQtDBus -lQtCore -lpthread
echo "== wzf-schritte fertig ($(stat -c %s build/meego/wzf-schritte) B)"

# --- Oberflaeche ---------------------------------------------------------------
if [ -f meego/main.cpp ]; then
    for h in meego/src/*.h; do
        "$MOC" "$h" -o "$OBJ/moc_$(basename "$h" .h).cpp"
    done
    OBJE=""
    for q in meego/main.cpp meego/src/*.cpp "$OBJ"/moc_Dienst.cpp "$OBJ"/moc_Schrittzaehler.cpp "$OBJ"/moc_Sucher.cpp; do
        [ -f "$q" ] || continue
        o="$OBJ/ui-$(basename "$q" .cpp).o"
        "$CXX" $CXXFLAGS $GSTINC -I"$WURZEL/meego" -I"$WURZEL/qr" -c "$q" -o "$o"
        OBJE="$OBJE $o"
    done
    # QR: quirc, vier C-Dateien (qr/quirc, ISC).
    for q in quirc decode identify version_db; do
        "$CC" --sysroot="$SYSROOT" -O2 -std=gnu99 -I"$WURZEL/qr/quirc" -c "qr/quirc/$q.c" -o "$OBJ/quirc_$q.o"
        OBJE="$OBJE $OBJ/quirc_$q.o"
    done
    "$CXX" $LDFLAGS -o build/meego/wienzufuss $OBJE \
        -lQtDeclarative -lQtGui -lQtDBus -lQtCore -lpthread \
        -lgstapp-0.10 -lgstbase-0.10 -lgstreamer-0.10 -lgobject-2.0 -lglib-2.0 -lm
    echo "== wienzufuss fertig ($(stat -c %s build/meego/wienzufuss) B)"
fi
