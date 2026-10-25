import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    property string postId: ""
    property string replyToCommentId: ""
    property string replyToNickname: ""

    signal backRequested()
    signal trailClicked(string trailId)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top Bar
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
                    text: api.currentPost.type === "question" ? "問答詳情" : "動態詳情"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }
                Item { width: 42 }
            }
        }

        // Scrollable Post + Comments Content
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: postCol.implicitHeight + 24
            clip: true

            ColumnLayout {
                id: postCol
                width: parent.width - 28
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                spacing: 12

                // Author Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: Theme.primaryGreen
                        Text {
                            anchors.centerIn: parent
                            text: (api.currentPost.author_nickname || "山")[0]
                            color: "#FFFFFF"
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: api.currentPost.author_nickname || "山友"
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.textPrimary
                        }
                        Text {
                            text: (api.currentPost.created_display || "") + " · " + (api.currentPost.tags_text || "")
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }
                }

                // Cover Photo (if present)
                Rectangle {
                    Layout.fillWidth: true
                    height: 210
                    radius: Theme.radiusCard
                    color: "#DCE7E1"
                    clip: true
                    visible: (api.currentPost.cover_photo || "") !== "" && api.currentPost.type !== "question"

                    Image {
                        anchors.fill: parent
                        source: api.currentPost.cover_photo || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                // Title & Body
                Text {
                    Layout.fillWidth: true
                    text: api.currentPost.title || ""
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    text: api.currentPost.body || ""
                    font.pixelSize: Theme.fontBody
                    color: Theme.textPrimary
                    wrapMode: Text.Wrap
                }

                // Linked Trail Pill
                Rectangle {
                    visible: (api.currentPost.trail_id || "") !== ""
                    radius: 8
                    color: "#E8F3EE"
                    height: 32
                    width: trailLinkTxt.implicitWidth + 20
                    Text {
                        id: trailLinkTxt
                        anchors.centerIn: parent
                        text: "🥾 關聯路線：" + (api.currentPost.trail_name || "查看路線") + " >"
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.primaryGreen
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.trailClicked(api.currentPost.trail_id)
                    }
                }

                // Interactive Counters Bar (Like / Favorite / Comment)
                Rectangle {
                    Layout.fillWidth: true
                    height: 46
                    radius: Theme.radiusCard
                    color: Theme.cardWhite

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10

                        // Like Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: api.currentPost.is_liked ? "#FDECE7" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: (api.currentPost.is_liked ? "♥ 已讚 " : "♡ 點讚 ") + (api.currentPost.like_count || 0)
                                font.pixelSize: 13
                                font.bold: true
                                color: api.currentPost.is_liked ? Theme.accentOrange : Theme.textPrimary
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: api.toggleLike(api.currentPost.id || root.postId)
                            }
                        }

                        // Favorite Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: api.currentPost.is_favorited ? "#E8F3EE" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: (api.currentPost.is_favorited ? "★ 已收藏 " : "☆ 收藏 ") + (api.currentPost.favorite_count || 0)
                                font.pixelSize: 13
                                font.bold: true
                                color: api.currentPost.is_favorited ? Theme.primaryGreen : Theme.textPrimary
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: api.toggleFavorite("post", api.currentPost.id || root.postId)
                            }
                        }

                        // Comment Count
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Text {
                                anchors.centerIn: parent
                                text: "💬 評論 " + (api.currentPost.comment_count || 0)
                                font.pixelSize: 13
                                color: Theme.textSecondary
                            }
                        }
                    }
                }

                // Comments & Q&A Answers List
                Text {
                    text: api.currentPost.type === "question"
                          ? ("山友回答 (" + (api.currentPost.comment_count || 0) + ")")
                          : ("全部評論 (" + (api.currentPost.comment_count || 0) + ")")
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }

                Repeater {
                    model: api.currentPost.comments || []
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        radius: Theme.radiusCard
                        color: modelData.is_accepted ? "#E8F3EE" : Theme.cardWhite
                        border.color: modelData.is_accepted ? Theme.primaryGreen : "transparent"
                        border.width: modelData.is_accepted ? 1.5 : 0
                        implicitHeight: cmtCol.implicitHeight + 20

                        ColumnLayout {
                            id: cmtCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.author_nickname || "山友"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                                Text {
                                    visible: (modelData.reply_to_nickname || "") !== ""
                                    text: "回覆 @" + modelData.reply_to_nickname
                                    font.pixelSize: 12
                                    color: Theme.primaryGreen
                                }
                                Item { Layout.fillWidth: true }

                                // Accepted Badge
                                Rectangle {
                                    visible: modelData.is_accepted
                                    radius: 6
                                    color: Theme.primaryGreen
                                    width: accTxt.implicitWidth + 12
                                    height: 20
                                    Text {
                                        id: accTxt
                                        anchors.centerIn: parent
                                        text: "✓ 已採納最佳回答"
                                        color: "#FFFFFF"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }

                                // Accept Button (Only shown to Question Author when no answer is accepted yet)
                                Rectangle {
                                    visible: api.currentPost.type === "question"
                                             && !api.currentPost.has_accepted
                                             && api.currentUser.id === api.currentPost.author_id
                                    radius: 6
                                    color: Theme.accentOrange
                                    width: btnAccTxt.implicitWidth + 12
                                    height: 22
                                    Text {
                                        id: btnAccTxt
                                        anchors.centerIn: parent
                                        text: "採納此回答"
                                        color: "#FFFFFF"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: api.acceptAnswer(api.currentPost.id, modelData.id)
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.body || ""
                                font.pixelSize: 13
                                color: Theme.textPrimary
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.created_display || ""
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "回覆"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.primaryGreen
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.replyToCommentId = modelData.id
                                            root.replyToNickname = modelData.author_nickname
                                            commentInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Bottom Comment / Reply Input Bar
        Rectangle {
            Layout.fillWidth: true
            height: 58
            color: Theme.cardWhite

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                TextField {
                    id: commentInput
                    Layout.fillWidth: true
                    placeholderText: root.replyToNickname !== ""
                                     ? ("回覆 @" + root.replyToNickname + "（點擊發送）...")
                                     : (api.currentPost.type === "question" ? "撰寫回答幫下山友..." : "留低你嘅評論...")
                    font.pixelSize: 13
                    padding: 8
                    background: Rectangle {
                        radius: 8
                        color: Theme.bgCream
                    }
                }

                Rectangle {
                    visible: root.replyToNickname !== ""
                    width: 40
                    height: 34
                    radius: 8
                    color: "#EAE8E3"
                    Text {
                        anchors.centerIn: parent
                        text: "取消"
                        font.pixelSize: 11
                        color: Theme.textSecondary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.replyToCommentId = ""
                            root.replyToNickname = ""
                        }
                    }
                }

                PrimaryButton {
                    width: 68
                    height: 36
                    text: "發送"
                    onClicked: {
                        if (commentInput.text.trim().length === 0) return
                        api.addComment(api.currentPost.id || root.postId, commentInput.text, root.replyToCommentId)
                        commentInput.text = ""
                        root.replyToCommentId = ""
                        root.replyToNickname = ""
                    }
                }
            }
        }
    }
}
