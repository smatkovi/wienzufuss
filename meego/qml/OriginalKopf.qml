import QtQuick 1.1

// Die Titelleiste der Android-App (activity_main_appbar): 56 dp, Blau,
// weisser Zurueck-Pfeil, Titel 18 sp weiss. Der Pfeil ist aus Balken
// gezeichnet wie ic_arrow_back (Material), ohne Bilddatei.
Rectangle {
    id: kopf
    property real dp: 1
    property string titel: ""
    property string schrift: ""
    signal zurueck

    height: 56 * dp
    color: "#3790ad"

    Item {
        id: pfeil
        anchors { left: parent.left; leftMargin: 12 * kopf.dp; verticalCenter: parent.verticalCenter }
        width: 48 * kopf.dp
        height: 48 * kopf.dp
        // Material ic_arrow_back (24-dp-Raster, mittig im 48-dp-Feld):
        // Schaft von x=4 bis 20 auf y=12, Spitze aus zwei Balken von (4,12)
        // nach (12,4) und (12,20).
        Rectangle {
            x: (12 + 4.6) * kopf.dp
            y: (12 + 11) * kopf.dp
            width: 15.4 * kopf.dp
            height: 2 * kopf.dp
            color: "white"
        }
        Rectangle {
            x: (12 + 4) * kopf.dp
            y: (12 + 11) * kopf.dp
            width: 11.3 * kopf.dp
            height: 2 * kopf.dp
            color: "white"
            smooth: true
            transformOrigin: Item.Left
            rotation: -45
        }
        Rectangle {
            x: (12 + 4) * kopf.dp
            y: (12 + 11) * kopf.dp
            width: 11.3 * kopf.dp
            height: 2 * kopf.dp
            color: "white"
            smooth: true
            transformOrigin: Item.Left
            rotation: 45
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#33ffffff"
            visible: maus.pressed
        }
        MouseArea {
            id: maus
            anchors.fill: parent
            onClicked: kopf.zurueck()
        }
    }
    Text {
        anchors { left: pfeil.right; leftMargin: 12 * kopf.dp; right: parent.right; rightMargin: 12 * kopf.dp
                  verticalCenter: parent.verticalCenter }
        text: kopf.titel
        color: "white"
        font.pixelSize: 18 * kopf.dp
        font.family: kopf.schrift
        elide: Text.ElideRight
    }
}
