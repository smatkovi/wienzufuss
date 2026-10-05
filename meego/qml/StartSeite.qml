import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Heute: gezaehlte Schritte, Tagesziel, die letzten sieben Tage, Stand des
// Hochladens -- und der Weg zu allen anderen Seiten.
Page {
    id: seite
    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-refresh"; onClicked: seite.neuLaden() }
        ToolIcon { iconId: "toolbar-view-menu"; onClicked: menue.open() }
    }

    // Vom Schrittdienst (JSON, siehe schritte/Schrittdienst.h)
    property variant stand: W.json(Schritte.stand, null)
    // Vom Netzdienst: Einstellungen und Stand des Hochladens
    property variant lokal: null
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
                seite.uploadMeldung = "Achtung: der Server zeigt andere Werte als geschickt – Hochladen angehalten."
            else if (n > 0)
                seite.uploadMeldung = n === 1 ? "1 Tag hochgeladen." : n + " Tage hochgeladen."
            else
                seite.uploadMeldung = daten.hinweis ? daten.hinweis : "Nichts hochzuladen."
            lokalAnfrage.senden("lokal", {})
            nutzerAnfrage.senden("nutzer", {})
        }
        onFehler: if (!fenster.fehler(text)) seite.uploadMeldung = W.fehlerText(text)
    }

    Menu {
        id: menue
        MenuLayout {
            MenuItem { text: "Einstellungen"; onClicked: pageStack.push(Qt.resolvedUrl("EinstellungenSeite.qml")) }
            MenuItem { text: "Profil"; onClicked: pageStack.push(Qt.resolvedUrl("ProfilSeite.qml"), { modus: "bearbeiten" }) }
            MenuItem { text: "Über diese App"; onClicked: pageStack.push(Qt.resolvedUrl("InfoSeite.qml")) }
        }
    }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: "Wien zu Fuß"
        untertitel: stand ? W.tag(stand.heute) : ""
        laedt: nutzerAnfrage.laeuft || upload.laeuft || statusAnfrage.laeuft
    }

    Flickable {
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: inhalt.height + 24
        clip: true

        Column {
            id: inhalt
            x: 16
            width: parent.width - 32
            spacing: 10

            Item { width: 1; height: 8 }

            // --- Heute -----------------------------------------------------
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: W.tausender(seite.heute)
                color: seite.heute >= seite.ziel ? "#a0b436" : "white"
                font.pixelSize: 84
                font.family: "Nokia Pure Text Light"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: "#8c8c8c"
                font.pixelSize: 22
                text: "Schritte heute · Ziel " + W.tausender(seite.ziel)
            }
            ProgressBar {
                width: parent.width
                minimumValue: 0
                maximumValue: Math.max(1, seite.ziel)
                value: Math.min(seite.heute, seite.ziel)
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: seite.heute >= seite.ziel ? "#a0b436" : "#e8bc2c"
                font.pixelSize: 22
                text: seite.heute >= seite.ziel ? "Tagesziel erreicht"
                                                : "Noch " + W.tausender(seite.ziel - seite.heute) + " Schritte zu deinem Ziel"
            }
            Row {
                width: parent.width
                Wert { width: parent.width / 2; zahl: W.strecke(seite.heute * seite.schrittlaenge); text: "Strecke" }
                Wert {
                    width: parent.width / 2
                    zahl: stand && stand.geht ? "unterwegs" : "–"
                    farbe: stand && stand.geht ? "#a0b436" : "#8c8c8c"
                    text: "gerade"
                }
            }

            // --- Woche -----------------------------------------------------
            Ueberschrift { text: "Die letzten 7 Tage" }
            Row {
                id: woche
                width: parent.width
                height: 150
                property variant tage: W.letzteTage(stand ? stand.heute : "", 7)
                property int hoechster: hoechsterWert()
                function hoechsterWert() {
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
                        Rectangle {
                            anchors { bottom: tagText.top; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
                            width: parent.width - 18
                            height: Math.max(2, (parent.height - 50) * n / woche.hoechster)
                            color: n >= seite.ziel ? "#a0b436" : "#3790ad"
                        }
                        Text {
                            anchors { bottom: tagText.top; bottomMargin: 6 + Math.max(2, (parent.height - 50) * n / woche.hoechster)
                                      horizontalCenter: parent.horizontalCenter }
                            text: n > 0 ? (n >= 1000 ? (Math.round(n / 100) / 10 + "k").replace(".", ",") : n) : ""
                            color: "#bfbfbf"
                            font.pixelSize: 16
                        }
                        Text {
                            id: tagText
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            text: W.kurzTag(modelData)
                            color: index === 6 ? "white" : "#8c8c8c"
                            font.pixelSize: 18
                        }
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#8c8c8c"
                font.pixelSize: 18
                text: "Gezählt mit: " + W.quelleText(stand ? stand.quelle : "")
                      + (stand && stand.hinweis ? "\n" + stand.hinweis : "")
                      + (!Schritte.erreichbar ? "\nDer Schrittdienst antwortet nicht." : "")
            }

            // --- Hochladen -------------------------------------------------
            Ueberschrift { text: "Übertragen" }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "white"
                font.pixelSize: 22
                text: !seite.hochladen ? "Das Übertragen der Schritte ist ausgeschaltet. Einschalten in den Einstellungen."
                      : (lokal && lokal.sync && lokal.sync.letzter ? "Zuletzt übertragen: " + lokal.sync.letzter
                                                                   : "Noch nichts übertragen.")
            }
            Text {
                width: parent.width
                visible: seite.gesperrt !== ""
                wrapMode: Text.WordWrap
                color: "#ff6060"
                font.pixelSize: 20
                text: seite.gesperrt
            }
            Text {
                width: parent.width
                visible: seite.uploadMeldung !== ""
                wrapMode: Text.WordWrap
                color: "#e8bc2c"
                font.pixelSize: 20
                text: seite.uploadMeldung
            }
            Button {
                width: parent.width
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

            // --- Profil ----------------------------------------------------
            Column {
                width: parent.width
                spacing: 4
                visible: fenster.nutzer ? true : false
                Text {
                    width: parent.width
                    color: "white"
                    font.pixelSize: 26
                    elide: Text.ElideRight
                    text: fenster.nutzer ? fenster.nutzer.username : ""
                }
                Text {
                    width: parent.width
                    color: "#8c8c8c"
                    font.pixelSize: 20
                    elide: Text.ElideRight
                    text: fenster.nutzer ? W.bezirkName(fenster.nutzer.territory) : ""
                }
                Row {
                    width: parent.width
                    spacing: 0
                    Wert {
                        width: parent.width / 2
                        groesse: 30
                        zahl: fenster.nutzer ? W.tausender(fenster.nutzer.points) : "–"
                        text: "Punkte"
                    }
                    Wert {
                        width: parent.width / 2
                        groesse: 30
                        zahl: fenster.nutzer ? W.tausender(fenster.nutzer.steps) : "–"
                        text: "Schritte gesamt"
                    }
                }
            }
            Text {
                id: fehlerText
                width: parent.width
                visible: text !== ""
                wrapMode: Text.WordWrap
                color: "#ff6060"
                font.pixelSize: 20
            }

            // --- Wege ------------------------------------------------------
            Item { width: 1; height: 4 }
            Column {
                width: parent.width + 32
                x: -16
                Zeile { titel: "Wie stehe ich da?"; wert: "Ranking"; onClicked: pageStack.push(Qt.resolvedUrl("RanglisteSeite.qml")) }
                Zeile { titel: "Gemeinsam gehen"; wert: "Challenges"; onClicked: pageStack.push(Qt.resolvedUrl("ChallengesSeite.qml")) }
                Zeile { titel: "Belohnungen"; wert: "Gutscheine"; onClicked: pageStack.push(Qt.resolvedUrl("GutscheineSeite.qml")) }
                Zeile { titel: "Mein Jahr"; wert: "Jahresrückblick"; onClicked: pageStack.push(Qt.resolvedUrl("RueckblickSeite.qml")) }
            }
        }
    }
}
