import QtQuick
import "../theme"

Rectangle {
    id: root
    property string label: "全部"
    property bool selected: false
    signal clicked()

    height: 30
    width: chipTxt.implicitWidth + 22
    radius: 15
    color: selected ? Theme.primaryGreen : Theme.cardWhite
    border.color: selected ? Theme.primaryGreen : "#DCDCDC"
    border.width: 1

    Text {
        id: chipTxt
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: Theme.fontCaption
        font.bold: root.selected
        color: root.selected ? "#FFFFFF" : Theme.textPrimary
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
