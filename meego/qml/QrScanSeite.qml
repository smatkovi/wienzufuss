import QtQuick 1.1
import com.nokia.meego 1.1
import WienZuFuss 1.0

// QR-Code im Lokal lesen, wie die Android-App: Kamerabild mit Rahmen, nach
// dem Fund "Code einloesen?". Das Kamerabild liefert der Sucher aus dem
// Briar-Port (src/Sucher.h, GStreamer subdevsrc2), gelesen wird mit quirc.
Page {
    id: seite
    property variant g: null
    property real dp: Math.min(width, height) / 360
    tools: null
    orientationLock: PageOrientation.LockPortrait

    onStatusChanged: {
        if (status === PageStatus.Activating) {
            fenster.showToolBar = false
        } else if (status === PageStatus.Active) {
            if (!sucher.starten())
                aufsatz.unten = "Die Kamera lässt sich nicht öffnen – bitte nach dem PIN-Code fragen."
        } else if (status === PageStatus.Deactivating) {
            sucher.anhalten()
        }
    }

    FontLoader { id: normal; source: Qt.resolvedUrl("vorlage/neo_sans_pro_regular.otf") }

    Rectangle { anchors.fill: parent; color: "black" }

    OriginalKopf {
        id: kopf
        anchors { top: parent.top; left: parent.left; right: parent.right }
        dp: seite.dp
        titel: "QR-Code Scanner"
        schrift: normal.status === FontLoader.Ready ? normal.name : ""
        onZurueck: pageStack.pop()
        z: 2
    }

    Sucher {
        id: sucher
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        onGelesen: aufsatz.gelesen = text
    }

    OriginalScanner {
        id: aufsatz
        anchors.fill: sucher
        dp: seite.dp
        schrift: normal.status === FontLoader.Ready ? normal.name : ""
        onNein: sucher.weitersuchen()
        onJa: {
            sucher.anhalten()
            pageStack.push(Qt.resolvedUrl("EingeloestOriginalSeite.qml"),
                           { werte: { id: seite.g.id, code: code } })
        }
    }
}
