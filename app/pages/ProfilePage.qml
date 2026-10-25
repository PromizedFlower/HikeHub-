import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    property int mainTab: 0   // 0 = 我的動態, 1 = 我的收藏
    property int favSubTab: 0 // 0 = 收藏的路線, 1 = 收藏的動態

    signal postSelected(string postId)
    signal trailSelected(string trailId)
    signal editProfileRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Profile Header Card (Avatar + Nickname + Bio + Edit + Logout)
        Rectangle {
            Layout.fillWidth: true
            radius: Theme.radiusCard
            color: Theme.cardWhite
            implicitHeight: profCol.implicitHeight + 24

            ColumnLayout {
                id: profCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 56
                        height: 56
                        radius: 28
                        color: Theme.primaryGreen
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            text: (api.currentUser.nickname || "山")[0]
                            color: "#FFFFFF"
                            font.pixelSize: 22
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            text: api.currentUser.nickname || "山友"
                            font.pixelSize: Theme.fontTitle
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: api.currentUser.bio || "熱愛香港山野，週末必出發行山！"
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textSecondary
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // 3 Stat Numbers: 動態數 / 收藏數 / 行山次數
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    StatPill {
                        Layout.fillWidth: true
                        label: "我的動態"
                        value: "" + (api.profileStats.post_count || 0)
                    }
                    StatPill {
                        Layout.fillWidth: true
                        label: "我的收藏"
                        value: "" + (api.profileStats.favorite_count || 0)
                    }
                    StatPill {
                        Layout.fillWidth: true
                        label: "行山次數"
                        value: "" + (api.profileStats.trip_count || 0)
                    }
                }

                // Settings Action Row: Edit Profile & Logout
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    PrimaryButton {
                        Layout.fillWidth: true
                        height: 36
                        text: "✎ 編輯個人資料"
                        bgColor: Theme.primaryGreen
                        onClicked: root.editProfileRequested()
                    }

                    PrimaryButton {
                        Layout.fillWidth: true
                        height: 36
                        text: "⎋ 登出帳號"
                        bgColor: Theme.accentOrange
                        onClicked: api.signOut()
                    }
                }
            }
        }

        // Main Switcher: 我的動態 vs 我的收藏
        SegmentedTabs {
            Layout.fillWidth: true
            items: ["我的動態（可編輯/刪除）", "我的收藏"]
            currentIndex: root.mainTab
            onIndexChanged: function(idx) { root.mainTab = idx }
        }

        // Sub-tabs when inside 我的收藏
        SegmentedTabs {
            Layout.fillWidth: true
            visible: root.mainTab === 1
            items: ["收藏的路線 (" + api.myFavoriteTrails.length + ")", "收藏的動態 (" + api.myFavoritePosts.length + ")"]
            currentIndex: root.favSubTab
            onIndexChanged: function(idx) { root.favSubTab = idx }
        }

        // List 1: 我的動態 (with View, Edit, Delete)
        ListView {
            id: myPostsListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mainTab === 0
            spacing: 10
            clip: true
            model: api.myPosts

            delegate: Rectangle {
                width: myPostsListView.width
                radius: Theme.radiusCard
                color: Theme.cardWhite
                implicitHeight: mpCol.implicitHeight + 20

                ColumnLayout {
                    id: mpCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || ""
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "查看 >"
                            font.pixelSize: 12
                            color: Theme.primaryGreen
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.postSelected(modelData.id)
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.body || ""
                        font.pixelSize: 12
                        color: Theme.textSecondary
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: modelData.created_display + " · ♥ " + modelData.like_count + " · 💬 " + modelData.comment_count
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 54
                            height: 24
                            radius: 6
                            color: "#E8F3EE"
                            Text {
                                anchors.centerIn: parent
                                text: "快速修訂"
                                font.pixelSize: 11
                                color: Theme.primaryGreen
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    api.editMyPost(modelData.id, modelData.title + "（已更新）", modelData.body)
                                }
                            }
                        }
                        Rectangle {
                            width: 46
                            height: 24
                            radius: 6
                            color: "#FDECE7"
                            Text {
                                anchors.centerIn: parent
                                text: "刪除"
                                font.pixelSize: 11
                                color: Theme.accentOrange
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: api.deleteMyPost(modelData.id)
                            }
                        }
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: api.myPosts.length === 0
                message: "你仲未發布過行山動態或提問"
                actionText: "去社區發一條"
                onActionClicked: api.navigateToTabRequested(3)
            }
        }

        // List 2A: 收藏的路線
        ListView {
            id: favTrailsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mainTab === 1 && root.favSubTab === 0
            spacing: 10
            clip: true
            model: api.myFavoriteTrails

            delegate: TrailCard {
                width: favTrailsView.width
                trailData: modelData
                onCardClicked: function(tid) { root.trailSelected(tid) }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: api.myFavoriteTrails.length === 0
                message: "尚未收藏任何行山路線"
                actionText: "去瀏覽路線"
                onActionClicked: api.navigateToTabRequested(1)
            }
        }

        // List 2B: 收藏的動態
        ListView {
            id: favPostsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mainTab === 1 && root.favSubTab === 1
            spacing: 10
            clip: true
            model: api.myFavoritePosts

            delegate: Rectangle {
                width: favPostsView.width
                radius: Theme.radiusCard
                color: Theme.cardWhite
                implicitHeight: 74

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
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
                            text: modelData.author_nickname + " · ♥ " + modelData.like_count + " · ★ " + modelData.favorite_count
                            font.pixelSize: 12
                            color: Theme.textSecondary
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
                visible: api.myFavoritePosts.length === 0
                message: "尚未收藏任何社區動態"
                actionText: "去逛逛社區"
                onActionClicked: api.navigateToTabRequested(3)
            }
        }
    }
}
