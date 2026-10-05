import QtQuick 1.1

// Die Bestaetigung, die man vor Ort herzeigt -- wie in der Android-App
// (fragment_coupon_redeemed): "Bitte zeige diese Bestaetigung vor Ort
// her", das Foto, "Der Gutschein wurde erfolgreich eingeloest ...". Foto
// und Schrift aus der eigenen APK (tools/apk-vorlage.py), sonst Ersatz.
//
// Diese Seite loest selbst ein (wie die App: erst hier geht die Anfrage
// an den Server) und zeigt die Bestaetigung NUR, wenn der Server das
// Einloesen bestaetigt hat. Wieder aufrufen laesst sie sich nicht: einmal
// eingeloest, einmal gezeigt.
Rectangle {
    id: seite
    property real dp: Math.min(width, height) / 360
    property string vorlage: Qt.resolvedUrl("vorlage/")
    property variant werte: null          // fuer den Befehl "einloesen"
    property bool erfolg: false
    property string fehlerText: ""
    signal zurueck
    signal fertig

    color: "#f7fbfc"

    FontLoader { id: normal; source: seite.vorlage + "neo_sans_pro_regular.otf" }
    FontLoader { id: mittel; source: seite.vorlage + "neo_sans_pro_medium.otf" }
    property string schrift: normal.status === FontLoader.Ready ? normal.name : ""
    property string schriftMittel: mittel.status === FontLoader.Ready ? mittel.name : ""

    Component.onCompleted: if (werte) einloesen.senden("einloesen", werte)

    Anfrage {
        id: einloesen
        onFertig: seite.erfolg = true
        onFehler: {
            var t = String(text)
            if (t.indexOf("ABGEMELDET:") === 0)
                t = t.substring(11).replace(/^\s+/, "")
            seite.fehlerText = t !== "" ? t : "Beim Einlösen des Gutscheins trat ein Fehler auf!"
        }
    }

    OriginalKopf {
        id: kopf
        anchors { top: parent.top; left: parent.left; right: parent.right }
        dp: seite.dp
        titel: "Einlösen"
        schrift: seite.schrift
        onZurueck: seite.erfolg ? seite.fertig() : seite.zurueck()
        z: 2
        // LinearProgressIndicator der App, solange der Server fragt
        Rectangle {
            id: lauf
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 4 * seite.dp
            color: "#7cb8cc"
            visible: einloesen.laeuft
            clip: true
            Rectangle {
                id: balken
                width: parent.width / 3
                height: parent.height
                color: "white"
                SequentialAnimation on x {
                    running: lauf.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: -balken.width; to: lauf.width; duration: 1100 }
                }
            }
        }
    }

    // --- Erfolg -------------------------------------------------------------
    Column {
        anchors { top: kopf.bottom; left: parent.left; right: parent.right }
        visible: seite.erfolg
        Item { width: 1; height: 32 * seite.dp }
        Text {
            x: 16 * seite.dp
            width: parent.width - 32 * seite.dp
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#717171"
            font.pixelSize: 16 * seite.dp
            font.family: seite.schrift
            text: "Bitte zeige diese Bestätigung vor Ort her"
        }
        Item { width: 1; height: 32 * seite.dp }
        Item {
            width: parent.width
            height: width * 600 / 1125
            Image {
                id: foto
                anchors.fill: parent
                source: seite.vorlage + "voucher_redeemed.jpg"
                fillMode: Image.PreserveAspectCrop
                smooth: true
                sourceSize.width: width
            }
            // Ohne Foto aus der APK: eine Flaeche mit Haken.
            Rectangle {
                anchors.fill: parent
                visible: foto.status !== Image.Ready
                color: "#3790ad"
                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    color: "white"
                    font.pixelSize: parent.height * 0.6
                }
            }
        }
        Item { width: 1; height: 32 * seite.dp }
        Text {
            x: 16 * seite.dp
            width: parent.width - 32 * seite.dp
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#3790ad"
            font.pixelSize: 18 * seite.dp
            font.family: seite.schriftMittel !== "" ? seite.schriftMittel : seite.schrift
            text: "Der Gutschein wurde erfolgreich eingelöst. Viel Freude damit!"
        }
    }

    // --- Fehler -------------------------------------------------------------
    Text {
        anchors { top: kopf.bottom; topMargin: 32 * seite.dp; left: parent.left; leftMargin: 16 * seite.dp
                  right: parent.right; rightMargin: 16 * seite.dp }
        visible: seite.fehlerText !== ""
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: "#3790ad"
        font.pixelSize: 18 * seite.dp
        font.family: seite.schriftMittel !== "" ? seite.schriftMittel : seite.schrift
        text: seite.fehlerText
    }

    OriginalKnopf {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 * seite.dp }
        height: 50 * seite.dp
        dp: seite.dp
        visible: seite.erfolg || seite.fehlerText !== ""
        text: seite.erfolg ? "Zurück zu den Gutscheinen" : "Zurück"
        onClicked: seite.erfolg ? seite.fertig() : seite.zurueck()
    }
}
