import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Ein Gutschein: Bild, Beschreibung, wo einloesen; einloesen oder den
// erhaltenen Code zeigen.
Page {
    id: seite
    property int gid: 0
    property string titel: ""
    property var g: null
    property string hinweis: ""
    property var eingeloest: g && g.redeemedVoucher ? g.redeemedVoucher : null
    property string art: g ? String(g.type).toLowerCase() : ""

    Component.onCompleted: laden.senden("gutschein", { id: gid })
    onStatusChanged: if (status === PageStatus.Active && g) laden.senden("gutschein", { id: gid })

    Anfrage {
        id: laden
        onFertig: seite.g = daten
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge

        PullDownMenu {
            visible: seite.g && !seite.eingeloest ? true : false
            MenuItem { text: "Einlösen"; onClicked: pageStack.push(Qt.resolvedUrl("EinloesenSeite.qml"), { g: seite.g }) }
        }

        Column {
            id: inhalt
            width: parent.width
            spacing: Theme.paddingMedium
            PageHeader {
                title: seite.g && seite.g.title ? seite.g.title : seite.titel
                description: seite.g ? W.gutscheinArt(seite.g.type) : ""
            }
            Image {
                width: parent.width
                height: visible ? width * 9 / 16 : 0
                visible: seite.g && (seite.g.headerImageUrl || seite.g.listImageUrl) ? true : false
                source: seite.g ? (seite.g.headerImageUrl ? seite.g.headerImageUrl : (seite.g.listImageUrl ? seite.g.listImageUrl : "")) : ""
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
                sourceSize.width: width
            }
            Hinweis {
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                text: seite.g && seite.g.name ? seite.g.name : ""
            }
            Row {
                width: parent.width
                visible: seite.g ? true : false
                Wert { width: parent.width / 2; zahl: seite.g ? W.tausender(seite.g.requiredSteps) : "–"; text: "Schritte nötig" }
                Wert {
                    width: parent.width / 2
                    zahl: seite.g && seite.g.contingent !== undefined && seite.g.contingent !== null
                          ? W.tausender(Math.max(0, W.zahl(seite.g.contingent, 0) - W.zahl(seite.g.redeemed, 0))) : "–"
                    text: "noch verfügbar"
                }
            }
            Hinweis {
                visible: text !== "" && !seite.eingeloest
                text: seite.g && fenster.nutzer
                      ? (W.gutscheinStand(fenster.nutzer.points, seite.g.requiredSteps) === "einlösbar"
                         ? "Mit deinen " + W.tausender(fenster.nutzer.points) + " Punkten einlösbar."
                         : "Du hast " + W.tausender(fenster.nutzer.points) + " Punkte – es fehlen "
                           + W.gutscheinStand(fenster.nutzer.points, seite.g.requiredSteps).replace("noch ", "") + ".")
                      : ""
                color: text.indexOf("einlösbar") >= 0 ? "#a0b436" : Theme.highlightColor
            }
            Hinweis {
                color: Theme.secondaryColor
                text: seite.g && seite.g.published && seite.g.published.until ? "Gültig bis " + W.datum(seite.g.published.until) : ""
            }

            // Schon eingeloest: Code und Text
            SectionHeader { text: "Eingelöst"; visible: !!seite.eingeloest }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: seite.eingeloest && seite.eingeloest.code ? true : false
                text: seite.eingeloest && seite.eingeloest.code ? seite.eingeloest.code : ""
                font.pixelSize: Theme.fontSizeExtraLarge
                color: Theme.highlightColor
                wrapMode: Text.WrapAnywhere
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: text !== ""
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                font.pixelSize: Theme.fontSizeSmall
                text: seite.eingeloest && seite.eingeloest.redeemTextHtml ? seite.eingeloest.redeemTextHtml : ""
                onLinkActivated: Qt.openUrlExternally(link)
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: seite.eingeloest && seite.eingeloest.code ? true : false
                text: "Code kopieren"
                onClicked: { Clipboard.text = seite.eingeloest.code; fenster.meldung("Kopiert.") }
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: seite.g && !seite.eingeloest ? true : false
                text: "Einlösen"
                onClicked: pageStack.push(Qt.resolvedUrl("EinloesenSeite.qml"), { g: seite.g })
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                font.pixelSize: Theme.fontSizeSmall
                text: seite.g && seite.g.descriptionHtml
                      ? "<style>a:link{color:" + Theme.highlightColor + "}</style>" + seite.g.descriptionHtml : ""
                onLinkActivated: Qt.openUrlExternally(link)
            }
            SectionHeader {
                text: seite.art === "gastronomy" ? "Hier einlösen" : "Abholstellen"
                visible: stellen.count > 0
            }
            Repeater {
                id: stellen
                model: seite.g && seite.g.pickupStations ? seite.g.pickupStations : []
                Column {
                    x: Theme.horizontalPageMargin
                    width: inhalt.width - 2 * Theme.horizontalPageMargin
                    Label { width: parent.width; text: modelData.name ? modelData.name : ""; wrapMode: Text.WordWrap }
                    Label {
                        width: parent.width
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        wrapMode: Text.WordWrap
                        text: modelData.addressStringOverride ? modelData.addressStringOverride
                              : (modelData.address ? (modelData.address.street ? modelData.address.street : "") + ", "
                                                     + (modelData.address.zip ? modelData.address.zip : "") + " "
                                                     + (modelData.address.city ? modelData.address.city : "") : "")
                    }
                }
            }
            Hinweis { fehler: true; text: seite.hinweis }
        }
        VerticalScrollDecorator { }
    }
}
