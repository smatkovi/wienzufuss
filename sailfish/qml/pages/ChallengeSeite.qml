import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Eine Challenge: Ziel, gemeinsamer Stand, Beschreibung, Teilnehmerliste;
// mitmachen oder austreten.
Page {
    id: seite
    property int cid: 0
    property string titel: ""
    property var c: null
    property string hinweis: ""

    property real ziel: c ? (c.stepGoal ? W.zahl(c.stepGoal, 0) : W.zahl(c.distanceGoal, 0)) : 0
    property real erreicht: c ? (c.stepGoal ? W.zahl(c.totalSteps, 0) : W.zahl(c.totalDistance, 0)) : 0
    property bool inSchritten: c && c.stepGoal ? true : false
    function fmt(v) { return inSchritten ? W.tausender(v) + " Schritte" : W.strecke(v) }

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
    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge

        PullDownMenu {
            visible: seite.c ? seite.c.challengeIsLocked !== true : false
            busy: teilnahme.laeuft
            MenuItem {
                text: seite.c && seite.c.hasJoined ? "Challenge verlassen" : "Mitmachen"
                onClicked: {
                    if (seite.c.hasJoined)
                        remorse.execute("Challenge verlassen", function() { teilnahme.senden("teilnehmen", { id: seite.cid, ja: false }) })
                    else
                        teilnahme.senden("teilnehmen", { id: seite.cid, ja: true })
                }
            }
        }

        Column {
            id: inhalt
            width: parent.width
            spacing: Theme.paddingMedium
            PageHeader {
                title: seite.c && seite.c.title ? seite.c.title : seite.titel
                description: seite.c ? (W.datum(seite.c.from) + (seite.c.to ? " – " + W.datum(seite.c.to) : "")) : ""
            }
            Image {
                width: parent.width
                height: visible ? width * 9 / 16 : 0
                visible: seite.c && seite.c.imageUrl ? true : false
                source: seite.c && seite.c.imageUrl ? seite.c.imageUrl : ""
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
            }
            Hinweis {
                visible: seite.ziel > 0
                color: Theme.primaryColor
                text: seite.ziel > 0 ? "Ziel: " + seite.fmt(seite.ziel) + "\nGemeinsam geschafft: " + seite.fmt(seite.erreicht) : ""
            }
            ProgressBar {
                width: parent.width
                visible: seite.ziel > 0
                minimumValue: 0
                maximumValue: Math.max(1, seite.ziel)
                value: Math.min(seite.erreicht, seite.ziel)
            }
            Hinweis {
                text: seite.c && seite.c.userRank
                      ? "Du bist auf Platz " + W.zahl(seite.c.userRank.position, 0) + " mit "
                        + W.tausender(seite.c.userRank.steps) + " Schritten." : ""
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: seite.c ? seite.c.challengeIsLocked !== true && seite.c.hasJoined !== true : false
                text: "Mitmachen"
                enabled: !teilnahme.laeuft
                onClicked: teilnahme.senden("teilnehmen", { id: seite.cid, ja: true })
            }
            Hinweis {
                color: Theme.secondaryColor
                text: seite.c && seite.c.challengeIsLocked === true ? "Bei dieser Challenge ist keine Anmeldung (mehr) möglich." : ""
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                font.pixelSize: Theme.fontSizeSmall
                text: seite.c && seite.c.descriptionHtml
                      ? "<style>a:link{color:" + Theme.highlightColor + "}</style>" + seite.c.descriptionHtml : ""
                onLinkActivated: Qt.openUrlExternally(link)
            }
            SectionHeader {
                text: "Teilnehmerliste"
                visible: seite.c && seite.c.ranking && seite.c.ranking.length > 0 ? true : false
            }
            Repeater {
                model: seite.c && seite.c.ranking ? seite.c.ranking : []
                Item {
                    width: inhalt.width
                    height: Theme.itemSizeExtraSmall
                    Label {
                        id: p
                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.itemSizeSmall
                        text: W.zahl(modelData.position, index + 1) + "."
                        color: Theme.secondaryColor
                    }
                    Label {
                        anchors { left: p.right; right: s.left; rightMargin: Theme.paddingMedium; verticalCenter: parent.verticalCenter }
                        text: modelData.username ? modelData.username : "–"
                        truncationMode: TruncationMode.Fade
                    }
                    Label {
                        id: s
                        anchors { right: parent.right; rightMargin: Theme.horizontalPageMargin; verticalCenter: parent.verticalCenter }
                        text: W.tausender(modelData.steps)
                        color: Theme.secondaryColor
                    }
                }
            }
            Hinweis { fehler: true; text: seite.hinweis }
        }
        VerticalScrollDecorator { }
    }
}
