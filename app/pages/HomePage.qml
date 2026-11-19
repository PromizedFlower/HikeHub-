import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    signal trailClicked(string trailId)
    signal postClicked(string postId)
    signal resumeHikeClicked()

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 28
        clip: true

        ColumnLayout {
            id: contentCol
            width: parent.width - 28
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            spacing: 16

            // Top Brand & Search Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "行山腳 HikeHub"
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                        color: Theme.textPrimary
                    }
                    Text {
                        text: "今日想去邊條香港山徑行下？"
                        font.pixelSize: Theme.fontCaption
                        color: Theme.textSecondary
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    radius: 14
                    color: "#E8F3EE"
                    width: userTag.implicitWidth + 16
                    height: 28
                    Text {
                        id: userTag
                        anchors.centerIn: parent
                        text: "山友：" + (api.currentUser.nickname || "訪客")
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.primaryGreen
                    }
                }
            }

            // Search Box (Route name / Region keyword)
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: Theme.radiusCard
                color: Theme.cardWhite
                border.color: "#E2E2E2"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Text { text: "🔍"; font.pixelSize: 15 }
                    TextField {
                        id: homeSearchInput
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textSecondary
                        placeholderText: "搜尋路線名或地區（如：龍脊、西貢、大嶼山）"
                        font.pixelSize: 13
                        background: Item {}
                        onAccepted: {
                            api.filterTrails("全部", 0, "全部", text)
                            api.navigateToTabRequested(1)
                        }
                    }
                    Rectangle {
                        visible: homeSearchInput.text.length > 0
                        width: 52
                        height: 28
                        radius: 8
                        color: Theme.primaryGreen
                        Text {
                            anchors.centerIn: parent
                            text: "搵路線"
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                api.filterTrails("全部", 0, "全部", homeSearchInput.text)
                                api.navigateToTabRequested(1)
                            }
                        }
                    }
                }
            }

            // Active Hiking Session Banner (Only shown when a hike session is active)
            Rectangle {
                Layout.fillWidth: true
                visible: api.hikeState === "active"
                radius: Theme.radiusCard
                color: Theme.primaryGreen
                implicitHeight: 72

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "🧭 進行中的行山：" + (api.hikeTrail.name || "")
                            color: "#FFFFFF"
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "已行 " + api.hikeDistanceKm + " km · 時長 " + api.hikeDurationText + " · 打卡 " + api.hikeCheckedCount + "/" + api.hikeTotalCheckpoints
                            color: "#E8F3EE"
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        width: 74
                        height: 32
                        radius: 8
                        color: Theme.accentOrange
                        Text {
                            anchors.centerIn: parent
                            text: "繼續記錄"
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.resumeHikeClicked()
                        }
                    }
                }
            }

            // Section 1: 本週精選 (2 Horizontal Large Cards)
            Text {
                text: "本週精選路線"
                font.pixelSize: Theme.fontBody
                font.bold: true
                color: Theme.textPrimary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: api.featuredTrails
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 168
                        radius: Theme.radiusCard
                        color: Theme.cardWhite
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 96
                                color: "#DCE7E1"
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: modelData.cover_url || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                DifficultyBadge {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 6
                                    level: modelData.difficulty || 2
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.margins: 8
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name || ""
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.region + " · " + modelData.distance_km + "km · 爬升" + modelData.ascent_m + "m"
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.trailClicked(modelData.id)
                        }
                    }
                }
            }

            // Section 2: 附近路線 (Horizontal Flickable List)
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "附近熱門山徑"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "查看全部 >"
                    font.pixelSize: Theme.fontCaption
                    color: Theme.primaryGreen
                    MouseArea {
                        anchors.fill: parent
                        onClicked: api.navigateToTabRequested(1)
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                height: 96
                contentWidth: nearbyRow.implicitWidth
                contentHeight: 96
                clip: true

                Row {
                    id: nearbyRow
                    spacing: 10
                    Repeater {
                        model: api.nearbyTrails
                        delegate: Rectangle {
                            width: 215
                            height: 92
                            radius: Theme.radiusCard
                            color: Theme.cardWhite

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name || ""
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                                DifficultyBadge { level: modelData.difficulty || 2 }
                                Text {
                                    text: modelData.region + " · " + modelData.distance_km + " km"
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.trailClicked(modelData.id)
                            }
                        }
                    }
                }
            }

            // Section 3: 社區熱帖 (Top 3 by like_count)
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "社區熱帖（山友最新實況）"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "進入社區 >"
                    font.pixelSize: Theme.fontCaption
                    color: Theme.primaryGreen
                    MouseArea {
                        anchors.fill: parent
                        onClicked: api.navigateToTabRequested(3)
                    }
                }
            }

            Repeater {
                model: api.hotPosts
                delegate: Rectangle {
                    Layout.fillWidth: true
                    radius: Theme.radiusCard
                    color: Theme.cardWhite
                    implicitHeight: 86

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || ""
                                font.pixelSize: 14
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.body || ""
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.author_nickname + " · ♥ " + modelData.like_count + " · 💬 " + modelData.comment_count
                                font.pixelSize: 11
                                color: Theme.primaryGreen
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.postClicked(modelData.id)
                    }
                }
            }
        }
    }
}
