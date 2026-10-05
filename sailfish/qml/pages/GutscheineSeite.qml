import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Gutscheine: was es gibt, und was schon eingeloest ist.
Page {
    id: seite
    property bool eingeloest: false
    property string hinweis: ""

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
                    art: W.gutscheinArt(g.type),
                    schritte: W.zahl(g.requiredSteps, 0),
                    bild: g.listImageUrl ? String(g.listImageUrl) : (g.headerImageUrl ? String(g.headerImageUrl) : ""),
                    vorrat: g.contingent !== undefined && g.contingent !== null ? W.zahl(g.contingent, -1) - W.zahl(g.redeemed, 0) : -1,
                    code: g.redeemedVoucher && g.redeemedVoucher.code ? String(g.redeemedVoucher.code) : ""
                })
            }
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    ListModel { id: liste }

    SilicaListView {
        id: ansicht
        anchors.fill: parent
        model: liste

        PullDownMenu {
            busy: anfrage.laeuft
            MenuItem {
                text: seite.eingeloest ? "Verfügbare Gutscheine" : "Eingelöste Gutscheine"
                onClicked: seite.eingeloest = !seite.eingeloest
            }
            MenuItem { text: "Aktualisieren"; onClicked: seite.laden() }
        }
        header: PageHeader {
            title: seite.eingeloest ? "Eingelöste Gutscheine" : "Gutscheine"
            description: fenster.nutzer ? W.tausender(fenster.nutzer.points) + " Punkte" : ""
        }
        ViewPlaceholder {
            enabled: liste.count === 0 && !anfrage.laeuft
            text: seite.hinweis !== "" ? seite.hinweis
                  : (seite.eingeloest ? "Du hast noch keine Gutscheine eingelöst." : "Derzeit gibt es keine Gutscheine.")
        }

        delegate: ListItem {
            contentHeight: Theme.itemSizeExtraLarge
            Image {
                id: vorschau
                anchors { left: parent.left; leftMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                width: height
                height: Theme.itemSizeExtraLarge - Theme.paddingMedium * 2
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
                sourceSize.width: width
                source: model.bild
                Rectangle { anchors.fill: parent; color: Theme.rgba(Theme.highlightBackgroundColor, 0.15); visible: parent.status !== Image.Ready }
            }
            Column {
                anchors { left: vorschau.right; leftMargin: Theme.paddingMedium; right: parent.right
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
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                    text: seite.eingeloest ? (code !== "" ? "Code: " + code : art)
                                           : (art + (schritte > 0 ? " · " + W.tausender(schritte) + " Schritte" : "")
                                              + (vorrat === 0 ? " · vergriffen" : ""))
                }
                Label {
                    width: parent.width
                    visible: !seite.eingeloest && text !== ""
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: text === "einlösbar" ? "#a0b436" : Theme.highlightColor
                    text: fenster.nutzer ? W.gutscheinStand(fenster.nutzer.points, schritte) : ""
                }
            }
            onClicked: pageStack.push(Qt.resolvedUrl("GutscheinSeite.qml"), { gid: gid, titel: titel })
        }
        VerticalScrollDecorator { }
    }
}
