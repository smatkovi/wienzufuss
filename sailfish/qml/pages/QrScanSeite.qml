import QtQuick 2.0
import QtMultimedia 5.0
import Sailfish.Silica 1.0
import "../components"

// QR-Code im Lokal lesen, wie die Android-App: Kamerabild mit Rahmen, nach
// dem Fund "Code einloesen?". Wie im Briar-Port lesen zwei Leser
// nebeneinander:
//
//  * der Filter der Kamera-App (Amber.QrFilter, ZXing) im Videostrom, wenn
//    das Paket qr-filter-qml-plugin da ist (QrLive.qml) -- sofort;
//  * sonst bzw. zusaetzlich nach ein paar Sekunden: alle 1,5 s ein Foto,
//    gelesen mit quirc im Arbeitsfaden (src/QrLeser.h).
Page {
    id: seite
    property var g: null
    property real dp: Math.min(width, height) / 360
    allowedOrientations: Orientation.Portrait

    property var filter: null
    property bool fertig: false
    property bool beschaeftigt: false
    property int zaehler: 0
    property bool grosseAufnahme: false
    property int fehlschlaege: 0

    Component.onCompleted: {
        var bauplan = Qt.createComponent(Qt.resolvedUrl("QrLive.qml"))
        if (bauplan.status !== Component.Ready)
            return
        seite.filter = bauplan.createObject(seite)
        if (seite.filter)
            seite.filter.decodeFinished.connect(seite.gefunden)
    }

    function gefunden(text) {
        text = String(text ? text : "").replace(/^\s+|\s+$/g, "")
        if (seite.fertig || text === "" || aufsatz.gelesen !== "")
            return
        aufsatz.gelesen = text
    }

    Binding {
        target: seite.filter
        property: "active"
        value: seite.status === PageStatus.Active && !seite.fertig && aufsatz.gelesen === ""
        when: seite.filter !== null
    }

    Connections {
        target: QrLeser
        onFertig: {
            seite.beschaeftigt = false
            seite.gefunden(text)
        }
    }

    FontLoader { id: normal; source: Qt.resolvedUrl("../vorlage/neo_sans_pro_regular.otf") }

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

    Camera {
        id: kamera
        cameraState: seite.status === PageStatus.Active && !seite.fertig ? Camera.ActiveState : Camera.LoadedState
        captureMode: Camera.CaptureStillImage
        focus.focusMode: Camera.FocusContinuous
        imageCapture {
            // Ein QR-Code braucht keine acht Millionen Bildpunkte; volle
            // Aufloesung haelt Sucher und Autofokus nur auf.
            resolution: seite.grosseAufnahme ? Qt.size(-1, -1) : Qt.size(1280, 960)
            onImageSaved: {
                if (!QrLeser.lesen(path))
                    seite.beschaeftigt = false
            }
            onCaptureFailed: {
                seite.beschaeftigt = false
                // Nimmt das Geraet die Groesse nicht an: zurueck auf das, was
                // die Kamera selbst waehlt.
                seite.fehlschlaege++
                if (seite.fehlschlaege >= 2)
                    seite.grosseAufnahme = true
            }
        }
    }

    VideoOutput {
        id: bild
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        source: kamera
        fillMode: VideoOutput.PreserveAspectCrop
        filters: seite.filter ? [ seite.filter ] : []
    }

    // Dem Filter ein paar Sekunden Vorsprung; ohne Filter gleich Fotos.
    Timer {
        id: vorsprung
        interval: 4000
        running: seite.status === PageStatus.Active && seite.filter !== null
    }
    Timer {
        interval: 1500
        repeat: true
        running: seite.status === PageStatus.Active && !seite.fertig && aufsatz.gelesen === ""
                 && (seite.filter === null || !vorsprung.running)
        onTriggered: {
            if (seite.beschaeftigt || !kamera.imageCapture.ready)
                return
            seite.beschaeftigt = true
            seite.zaehler++
            kamera.imageCapture.captureToLocation(StandardPaths.temporary + "/wzf-qr-" + seite.zaehler + ".jpg")
        }
    }

    OriginalScanner {
        id: aufsatz
        anchors.fill: bild
        dp: seite.dp
        schrift: normal.status === FontLoader.Ready ? normal.name : ""
        unten: kamera.cameraStatus === Camera.UnavailableStatus || kamera.errorCode !== Camera.NoError
               ? "Die Kamera lässt sich nicht öffnen – bitte nach dem PIN-Code fragen."
               : "Nach QR-Code suchen…"
        onNein: if (seite.filter && seite.filter.clearResult) seite.filter.clearResult()
        onJa: {
            seite.fertig = true
            pageStack.push(Qt.resolvedUrl("EingeloestOriginalSeite.qml"), { werte: { id: seite.g.id, code: code } })
        }
    }
}
