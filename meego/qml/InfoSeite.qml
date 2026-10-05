import QtQuick 1.1
import com.nokia.meego 1.1

Page {
    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
    }
    Kopf { id: kopf; anchors.top: parent.top; titel: "Über diese App" }
    Flickable {
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: t.height + 32
        clip: true
        Text {
            id: t
            x: 16
            y: 16
            width: parent.width - 32
            wrapMode: Text.WordWrap
            textFormat: Text.RichText
            color: "white"
            font.pixelSize: 22
            onLinkActivated: Dienst.oeffnen(link)
            text: "<p><b>Wien zu Fuß</b> für das N9 – ein inoffizieller Client. Nicht von der Stadt Wien "
                  + "oder der Mobilitätsagentur, ohne deren Unterstützung.</p>"
                  + "<p>Er spricht dieselbe Schnittstelle wie die Android-App: Anmeldung über Firebase, "
                  + "Ranking, Challenges, Gutscheine und Rückblick über wzfapp.wienzufuss.at.</p>"
                  + "<p>Die Schritte zählt dieses Telefon selbst, mit dem Beschleunigungssensor. Übertragen werden "
                  + "nur echte, gezählte Schritte – es gibt keine Eingabe von Hand.</p>"
                  + "<p>Quellen: <a href=\"https://github.com/smatkovi/wienzufuss\">github.com/smatkovi/wienzufuss</a>"
                  + " · GPLv3</p>"
        }
    }
}
