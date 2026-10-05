import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Jahresrueckblick (GET v1/user/review?year=).
Page {
    id: seite
    property int jahr: new Date().getFullYear()
    property variant r: null
    property string hinweis: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
    }

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

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: "Jahresrückblick"
        untertitel: String(seite.jahr)
        laedt: laden.laeuft
    }

    Flickable {
        id: flick
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: inhalt.height + 32
        clip: true
        Column {
            id: inhalt
            x: 16
            width: parent.width - 32
            spacing: 14
            Item { width: 1; height: 6 }
            ButtonRow {
                width: parent.width
                Button { text: String(new Date().getFullYear() - 1); checked: seite.jahr === new Date().getFullYear() - 1; onClicked: seite.jahr = new Date().getFullYear() - 1 }
                Button { text: String(new Date().getFullYear()); checked: seite.jahr === new Date().getFullYear(); onClicked: seite.jahr = new Date().getFullYear() }
            }
            Text {
                width: parent.width
                visible: seite.hinweis !== ""
                wrapMode: Text.WordWrap
                color: "#bfbfbf"
                font.pixelSize: 22
                text: seite.hinweis
            }
            Column {
                width: parent.width
                spacing: 14
                visible: seite.r ? true : false
                Row {
                    width: parent.width
                    Wert { width: parent.width / 2; zahl: seite.r ? W.tausender(seite.r.totalStepsForYear) : "–"; text: "Schritte im Jahr" }
                    Wert { width: parent.width / 2; zahl: seite.r ? W.strecke(seite.r.totalDistanceForYear) : "–"; text: "Strecke im Jahr" }
                }
                Row {
                    width: parent.width
                    Wert { width: parent.width / 2; groesse: 28; zahl: seite.r ? W.tausender(seite.r.dailyTargetReached) : "–"; text: "Tage mit erreichtem Ziel" }
                    Wert { width: parent.width / 2; groesse: 28; zahl: seite.r ? W.tausender(seite.r.daysWithZeroSteps) : "–"; text: "Tage ohne Schritte" }
                }
                Row {
                    width: parent.width
                    Wert { width: parent.width / 2; groesse: 28; zahl: seite.r ? W.tausender(seite.r.numberOfChallenges) : "–"; text: "Challenges" }
                    Wert { width: parent.width / 2; groesse: 28; zahl: seite.r ? W.tausender(seite.r.numberOfVouchers) : "–"; text: "Gutscheine" }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "white"
                    font.pixelSize: 22
                    visible: text !== ""
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
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#bfbfbf"
                    font.pixelSize: 20
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
    }
    ScrollDecorator { flickableItem: flick }
}
