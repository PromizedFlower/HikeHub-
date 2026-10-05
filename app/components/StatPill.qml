import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    property string label: "距離"
    property string value: "0.0 km"
    radius: Theme.radiusCard
    color: Theme.bgCream
    implicitHeight: 54
    implicitWidth: 96

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: value
            font.pixelSize: Theme.fontBody
            font.bold: true
            color: Theme.primaryGreen
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: label
            font.pixelSize: Theme.fontCaption
            color: Theme.textSecondary
        }
    }
}
