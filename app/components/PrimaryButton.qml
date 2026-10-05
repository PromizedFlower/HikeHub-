import QtQuick
import "../theme"

Rectangle {
    id: root
    property string text: "確認"
    property color bgColor: Theme.primaryGreen
    property color textColor: "#FFFFFF"
    property bool enabledButton: true
    signal clicked()

    height: 44
    radius: Theme.radiusCard
    color: enabledButton ? (mouseArea.pressed ? Qt.darker(bgColor, 1.12) : bgColor) : "#CCCCCC"

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.pixelSize: Theme.fontBody
        font.bold: true
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabledButton
        onClicked: root.clicked()
    }
}
