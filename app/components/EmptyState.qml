import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    id: root
    property string message: "還沒有打卡記錄，去發一條吧"
    property string actionText: "立即行動"
    property bool showAction: true
    signal actionClicked()

    implicitHeight: 180

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "⛰️"
            font.pixelSize: 32
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.message
            font.pixelSize: Theme.fontBody
            color: Theme.textSecondary
        }

        PrimaryButton {
            visible: root.showAction
            Layout.alignment: Qt.AlignHCenter
            width: 140
            height: 36
            text: root.actionText
            onClicked: root.actionClicked()
        }
    }
}
