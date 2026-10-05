import QtQuick 2.0
import Sailfish.Silica 1.0

// Ein Absatz Text mit Seitenrand, nur sichtbar, wenn er etwas sagt.
Label {
    property bool fehler: false
    x: Theme.horizontalPageMargin
    width: parent ? parent.width - 2 * Theme.horizontalPageMargin : 0
    visible: text !== ""
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSizeSmall
    color: fehler ? "#ff6060" : Theme.highlightColor
}
