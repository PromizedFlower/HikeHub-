import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    property string trailId: ""
    signal backRequested()
    signal postClicked(string postId)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top Navigation Bar
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
                    text: api.currentTrail.name || "路線詳情"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }
                Text {
                    text: (api.currentTrail.is_favorited ? "★ 已收藏" : "☆ 收藏")
                    font.pixelSize: 13
                    font.bold: true
                    color: api.currentTrail.is_favorited ? Theme.accentOrange : Theme.textSecondary
                    MouseArea {
                        anchors.fill: parent
                        onClicked: api.toggleFavorite("trail", api.currentTrail.id || root.trailId)
                    }
                }
            }
        }

        // Scrollable Detail Content
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: detailCol.implicitHeight + 24
            clip: true

            ColumnLayout {
                id: detailCol
                width: parent.width - 28
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                spacing: 14

                // Cover Image
                Rectangle {
                    Layout.fillWidth: true
                    height: 180
                    radius: Theme.radiusCard
                    color: "#DCE7E1"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: api.currentTrail.cover_url || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    DifficultyBadge {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 10
                        level: api.currentTrail.difficulty || 2
                    }
                }

                // Title & Description
                Text {
                    Layout.fillWidth: true
                    text: api.currentTrail.name || ""
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    color: Theme.textPrimary
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    text: api.currentTrail.description || ""
                    font.pixelSize: 13
                    color: Theme.textSecondary
                    wrapMode: Text.Wrap
                }

                // 3 Stat Pills (Distance / Ascent / Duration)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    StatPill {
                        Layout.fillWidth: true
                        label: "總距離"
                        value: (api.currentTrail.distance_km || 0) + " km"
                    }
                    StatPill {
                        Layout.fillWidth: true
                        label: "累計爬升"
                        value: (api.currentTrail.ascent_m || 0) + " m"
                    }
                    StatPill {
                        Layout.fillWidth: true
                        label: "預計耗時"
                        value: Math.round((api.currentTrail.duration_min || 120) / 60 * 10) / 10 + " 小時"
                    }
                }

                // Segments with Supply & Retreat Badges
                Text {
                    text: "分段路況（含補給點 / 撤退點標記）"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }

                Repeater {
                    model: api.currentTrail.segments || []
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        radius: Theme.radiusCard
                        color: Theme.cardWhite
                        implicitHeight: segCol.implicitHeight + 20

                        ColumnLayout {
                            id: segCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: "第 " + modelData.seq + " 段：" + modelData.name
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    wrapMode: Text.Wrap
                                }
                            }

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: modelData.distance_km + " km · 爬升 " + modelData.ascent_m + "m"
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                }
                                Rectangle {
                                    visible: modelData.has_supply
                                    radius: 4
                                    color: "#E8F3EE"
                                    width: supTxt.implicitWidth + 10
                                    height: 20
                                    Text {
                                        id: supTxt
                                        anchors.centerIn: parent
                                        text: "🍜 有補給點"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.primaryGreen
                                    }
                                }
                                Rectangle {
                                    visible: modelData.has_retreat
                                    radius: 4
                                    color: "#FDECE7"
                                    width: retTxt.implicitWidth + 10
                                    height: 20
                                    Text {
                                        id: retTxt
                                        anchors.centerIn: parent
                                        text: "🚌 可撤退點"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.accentOrange
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: (modelData.note || "") !== ""
                                text: modelData.note || ""
                                font.pixelSize: 12
                                color: Theme.textSecondary
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }

                // Checkpoints List
                Text {
                    text: "沿途打卡點清單"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }

                Repeater {
                    model: api.currentTrail.checkpoints || []
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        radius: Theme.radiusCard
                        color: Theme.cardWhite
                        implicitHeight: 58

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: Theme.primaryGreen
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.seq
                                    color: "#FFFFFF"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.name
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                                Text {
                                    text: modelData.note + " (" + modelData.lat.toFixed(4) + ", " + modelData.lng.toFixed(4) + ")"
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // Related Community Posts on this route ("這條路線最近有人走過")
                Text {
                    text: "山友近期走過實況"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }

                Repeater {
                    model: api.currentTrail.related_posts || []
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        radius: Theme.radiusCard
                        color: Theme.cardWhite
                        implicitHeight: 68

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || ""
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.author_nickname + " · " + modelData.created_display + " · ♥ " + modelData.like_count
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
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

        // Fixed Bottom Action Bar: Single Main Action "立即出發行呢條線"
        Rectangle {
            Layout.fillWidth: true
            height: 62
            color: Theme.cardWhite
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                PrimaryButton {
                    Layout.fillWidth: true
                    text: "🧭 選擇此路線立即出發"
                    onClicked: api.jumpToStartWithTrail(api.currentTrail.id || root.trailId)
                }
            }
        }
    }
}
