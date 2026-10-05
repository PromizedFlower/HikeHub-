import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property var items: ["動態", "問答"]
    property int currentIndex: 0
    signal indexChanged(int idx)

    height: 38
    radius: Theme.radiusCard
    color: "#EAE8E3"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 4

        Repeater {
            model: root.items
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 9
                color: root.currentIndex === index ? Theme.cardWhite : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: Theme.fontBody
                    font.bold: root.currentIndex === index
                    color: root.currentIndex === index ? Theme.primaryGreen : Theme.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.currentIndex = index
                        root.indexChanged(index)
                    }
                }
            }
        }
    }
}
