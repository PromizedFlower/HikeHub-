import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    property string errorText: ""

    Connections {
        target: api
        function onLoginError(err) {
            root.errorText = err
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainCol.implicitHeight + 48
        clip: true

        ColumnLayout {
            id: mainCol
            width: parent.width - 36
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 36
            spacing: 16

            // Brand Logo Header
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 76
                height: 76
                radius: 22
                color: Theme.primaryGreen
                Text {
                    anchors.centerIn: parent
                    text: "⛰️"
                    font.pixelSize: 36
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "行山腳 HikeHub"
                font.pixelSize: 24
                font.bold: true
                color: Theme.textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "找路線 · 出發行山 · 留下打卡 · 山友互動"
                font.pixelSize: Theme.fontCaption
                color: Theme.textSecondary
            }

            // .env Configuration Status Card (Mandatory fallback requirement)
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.radiusCard
                color: (api.envStatus.env_valid && !api.envStatus.offline) ? "#E8F3EE" : "#FDECE7"
                border.color: (api.envStatus.env_valid && !api.envStatus.offline) ? Theme.primaryGreen : Theme.accentOrange
                border.width: 1
                implicitHeight: envCol.implicitHeight + 16

                ColumnLayout {
                    id: envCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: !api.envStatus.env_valid
                              ? ("⚠️ 檢查 .env 配置：" + api.envStatus.env_error_message)
                              : (api.envStatus.offline
                                 ? ("⚠️ 離線演示模式：" + api.envStatus.mode)
                                 : ("✓ 已連線：" + api.envStatus.mode))
                        font.pixelSize: Theme.fontCaption
                        font.bold: true
                        color: (api.envStatus.env_valid && !api.envStatus.offline) ? Theme.primaryGreen : Theme.accentOrange
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: api.envStatus.offline === true
                        text: "離線期間的點讚、評論、收藏、發文僅保存在本機；重新連線後以雲端資料為準。"
                        font.pixelSize: 11
                        color: Theme.accentOrange
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "專案端點：" + (api.envStatus.supabase_url || "未設定 (.env)")
                        font.pixelSize: 11
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                    }
                }
            }

            // Login Form Card
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.radiusCard
                color: Theme.cardWhite
                implicitHeight: formCol.implicitHeight + 28

                ColumnLayout {
                    id: formCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    Text {
                        text: "山友帳號登錄"
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "電郵帳號 Email"
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textSecondary
                        }
                        TextField {
                            id: emailField
                            Layout.fillWidth: true
                            placeholderText: "例如：ahon@hikehub.hk"
                            text: "ahon@hikehub.hk"
                            font.pixelSize: Theme.fontBody
                            padding: 10
                            background: Rectangle {
                                radius: 8
                                color: Theme.bgCream
                                border.color: emailField.activeFocus ? Theme.primaryGreen : "#DCDCDC"
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "登錄密碼 Password"
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textSecondary
                        }
                        TextField {
                            id: passwordField
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            placeholderText: "請輸入密碼"
                            text: "HikeHub2026!"
                            font.pixelSize: Theme.fontBody
                            padding: 10
                            background: Rectangle {
                                radius: 8
                                color: Theme.bgCream
                                border.color: passwordField.activeFocus ? Theme.primaryGreen : "#DCDCDC"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.errorText !== ""
                        color: "#FDECE7"
                        radius: 8
                        implicitHeight: errTxt.implicitHeight + 12
                        Text {
                            id: errTxt
                            anchors.fill: parent
                            anchors.margins: 6
                            text: root.errorText
                            color: Theme.accentOrange
                            font.pixelSize: Theme.fontCaption
                            wrapMode: Text.Wrap
                        }
                    }

                    PrimaryButton {
                        Layout.fillWidth: true
                        text: "立即登錄出發"
                        onClicked: {
                            root.errorText = ""
                            api.signIn(emailField.text, passwordField.text)
                        }
                    }
                }
            }

            // 6 Pre-built Grading Accounts Quick Selector
            Rectangle {
                Layout.fillWidth: true
                radius: Theme.radiusCard
                color: Theme.cardWhite
                implicitHeight: presetCol.implicitHeight + 24

                ColumnLayout {
                    id: presetCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "預建 6 個測試帳號（點擊一鍵填入 · 密碼 HikeHub2026!）"
                        font.pixelSize: Theme.fontCaption
                        font.bold: true
                        color: Theme.textSecondary
                    }

                    Repeater {
                        model: api.presetAccounts
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 8
                            color: emailField.text === modelData.email ? "#E8F3EE" : Theme.bgCream
                            border.color: emailField.text === modelData.email ? Theme.primaryGreen : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                Text {
                                    text: modelData.nickname
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: modelData.email
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    emailField.text = modelData.email
                                    passwordField.text = modelData.password
                                    root.errorText = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
