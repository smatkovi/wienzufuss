import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import "wzf.js" as W

// Wien zu Fuss fuer Sailfish. Eine Datei je Seite (pages/); ins Netz geht
// alles ueber den Dienst (Kontexteigenschaft "Dienst", components/
// Anfrage.qml), die gezaehlten Schritte kommen vom Schrittdienst
// ("Schritte").
ApplicationWindow {
    id: fenster
    initialPage: Component { StartSeite { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations

    // Das Profil vom Server (GET v1/user), fuer alle Seiten.
    property var nutzer: null
    property bool angemeldet: false
    // Vom Schrittdienst (JSON), auch fuer das Titelbild.
    property var stand: W.json(Schritte.stand, null)

    // Nur nachfragen, solange die App vorne ist.
    Binding { target: Schritte; property: "aktiv"; value: Qt.application.state === Qt.ApplicationActive }

    function anmeldenZeigen() {
        var p = pageStack.currentPage
        if (p && p.istAnmeldung)
            return
        pageStack.push(Qt.resolvedUrl("pages/AnmeldeSeite.qml"))
    }

    // Jede Seite reicht Fehler hierher: ist die Anmeldung weg, geht es zur
    // Anmeldeseite.
    function fehler(text) {
        if (W.abgemeldet(text)) {
            angemeldet = false
            nutzer = null
            anmeldenZeigen()
            return true
        }
        return false
    }

    function meldung(text) {
        notiz.text = text
        notiz.show()
    }

    Notice {
        id: notiz
        duration: Notice.Long
    }
}
