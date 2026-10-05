import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Heute: gezaehlte Schritte, Tagesziel, die letzten sieben Tage, Stand des
// Uebertragens -- und der Weg zu allen anderen Seiten.
Page {
    id: seite
    property bool istStart: true

    property var stand: fenster.stand
    property var lokal: null
    property string uploadMeldung: ""

    property int heute: stand ? W.zahl(stand.schritteHeute, 0) : 0
    property int ziel: fenster.nutzer ? W.zahl(fenster.nutzer.dailyTarget, 10000) : 10000
    property real schrittlaenge: lokal && lokal.einstellungen ? W.zahl(lokal.einstellungen.schrittlaenge, 0.7) : 0.7
    property bool hochladen: lokal && lokal.einstellungen ? lokal.einstellungen.hochladen === true : false
    property string gesperrt: lokal && lokal.sync && lokal.sync.gesperrt ? lokal.sync.gesperrt : ""

    Component.onCompleted: statusAnfrage.senden("status", {})
    onStatusChanged: {
        if (status === PageStatus.Active && fenster.angemeldet)
            neuLaden()
    }

    function neuLaden() {
        Schritte.aktualisieren()
        lokalAnfrage.senden("lokal", {})
        if (fenster.angemeldet)
            nutzerAnfrage.senden("nutzer", {})
    }

    Anfrage {
        id: statusAnfrage
        onFertig: {
            fenster.angemeldet = daten.angemeldet
            lokalAnfrage.senden("lokal", {})
            if (daten.angemeldet)
                nutzerAnfrage.senden("nutzer", {})
            else
                fenster.anmeldenZeigen()
        }
    }
    Anfrage {
        id: nutzerAnfrage
        onFertig: fenster.nutzer = daten
        onFehler: if (!fenster.fehler(text)) fehlerText.text = W.fehlerText(text)
    }
    Anfrage { id: lokalAnfrage; onFertig: seite.lokal = daten }
    Anfrage {
        id: upload
        onFertig: {
            var n = daten.gesendet ? daten.gesendet.length : 0
            if (daten.abweichung && daten.abweichung.length > 0)
                seite.uploadMeldung = "Achtung: der Server zeigt andere Werte als geschickt – Übertragen angehalten."
            else if (n > 0)
                seite.uploadMeldung = n === 1 ? "1 Tag übertragen." : n + " Tage übertragen."
            else
                seite.uploadMeldung = daten.hinweis ? daten.hinweis : "Nichts zu übertragen."
            lokalAnfrage.senden("lokal", {})
            nutzerAnfrage.senden("nutzer", {})
        }
        onFehler: if (!fenster.fehler(text)) seite.uploadMeldung = W.fehlerText(text)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge

        PullDownMenu {
            busy: nutzerAnfrage.laeuft || upload.laeuft || statusAnfrage.laeuft
            MenuItem { text: "Über diese App"; onClicked: pageStack.push(Qt.resolvedUrl("InfoSeite.qml")) }
            MenuItem { text: "Profil"; onClicked: pageStack.push(Qt.resolvedUrl("ProfilSeite.qml"), { modus: "bearbeiten" }) }
            MenuItem { text: "Einstellungen"; onClicked: pageStack.push(Qt.resolvedUrl("EinstellungenSeite.qml")) }
            MenuItem { text: "Aktualisieren"; onClicked: seite.neuLaden() }
        }

        Column {
            id: inhalt
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: "Wien zu Fuß"
                description: stand ? W.tag(stand.heute) : ""
            }

            // --- Heute -----------------------------------------------------
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: W.tausender(seite.heute)
                color: seite.heute >= seite.ziel ? "#a0b436" : Theme.highlightColor
                font.pixelSize: Theme.fontSizeHuge * 1.6
                font.family: Theme.fontFamilyHeading
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: "Schritte heute · Ziel " + W.tausender(seite.ziel)
            }
            ProgressBar {
                width: parent.width
                minimumValue: 0
                maximumValue: Math.max(1, seite.ziel)
                value: Math.min(seite.heute, seite.ziel)
                label: seite.heute >= seite.ziel ? "Tagesziel erreicht"
                                                 : "Noch " + W.tausender(seite.ziel - seite.heute) + " Schritte zu deinem Ziel"
            }
            Row {
                width: parent.width
                Wert { width: parent.width / 2; zahl: W.strecke(seite.heute * seite.schrittlaenge); text: "Strecke" }
                Wert {
                    width: parent.width / 2
                    zahl: stand && stand.geht ? "unterwegs" : "–"
                    farbe: stand && stand.geht ? "#a0b436" : Theme.secondaryColor
                    text: "gerade"
                }
            }

            // --- Woche -----------------------------------------------------
            SectionHeader { text: "Die letzten 7 Tage" }
            Row {
                id: woche
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Theme.itemSizeHuge * 1.2
                property var tage: W.letzteTage(stand ? stand.heute : "", 7)
                property int hoechster: {
                    var m = seite.ziel
                    for (var i = 0; i < tage.length; ++i) {
                        var n = stand && stand.tage ? W.zahl(stand.tage[tage[i]], 0) : 0
                        if (n > m) m = n
                    }
                    return Math.max(1, m)
                }
                Repeater {
                    model: woche.tage
                    Item {
                        width: woche.width / 7
                        height: woche.height
                        property int n: stand && stand.tage ? W.zahl(stand.tage[modelData], 0) : 0
                        property real hoehe: Math.max(2, (height - tagLabel.height - Theme.paddingLarge * 2) * n / woche.hoechster)
                        Rectangle {
                            anchors { bottom: tagLabel.top; bottomMargin: Theme.paddingSmall; horizontalCenter: parent.horizontalCenter }
                            width: parent.width * 0.65
                            height: parent.hoehe
                            radius: Theme.paddingSmall / 2
                            color: n >= seite.ziel ? "#a0b436" : "#3790ad"
                        }
                        Label {
                            anchors { bottom: tagLabel.top; bottomMargin: parent.hoehe + Theme.paddingSmall * 2
                                      horizontalCenter: parent.horizontalCenter }
                            text: n > 0 ? (n >= 1000 ? (Math.round(n / 100) / 10 + "k").replace(".", ",") : n) : ""
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeTiny
                        }
                        Label {
                            id: tagLabel
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            text: W.kurzTag(modelData)
                            color: index === 6 ? Theme.highlightColor : Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }
                    }
                }
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: "Gezählt mit: " + W.quelleText(stand ? stand.quelle : "")
                      + (stand && stand.hinweis ? "\n" + stand.hinweis : "")
                      + (!Schritte.erreichbar ? "\nDer Schrittdienst antwortet nicht." : "")
            }

            // --- Uebertragen -------------------------------------------------
            SectionHeader { text: "Übertragen" }
            Hinweis {
                color: Theme.primaryColor
                text: !seite.hochladen ? "Das Übertragen der Schritte ist ausgeschaltet. Einschalten in den Einstellungen."
                      : (lokal && lokal.sync && lokal.sync.letzter ? "Zuletzt übertragen: " + lokal.sync.letzter
                                                                   : "Noch nichts übertragen.")
            }
            Hinweis { fehler: true; text: seite.gesperrt }
            Hinweis { text: seite.uploadMeldung }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: fenster.angemeldet
                text: !seite.hochladen ? "Einstellungen" : (seite.gesperrt !== "" ? "Freigeben und übertragen" : "Jetzt übertragen")
                enabled: !upload.laeuft
                onClicked: {
                    if (!seite.hochladen) {
                        pageStack.push(Qt.resolvedUrl("EinstellungenSeite.qml"))
                        return
                    }
                    seite.uploadMeldung = ""
                    Schritte.aktualisieren()
                    upload.senden("synchronisieren", { freigeben: seite.gesperrt !== "" })
                }
            }

            // --- Profil ------------------------------------------------------
            SectionHeader { text: fenster.nutzer ? fenster.nutzer.username : "Profil"; visible: !!fenster.nutzer }
            Row {
                width: parent.width
                visible: !!fenster.nutzer
                Wert { width: parent.width / 2; zahl: fenster.nutzer ? W.tausender(fenster.nutzer.points) : "–"; text: "Punkte" }
                Wert { width: parent.width / 2; zahl: fenster.nutzer ? W.tausender(fenster.nutzer.steps) : "–"; text: "Schritte gesamt" }
            }
            Hinweis { id: fehlerText; fehler: true }

            // --- Wege --------------------------------------------------------
            Item { width: 1; height: Theme.paddingSmall }
            Eintrag { titel: "Ranking"; beschreibung: fenster.nutzer ? W.bezirkName(fenster.nutzer.territory) : ""; onClicked: pageStack.push(Qt.resolvedUrl("RanglisteSeite.qml")) }
            Eintrag { titel: "Challenges"; beschreibung: "Gemeinsam gehen"; onClicked: pageStack.push(Qt.resolvedUrl("ChallengesSeite.qml")) }
            Eintrag { titel: "Gutscheine"; beschreibung: "Belohnungen"; onClicked: pageStack.push(Qt.resolvedUrl("GutscheineSeite.qml")) }
            Eintrag { titel: "Jahresrückblick"; beschreibung: "Mein Jahr"; onClicked: pageStack.push(Qt.resolvedUrl("RueckblickSeite.qml")) }
        }
        VerticalScrollDecorator { }
    }
}
