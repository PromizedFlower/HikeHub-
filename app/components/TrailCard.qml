import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property var trailData: ({})
    signal cardClicked(string trailId)

    radius: Theme.radiusCard
    color: Theme.cardWhite
    implicitHeight: 112

    // Strict <= 3 visual hierarchy layers per card: Photo / Title+Difficulty / 1-line Meta
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 92
            Layout.preferredHeight: 92
            radius: 8
            color: "#DCE7E1"
            clip: true

            Image {
                anchors.fill: parent
                source: root.trailData.cover_url || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 4
                radius: 4
                color: "#CC1C1C1E"
                width: regTxt.implicitWidth + 8
                height: 18
                Text {
                    id: regTxt
                    anchors.centerIn: parent
                    text: root.trailData.region || "香港"
                    color: "#FFFFFF"
                    font.pixelSize: 10
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.trailData.name || ""
                font.pixelSize: Theme.fontBody
                font.bold: true
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            DifficultyBadge {
                level: root.trailData.difficulty || 2
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: (root.trailData.distance_km || 0) + " km · 爬升 " + (root.trailData.ascent_m || 0) + "m"
                    font.pixelSize: Theme.fontCaption
                    color: Theme.textSecondary
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "★ " + (root.trailData.favorite_count || 0)
                    font.pixelSize: Theme.fontCaption
                    font.bold: true
                    color: Theme.accentOrange
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.cardClicked(root.trailData.id || "")
    }
}
