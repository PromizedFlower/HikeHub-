import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top Mode & Location Provider Banner (System GPS vs 示範模式 · 模擬定位)
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: Theme.cardWhite
            z: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Text {
                    text: "出發 · 軌跡與打卡"
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    color: Theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    radius: 10
                    color: api.hikeModeLabel.indexOf("模擬") !== -1 ? "#FDECE7" : "#E8F3EE"
                    width: locBadgeTxt.implicitWidth + 14
                    height: 24
                    Text {
                        id: locBadgeTxt
                        anchors.centerIn: parent
                        text: api.hikeModeLabel
                        font.pixelSize: 11
                        font.bold: true
                        color: api.hikeModeLabel.indexOf("模擬") !== -1 ? Theme.accentOrange : Theme.primaryGreen
                    }
                }
            }
        }

        // Map Area (Fills screen in idle & active states)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MapCanvas {
                anchors.fill: parent
                centerLat: api.hikeCurrentLat
                centerLng: api.hikeCurrentLng
                fullPath: api.hikeTrail.path || []
                walkedPath: api.hikeWalkedPath
                remainingPath: api.hikeRemainingPath
                checkpoints: api.hikeTrail.checkpoints || []
                checkedIds: api.hikeCheckedIds
                isTracking: api.hikeState === "active"
            }

            // State 2 Overlay: Top 3 Live Metrics Bar (Distance km / Duration / Checkpoints n/m)
            Rectangle {
                visible: api.hikeState === "active"
                width: parent.width - 24
                height: 68
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.radiusCard
                color: "#F2FFFFFF"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    StatPill {
                        Layout.fillWidth: true
                        label: "行進距離"
                        value: api.hikeDistanceKm + " km"
                    }
                    StatPill {
                        Layout.fillWidth: true
                        label: "行山時長"
                        value: api.hikeDurationText
                    }
                    StatPill {
                        Layout.fillWidth: true
                        label: "已打卡點"
                        value: api.hikeCheckedCount + " / " + api.hikeTotalCheckpoints
                    }
                }
            }

            // 2bulu-style Floating Right Map Controls (Recenter, Full Route, Manual Step)
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                z: 15

                Rectangle {
                    width: 38; height: 38; radius: 10; color: Theme.cardWhite
                    border.color: Theme.primaryGreen; border.width: 1.5
                    Text { anchors.centerIn: parent; text: "🎯"; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: api.toastMessage("已鎖定當前定位中心點 (" + api.hikeCurrentLat.toFixed(4) + ", " + api.hikeCurrentLng.toFixed(4) + ")") }
                }

                Rectangle {
                    width: 38; height: 38; radius: 10; color: Theme.accentOrange
                    Text { anchors.centerIn: parent; text: "👣"; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: api.checkInNextPoint() }
                }
            }

            // State 1 Bottom Card: Idle -> Route Selector + Start Button
            Rectangle {
                visible: api.hikeState === "idle"
                width: parent.width - 24
                implicitHeight: idleCol.implicitHeight + 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.radiusCard
                color: Theme.cardWhite

                ColumnLayout {
                    id: idleCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "當前選定路線：" + (api.hikeTrail.name || "龍脊 Dragon's Back")
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "全長 " + (api.hikeTrail.distance_km || 0) + " km · 爬升 " + (api.hikeTrail.ascent_m || 0) + " m · 共 " + api.hikeTotalCheckpoints + " 個打卡點"
                        font.pixelSize: Theme.fontCaption
                        color: Theme.textSecondary
                    }

                    // Quick Route Switcher Chips
                    Flickable {
                        Layout.fillWidth: true
                        height: 32
                        contentWidth: routePickerRow.implicitWidth
                        clip: true
                        Row {
                            id: routePickerRow
                            spacing: 6
                            Repeater {
                                model: api.trailsList
                                delegate: TagChip {
                                    label: modelData.name.split("（")[0]
                                    selected: (api.hikeTrail.id || "") === modelData.id
                                    onClicked: api.selectHikeTrail(modelData.id)
                                }
                            }
                        }
                    }

                    PrimaryButton {
                        Layout.fillWidth: true
                        text: "開始出發記錄軌跡"
                        onClicked: api.startHike()
                    }
                }
            }

            // State 2 Bottom Card: Active Hiking Controls ("打卡" / "拍照" / "結束")
            Rectangle {
                visible: api.hikeState === "active"
                width: parent.width - 24
                implicitHeight: activeCol.implicitHeight + 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.radiusCard
                color: Theme.cardWhite

                ColumnLayout {
                    id: activeCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "正在行進：" + (api.hikeTrail.name || "") + "（已拍 " + api.hikePhotoCount + " 張相片）"
                        font.pixelSize: Theme.fontCaption
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    TextField {
                        id: hikePhotoField
                        Layout.fillWidth: true
                        placeholderText: "貼上相片網址或本機檔案路徑（選填）"
                        font.pixelSize: 12
                        padding: 8
                        background: Rectangle {
                            radius: 8
                            color: Theme.bgCream
                            border.color: "#DCDCDC"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        PrimaryButton {
                            Layout.fillWidth: true
                            text: "📍 打卡路標"
                            bgColor: Theme.primaryGreen
                            onClicked: api.checkInNextPoint()
                        }

                        PrimaryButton {
                            Layout.fillWidth: true
                            text: "📷 加入相片"
                            bgColor: "#3D7A5D"
                            onClicked: {
                                api.addHikePhoto(hikePhotoField.text)
                                hikePhotoField.text = ""
                            }
                        }

                        PrimaryButton {
                            Layout.fillWidth: true
                            text: "⏹ 結束行山"
                            bgColor: Theme.accentOrange
                            onClicked: api.finishHike()
                        }
                    }
                }
            }

            // State 3 Overlay: Trip Settlement Card ("發布到社區" / "僅保存")
            Rectangle {
                visible: api.hikeState === "summary"
                anchors.fill: parent
                color: "#D91C1C1E"

                Rectangle {
                    width: parent.width - 32
                    implicitHeight: summaryCol.implicitHeight + 28
                    anchors.centerIn: parent
                    radius: Theme.radiusCard
                    color: Theme.cardWhite

                    ColumnLayout {
                        id: summaryCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: "🎉 行山行程結算單"
                            font.pixelSize: Theme.fontTitle
                            font.bold: true
                            color: Theme.primaryGreen
                        }

                        Text {
                            Layout.fillWidth: true
                            text: api.hikeTrail.name || ""
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 8

                            StatPill {
                                Layout.fillWidth: true
                                label: "完成距離"
                                value: api.hikeDistanceKm + " km"
                            }
                            StatPill {
                                Layout.fillWidth: true
                                label: "總計時長"
                                value: api.hikeDurationText
                            }
                            StatPill {
                                Layout.fillWidth: true
                                label: "打卡路標"
                                value: api.hikeCheckedCount + " / " + api.hikeTotalCheckpoints
                            }
                            StatPill {
                                Layout.fillWidth: true
                                label: "沿途拍照 / 爬升"
                                value: api.hikePhotoCount + "張 / " + (api.hikeTrail.ascent_m || 0) + "m"
                            }
                        }

                        TextField {
                            id: settlementNoteField
                            Layout.fillWidth: true
                            placeholderText: "寫句今日行山感想（如：山頂海風超爽，士多豆腐花必食！）"
                            font.pixelSize: 13
                            padding: 10
                            background: Rectangle {
                                radius: 8
                                color: Theme.bgCream
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            PrimaryButton {
                                Layout.fillWidth: true
                                text: "僅保存記錄"
                                bgColor: "#8A8A8E"
                                onClicked: {
                                    api.completeHikeSettlement(false, settlementNoteField.text)
                                    settlementNoteField.text = ""
                                }
                            }

                            PrimaryButton {
                                Layout.fillWidth: true
                                text: "一鍵發布到社區"
                                bgColor: Theme.primaryGreen
                                onClicked: {
                                    api.completeHikeSettlement(true, settlementNoteField.text)
                                    settlementNoteField.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
