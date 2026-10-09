import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Challenges: an denen ich teilnehme, die laufenden, die vergangenen.
Page {
    id: seite
    property string hinweis: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
        ToolIcon { iconId: "toolbar-refresh"; onClicked: laden.senden("challenges", {}) }
    }

    Component.onCompleted: { laden.senden("challenges", {}); angekuendigt.senden("ankuendigungen", {}) }
    onStatusChanged: if (status === PageStatus.Active && liste.count > 0) laden.senden("challenges", {})

    // Die Schnittstelle listet unter v1/challenge nur, was laeuft. Was
    // erst naechste Woche beginnt, steht nur auf der Webseite -- das
    // holt der Dienst getrennt und zieht ab, was schon als Gutschein
    // in der App steht.
    property variant ankuendigungen: []

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
        id: angekuendigt
        // Lesehilfe, keine Schnittstelle: scheitert sie, bleibt der
        // Abschnitt leer und die Seite laeuft weiter.
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

    Anfrage {
        id: laden
        onFertig: {
            liste.clear()
            seite.hinweis = ""
            eintragen("Meine Challenges", daten.joined)
            eintragen("Aktuelle Challenges", daten.available)
            eintragen("Vergangene Challenges", daten.closed)
            seite.ankuendigungEintragen()
            if (liste.count === 0)
                seite.hinweis = "Derzeit gibt es keine Challenges."
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    ListModel { id: liste }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: "Challenges"
        laedt: laden.laeuft
    }

    ListView {
        id: ansicht
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: liste
        section.property: "gruppe"
        section.delegate: Ueberschrift { x: 16; width: ansicht.width - 32; text: section }
        header: Text {
            x: 16
            width: ansicht.width - 32
            height: visible ? implicitHeight + 16 : 0
            visible: seite.hinweis !== ""
            wrapMode: Text.WordWrap
            color: "#bfbfbf"
            font.pixelSize: 22
            text: seite.hinweis
        }
        delegate: Item {
            width: ansicht.width
            height: 112
            Rectangle { anchors.fill: parent; color: "#26ffffff"; visible: maus.pressed }
            Bild {
                id: bild
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                width: 140
                height: 92
                url: model.bild
            }
            Column {
                anchors { left: bild.right; leftMargin: 12; right: parent.right; rightMargin: 16
                          verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    text: titel
                    color: "white"
                    font.pixelSize: 24
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: zeitraum + (dabei ? " · dabei" : "")
                    color: dabei ? "#a0b436" : "#8c8c8c"
                    font.pixelSize: 18
                }
            }
            MouseArea {
                id: maus
                anchors.fill: parent
                // Angekuendigtes hat noch keine Challenge-Kennung; dort gibt
                // es nur den Text der Webseite zu lesen.
                onClicked: {
                    if (cid > 0)
                        pageStack.push(Qt.resolvedUrl("ChallengeSeite.qml"), { cid: cid, titel: titel })
                    else
                        pageStack.push(Qt.resolvedUrl("AnkuendigungSeite.qml"), { titel: titel, text: text })
                }
            }
        }
    }
    ScrollDecorator { flickableItem: ansicht }
}
