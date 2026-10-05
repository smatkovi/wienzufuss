import QtQuick 2.0
import Sailfish.Silica 1.0
import "../wzf.js" as W

// Titelbild: Schritte heute und der Weg zum Tagesziel.
CoverBackground {
    property var stand: fenster.stand
    property int heute: stand ? W.zahl(stand.schritteHeute, 0) : 0
    property int ziel: fenster.nutzer ? W.zahl(fenster.nutzer.dailyTarget, 10000) : 10000

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingLarge
        spacing: Theme.paddingSmall
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: W.tausender(heute)
            font.pixelSize: Theme.fontSizeHuge
            color: heute >= ziel ? "#a0b436" : Theme.highlightColor
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Schritte"
            color: Theme.secondaryColor
        }
        Rectangle {
            width: parent.width
            height: Theme.paddingSmall
            radius: height / 2
            color: Theme.rgba(Theme.primaryColor, 0.2)
            Rectangle {
                width: parent.width * Math.min(1, heute / Math.max(1, ziel))
                height: parent.height
                radius: height / 2
                color: heute >= ziel ? "#a0b436" : "#3790ad"
            }
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Ziel " + W.tausender(ziel)
            font.pixelSize: Theme.fontSizeExtraSmall
            color: Theme.secondaryColor
        }
    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-refresh"
            onTriggered: Schritte.aktualisieren()
        }
    }
}
