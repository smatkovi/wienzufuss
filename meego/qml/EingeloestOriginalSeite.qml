import QtQuick 1.1
import com.nokia.meego 1.1

// Loest ein und zeigt die Bestaetigung wie die Android-App
// (OriginalEingeloest.qml). "Zurueck zu den Gutscheinen" fuehrt zur Liste.
Page {
    id: seite
    property variant werte: null
    tools: null
    orientationLock: PageOrientation.LockPortrait

    onStatusChanged: {
        if (status === PageStatus.Activating)
            fenster.showToolBar = false
        else if (status === PageStatus.Deactivating)
            fenster.showToolBar = true
    }

    OriginalEingeloest {
        anchors.fill: parent
        werte: seite.werte
        onZurueck: pageStack.pop()
        onFertig: {
            fenster.showToolBar = true
            var liste = pageStack.find(function(p) { return p.istGutscheine === true })
            if (liste)
                pageStack.pop(liste)
            else
                pageStack.pop()
        }
    }
}
