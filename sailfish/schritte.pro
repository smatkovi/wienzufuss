# wzf-schritte: zaehlt im Hintergrund (systemd-Benutzerdienst).
TEMPLATE = app
TARGET = wzf-schritte
QT = core dbus network sensors
CONFIG += link_pkgconfig
PKGCONFIG += keepalive

DEFINES += NETZDIENST=\\\"/usr/libexec/wienzufuss/wzf-dienst\\\"
INCLUDEPATH += ../schritte ../schritte/sailfish
SOURCES += \
    ../schritte/Tagebuch.cpp \
    ../schritte/Schrittdienst.cpp \
    ../schritte/sailfish/Hardwarezaehler.cpp \
    ../schritte/sailfish/main.cpp
HEADERS += \
    ../schritte/Tagebuch.h \
    ../schritte/Schrittdienst.h \
    ../schritte/Schritterkennung.h \
    ../schritte/sailfish/Hardwarezaehler.h

target.path = /usr/libexec/wienzufuss
INSTALLS += target

OBJECTS_DIR = .obj-schritte
MOC_DIR = .moc-schritte
