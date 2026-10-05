import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Gutscheine: was es gibt, und was schon eingeloest ist.
Page {
    id: seite
    property bool istGutscheine: true
    property bool eingeloest: false
    property string hinweis: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
        ToolIcon { iconId: "toolbar-refresh"; onClicked: seite.laden() }
    }

    Component.onCompleted: laden()
    onEingeloestChanged: laden()
    onStatusChanged: if (status === PageStatus.Active && liste.count > 0) laden()

    function laden() {
        hinweis = ""
        anfrage.senden(eingeloest ? "eingeloest" : "gutscheine", {})
    }

    Anfrage {
        id: anfrage
        onFertig: {
            liste.clear()
            var l = daten && daten.length !== undefined ? daten : []
            for (var i = 0; i < l.length; ++i) {
                var g = l[i]
                liste.append({
                    gid: W.zahl(g.id, 0),
                    titel: g.title ? String(g.title) : (g.name ? String(g.name) : "Gutschein"),
                    name: g.name ? String(g.name) : "",
                    art: W.gutscheinArt(g.type),
                    schritte: W.zahl(g.requiredSteps, 0),
                    bild: g.listImageUrl ? String(g.listImageUrl) : (g.headerImageUrl ? String(g.headerImageUrl) : ""),
                    vorrat: g.contingent !== undefined && g.contingent !== null ? W.zahl(g.contingent, -1) - W.zahl(g.redeemed, 0) : -1,
                    code: g.redeemedVoucher && g.redeemedVoucher.code ? String(g.redeemedVoucher.code) : ""
                })
            }
            if (liste.count === 0)
                seite.hinweis = seite.eingeloest ? "Du hast noch keine Gutscheine eingelöst." : "Derzeit gibt es keine Gutscheine."
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    ListModel { id: liste }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: "Gutscheine"
        untertitel: fenster.nutzer ? W.tausender(fenster.nutzer.points) + " Punkte" : ""
        laedt: anfrage.laeuft
    }

    ListView {
        id: ansicht
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: liste
        header: Column {
            width: ansicht.width
            spacing: 8
            Item { width: 1; height: 6 }
            ButtonRow {
                x: 16
                width: parent.width - 32
                Button { text: "Verfügbar"; checked: !seite.eingeloest; onClicked: seite.eingeloest = false }
                Button { text: "Eingelöst"; checked: seite.eingeloest; onClicked: seite.eingeloest = true }
            }
            Text {
                x: 16
                width: parent.width - 32
                visible: seite.hinweis !== ""
                wrapMode: Text.WordWrap
                color: "#bfbfbf"
                font.pixelSize: 22
                text: seite.hinweis
            }
            Item { width: 1; height: 4 }
        }
        delegate: Item {
            width: ansicht.width
            height: 112
            Rectangle { anchors.fill: parent; color: "#26ffffff"; visible: maus.pressed }
            Bild {
                id: vorschau
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                width: 92
                height: 92
                url: model.bild
            }
            Column {
                anchors { left: vorschau.right; leftMargin: 12; right: parent.right; rightMargin: 16
                          verticalCenter: parent.verticalCenter }
                Text {
                    width: parent.width
                    text: titel
                    color: "white"
                    font.pixelSize: 22
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    color: "#8c8c8c"
                    font.pixelSize: 18
                    elide: Text.ElideRight
                    text: seite.eingeloest ? (code !== "" ? "Code: " + code : art)
                                           : (art + (schritte > 0 ? " · " + W.tausender(schritte) + " Schritte" : "")
                                              + (vorrat === 0 ? " · vergriffen" : ""))
                }
                Text {
                    width: parent.width
                    visible: !seite.eingeloest && text !== ""
                    font.pixelSize: 18
                    color: text === "einlösbar" ? "#a0b436" : "#e8bc2c"
                    text: fenster.nutzer ? W.gutscheinStand(fenster.nutzer.points, schritte) : ""
                }
            }
            MouseArea {
                id: maus
                anchors.fill: parent
                onClicked: pageStack.push(Qt.resolvedUrl("GutscheinSeite.qml"), { gid: gid, titel: titel })
            }
        }
    }
    ScrollDecorator { flickableItem: ansicht }
}
