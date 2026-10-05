import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Ranking: der eigene Platz in Wien und im Bezirk, darunter die Liste.
Page {
    id: seite
    property string intervall: "WEEK"
    property bool imBezirk: false
    property var rang: null
    property int gesamt: 0
    property string hinweis: ""

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
                    schritte: W.zahl(e.steps, 0)
                })
            }
            seite.gesamt = daten && daten.total !== undefined ? W.zahl(daten.total, liste.count) : liste.count
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    ListModel { id: liste }

    SilicaListView {
        id: ansicht
        anchors.fill: parent
        model: liste

        PullDownMenu {
            busy: rangAnfrage.laeuft || listeAnfrage.laeuft
            MenuItem { text: "Aktualisieren"; onClicked: seite.laden() }
        }

        header: Column {
            width: ansicht.width
            spacing: Theme.paddingSmall
            PageHeader {
                title: "Ranking"
                description: fenster.nutzer ? W.bezirkName(fenster.nutzer.territory) : ""
            }
            ComboBox {
                label: "Zeitraum"
                currentIndex: 1
                menu: ContextMenu {
                    Repeater {
                        model: W.intervalle
                        MenuItem { text: modelData.name; onClicked: seite.intervall = modelData.wert }
                    }
                }
            }
            Row {
                width: parent.width
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
            Hinweis {
                color: Theme.secondaryHighlightColor
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (!seite.rang)
                        return ""
                    var t = W.tausender(seite.rang.steps) + " Schritte · " + W.strecke(seite.rang.distance)
                    if (seite.rang.global && W.zahl(seite.rang.global.stepsToLead, 0) > 0)
                        t += "\nDu bist " + W.tausender(seite.rang.global.stepsToLead) + " Schritte hinter dem ersten Platz."
                    return t
                }
            }
            Hinweis { fehler: true; text: seite.hinweis }
            ComboBox {
                label: "Liste"
                menu: ContextMenu {
                    MenuItem { text: "Wien"; onClicked: seite.imBezirk = false }
                    MenuItem { text: "Mein Bezirk"; onClicked: seite.imBezirk = true }
                }
            }
        }

        delegate: ListItem {
            contentHeight: Theme.itemSizeSmall
            property bool ich: fenster.nutzer && name === fenster.nutzer.username
            highlighted: down || ich
            Label {
                id: platzLabel
                anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                width: Theme.itemSizeSmall * 1.2
                text: platz + "."
                color: platz <= 3 ? "#e8bc2c" : Theme.secondaryColor
            }
            Label {
                anchors { left: platzLabel.right; right: schritteLabel.left; rightMargin: Theme.paddingMedium
                          verticalCenter: parent.verticalCenter }
                text: name
                truncationMode: TruncationMode.Fade
            }
            Label {
                id: schritteLabel
                anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                text: W.tausender(schritte)
                color: Theme.secondaryColor
            }
        }

        footer: Item {
            width: ansicht.width
            height: mehr.visible ? mehr.height + 2 * Theme.paddingLarge : Theme.paddingLarge
            Button {
                id: mehr
                anchors.centerIn: parent
                visible: liste.count > 0 && liste.count < seite.gesamt
                text: "Weitere laden"
                enabled: !listeAnfrage.laeuft
                onClicked: seite.listeLaden(liste.count)
            }
        }
        VerticalScrollDecorator { }
    }
}
