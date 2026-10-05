import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    property var postData: ({})
    signal tileClicked(string postId)
    signal likeClicked(string postId)

    radius: Theme.radiusCard
    color: Theme.cardWhite
    implicitHeight: 218
    clip: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 130
            color: "#DCE7E1"
            clip: true

            Image {
                anchors.fill: parent
                source: root.postData.cover_photo || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Rectangle {
                visible: root.postData.type === "trip"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                radius: 4
                color: Theme.primaryGreen
                width: tripTag.implicitWidth + 10
                height: 20
                Text {
                    id: tripTag
                    anchors.centerIn: parent
                    text: "軌跡打卡"
                    color: "#FFFFFF"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: root.postData.title || root.postData.body || ""
                font.pixelSize: 13
                font.bold: true
                color: Theme.textPrimary
                maximumLineCount: 2
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.postData.author_nickname || "山友"
                    font.pixelSize: 11
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                }

                Text {
                    text: (root.postData.is_liked ? "♥ " : "♡ ") + (root.postData.like_count || 0)
                    font.pixelSize: 12
                    font.bold: true
                    color: root.postData.is_liked ? Theme.accentOrange : Theme.textSecondary

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.likeClicked(root.postData.id || "")
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.tileClicked(root.postData.id || "")
    }

    // Tap anywhere except heart to open detail
    TapHandler {
        onTapped: root.tileClicked(root.postData.id || "")
    }
}
