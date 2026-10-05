import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge
        Column {
            id: inhalt
            width: parent.width
            PageHeader { title: "Über diese App"; description: "Version " + appVersion }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                font.pixelSize: Theme.fontSizeSmall
                onLinkActivated: Qt.openUrlExternally(link)
                text: "<style>a:link{color:" + Theme.highlightColor + "}</style>"
                      + "<p><b>Wien zu Fuß</b> für Sailfish OS – ein inoffizieller Client. Nicht von der Stadt Wien "
                      + "oder der Mobilitätsagentur, ohne deren Unterstützung.</p>"
                      + "<p>Er spricht dieselbe Schnittstelle wie die Android-App: Anmeldung über Firebase, "
                      + "Ranking, Challenges, Gutscheine und Rückblick über wzfapp.wienzufuss.at.</p>"
                      + "<p>Die Schritte zählt dieses Telefon selbst – mit seinem eingebauten Schrittzähler, wenn "
                      + "sensorfw ihn anbietet, sonst auf Wunsch mit dem Beschleunigungssensor. Übertragen werden "
                      + "nur echte, gezählte Schritte – es gibt keine Eingabe von Hand.</p>"
                      + "<p>Quellen: <a href=\"https://github.com/smatkovi/wienzufuss\">github.com/smatkovi/wienzufuss</a>"
                      + " · GPLv3</p>"
            }
        }
    }
}
