import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Challenges: an denen ich teilnehme, die laufenden, die vergangenen.
Page {
    id: seite
    property string hinweis: ""

    Component.onCompleted: { laden.senden("challenges", {}); angekuendigt.senden("ankuendigungen", {}) }
    onStatusChanged: if (status === PageStatus.Active && liste.count > 0) laden.senden("challenges", {})

    // Was die Webseite ankuendigt, steht nicht in der Schnittstelle: der
    // Dienst listet unter v1/challenge nur, was laeuft. Eine Challenge,
    // die erst morgen beginnt, taucht dort nicht auf. Deshalb daneben
    // die Ankuendigungen -- und zwar nur die, die nicht ohnehin schon
    // als Gutschein in der App stehen.
    property var ankuendigungen: []

    function eintragen(gruppe, l) {
        if (!l)
            return
        for (var i = 0; i < l.length; ++i) {
            var c = l[i]
            liste.append({
                gruppe: gruppe,
                cid: W.zahl(c.id, 0),
                titel: c.title ? String(c.title) : "Challenge",
                zeitraum: (c.from ? W.datum(c.from) : "") + (c.to ? " – " + W.datum(c.to) : ""),
                bild: c.imageUrl ? String(c.imageUrl) : "",
                dabei: c.hasJoined === true,
                text: ""
            })
        }
    }

    Anfrage {
        id: laden
        onFertig: {
            liste.clear()
            seite.hinweis = ""
            eintragen("Meine Challenges", daten.joined)
            eintragen("Aktuelle Challenges", daten.available)
            eintragen("Vergangene Challenges", daten.closed)
            seite.ankuendigungEintragen()
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    Anfrage {
        id: angekuendigt
        // Eine Lesehilfe, keine Schnittstelle: scheitert sie, bleibt der
        // Abschnitt einfach leer, und die Seite funktioniert weiter.
        onFertig: { seite.ankuendigungen = daten ? daten : []; seite.ankuendigungEintragen() }
        onFehler: seite.ankuendigungen = []
    }

    function ankuendigungEintragen() {
        for (var i = 0; i < seite.ankuendigungen.length; ++i) {
            var a = seite.ankuendigungen[i]
            liste.append({
                gruppe: "Angekündigt",
                cid: 0,
                titel: a.titel ? String(a.titel) : "",
                zeitraum: "noch nicht in der App",
                bild: "",
                dabei: false,
                text: a.text ? String(a.text) : ""
            })
        }
    }

    ListModel { id: liste }

    SilicaListView {
        id: ansicht
        anchors.fill: parent
        model: liste
        header: PageHeader { title: "Challenges" }
        section.property: "gruppe"
        section.delegate: SectionHeader { text: section }

        PullDownMenu {
            busy: laden.laeuft
            MenuItem {
                text: "Aktualisieren"
                onClicked: { laden.senden("challenges", {}); angekuendigt.senden("ankuendigungen", {}) }
            }
        }
        ViewPlaceholder {
            enabled: liste.count === 0 && !laden.laeuft
            text: seite.hinweis !== "" ? seite.hinweis : "Derzeit gibt es keine Challenges."
        }

        delegate: ListItem {
            contentHeight: Theme.itemSizeExtraLarge
            Image {
                id: bild
                anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                width: Theme.itemSizeExtraLarge * 1.3
                height: Theme.itemSizeExtraLarge - Theme.paddingMedium * 2
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
                source: model.bild
                Rectangle { anchors.fill: parent; color: Theme.rgba(Theme.highlightBackgroundColor, 0.15); visible: parent.status !== Image.Ready }
            }
            Column {
                anchors { left: bild.right; leftMargin: Theme.paddingMedium; right: parent.right
                          rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                Label {
                    width: parent.width
                    text: titel
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    truncationMode: TruncationMode.Elide
                    color: highlighted ? Theme.highlightColor : Theme.primaryColor
                }
                Label {
                    width: parent.width
                    text: zeitraum + (dabei ? " · dabei" : "")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: dabei ? "#a0b436" : Theme.secondaryColor
                }
            }
            // Angekuendigtes hat noch keine Challenge-Kennung; dort
            // gibt es nur den Text der Webseite zu lesen.
            onClicked: {
                if (cid > 0)
                    pageStack.push(Qt.resolvedUrl("ChallengeSeite.qml"), { cid: cid, titel: titel })
                else
                    pageStack.push(Qt.resolvedUrl("AnkuendigungSeite.qml"), { titel: titel, text: text })
            }
        }
        VerticalScrollDecorator { }
    }
}
