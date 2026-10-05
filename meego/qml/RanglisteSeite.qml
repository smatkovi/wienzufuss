import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Ranking: der eigene Platz in Wien und im Bezirk, darunter die Liste.
Page {
    id: seite
    property string intervall: "WEEK"
    property bool imBezirk: false
    property variant rang: null
    property int gesamt: 0
    property string hinweis: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
        ToolIcon { iconId: "toolbar-refresh"; onClicked: seite.laden() }
    }

    Component.onCompleted: laden()
    onIntervallChanged: laden()
    onImBezirkChanged: listeLaden(0)

    function laden() {
        hinweis = ""
        rangAnfrage.senden("rang", { intervall: intervall })
        listeLaden(0)
    }

    function listeLaden(ab) {
        if (ab === 0)
            liste.clear()
        var w = { intervall: intervall, limit: 50, offset: ab }
        if (imBezirk && fenster.nutzer && fenster.nutzer.territory)
            w.bezirk = String(fenster.nutzer.territory)
        listeAnfrage.senden("bestenliste", w)
    }

    Anfrage {
        id: rangAnfrage
        onFertig: seite.rang = daten
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }
    Anfrage {
        id: listeAnfrage
        onFertig: {
            var l = daten && daten.list ? daten.list : (daten && daten.length !== undefined ? daten : [])
            for (var i = 0; i < l.length; ++i) {
                var e = l[i]
                liste.append({
                    platz: W.zahl(e.position, liste.count + 1),
                    name: e.username ? String(e.username) : "–",
                    schritte: W.zahl(e.steps, 0),
                    meter: W.zahl(e.distance, 0)
                })
            }
            seite.gesamt = daten && daten.total !== undefined ? W.zahl(daten.total, liste.count) : liste.count
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    ListModel { id: liste }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: "Ranking"
        untertitel: fenster.nutzer ? W.bezirkName(fenster.nutzer.territory) : ""
        laedt: rangAnfrage.laeuft || listeAnfrage.laeuft
    }

    ListView {
        id: ansicht
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: liste
        header: Column {
            width: ansicht.width
            spacing: 10
            Item { width: 1; height: 6 }
            ButtonRow {
                x: 16
                width: parent.width - 32
                Repeater {
                    model: W.intervalle
                    Button {
                        text: modelData.name
                        checked: seite.intervall === modelData.wert
                        onClicked: seite.intervall = modelData.wert
                    }
                }
            }
            Row {
                x: 16
                width: parent.width - 32
                Wert {
                    width: parent.width / 2
                    zahl: seite.rang && seite.rang.global ? W.tausender(seite.rang.global.rank) + "." : "–"
                    text: "Platz in Wien"
                }
                Wert {
                    width: parent.width / 2
                    zahl: seite.rang && seite.rang.territory ? W.tausender(seite.rang.territory.rank) + "." : "–"
                    text: "Platz im Bezirk"
                }
            }
            Text {
                x: 16
                width: parent.width - 32
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: "#bfbfbf"
                font.pixelSize: 20
                text: {
                    if (!seite.rang)
                        return ""
                    var t = W.tausender(seite.rang.steps) + " Schritte · " + W.strecke(seite.rang.distance)
                    if (seite.rang.global && W.zahl(seite.rang.global.stepsToLead, 0) > 0)
                        t += "\nDu bist " + W.tausender(seite.rang.global.stepsToLead) + " Schritte hinter dem ersten Platz."
                    return t
                }
            }
            Text {
                x: 16
                width: parent.width - 32
                visible: seite.hinweis !== ""
                wrapMode: Text.WordWrap
                color: "#ff6060"
                font.pixelSize: 20
                text: seite.hinweis
            }
            ButtonRow {
                x: 16
                width: parent.width - 32
                Button { text: "Wien"; checked: !seite.imBezirk; onClicked: seite.imBezirk = false }
                Button { text: "Mein Bezirk"; checked: seite.imBezirk; onClicked: seite.imBezirk = true }
            }
            Item { width: 1; height: 4 }
        }
        delegate: Item {
            width: ansicht.width
            height: 64
            property bool ich: fenster.nutzer && name === fenster.nutzer.username
            Rectangle { anchors.fill: parent; color: "#1d3a44"; visible: ich }
            Text {
                id: platzText
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                width: 70
                text: platz + "."
                color: platz <= 3 ? "#e8bc2c" : "#8c8c8c"
                font.pixelSize: 24
            }
            Text {
                anchors { left: platzText.right; right: schritteText.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: name
                color: "white"
                font.pixelSize: 24
                elide: Text.ElideRight
            }
            Text {
                id: schritteText
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: W.tausender(schritte)
                color: "#bfbfbf"
                font.pixelSize: 22
            }
        }
        footer: Item {
            width: ansicht.width
            height: mehr.visible ? 90 : 20
            Button {
                id: mehr
                anchors.centerIn: parent
                width: parent.width - 32
                visible: liste.count > 0 && liste.count < seite.gesamt
                text: "Weitere laden"
                enabled: !listeAnfrage.laeuft
                onClicked: seite.listeLaden(liste.count)
            }
        }
    }
    ScrollDecorator { flickableItem: ansicht }
}
