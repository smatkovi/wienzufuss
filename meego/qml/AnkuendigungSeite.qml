import QtQuick 1.1
import com.nokia.meego 1.0

// Eine Ankuendigung von der Webseite der Mobilitaetsagentur.
//
// Bewusst ohne Knopf zum Mitmachen: solange die Aktion nicht laeuft, kennt
// die Schnittstelle sie nicht, es gibt also nichts anzumelden. Das steht
// auch so da, damit niemand vergeblich sucht.
Page {
    id: seite
    property string titel: ""
    property string text: ""

    tools: werkzeuge

    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: inhalt.height
        clip: true

        Column {
            id: inhalt
            width: parent.width
            spacing: 12

            Label {
                width: parent.width
                font.pixelSize: 28
                wrapMode: Text.WordWrap
                text: seite.titel
            }

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: seite.text
            }

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: 18
                color: "#8c8c8c"
                text: "Angekündigt auf mobilitaetsagentur.at. Sobald die Aktion läuft, "
                      + "erscheint sie oben unter „Aktuelle Challenges“ und lässt sich "
                      + "dort mitmachen."
            }
        }
    }

    ToolBarLayout {
        id: werkzeuge
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
    }
}
