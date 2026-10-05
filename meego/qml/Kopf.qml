import QtQuick 1.1
import com.nokia.meego 1.1

// Die Titelleiste im Blau von Wien zu Fuss (#3790ad), gebaut wie die
// Kopfzeilen der Standard-Apps (72 px hoch im Hochformat), mit optionaler
// Unterzeile und einem Drehrad, solange etwas laedt.
Rectangle {
    id: kopf
    property alias titel: titelText.text
    property alias untertitel: unterText.text
    property bool laedt: false

    width: parent ? parent.width : 480
    height: screen.currentOrientation === Screen.Landscape ? 56 : 72
    color: "#3790ad"
    z: 10

    // Das Gelb des Fortschrittskreises der App als Strich darunter.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 4
        color: "#e8bc2c"
    }

    Column {
        anchors { left: parent.left; leftMargin: 16; right: rad.left; rightMargin: 8
                  verticalCenter: parent.verticalCenter; verticalCenterOffset: -2 }
        Text {
            id: titelText
            width: parent.width
            color: "white"
            font.pixelSize: unterText.text === "" ? 28 : 24
            font.family: "Nokia Pure Text Light"
            elide: Text.ElideRight
        }
        Text {
            id: unterText
            visible: text !== ""
            width: parent.width
            color: "#d9eef5"
            font.pixelSize: 18
            elide: Text.ElideRight
        }
    }

    BusyIndicator {
        id: rad
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        running: kopf.laedt
        visible: kopf.laedt
        platformStyle: BusyIndicatorStyle { inverted: true }
    }
}
