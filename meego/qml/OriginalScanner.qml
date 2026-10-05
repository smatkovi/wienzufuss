import QtQuick 1.1

// Was ueber dem Kamerabild liegt, wie in der Android-App (custom_qr_scanner):
// abgedunkelt bis auf ein 250-dp-Quadrat mit vier weissen Eckwinkeln, oben
// "Halte die Kamera ruhig ...", unten "Nach QR-Code suchen ...". Danach die
// Frage "Code einloesen?" mit Nein/Ja (AlertDialog der App). Reines
// QtQuick wie die anderen Original*.qml -- das Kamerabild selbst kommt von
// der Plattform (N9: Sucher, Sailfish: VideoOutput).
Item {
    id: aufsatz
    property real dp: 1
    property string schrift: ""
    property string unten: "Nach QR-Code suchen…"
    property string gelesen: ""          // nicht leer: die Frage ist offen
    signal ja(string code)
    signal nein

    property real seite: 250 * dp
    property real links: (width - seite) / 2
    property real oben: (height - seite) / 2

    // Abdunkeln (#60000000) rund um das Quadrat
    Rectangle { x: 0; y: 0; width: parent.width; height: aufsatz.oben; color: "#60000000" }
    Rectangle { x: 0; y: aufsatz.oben + aufsatz.seite; width: parent.width; height: parent.height - y; color: "#60000000" }
    Rectangle { x: 0; y: aufsatz.oben; width: aufsatz.links; height: aufsatz.seite; color: "#60000000" }
    Rectangle { x: aufsatz.links + aufsatz.seite; y: aufsatz.oben; width: parent.width - x; height: aufsatz.seite; color: "#60000000" }

    // ic_edge: 52 dp, Balken 4 dp, in jeder Ecke gedreht
    Repeater {
        model: 4
        Item {
            width: 52 * aufsatz.dp
            height: 52 * aufsatz.dp
            x: (index === 0 || index === 3) ? aufsatz.links + aufsatz.seite - width : aufsatz.links
            y: (index === 0 || index === 1) ? aufsatz.oben + aufsatz.seite - height : aufsatz.oben
            rotation: index * 90
            Rectangle { x: 0; y: 48 * aufsatz.dp; width: 52 * aufsatz.dp; height: 4 * aufsatz.dp; color: "white" }
            Rectangle { x: 48 * aufsatz.dp; y: 0; width: 4 * aufsatz.dp; height: 52 * aufsatz.dp; color: "white" }
        }
    }

    Text {
        anchors { top: parent.top; topMargin: 64 * aufsatz.dp; horizontalCenter: parent.horizontalCenter }
        width: parent.width - 24 * aufsatz.dp
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: "white"
        font.pixelSize: 17 * aufsatz.dp
        font.family: aufsatz.schrift
        text: "Halte die Kamera ruhig über den QR-Code um ihn einzuscannen."
    }
    Text {
        anchors { bottom: parent.bottom; bottomMargin: 24 * aufsatz.dp; horizontalCenter: parent.horizontalCenter }
        width: parent.width - 24 * aufsatz.dp
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: "white"
        font.pixelSize: 17 * aufsatz.dp
        font.family: aufsatz.schrift
        text: aufsatz.unten
    }

    // --- "Code einloesen?" (Material-AlertDialog) ----------------------------
    Rectangle {
        anchors.fill: parent
        color: "#99000000"
        visible: aufsatz.gelesen !== ""
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 48 * aufsatz.dp
            height: frageSpalte.height
            radius: 4 * aufsatz.dp
            color: "white"
            Column {
                id: frageSpalte
                width: parent.width
                Item { width: 1; height: 24 * aufsatz.dp }
                Text {
                    x: 24 * aufsatz.dp
                    width: parent.width - 48 * aufsatz.dp
                    wrapMode: Text.WordWrap
                    color: "#1a1a1a"
                    font.pixelSize: 20 * aufsatz.dp
                    font.family: aufsatz.schrift
                    text: "Code einlösen?"
                }
                Item { width: 1; height: 28 * aufsatz.dp }
                Row {
                    anchors { right: parent.right; rightMargin: 8 * aufsatz.dp }
                    spacing: 8 * aufsatz.dp
                    Repeater {
                        model: [ "Nein", "Ja" ]
                        Item {
                            width: knopfText.width + 16 * aufsatz.dp
                            height: 36 * aufsatz.dp
                            Rectangle { anchors.fill: parent; color: "#1f3790ad"; visible: maus.pressed }
                            Text {
                                id: knopfText
                                anchors.centerIn: parent
                                text: modelData.toUpperCase()
                                color: "#3790ad"
                                font.pixelSize: 14 * aufsatz.dp
                                font.bold: true
                                font.letterSpacing: 14 * aufsatz.dp * 0.089
                            }
                            MouseArea {
                                id: maus
                                anchors.fill: parent
                                onClicked: {
                                    var code = aufsatz.gelesen
                                    aufsatz.gelesen = ""
                                    if (index === 1)
                                        aufsatz.ja(code)
                                    else
                                        aufsatz.nein()
                                }
                            }
                        }
                    }
                }
                Item { width: 1; height: 8 * aufsatz.dp }
            }
        }
    }
}
