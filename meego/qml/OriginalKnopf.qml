import QtQuick 1.1

// Eine Schaltflaeche wie in der Android-App (MaterialButton, Stile
// Button.Primary / Button.Secondary): eckig, 16 sp, fett, GROSS, etwas
// Zeichenabstand; primaer blau mit weisser Schrift, sekundaer weiss mit
// blauem Rand. Reines QtQuick -- die Sailfish-Fassung entsteht beim Bauen
// durch Tausch der import-Zeile.
Item {
    id: knopf
    property real dp: 1
    property string text: ""
    property bool primaer: true
    property bool aktiv: true
    property string schrift: ""
    signal clicked

    height: 48 * dp
    // Material-Knoepfe haben oben und unten je 6 dp Luft (mtrl_btn_inset).
    Rectangle {
        id: flaeche
        anchors { fill: parent; topMargin: 6 * knopf.dp; bottomMargin: 6 * knopf.dp }
        color: knopf.primaer ? (knopf.aktiv ? (maus.pressed ? "#2c7690" : "#3790ad") : "#993790ad")
                             : (maus.pressed ? "#e6f1f5" : "white")
        border.width: knopf.primaer ? 0 : Math.max(1, knopf.dp)
        border.color: "#3790ad"
    }
    // Schatten der erhabenen Primaerknoepfe (elevation 2 dp)
    Rectangle {
        visible: knopf.primaer
        anchors { left: flaeche.left; right: flaeche.right; top: flaeche.bottom }
        height: Math.max(1, knopf.dp)
        color: "#22000000"
    }
    // Natuerliche Breite bei 16 dp: passt der Text nicht, wird er kleiner
    // statt abgeschnitten (die Schrift des Geraets ist breiter als Roboto).
    Text {
        id: mass
        visible: false
        text: knopf.text.toUpperCase()
        font.pixelSize: 16 * knopf.dp
        font.bold: true
        font.letterSpacing: 16 * knopf.dp * 0.089
        font.family: knopf.schrift
    }
    Text {
        property real faktor: Math.min(1, (flaeche.width - 24 * knopf.dp) / Math.max(1, mass.paintedWidth))
        anchors.centerIn: flaeche
        horizontalAlignment: Text.AlignHCenter
        text: knopf.text.toUpperCase()
        color: knopf.primaer ? "white" : "#3790ad"
        font.pixelSize: 16 * knopf.dp * faktor
        font.bold: true
        font.letterSpacing: 16 * knopf.dp * 0.089 * faktor
        font.family: knopf.schrift
    }
    MouseArea {
        id: maus
        anchors.fill: parent
        enabled: knopf.aktiv
        onClicked: knopf.clicked()
    }
}
