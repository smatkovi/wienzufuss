import QtQuick 2.0
import Sailfish.Silica 1.0

// Eine antippbare Zeile: oben gross, darunter klein, rechts der Pfeil.
BackgroundItem {
    id: eintrag
    property alias titel: titelLabel.text
    property alias beschreibung: beschreibungLabel.text
    height: Theme.itemSizeMedium
    Column {
        anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; right: pfeil.left
                  rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
        Label {
            id: titelLabel
            width: parent.width
            color: eintrag.highlighted ? Theme.highlightColor : Theme.primaryColor
            truncationMode: TruncationMode.Fade
        }
        Label {
            id: beschreibungLabel
            width: parent.width
            visible: text !== ""
            font.pixelSize: Theme.fontSizeExtraSmall
            color: eintrag.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }
    }
    Image {
        id: pfeil
        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
        source: "image://theme/icon-m-right?" + (eintrag.highlighted ? Theme.highlightColor : Theme.primaryColor)
    }
}
