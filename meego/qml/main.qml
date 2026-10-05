import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Wien zu Fuss fuer Harmattan. Eine Datei je Seite; ins Netz geht alles
// ueber den Dienst (Kontexteigenschaft "Dienst", Bausteine Anfrage.qml),
// die gezaehlten Schritte kommen vom Schrittdienst ("Schritte").
PageStackWindow {
    id: fenster
    showStatusBar: true
    initialPage: StartSeite { }
    Component.onCompleted: {
        theme.inverted = true
        if (startSeite !== "")
            pageStack.push(Qt.resolvedUrl(startSeite), { g: { id: 0, type: "gastronomy" } })
    }

    // Das Profil vom Server (GET v1/user), fuer alle Seiten.
    property variant nutzer: null
    property bool angemeldet: false

    // Nur nachfragen, solange die App sichtbar ist.
    Binding { target: Schritte; property: "aktiv"; value: platformWindow.active }

    function anmeldenZeigen() {
        var p = pageStack.currentPage
        if (p && p.istAnmeldung)
            return
        pageStack.push(Qt.resolvedUrl("AnmeldeSeite.qml"))
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

    // Kurze Meldung oben, verschwindet nach vier Sekunden. Selbst gebaut
    // statt InfoBanner aus com.nokia.extras: dessen Eigenschaften
    // unterscheiden sich zwischen Geraet und SDK.
    function meldung(text) {
        bannerText.text = text
        banner.opacity = 1
        bannerZeit.restart()
    }

    Rectangle {
        id: banner
        z: 100
        x: 8
        y: 44
        width: parent.width - 16
        height: bannerText.height + 32
        radius: 6
        color: "#e6202020"
        border.color: "#3790ad"
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Text {
            id: bannerText
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 32
            wrapMode: Text.WordWrap
            color: "white"
            font.pixelSize: 22
        }
        MouseArea { anchors.fill: parent; onClicked: banner.opacity = 0 }
        Timer { id: bannerZeit; interval: 4000; onTriggered: banner.opacity = 0 }
    }
}
