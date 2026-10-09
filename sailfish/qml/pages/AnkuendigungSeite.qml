import QtQuick 2.0
import Sailfish.Silica 1.0

// Eine Ankuendigung von der Webseite der Mobilitaetsagentur.
//
// Bewusst ohne Knopf zum Mitmachen: solange die Challenge nicht laeuft,
// kennt die Schnittstelle sie nicht, und es gibt nichts anzumelden. Das
// steht auch so da, damit niemand vergeblich sucht.
Page {
    id: page
    property string titel: ""
    property string text: ""

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height

        Column {
            id: inhalt
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader { title: titel }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                text: page.text
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: "Angekündigt auf mobilitaetsagentur.at. Sobald die Aktion läuft, "
                      + "erscheint sie oben unter „Aktuelle Challenges“ und lässt sich dort "
                      + "mitmachen."
            }

            Item { width: 1; height: Theme.paddingLarge }
        }
    }
}
