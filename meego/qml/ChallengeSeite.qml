import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Eine Challenge: Ziel, gemeinsamer Stand, Beschreibung, Teilnehmerliste;
// mitmachen oder austreten.
Page {
    id: seite
    property int cid: 0
    property string titel: ""
    property variant c: null
    property string hinweis: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
    }

    Component.onCompleted: laden.senden("challenge", { id: cid })

    Anfrage {
        id: laden
        onFertig: seite.c = daten
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }
    Anfrage {
        id: teilnahme
        onFertig: {
            fenster.meldung(daten.teilgenommen ? "Du machst mit." : "Du hast die Challenge verlassen.")
            laden.senden("challenge", { id: seite.cid })
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    QueryDialog {
        id: verlassen
        titleText: "Challenge verlassen?"
        message: "Wenn du die Challenge verlässt, zählen deine Schritte nicht mehr für ihr Ziel. Ein neuerliches Anmelden ist möglich."
        acceptButtonText: "Verlassen"
        rejectButtonText: "Abbrechen"
        onAccepted: teilnahme.senden("teilnehmen", { id: seite.cid, ja: false })
    }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: seite.c && seite.c.title ? seite.c.title : seite.titel
        untertitel: seite.c ? (W.datum(seite.c.from) + (seite.c.to ? " – " + W.datum(seite.c.to) : "")) : ""
        laedt: laden.laeuft || teilnahme.laeuft
    }

    Flickable {
        id: flick
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: inhalt.height + 32
        clip: true
        Column {
            id: inhalt
            width: parent.width
            spacing: 12
            Bild {
                width: parent.width
                height: visible ? width * 9 / 16 : 0
                visible: seite.c && seite.c.imageUrl ? true : false
                url: seite.c && seite.c.imageUrl ? seite.c.imageUrl : ""
            }
            Column {
                id: spalte
                x: 16
                width: parent.width - 32
                spacing: 12
                visible: seite.c ? true : false

                // Ziel und gemeinsamer Stand
                property real ziel: seite.c ? (seite.c.stepGoal ? W.zahl(seite.c.stepGoal, 0) : W.zahl(seite.c.distanceGoal, 0)) : 0
                property real stand: seite.c ? (seite.c.stepGoal ? W.zahl(seite.c.totalSteps, 0) : W.zahl(seite.c.totalDistance, 0)) : 0
                property bool schritte: seite.c && seite.c.stepGoal ? true : false
                function fmt(v) { return schritte ? W.tausender(v) + " Schritte" : W.strecke(v) }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "white"
                    font.pixelSize: 24
                    visible: parent.ziel > 0
                    text: "Ziel: " + parent.fmt(parent.ziel) + "\nGemeinsam geschafft: " + parent.fmt(parent.stand)
                }
                ProgressBar {
                    width: parent.width
                    visible: parent.ziel > 0
                    minimumValue: 0
                    maximumValue: Math.max(1, parent.ziel)
                    value: Math.min(parent.stand, parent.ziel)
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#e8bc2c"
                    font.pixelSize: 22
                    visible: seite.c && seite.c.userRank ? true : false
                    text: seite.c && seite.c.userRank
                          ? "Du bist auf Platz " + W.zahl(seite.c.userRank.position, 0) + " mit "
                            + W.tausender(seite.c.userRank.steps) + " Schritten." : ""
                }
                Button {
                    width: parent.width
                    visible: seite.c ? seite.c.challengeIsLocked !== true : false
                    text: seite.c && seite.c.hasJoined ? "Challenge verlassen" : "Mitmachen"
                    enabled: !teilnahme.laeuft
                    onClicked: {
                        if (seite.c.hasJoined)
                            verlassen.open()
                        else
                            teilnahme.senden("teilnehmen", { id: seite.cid, ja: true })
                    }
                }
                Text {
                    width: parent.width
                    visible: seite.c ? seite.c.challengeIsLocked === true : false
                    wrapMode: Text.WordWrap
                    color: "#8c8c8c"
                    font.pixelSize: 20
                    text: "Bei dieser Challenge ist keine Anmeldung (mehr) möglich."
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    color: "white"
                    font.pixelSize: 22
                    text: seite.c && seite.c.descriptionHtml ? "<style>a{color:#7fd0ea}</style>" + seite.c.descriptionHtml : ""
                    onLinkActivated: Dienst.oeffnen(link)
                }
                Ueberschrift {
                    text: "Teilnehmerliste"
                    visible: seite.c && seite.c.ranking && seite.c.ranking.length > 0 ? true : false
                }
                Repeater {
                    model: seite.c && seite.c.ranking ? seite.c.ranking : []
                    Item {
                        width: spalte.width
                        height: 52
                        Text {
                            id: p
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64
                            text: W.zahl(modelData.position, index + 1) + "."
                            color: "#8c8c8c"
                            font.pixelSize: 22
                        }
                        Text {
                            anchors { left: p.right; right: s.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: modelData.username ? modelData.username : "–"
                            color: "white"
                            font.pixelSize: 22
                            elide: Text.ElideRight
                        }
                        Text {
                            id: s
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: W.tausender(modelData.steps)
                            color: "#bfbfbf"
                            font.pixelSize: 20
                        }
                    }
                }
            }
            Text {
                x: 16
                width: parent.width - 32
                visible: seite.hinweis !== ""
                wrapMode: Text.WordWrap
                color: "#ff6060"
                font.pixelSize: 22
                text: seite.hinweis
            }
        }
    }
    ScrollDecorator { flickableItem: flick }
}
