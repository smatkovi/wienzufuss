# Wien zu Fuss fuer Sailfish OS: Oberflaeche und Schrittdienst.
# Der Netzdienst (Rust) kommt fertig gebaut aus prebuilt/<arch>/
# (tools/build-dienst.sh) und wird in der spec installiert.
TEMPLATE = subdirs
SUBDIRS = app.pro schritte.pro

OTHER_FILES += \
    rpm/wienzufuss.spec \
    wienzufuss.desktop \
    wienzufuss-schritte.service \
    org.smatkovi.WienZuFuss.Schritte.service
