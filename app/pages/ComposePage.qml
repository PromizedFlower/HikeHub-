import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    property string initialType: "moment"
    property string initialTrailId: "trail-01"
    property string currentType: initialType
    property string selectedTrailId: initialTrailId
    property var selectedPhotos: [
        "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80"
    ]
    property var selectedTags: ["風景", "補給"]

    signal backRequested()
    signal published()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header Bar
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Theme.cardWhite
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Text {
                    text: "取消"
                    font.pixelSize: Theme.fontBody
                    color: Theme.textSecondary
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.backRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.currentType === "question" ? "發起山友提問" : "發布行山動態"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: "發布"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.primaryGreen
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            api.publishPost(
                                root.currentType,
                                titleInput.text,
                                bodyInput.text,
                                root.selectedTrailId,
                                root.currentType === "question" ? [] : root.selectedPhotos,
                                root.selectedTags
                            )
                            root.published()
                        }
                    }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: formCol.implicitHeight + 28
            clip: true

            ColumnLayout {
                id: formCol
                width: parent.width - 28
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 14
                spacing: 12

                SegmentedTabs {
                    Layout.fillWidth: true
                    items: ["發動態（相片分享）", "發提問（求助山友）"]
                    currentIndex: root.currentType === "question" ? 1 : 0
                    onIndexChanged: function(idx) {
                        root.currentType = idx === 1 ? "question" : "moment"
                        if (idx === 1) root.selectedTags = ["交通", "裝備"]
                        else root.selectedTags = ["風景", "補給"]
                    }
                }

                TextField {
                    id: titleInput
                    Layout.fillWidth: true
                    placeholderText: root.currentType === "question"
                                     ? "輸入問題標題（如：請問西灣亭村巴尾班車幾點？）"
                                     : "輸入一句話標題（如：今日龍脊秋風超爽！）"
                    font.pixelSize: Theme.fontBody
                    padding: 10
                    background: Rectangle {
                        radius: Theme.radiusCard
                        color: Theme.cardWhite
                    }
                }

                TextArea {
                    id: bodyInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    placeholderText: root.currentType === "question"
                                     ? "詳細描述你想請教山友嘅路線、交通、補給或天氣問題..."
                                     : "分享沿途風景、路況、士多補給或行山心得..."
                    font.pixelSize: 14
                    wrapMode: TextArea.Wrap
                    padding: 10
                    background: Rectangle {
                        radius: Theme.radiusCard
                        color: Theme.cardWhite
                    }
                }

                // Multi-photo selector (Shown for moment type)
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.currentType !== "question"
                    spacing: 8

                    Text {
                        text: "選擇或添加行山相片（將上傳至 trail-photos Storage）"
                        font.pixelSize: Theme.fontCaption
                        font.bold: true
                        color: Theme.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { name: "龍脊海景", url: "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80" },
                                { name: "西貢浪茄", url: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&auto=format&fit=crop&q=80" },
                                { name: "大東芒草", url: "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&auto=format&fit=crop&q=80" }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 74
                                radius: 8
                                clip: true
                                border.color: root.selectedPhotos.indexOf(modelData.url) !== -1 ? Theme.primaryGreen : "transparent"
                                border.width: 3

                                Image {
                                    anchors.fill: parent
                                    source: modelData.url
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.selectedPhotos = [modelData.url]
                                    }
                                }
                            }
                        }
                    }

                    TextField {
                        id: customPhotoPath
                        Layout.fillWidth: true
                        placeholderText: "或貼上本機圖片路徑 / URL..."
                        font.pixelSize: 12
                        padding: 8
                        background: Rectangle { radius: 8; color: Theme.cardWhite }
                        onEditingFinished: {
                            if (text.length > 0) root.selectedPhotos = [text]
                        }
                    }
                }

                // Route Association Selector
                Text {
                    text: "關聯香港行山路線"
                    font.pixelSize: Theme.fontCaption
                    font.bold: true
                    color: Theme.textSecondary
                }

                Flickable {
                    Layout.fillWidth: true
                    height: 32
                    contentWidth: trailPickRow.implicitWidth
                    clip: true
                    Row {
                        id: trailPickRow
                        spacing: 6
                        Repeater {
                            model: api.trailsList
                            delegate: TagChip {
                                label: modelData.name.split("（")[0]
                                selected: root.selectedTrailId === modelData.id
                                onClicked: root.selectedTrailId = modelData.id
                            }
                        }
                    }
                }

                // Topic Tags
                Text {
                    text: "話題標籤"
                    font.pixelSize: Theme.fontCaption
                    font.bold: true
                    color: Theme.textSecondary
                }

                Flickable {
                    Layout.fillWidth: true
                    height: 32
                    contentWidth: tagPickRow.implicitWidth
                    clip: true
                    Row {
                        id: tagPickRow
                        spacing: 6
                        Repeater {
                            model: ["風景", "補給", "裝備", "交通", "天氣", "撤退點", "湊人"]
                            delegate: TagChip {
                                label: "#" + modelData
                                selected: root.selectedTags.indexOf(modelData) !== -1
                                onClicked: {
                                    var copy = root.selectedTags.slice()
                                    var idx = copy.indexOf(modelData)
                                    if (idx >= 0) copy.splice(idx, 1)
                                    else copy.push(modelData)
                                    root.selectedTags = copy
                                }
                            }
                        }
                    }
                }

                PrimaryButton {
                    Layout.fillWidth: true
                    text: "確認發布到社區"
                    onClicked: {
                        api.publishPost(
                            root.currentType,
                            titleInput.text,
                            bodyInput.text,
                            root.selectedTrailId,
                            root.currentType === "question" ? [] : root.selectedPhotos,
                            root.selectedTags
                        )
                        root.published()
                    }
                }
            }
        }
    }
}
