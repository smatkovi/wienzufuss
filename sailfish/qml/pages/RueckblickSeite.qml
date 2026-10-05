import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Jahresrueckblick (GET v1/user/review?year=).
Page {
    id: seite
    property int jahr: new Date().getFullYear()
    property var r: null
    property string hinweis: ""

    Component.onCompleted: laden.senden("rueckblick", { jahr: jahr })
    onJahrChanged: { r = null; laden.senden("rueckblick", { jahr: jahr }) }

    Anfrage {
        id: laden
        onFertig: {
            seite.r = daten && daten.review ? daten.review : null
            seite.hinweis = seite.r ? "" : "Für " + seite.jahr + " gibt es keinen Rückblick."
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge

        PullDownMenu {
            busy: laden.laeuft
            MenuItem { text: String(new Date().getFullYear() - 1); onClicked: seite.jahr = new Date().getFullYear() - 1 }
            MenuItem { text: String(new Date().getFullYear()); onClicked: seite.jahr = new Date().getFullYear() }
        }

        Column {
            id: inhalt
            width: parent.width
            spacing: Theme.paddingLarge
            PageHeader { title: "Jahresrückblick"; description: String(seite.jahr) }
            Hinweis { color: Theme.secondaryHighlightColor; text: seite.hinweis }
            Column {
                width: parent.width
                spacing: Theme.paddingLarge
                visible: !!seite.r
                Row {
                    width: parent.width
                    Wert { width: parent.width / 2; zahl: seite.r ? W.tausender(seite.r.totalStepsForYear) : "–"; text: "Schritte im Jahr" }
                    Wert { width: parent.width / 2; zahl: seite.r ? W.strecke(seite.r.totalDistanceForYear) : "–"; text: "Strecke im Jahr" }
                }
                Row {
                    width: parent.width
                    Wert { width: parent.width / 2; groesse: Theme.fontSizeMedium; zahl: seite.r ? W.tausender(seite.r.dailyTargetReached) : "–"; text: "Tage mit erreichtem Ziel" }
                    Wert { width: parent.width / 2; groesse: Theme.fontSizeMedium; zahl: seite.r ? W.tausender(seite.r.daysWithZeroSteps) : "–"; text: "Tage ohne Schritte" }
                }
                Row {
                    width: parent.width
                    Wert { width: parent.width / 2; groesse: Theme.fontSizeMedium; zahl: seite.r ? W.tausender(seite.r.numberOfChallenges) : "–"; text: "Challenges" }
                    Wert { width: parent.width / 2; groesse: Theme.fontSizeMedium; zahl: seite.r ? W.tausender(seite.r.numberOfVouchers) : "–"; text: "Gutscheine" }
                }
                Hinweis {
                    color: Theme.primaryColor
                    text: {
                        if (!seite.r)
                            return ""
                        var t = ""
                        if (seite.r.fromCityName && seite.r.toCityName)
                            t += "So weit bist du gegangen: von " + seite.r.fromCityName + " nach " + seite.r.toCityName + "."
                        if (seite.r.nextGoalCityName)
                            t += (t ? "\n" : "") + "Bis " + seite.r.nextGoalCityName + " fehlen noch "
                                 + W.strecke(W.zahl(seite.r.nextGoalCityDistance, 0)) + "."
                        return t
                    }
                }
                Hinweis {
                    color: Theme.secondaryColor
                    text: {
                        if (!seite.r)
                            return ""
                        var t = []
                        var b = W.rueckblickTage(seite.r.mostSteps), l = W.rueckblickTage(seite.r.leastSteps)
                        if (b !== "")
                            t.push("Beste Tage: " + b)
                        if (l !== "")
                            t.push("Ruhigste Tage: " + l)
                        return t.join("\n")
                    }
                }
            }
        }
        VerticalScrollDecorator { }
    }
}
