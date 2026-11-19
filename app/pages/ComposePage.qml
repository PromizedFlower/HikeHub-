import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    property string initialType: "moment"
    property string initialTrailId: "trail-01"
    property string currentType: initialType
    property string selectedTrailId: initialTrailId
    // 不預置任何相片：貼文相片必須來自山友實際點選或輸入。
    property var selectedPhotos: []
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
                            var ok = api.publishPost(
                                root.currentType,
                                titleInput.text,
                                bodyInput.text,
                                root.selectedTrailId,
                                root.currentType === "question" ? [] : root.selectedPhotos,
                                root.selectedTags
                            )
                            if (ok) root.published()
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
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textSecondary
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
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textSecondary
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

                // 本地相片選擇（發布時上傳至 trail-photos Storage）
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.currentType !== "question"
                    spacing: 8

                    Text {
                        text: "從本機選擇行山相片（發布時上傳至雲端）"
                        font.pixelSize: Theme.fontCaption
                        font.bold: true
                        color: Theme.textSecondary
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: root.selectedPhotos
                            delegate: Rectangle {
                                width: 76
                                height: 76
                                radius: 8
                                clip: true
                                border.color: "#DDDDDD"
                                border.width: 1

                                Image {
                                    anchors.fill: parent
                                    source: modelData
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: "#CC000000"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: "#FFFFFF"
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var copy = root.selectedPhotos.slice()
                                            copy.splice(index, 1)
                                            root.selectedPhotos = copy
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PrimaryButton {
                        Layout.fillWidth: true
                        text: root.selectedPhotos.length > 0
                              ? "＋ 再添加相片（已選 " + root.selectedPhotos.length + " 張）"
                              : "＋ 從本機添加相片"
                        onClicked: fileDialog.open()
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
                        var ok = api.publishPost(
                            root.currentType,
                            titleInput.text,
                            bodyInput.text,
                            root.selectedTrailId,
                            root.currentType === "question" ? [] : root.selectedPhotos,
                            root.selectedTags
                        )
                        if (ok) root.published()
                    }
                }
            }
        }
    }

    // 本地相片選擇器：從本機選取多張圖片，發布時由後端上傳至雲端 Storage。
    FileDialog {
        id: fileDialog
        title: "選擇行山相片"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["圖片檔案 (*.jpg *.jpeg *.png *.webp *.bmp)", "所有檔案 (*.*)"]
        onAccepted: {
            var copy = root.selectedPhotos.slice()
            for (var i = 0; i < fileDialog.selectedFiles.length; i++) {
                var url = fileDialog.selectedFiles[i]
                if (copy.indexOf(url) === -1) copy.push(url)
            }
            root.selectedPhotos = copy
        }
    }
}
