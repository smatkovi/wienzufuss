import QtQuick 1.1
import com.nokia.meego 1.1

// Gastronomie-Gutschein einloesen: die Seite der Android-App
// (OriginalEinloesen.qml), ohne die Harmattan-Werkzeugleiste.
Page {
    id: seite
    property variant g: null
    tools: null
    orientationLock: PageOrientation.LockPortrait

    onStatusChanged: {
        if (status === PageStatus.Activating)
            fenster.showToolBar = false
        else if (status === PageStatus.Deactivating)
            fenster.showToolBar = true
    }

    OriginalEinloesen {
        anchors.fill: parent
        onZurueck: pageStack.pop()
        onPinSenden: pageStack.push(Qt.resolvedUrl("EingeloestOriginalSeite.qml"),
                                    { werte: { id: seite.g.id, code: pin } })
        onQrScannen: pageStack.push(Qt.resolvedUrl("QrScanSeite.qml"), { g: seite.g })
    }
}
