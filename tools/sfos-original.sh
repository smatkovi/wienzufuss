#!/bin/sh
# Die Einloese-Seiten im Original-Look (meego/qml/Original*.qml) sind reines
# QtQuick und laufen auch unter Sailfish -- dort mit "import QtQuick 2.0"
# und der Vorlage einen Ordner hoeher (qml/vorlage statt qml/components/vorlage).
# Erzeugt die Sailfish-Fassungen in sailfish/qml/components/ (nicht im Repo).
set -e
cd "$(dirname "$0")/.."
for f in meego/qml/Original*.qml; do
    sed -e 's/^import QtQuick 1\.1$/import QtQuick 2.0/' \
        -e 's#Qt.resolvedUrl("vorlage/")#Qt.resolvedUrl("../vorlage/")#' \
        "$f" > "sailfish/qml/components/$(basename "$f")"
done
