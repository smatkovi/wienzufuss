import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Ein Gutschein: Bild, Beschreibung, wo einloesen; einloesen oder den
// erhaltenen Code zeigen.
Page {
    id: seite
    property int gid: 0
    property string titel: ""
    property variant g: null
    property string hinweis: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
    }

    Component.onCompleted: laden.senden("gutschein", { id: gid })
    onStatusChanged: if (status === PageStatus.Active && g) laden.senden("gutschein", { id: gid })

    property variant eingeloest: g && g.redeemedVoucher ? g.redeemedVoucher : null
    property string art: g ? String(g.type).toLowerCase() : ""

    Anfrage {
        id: laden
        onFertig: seite.g = daten
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: seite.g && seite.g.title ? seite.g.title : seite.titel
        untertitel: seite.g ? W.gutscheinArt(seite.g.type) : ""
        laedt: laden.laeuft
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
                visible: seite.g && (seite.g.headerImageUrl || seite.g.listImageUrl) ? true : false
                url: seite.g ? (seite.g.headerImageUrl ? seite.g.headerImageUrl : (seite.g.listImageUrl ? seite.g.listImageUrl : "")) : ""
            }
            Column {
                id: spalte
                x: 16
                width: parent.width - 32
                spacing: 12
                visible: seite.g ? true : false

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "white"
                    font.pixelSize: 26
                    visible: seite.g && seite.g.name ? true : false
                    text: seite.g && seite.g.name ? seite.g.name : ""
                }
                Row {
                    width: parent.width
                    Wert {
                        width: parent.width / 2
                        groesse: 30
                        zahl: seite.g ? W.tausender(seite.g.requiredSteps) : "–"
                        text: "Schritte nötig"
                    }
                    Wert {
                        width: parent.width / 2
                        groesse: 30
                        zahl: seite.g && seite.g.contingent !== undefined && seite.g.contingent !== null
                              ? W.tausender(Math.max(0, W.zahl(seite.g.contingent, 0) - W.zahl(seite.g.redeemed, 0))) : "–"
                        text: "noch verfügbar"
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 22
                    visible: text !== "" && !seite.eingeloest
                    text: seite.g && fenster.nutzer
                          ? (W.gutscheinStand(fenster.nutzer.points, seite.g.requiredSteps) === "einlösbar"
                             ? "Mit deinen " + W.tausender(fenster.nutzer.points) + " Punkten einlösbar."
                             : "Du hast " + W.tausender(fenster.nutzer.points) + " Punkte – es fehlen "
                               + W.gutscheinStand(fenster.nutzer.points, seite.g.requiredSteps).replace("noch ", "") + ".")
                          : ""
                    color: text.indexOf("einlösbar") >= 0 ? "#a0b436" : "#e8bc2c"
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#8c8c8c"
                    font.pixelSize: 20
                    visible: seite.g && seite.g.published && seite.g.published.until ? true : false
                    text: seite.g && seite.g.published ? "Gültig bis " + W.datum(seite.g.published.until) : ""
                }

                // Schon eingeloest: Code und Text zeigen
                Rectangle {
                    width: parent.width
                    height: eingeloestSpalte.height + 24
                    visible: seite.eingeloest ? true : false
                    color: "#1d3a44"
                    radius: 8
                    Column {
                        id: eingeloestSpalte
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 6
                        Text { text: "Eingelöst"; color: "#a0b436"; font.pixelSize: 20 }
                        Text {
                            width: parent.width
                            visible: seite.eingeloest && seite.eingeloest.code ? true : false
                            text: seite.eingeloest && seite.eingeloest.code ? seite.eingeloest.code : ""
                            color: "white"
                            font.pixelSize: 34
                            font.family: "Nokia Pure Text Light"
                            wrapMode: Text.WrapAnywhere
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            textFormat: Text.RichText
                            color: "white"
                            font.pixelSize: 20
                            text: seite.eingeloest && seite.eingeloest.redeemTextHtml ? seite.eingeloest.redeemTextHtml : ""
                            onLinkActivated: Dienst.oeffnen(link)
                        }
                        Button {
                            width: parent.width
                            visible: seite.eingeloest && seite.eingeloest.code ? true : false
                            text: "Code kopieren"
                            onClicked: { Dienst.kopieren(seite.eingeloest.code); fenster.meldung("Kopiert.") }
                        }
                    }
                }

                Button {
                    width: parent.width
                    visible: seite.g && !seite.eingeloest ? true : false
                    text: "Einlösen"
                    onClicked: pageStack.push(Qt.resolvedUrl("EinloesenSeite.qml"), { g: seite.g })
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    color: "white"
                    font.pixelSize: 22
                    text: seite.g && seite.g.descriptionHtml ? "<style>a{color:#7fd0ea}</style>" + seite.g.descriptionHtml : ""
                    onLinkActivated: Dienst.oeffnen(link)
                }
                Ueberschrift {
                    text: seite.art === "gastronomy" ? "Hier einlösen" : "Abholstellen"
                    visible: stellen.count > 0
                }
                Repeater {
                    id: stellen
                    model: seite.g && seite.g.pickupStations ? seite.g.pickupStations : []
                    Column {
                        width: spalte.width
                        spacing: 2
                        Text { width: parent.width; text: modelData.name ? modelData.name : ""; color: "white"; font.pixelSize: 22; wrapMode: Text.WordWrap }
                        Text {
                            width: parent.width
                            color: "#8c8c8c"
                            font.pixelSize: 20
                            wrapMode: Text.WordWrap
                            text: modelData.addressStringOverride ? modelData.addressStringOverride
                                  : (modelData.address ? (modelData.address.street ? modelData.address.street : "") + ", "
                                                         + (modelData.address.zip ? modelData.address.zip : "") + " "
                                                         + (modelData.address.city ? modelData.address.city : "") : "")
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
