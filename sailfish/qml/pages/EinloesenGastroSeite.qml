import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

// Gastronomie-Gutschein einloesen: die Seite der Android-App
// (components/OriginalEinloesen.qml, erzeugt aus der N9-Fassung).
Page {
    id: seite
    property var g: null
    allowedOrientations: Orientation.Portrait

    OriginalEinloesen {
        anchors.fill: parent
        onZurueck: pageStack.pop()
        onPinSenden: pageStack.push(Qt.resolvedUrl("EingeloestOriginalSeite.qml"),
                                    { werte: { id: seite.g.id, code: pin } })
        onQrScannen: pageStack.push(Qt.resolvedUrl("QrScanSeite.qml"), { g: seite.g })
    }
}
