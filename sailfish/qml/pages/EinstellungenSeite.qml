import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Zaehlen, Quelle, Empfindlichkeit, Schrittlaenge, Tagesziel, Uebertragen,
// Abmelden.
Page {
    id: seite
    property var e: null
    property string hinweis: ""
    property bool geladen: false
    property var stand: fenster.stand

    Component.onCompleted: laden.senden("einstellungen", {})

    function setzen(werte) {
        speichern.senden("einstellungen_setzen", werte)
    }

    Anfrage {
        id: laden
        onFertig: {
            seite.e = daten
            zaehlen.checked = daten.zaehlen !== false
            beschleunigung.checked = daten.beschleunigung === true
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
            pageStack.pop(pageStack.find(function(p) { return p.istStart === true }), PageStackAction.Immediate)
            fenster.anmeldenZeigen()
        }
    }
    RemorsePopup { id: remorse }

    Component {
        id: hochladenFrage
        Dialog {
            onAccepted: seite.setzen({ hochladen: true })
            onRejected: hochladen.checked = false
            Column {
                width: parent.width
                spacing: Theme.paddingLarge
                DialogHeader { acceptText: "Einschalten"; cancelText: "Abbrechen" }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    wrapMode: Text.WordWrap
                    color: Theme.highlightColor
                    text: "Die auf diesem Telefon gezählten Schritte gehen als Tagessummen an Wien zu Fuß – ab dann "
                          + "automatisch etwa stündlich. Ein Tag, für den am Server schon mehr Schritte stehen (etwa vom "
                          + "Android-Telefon), wird nicht überschrieben.\n\nWer an einem Tag mit zwei Telefonen geht, "
                          + "bekommt den höheren der beiden Werte, nicht die Summe."
                }
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge

        Column {
            id: inhalt
            width: parent.width
            PageHeader { title: "Einstellungen" }

            SectionHeader { text: "Zählen" }
            TextSwitch {
                id: zaehlen
                text: "Schritte zählen"
                description: "Gezählt mit: " + W.quelleText(seite.stand ? seite.stand.quelle : "")
                             + (seite.stand && seite.stand.hinweis ? "\n" + seite.stand.hinweis : "")
                onCheckedChanged: if (seite.geladen && checked !== (seite.e.zaehlen !== false)) seite.setzen({ zaehlen: checked })
            }
            TextSwitch {
                id: beschleunigung
                text: "Beschleunigungssensor als Ersatz"
                description: "Nur für Telefone ohne eigenen Schrittzähler. Dann darf das Telefon nicht schlafen – "
                             + "das kostet spürbar Akku."
                onCheckedChanged: if (seite.geladen && checked !== (seite.e.beschleunigung === true)) seite.setzen({ beschleunigung: checked })
            }
            Slider {
                id: empf
                width: parent.width
                minimumValue: 1
                maximumValue: 5
                stepSize: 1
                label: "Empfindlichkeit (Beschleunigungssensor)"
                valueText: value
                onDownChanged: if (!down && seite.geladen) seite.setzen({ empfindlichkeit: value })
            }
            Slider {
                id: laenge
                width: parent.width
                minimumValue: 40
                maximumValue: 110
                stepSize: 1
                label: "Schrittlänge"
                valueText: value + " cm"
                onDownChanged: if (!down && seite.geladen) seite.setzen({ schrittlaenge: value / 100 })
            }

            SectionHeader { text: "Tagesziel" }
            Row {
                width: parent.width
                TextField {
                    id: ziel
                    width: parent.width - zielKnopf.width - Theme.horizontalPageMargin
                    label: "Schritte am Tag"
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 100; top: 100000 }
                }
                Button {
                    id: zielKnopf
                    text: "Speichern"
                    enabled: fenster.angemeldet && ziel.acceptableInput && !zielAnfrage.laeuft
                    onClicked: zielAnfrage.senden("tagesziel", { ziel: parseInt(ziel.text, 10) })
                }
            }

            SectionHeader { text: "Übertragen" }
            TextSwitch {
                id: hochladen
                text: "Schritte an Wien zu Fuß übertragen"
                description: "Übertragen werden die letzten 14 Tage, nie ein kleinerer Wert als der am Server. Steht nach dem "
                             + "Übertragen am Server etwas anderes als geschickt, hält die App an und fragt nach."
                automaticCheck: false
                onClicked: {
                    if (!seite.geladen)
                        return
                    if (!checked) {
                        checked = true
                        pageStack.push(hochladenFrage)
                    } else {
                        checked = false
                        seite.setzen({ hochladen: false })
                    }
                }
            }

            SectionHeader { text: "Konto" }
            Hinweis {
                color: Theme.primaryColor
                text: fenster.nutzer && fenster.nutzer.email ? fenster.nutzer.email : ""
            }
            Item { width: 1; height: Theme.paddingMedium }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Abmelden"
                enabled: fenster.angemeldet
                onClicked: remorse.execute("Abmelden", function() { abmelden.senden("abmelden", {}) })
            }
            Hinweis { fehler: true; text: seite.hinweis }
        }
        VerticalScrollDecorator { }
    }
}
