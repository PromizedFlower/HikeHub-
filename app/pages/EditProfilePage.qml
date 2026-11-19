import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    signal backRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Theme.cardWhite
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                Text {
                    text: "← 返回"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.primaryGreen
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.backRequested()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "編輯個人資料"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }
                Item { width: 42 }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 14

            Text {
                text: "山友暱稱 Nickname"
                font.pixelSize: Theme.fontCaption
                color: Theme.textSecondary
            }

            TextField {
                id: nickInput
                Layout.fillWidth: true
                color: Theme.textPrimary
                placeholderTextColor: Theme.textSecondary
                text: api.currentUser.nickname || ""
                font.pixelSize: Theme.fontBody
                padding: 10
                background: Rectangle { radius: 8; color: Theme.cardWhite }
            }

            Text {
                text: "個人簡介 Bio"
                font.pixelSize: Theme.fontCaption
                color: Theme.textSecondary
            }

            TextArea {
                id: bioInput
                Layout.fillWidth: true
                color: Theme.textPrimary
                placeholderTextColor: Theme.textSecondary
                Layout.preferredHeight: 90
                text: api.currentUser.bio || ""
                font.pixelSize: 14
                wrapMode: TextArea.Wrap
                padding: 10
                background: Rectangle { radius: 8; color: Theme.cardWhite }
            }

            Text {
                text: "頭像圖片 URL"
                font.pixelSize: Theme.fontCaption
                color: Theme.textSecondary
            }

            TextField {
                id: avatarInput
                Layout.fillWidth: true
                color: Theme.textPrimary
                placeholderTextColor: Theme.textSecondary
                text: api.currentUser.avatar_url || ""
                font.pixelSize: 12
                padding: 10
                background: Rectangle { radius: 8; color: Theme.cardWhite }
            }

            PrimaryButton {
                Layout.fillWidth: true
                text: "保存個人資料"
                onClicked: {
                    api.updateProfile(nickInput.text, bioInput.text, avatarInput.text)
                    root.backRequested()
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
