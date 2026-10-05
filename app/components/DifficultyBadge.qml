import QtQuick
import "../theme"

Rectangle {
    property int level: 2
    height: 22
    width: badgeText.implicitWidth + 14
    radius: 6
    color: level >= 4 ? Theme.accentOrange : Theme.primaryGreen

    Text {
        id: badgeText
        anchors.centerIn: parent
        text: "難度 " + "★".repeat(Math.max(1, Math.min(5, level)))
        color: "#FFFFFF"
        font.pixelSize: 11
        font.bold: true
    }
}
