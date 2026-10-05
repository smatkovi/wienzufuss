import QtQuick 1.1

// Zahl gross, Beschriftung klein darunter -- fuer die Kennzahlen.
Column {
    id: wert
    property alias zahl: zahlText.text
    property alias text: beschriftung.text
    property color farbe: "white"
    property int groesse: 34
    spacing: 0
    Text {
        id: zahlText
        width: parent.width
        color: wert.farbe
        font.pixelSize: wert.groesse
        font.family: "Nokia Pure Text Light"
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
    Text {
        id: beschriftung
        width: parent.width
        color: "#8c8c8c"
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
