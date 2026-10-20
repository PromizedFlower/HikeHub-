import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"
import "../components"

Rectangle {
    id: root
    color: Theme.bgCream
    signal trailSelected(string trailId)

    property string selectedRegion: "全部"
    property int selectedDifficulty: 0
    property string selectedDuration: "全部"
    property string searchKeyword: ""

    function applyFilter() {
        api.filterTrails(root.selectedRegion, root.selectedDifficulty, root.selectedDuration, root.searchKeyword)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            text: "香港行山線路庫"
            font.pixelSize: Theme.fontTitle
            font.bold: true
            color: Theme.textPrimary
        }

        // Keyword search bar
        Rectangle {
            Layout.fillWidth: true
            height: 38
            radius: Theme.radiusCard
            color: Theme.cardWhite
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                Text { text: "🔍"; font.pixelSize: 14 }
                TextField {
                    id: kwField
                    Layout.fillWidth: true
                    placeholderText: "搜尋山徑名稱、補給點或地區..."
                    font.pixelSize: 13
                    background: Item {}
                    onTextChanged: {
                        root.searchKeyword = text
                        root.applyFilter()
                    }
                }
                Text {
                    visible: kwField.text.length > 0
                    text: "清除"
                    font.pixelSize: 12
                    color: Theme.accentOrange
                    MouseArea {
                        anchors.fill: parent
                        onClicked: kwField.text = ""
                    }
                }
            }
        }

        // Region Filter Chips
        Flickable {
            Layout.fillWidth: true
            height: 32
            contentWidth: regionRow.implicitWidth
            clip: true
            Row {
                id: regionRow
                spacing: 6
                Repeater {
                    model: ["全部", "港島", "西貢", "大嶼山", "新界東北", "九龍及新界中"]
                    delegate: TagChip {
                        label: modelData
                        selected: root.selectedRegion === modelData
                        onClicked: {
                            root.selectedRegion = modelData
                            root.applyFilter()
                        }
                    }
                }
            }
        }

        // Difficulty & Duration Filter Chips
        Flickable {
            Layout.fillWidth: true
            height: 32
            contentWidth: diffRow.implicitWidth
            clip: true
            Row {
                id: diffRow
                spacing: 6
                Repeater {
                    model: [
                        { label: "難度不限", val: 0 },
                        { label: "★1 新手", val: 1 },
                        { label: "★2 輕鬆", val: 2 },
                        { label: "★3 進階", val: 3 },
                        { label: "★4 挑戰", val: 4 },
                        { label: "★5 專家", val: 5 }
                    ]
                    delegate: TagChip {
                        label: modelData.label
                        selected: root.selectedDifficulty === modelData.val
                        onClicked: {
                            root.selectedDifficulty = modelData.val
                            root.applyFilter()
                        }
                    }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            height: 32
            contentWidth: durRow.implicitWidth
            clip: true
            Row {
                id: durRow
                spacing: 6
                Repeater {
                    model: ["全部", "3小時內", "3-4小時", "4小時以上"]
                    delegate: TagChip {
                        label: modelData === "全部" ? "時長不限" : modelData
                        selected: root.selectedDuration === modelData
                        onClicked: {
                            root.selectedDuration = modelData
                            root.applyFilter()
                        }
                    }
                }
            }
        }

        // Route List View (with Empty State fallback)
        ListView {
            id: routeListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            model: api.trailsList

            delegate: TrailCard {
                width: routeListView.width
                trailData: modelData
                onCardClicked: function(tid) { root.trailSelected(tid) }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: api.trailsList.length === 0
                message: "找不到符合篩選條件的山徑"
                actionText: "重置篩選"
                onActionClicked: {
                    root.selectedRegion = "全部"
                    root.selectedDifficulty = 0
                    root.selectedDuration = "全部"
                    kwField.text = ""
                    root.applyFilter()
                }
            }
        }
    }
}
