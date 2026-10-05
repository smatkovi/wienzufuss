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

    Component.onCompleted: laden.senden("challenges", {})
    onStatusChanged: if (status === PageStatus.Active && liste.count > 0) laden.senden("challenges", {})

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
                dabei: c.hasJoined === true
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
                onClicked: pageStack.push(Qt.resolvedUrl("ChallengeSeite.qml"), { cid: cid, titel: titel })
            }
        }
    }
    ScrollDecorator { flickableItem: ansicht }
}
