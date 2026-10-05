import QtQuick 1.1

// Gastronomie-Gutschein einloesen, Seite fuer Seite wie in der Android-App
// (fragment_coupon_gastronomy_redeem): Hinweis, Karte "QR-Code",
// "oder", Karte "PIN". Masse in dp wie dort; dp ergibt sich aus der
// Bildschirmbreite (360 dp = volle Breite). Schrift Neo Sans Pro, wenn
// tools/apk-vorlage.py sie aus der eigenen APK geholt hat.
//
// "PIN senden" loest nicht hier ein, sondern meldet pinSenden(): die
// Seite "Eingeloest" fragt den Server und zeigt Erfolg oder Fehler -- wie
// in der App.
Rectangle {
    id: seite
    property real dp: Math.min(width, height) / 360
    property string vorlage: Qt.resolvedUrl("vorlage/")
    property bool qrHinweis: false
    signal zurueck
    signal pinSenden(string pin)

    color: "#f7fbfc"

    FontLoader { id: normal; source: seite.vorlage + "neo_sans_pro_regular.otf" }
    property string schrift: normal.status === FontLoader.Ready ? normal.name : ""

    OriginalKopf {
        id: kopf
        anchors { top: parent.top; left: parent.left; right: parent.right }
        dp: seite.dp
        titel: "Einlösen"
        schrift: seite.schrift
        onZurueck: seite.zurueck()
        z: 2
    }

    Flickable {
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: spalte.height
        clip: true

        Column {
            id: spalte
            width: parent.width

            Item { width: 1; height: 24 * seite.dp }
            Text {
                x: 16 * seite.dp
                width: parent.width - 32 * seite.dp
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: "#717171"
                font.pixelSize: 14 * seite.dp
                font.family: seite.schrift
                text: "Frag vor Ort nach dem QR- oder PIN-Code, um den Gutschein einzulösen"
            }

            // --- Karte QR-Code --------------------------------------------------
            Item { width: 1; height: 32 * seite.dp }
            Rectangle {
                x: 16 * seite.dp
                width: parent.width - 32 * seite.dp
                height: qrSpalte.height
                color: "white"
                Column {
                    id: qrSpalte
                    width: parent.width
                    Item { width: 1; height: 32 * seite.dp }
                    Text {
                        x: 16 * seite.dp
                        width: parent.width - 32 * seite.dp
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: "#1a1a1a"
                        font.pixelSize: 18 * seite.dp
                        font.family: seite.schrift
                        text: "QR-Code fotografieren"
                    }
                    Item { width: 1; height: 26 * seite.dp }
                    OriginalKnopf {
                        x: 16 * seite.dp
                        width: parent.width - 32 * seite.dp
                        dp: seite.dp
                        text: "QR-Code fotografieren"
                        onClicked: seite.qrHinweis = !seite.qrHinweis
                    }
                    // Eine Kamera-Erkennung gibt es in diesem Client nicht.
                    Text {
                        x: 16 * seite.dp
                        width: parent.width - 32 * seite.dp
                        visible: seite.qrHinweis
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: "#717171"
                        font.pixelSize: 14 * seite.dp
                        font.family: seite.schrift
                        text: "QR-Codes kann diese App nicht lesen – bitte nach dem PIN-Code fragen."
                    }
                    Item { width: 1; height: 18 * seite.dp }
                }
            }

            // --- oder -----------------------------------------------------------
            Item { width: 1; height: 32 * seite.dp }
            Item {
                width: parent.width
                height: oder.height
                Rectangle {
                    anchors { left: parent.left; leftMargin: 16 * seite.dp; right: oder.left; rightMargin: 8 * seite.dp
                              verticalCenter: oder.verticalCenter }
                    height: Math.max(1, seite.dp)
                    color: "#3790ad"
                }
                Text {
                    id: oder
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "oder"
                    color: "#3790ad"
                    font.pixelSize: 14 * seite.dp
                    font.family: seite.schrift
                }
                Rectangle {
                    anchors { left: oder.right; leftMargin: 8 * seite.dp; right: parent.right; rightMargin: 16 * seite.dp
                              verticalCenter: oder.verticalCenter }
                    height: Math.max(1, seite.dp)
                    color: "#3790ad"
                }
            }

            // --- Karte PIN ------------------------------------------------------
            Item { width: 1; height: 32 * seite.dp }
            Rectangle {
                x: 16 * seite.dp
                width: parent.width - 32 * seite.dp
                height: pinSpalte.height
                color: "white"
                Column {
                    id: pinSpalte
                    width: parent.width
                    Item { width: 1; height: 24 * seite.dp }
                    Text {
                        x: 16 * seite.dp
                        width: parent.width - 32 * seite.dp
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: "#1a1a1a"
                        font.pixelSize: 18 * seite.dp
                        font.family: seite.schrift
                        text: "PIN-Code eingeben, um Gutschein einzulösen"
                    }
                    Item { width: 1; height: 16 * seite.dp }
                    // TextInputLayout (OutlinedBox), 200 dp breit
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 200 * seite.dp
                        height: 56 * seite.dp
                        radius: 4 * seite.dp
                        color: "white"
                        border.width: pin.activeFocus ? 2 * seite.dp : Math.max(1, seite.dp)
                        border.color: pin.activeFocus ? "#3790ad" : "#8a8a8a"
                        Text {
                            anchors.centerIn: parent
                            visible: pin.text === ""
                            text: "PIN-Code eingeben"
                            color: "#8a8a8a"
                            font.pixelSize: 16 * seite.dp
                            font.family: seite.schrift
                        }
                        TextInput {
                            id: pin
                            anchors { left: parent.left; right: parent.right; margins: 12 * seite.dp
                                      verticalCenter: parent.verticalCenter }
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "black"
                            font.pixelSize: 16 * seite.dp
                            font.family: seite.schrift
                            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            Keys.onReturnPressed: senden.clicked()
                        }
                        MouseArea {
                            anchors.fill: parent
                            visible: !pin.activeFocus
                            onClicked: pin.forceActiveFocus()
                        }
                    }
                    Item { width: 1; height: 24 * seite.dp }
                    OriginalKnopf {
                        id: senden
                        x: 16 * seite.dp
                        width: parent.width - 32 * seite.dp
                        dp: seite.dp
                        primaer: false
                        text: "PIN senden"
                        onClicked: {
                            if (pin.text.replace(/\s/g, "") === "") {
                                fehler.text = "Ungültiger Pin"
                                return
                            }
                            fehler.text = ""
                            pin.focus = false
                            seite.pinSenden(pin.text.replace(/^\s+|\s+$/g, ""))
                        }
                    }
                    Text {
                        id: fehler
                        x: 16 * seite.dp
                        width: parent.width - 32 * seite.dp
                        visible: text !== ""
                        horizontalAlignment: Text.AlignHCenter
                        color: "#87003a"
                        font.pixelSize: 14 * seite.dp
                        font.family: seite.schrift
                    }
                    Item { width: 1; height: 10 * seite.dp }
                }
            }
            Item { width: 1; height: 24 * seite.dp }
        }
    }
}
