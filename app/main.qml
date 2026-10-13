import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "theme"
import "components"
import "pages"

ApplicationWindow {
    id: rootWindow
    width: 390
    height: 844
    minimumWidth: 360
    minimumHeight: 740
    visible: true
    title: "行山腳 HikeHub"
    color: Theme.bgCream

    property int currentTabIndex: 0

    // Helper functions to push subpages onto the active tab's StackView
    function activeStack() {
        var stacks = [homeStack, routeStack, startStack, communityStack, profileStack]
        return stacks[currentTabIndex]
    }

    function openTrailDetail(trailId) {
        api.loadTrailDetail(trailId)
        activeStack().push(routeDetailComponent, { "trailId": trailId })
    }

    function openPostDetail(postId) {
        api.loadPostDetail(postId)
        activeStack().push(postDetailComponent, { "postId": postId })
    }

    function openComposePage(defaultType, defaultTrailId) {
        activeStack().push(composePageComponent, {
            "initialType": defaultType || "moment",
            "initialTrailId": defaultTrailId || "trail-01"
        })
    }

    function openEditProfilePage() {
        profileStack.push(editProfileComponent)
    }

    Connections {
        target: api
        function onNavigateToTabRequested(tabIdx) {
            rootWindow.currentTabIndex = tabIdx
        }
        function onToastMessage(msg) {
            toastBanner.showToast(msg)
        }
    }

    // 1. Login Page (Shown before authentication; BottomTabBar hidden per spec)
    SignInPage {
        id: signInView
        anchors.fill: parent
        visible: !api.isLoggedIn
    }

    // 2. Main Authenticated Shell: 5 independent StackViews + BottomTabBar
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: api.isLoggedIn

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackView {
                id: homeStack
                anchors.fill: parent
                visible: rootWindow.currentTabIndex === 0
                initialItem: HomePage {
                    onTrailClicked: function(tid) { rootWindow.openTrailDetail(tid) }
                    onPostClicked: function(pid) { rootWindow.openPostDetail(pid) }
                    onResumeHikeClicked: { rootWindow.currentTabIndex = 2 }
                }
            }

            StackView {
                id: routeStack
                anchors.fill: parent
                visible: rootWindow.currentTabIndex === 1
                initialItem: RouteListPage {
                    onTrailSelected: function(tid) { rootWindow.openTrailDetail(tid) }
                }
            }

            StackView {
                id: startStack
                anchors.fill: parent
                visible: rootWindow.currentTabIndex === 2
                initialItem: StartPage {}
            }

            StackView {
                id: communityStack
                anchors.fill: parent
                visible: rootWindow.currentTabIndex === 3
                initialItem: CommunityPage {
                    onPostSelected: function(pid) { rootWindow.openPostDetail(pid) }
                    onComposeRequested: function(ptype) { rootWindow.openComposePage(ptype, "trail-01") }
                }
            }

            StackView {
                id: profileStack
                anchors.fill: parent
                visible: rootWindow.currentTabIndex === 4
                initialItem: ProfilePage {
                    onPostSelected: function(pid) { rootWindow.openPostDetail(pid) }
                    onTrailSelected: function(tid) { rootWindow.openTrailDetail(tid) }
                    onEditProfileRequested: { rootWindow.openEditProfilePage() }
                }
            }
        }

        BottomTabBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            currentIndex: rootWindow.currentTabIndex
            onTabClicked: function(idx) {
                if (rootWindow.currentTabIndex === idx) {
                    var st = rootWindow.activeStack()
                    if (st.depth > 1) st.pop(null)
                } else {
                    rootWindow.currentTabIndex = idx
                }
            }
        }
    }

    // Subpage Components for StackView.push(component, params)
    Component {
        id: routeDetailComponent
        RouteDetailPage {
            onBackRequested: { rootWindow.activeStack().pop() }
            onPostClicked: function(pid) { rootWindow.openPostDetail(pid) }
        }
    }

    Component {
        id: postDetailComponent
        PostDetailPage {
            onBackRequested: { rootWindow.activeStack().pop() }
            onTrailClicked: function(tid) { rootWindow.openTrailDetail(tid) }
        }
    }

    Component {
        id: composePageComponent
        ComposePage {
            onBackRequested: { rootWindow.activeStack().pop() }
            onPublished: { rootWindow.activeStack().pop() }
        }
    }

    Component {
        id: editProfileComponent
        EditProfilePage {
            onBackRequested: { profileStack.pop() }
        }
    }

    // Floating Toast Notification
    Rectangle {
        id: toastBanner
        property string message: ""
        width: Math.min(parent.width - 32, toastText.implicitWidth + 32)
        height: 40
        radius: 20
        color: "#E61C1C1E"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 18
        visible: opacity > 0
        opacity: 0
        z: 999

        function showToast(msg) {
            toastBanner.message = msg
            toastBanner.opacity = 1.0
            toastTimer.restart()
        }

        Text {
            id: toastText
            anchors.centerIn: parent
            text: toastBanner.message
            color: "#FFFFFF"
            font.pixelSize: 13
        }

        Timer {
            id: toastTimer
            interval: 2200
            onTriggered: toastBanner.opacity = 0
        }

        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
}
