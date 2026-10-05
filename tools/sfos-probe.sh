#!/bin/sh
# Probelauf der Sailfish-QML im SDK-Ziel unter qemu, ohne Geraet.
#
#   tools/sfos-probe.sh 'js:pageStack.push(Qt.resolvedUrl("pages/RanglisteSeite.qml"))' warte:2000 ...
#
# Zeigt alle QML-Warnungen und -Fehler; gezeichnet wird nichts (siehe
# tools/sfos-probe/probe.cpp). Der Netzdienst laeuft mit WZF_ATTRAPPE=1.
set -e
cd "$(dirname "$0")/.."
WURZEL=$(pwd)
SDK=${SFOS_SDK:-/srv/sailfishos/sdks/sfossdk/sdk-chroot}
ZIEL=${SFOS_ZIEL:-SailfishOS-5.1.0.11-aarch64}
AUS=$WURZEL/build/sfos-probe
mkdir -p "$AUS/heim" "$AUS/qml"
rm -rf "$AUS/qml"/*
sh tools/sfos-original.sh
cp -r sailfish/qml/. "$AUS/qml/"
[ -d build/vorlage ] && cp -r build/vorlage "$AUS/qml/vorlage"
cp meego/qml/wzf.js "$AUS/qml/"
[ -x sailfish/prebuilt/aarch64/wzf-dienst ] || sh tools/build-dienst.sh aarch64
if [ ! -x "$AUS/probe" ] || [ tools/sfos-probe/probe.cpp -nt "$AUS/probe" ]; then
    "$SDK" bash -c "cd '$WURZEL' && sb2 -t '$ZIEL' sh -c '
        /usr/lib64/qt5/bin/moc meego/src/Dienst.h -o build/sfos-probe/moc_Dienst.cpp &&
        /usr/lib64/qt5/bin/moc meego/src/Schrittzaehler.h -o build/sfos-probe/moc_Schrittzaehler.cpp &&
        g++ -std=c++11 -fPIC -O1 -Imeego/src tools/sfos-probe/probe.cpp meego/src/Dienst.cpp meego/src/Schrittzaehler.cpp \
            build/sfos-probe/moc_Dienst.cpp build/sfos-probe/moc_Schrittzaehler.cpp -o build/sfos-probe/probe \
            \$(pkg-config --cflags --libs Qt5Quick Qt5Qml Qt5Gui Qt5DBus Qt5Core)'" 2>&1 | grep -v "SAILFISH_SDK\|bashrc\|bash_profile\|^ *fi$\|^ *\.\.\.$\|^ *if \[\[\|branch to\|^$\|configuration bits" || true
fi
"$SDK" bash -c "cd '$WURZEL' && sb2 -t '$ZIEL' env QT_QPA_PLATFORM=minimal QT_LOGGING_TO_CONSOLE=1 QT_LOGGING_RULES='*.debug=false;qml.debug=true' WZF_ATTRAPPE=1 HOME='$AUS/heim' \
    '$AUS/probe' '$WURZEL/sailfish/prebuilt/aarch64/wzf-dienst' '$AUS/qml/wienzufuss.qml' $(printf " '%s'" "$@")" 2>&1 \
    | grep -v "SAILFISH_SDK\|bashrc\|bash_profile\|^ *fi$\|^ *\.\.\.$\|^ *if \[\[\|branch to\|^$\|configuration bits\|wzf-dienst: .* ok in\|Wurzelzertifikate\|bereit$"
