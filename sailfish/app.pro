TARGET = wienzufuss

CONFIG += sailfishapp
QT += dbus

isEmpty(VERSION) {
    VERSION = 0.1.3
}
DEFINES += APP_VERSION=\\\"$$VERSION\\\"
DEFINES += NETZDIENST=\\\"/usr/libexec/wienzufuss/wzf-dienst\\\"

# Die Bruecke zum Netzdienst und zum Schrittdienst ist dieselbe wie auf dem
# N9 (Qt 4 und Qt 5 aus einer Quelle).
INCLUDEPATH += ../meego/src
SOURCES += src/main.cpp ../meego/src/Dienst.cpp ../meego/src/Schrittzaehler.cpp
HEADERS += ../meego/src/Dienst.h ../meego/src/Schrittzaehler.h

# Die Hilfsfunktionen teilen sich beide Oberflaechen.
wzfjs.files = ../meego/qml/wzf.js
wzfjs.path = /usr/share/wienzufuss/qml
INSTALLS += wzfjs

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# Beide Teilprojekte bauen im selben Ordner; ohne eigene Objektordner
# ueberschreiben sich ihre main.o.
OBJECTS_DIR = .obj-app
MOC_DIR = .moc-app
