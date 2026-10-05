import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"

// Loest ein und zeigt die Bestaetigung wie die Android-App
// (components/OriginalEingeloest.qml). "Zurueck zu den Gutscheinen" fuehrt
// zur Liste.
Page {
    id: seite
    property var werte: null
    allowedOrientations: Orientation.Portrait

    OriginalEingeloest {
        anchors.fill: parent
        werte: seite.werte
        onZurueck: pageStack.pop()
        onFertig: {
            var liste = pageStack.find(function(p) { return p.istGutscheine === true })
            if (liste)
                pageStack.pop(liste)
            else
                pageStack.pop()
        }
    }
}
