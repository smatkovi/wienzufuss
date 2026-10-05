import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Zaehlen, Empfindlichkeit, Schrittlaenge, Tagesziel, Uebertragen, Abmelden.
Page {
    id: seite
    property variant e: null
    property string hinweis: ""
    property bool geladen: false

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
    }

    Component.onCompleted: laden.senden("einstellungen", {})

    function setzen(werte) {
        speichern.senden("einstellungen_setzen", werte)
    }

    Anfrage {
        id: laden
        onFertig: {
            seite.e = daten
            zaehlen.checked = daten.zaehlen !== false
            empf.value = W.zahl(daten.empfindlichkeit, 3)
            laenge.value = Math.round(W.zahl(daten.schrittlaenge, 0.7) * 100)
            hochladen.checked = daten.hochladen === true
            ziel.text = fenster.nutzer ? String(W.zahl(fenster.nutzer.dailyTarget, 10000)) : "10000"
            seite.geladen = true
        }
    }
    Anfrage {
        id: speichern
        onFertig: { seite.e = daten; Schritte.neuladen() }
        onFehler: seite.hinweis = W.fehlerText(text)
    }
    Anfrage {
        id: zielAnfrage
        onFertig: { fenster.nutzer = daten; fenster.meldung("Tagesziel gespeichert.") }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }
    Anfrage {
        id: abmelden
        onFertig: {
            fenster.angemeldet = false
            fenster.nutzer = null
            pageStack.pop(null)
            fenster.anmeldenZeigen()
        }
    }

    QueryDialog {
        id: hochladenFrage
        titleText: "Schritte übertragen?"
        message: "Die auf diesem Telefon gezählten Schritte gehen als Tagessummen an Wien zu Fuß – ab dann "
                 + "automatisch etwa stündlich. Ein Tag, für den am Server schon mehr Schritte stehen (etwa vom "
                 + "Android-Telefon), wird nicht überschrieben.\n\nWer an einem Tag mit zwei Telefonen geht, "
                 + "bekommt den höheren der beiden Werte, nicht die Summe."
        acceptButtonText: "Einschalten"
        rejectButtonText: "Abbrechen"
        onAccepted: seite.setzen({ hochladen: true })
        onRejected: hochladen.checked = false
    }
    QueryDialog {
        id: abmeldenFrage
        titleText: "Abmelden?"
        message: "Die gezählten Schritte bleiben auf dem Telefon."
        acceptButtonText: "Abmelden"
        rejectButtonText: "Abbrechen"
        onAccepted: abmelden.senden("abmelden", {})
    }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: "Einstellungen"
        laedt: laden.laeuft || speichern.laeuft || zielAnfrage.laeuft
    }

    Flickable {
        id: flick
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: inhalt.height + 32
        clip: true
        Column {
            id: inhalt
            x: 16
            width: parent.width - 32
            spacing: 12
            Item { width: 1; height: 6 }

            Ueberschrift { text: "Zählen" }
            Row {
                width: parent.width
                Text {
                    width: parent.width - zaehlen.width
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Schritte zählen"
                    color: "white"
                    font.pixelSize: 26
                }
                Switch {
                    id: zaehlen
                    onCheckedChanged: if (seite.geladen && checked !== (seite.e.zaehlen !== false)) seite.setzen({ zaehlen: checked })
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#8c8c8c"
                font.pixelSize: 20
                text: "Das N9 hat keinen eigenen Schrittzähler; gezählt wird mit dem Beschleunigungssensor, auch bei "
                      + "dunklem Bildschirm. Am genauesten in der Hosentasche."
            }
            Text { text: "Empfindlichkeit: " + empf.value; color: "white"; font.pixelSize: 24 }
            Slider {
                id: empf
                width: parent.width
                minimumValue: 1
                maximumValue: 5
                stepSize: 1
                valueIndicatorVisible: true
                onPressedChanged: if (!pressed && seite.geladen) seite.setzen({ empfindlichkeit: value })
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#8c8c8c"
                font.pixelSize: 20
                text: "Zählt es zu wenig, höher stellen; zählt es beim Sitzen oder Fahren, niedriger."
            }
            Text { text: "Schrittlänge: " + laenge.value + " cm"; color: "white"; font.pixelSize: 24 }
            Slider {
                id: laenge
                width: parent.width
                minimumValue: 40
                maximumValue: 110
                stepSize: 1
                valueIndicatorVisible: true
                onPressedChanged: if (!pressed && seite.geladen) seite.setzen({ schrittlaenge: value / 100 })
            }

            Ueberschrift { text: "Tagesziel" }
            Row {
                width: parent.width
                spacing: 12
                TextField {
                    id: ziel
                    width: parent.width - zielKnopf.width - 12
                    inputMethodHints: Qt.ImhDigitsOnly
                    maximumLength: 6
                }
                Button {
                    id: zielKnopf
                    width: 160
                    text: "Speichern"
                    enabled: fenster.angemeldet && ziel.text !== "" && !zielAnfrage.laeuft
                    onClicked: zielAnfrage.senden("tagesziel", { ziel: parseInt(ziel.text, 10) })
                }
            }

            Ueberschrift { text: "Übertragen" }
            Row {
                width: parent.width
                Text {
                    width: parent.width - hochladen.width
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Schritte an Wien zu Fuß übertragen"
                    color: "white"
                    font.pixelSize: 24
                    wrapMode: Text.WordWrap
                }
                Switch {
                    id: hochladen
                    onCheckedChanged: {
                        if (!seite.geladen || checked === (seite.e.hochladen === true))
                            return
                        if (checked)
                            hochladenFrage.open()
                        else
                            seite.setzen({ hochladen: false })
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#8c8c8c"
                font.pixelSize: 20
                text: "Übertragen werden die letzten 14 Tage, nie ein kleinerer Wert als der am Server. Steht nach dem "
                      + "Übertragen am Server etwas anderes als geschickt, hält die App an und fragt nach."
            }

            Ueberschrift { text: "Konto" }
            Text {
                width: parent.width
                color: "white"
                font.pixelSize: 22
                elide: Text.ElideRight
                text: fenster.nutzer && fenster.nutzer.email ? fenster.nutzer.email : ""
            }
            Button {
                width: parent.width
                text: "Abmelden"
                enabled: fenster.angemeldet
                onClicked: abmeldenFrage.open()
            }
            Text {
                width: parent.width
                visible: seite.hinweis !== ""
                wrapMode: Text.WordWrap
                color: "#ff6060"
                font.pixelSize: 22
                text: seite.hinweis
            }
        }
    }
    ScrollDecorator { flickableItem: flick }
}
