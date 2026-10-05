import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property int currentIndex: 0
    signal tabClicked(int index)

    color: Theme.cardWhite
    height: 68

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: "#E5E5EA"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: [
                { label: "首頁", icon: "🏠", idx: 0, isCenter: false },
                { label: "線路", icon: "🥾", idx: 1, isCenter: false },
                { label: "出發", icon: "🧭", idx: 2, isCenter: true },
                { label: "社區", icon: "💬", idx: 3, isCenter: false },
                { label: "我的", icon: "👤", idx: 4, isCenter: false }
            ]

            delegate: Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Raised circular primary action button for Tab 2 ("出發") per spec
                Rectangle {
                    visible: modelData.isCenter
                    width: 56
                    height: 56
                    radius: 28
                    color: root.currentIndex === 2 ? Theme.accentOrange : Theme.primaryGreen
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -8
                    border.color: Theme.cardWhite
                    border.width: 3

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "出發"
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }

                Column {
                    visible: !modelData.isCenter
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        font.pixelSize: 18
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        font.pixelSize: Theme.fontCaption
                        font.bold: root.currentIndex === modelData.idx
                        color: root.currentIndex === modelData.idx ? Theme.primaryGreen : Theme.textSecondary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.tabClicked(modelData.idx)
                }
            }
        }
    }
}
