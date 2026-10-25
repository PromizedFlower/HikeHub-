import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    property int currentSegment: 0 // 0 = 動態 (Waterfall 2-col), 1 = 問答
    signal postSelected(string postId)
    signal composeRequested(string defaultType)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Top Bar: Title + Right "+" Compose Button
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "山友社區"
                font.pixelSize: Theme.fontTitle
                font.bold: true
                color: Theme.textPrimary
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 78
                height: 34
                radius: 17
                color: Theme.primaryGreen
                Text {
                    anchors.centerIn: parent
                    text: "＋ 發帖"
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.composeRequested(root.currentSegment === 1 ? "question" : "moment")
                }
            }
        }

        // Dual Segment Switcher: 動態 / 問答 (Pure reverse-chronological sorting)
        SegmentedTabs {
            Layout.fillWidth: true
            items: ["山友動態（相片與軌跡）", "行山問答（裝備/交通/天氣）"]
            currentIndex: root.currentSegment
            onIndexChanged: function(idx) { root.currentSegment = idx }
        }

        // Segment 0: 2-Column Waterfall Grid for Moments & Trip Records
        GridView {
            id: momentsGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentSegment === 0
            clip: true
            cellWidth: width / 2
            cellHeight: 228
            model: api.momentPosts

            delegate: Item {
                width: momentsGrid.cellWidth
                height: momentsGrid.cellHeight

                PhotoTile {
                    anchors.fill: parent
                    anchors.margins: 5
                    postData: modelData
                    onTileClicked: function(pid) { root.postSelected(pid) }
                    onLikeClicked: function(pid) { api.toggleLike(pid) }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: api.momentPosts.length === 0
                message: "還沒有打卡動態，去發一條吧"
                actionText: "去發動態"
                onActionClicked: root.composeRequested("moment")
            }
        }

        // Segment 1: Q&A Forum List (Title, Tags, Answer Count, Accepted Badge)
        ListView {
            id: qaListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentSegment === 1
            spacing: 10
            clip: true
            model: api.questionPosts

            delegate: Rectangle {
                width: qaListView.width
                radius: Theme.radiusCard
                color: Theme.cardWhite
                implicitHeight: qaCol.implicitHeight + 24

                ColumnLayout {
                    id: qaCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            radius: 6
                            color: modelData.has_accepted ? "#E8F3EE" : "#FDECE7"
                            width: statusTxt.implicitWidth + 12
                            height: 22
                            Text {
                                id: statusTxt
                                anchors.centerIn: parent
                                text: modelData.has_accepted ? "✓ 已採納解答" : "待山友解答"
                                font.pixelSize: 11
                                font.bold: true
                                color: modelData.has_accepted ? Theme.primaryGreen : Theme.accentOrange
                            }
                        }

                        Text {
                            text: modelData.tags_text || "#交通 #裝備"
                            font.pixelSize: 11
                            color: Theme.primaryGreen
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: modelData.created_display || ""
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title || ""
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        color: Theme.textPrimary
                        wrapMode: Text.Wrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.body || ""
                        font.pixelSize: 13
                        color: Theme.textSecondary
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "提問山友：" + (modelData.author_nickname || "")
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "💬 " + (modelData.comment_count || 0) + " 條回答 · ♥ " + (modelData.like_count || 0)
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.primaryGreen
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.postSelected(modelData.id)
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: api.questionPosts.length === 0
                message: "暫時未有提問，有路線或裝備疑問即管問！"
                actionText: "發起提問"
                onActionClicked: root.composeRequested("question")
            }
        }
    }
}
