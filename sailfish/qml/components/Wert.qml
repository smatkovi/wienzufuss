import QtQuick 2.0
import Sailfish.Silica 1.0

// Zahl gross, Beschriftung klein darunter.
Column {
    id: wert
    property alias zahl: zahlLabel.text
    property alias text: beschriftung.text
    property color farbe: Theme.highlightColor
    property real groesse: Theme.fontSizeLarge
    Label {
        id: zahlLabel
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        color: wert.farbe
        font.pixelSize: wert.groesse
        truncationMode: TruncationMode.Fade
    }
    Label {
        id: beschriftung
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.fontSizeExtraSmall
        color: Theme.secondaryColor
        wrapMode: Text.WordWrap
    }
}
