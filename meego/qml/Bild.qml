import QtQuick 1.1

// Ein Bild aus dem Netz. Qt 4.7 auf dem N9 kann https mit TLS 1.2 nicht
// selbst laden; der Dienst holt es in den Cache und gibt den Pfad zurueck.
Item {
    id: bild
    property string url: ""
    property alias fillMode: img.fillMode
    property bool geladen: img.status === Image.Ready
    clip: true

    onUrlChanged: laden()
    Component.onCompleted: laden()

    function laden() {
        img.source = ""
        if (url !== "" && url.indexOf("http") === 0)
            holen.senden("bild", { url: url })
    }

    Anfrage {
        id: holen
        onFertig: {
            // WebP kann Qt 4.7 nicht anzeigen.
            if (daten.art !== "webp")
                img.source = "file://" + daten.datei
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#1d2a2f"
        visible: img.status !== Image.Ready
    }
    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        // Die Bilder des Servers sind 1000-1500 Pixel breit: nur in der
        // Groesse dekodieren, in der sie gezeigt werden.
        sourceSize.width: bild.width
    }
}
