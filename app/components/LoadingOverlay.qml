import QtQuick
import QtQuick.Controls
import "../theme"

Rectangle {
    property bool active: false
    property string label: "載入數據中..."
    anchors.fill: parent
    color: "#99F7F6F3"
    visible: active
    z: 100

    Column {
        anchors.centerIn: parent
        spacing: 8
        BusyIndicator {
            running: active
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: label
            font.pixelSize: Theme.fontCaption
            color: Theme.textPrimary
        }
    }
}
