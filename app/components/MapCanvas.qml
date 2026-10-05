import QtQuick
import QtLocation
import QtPositioning
import "../theme"

Item {
    id: root
    property double centerLat: 22.2369
    property double centerLng: 114.2431
    property var fullPath: []
    property var walkedPath: []
    property var remainingPath: []
    property var checkpoints: []
    property var checkedIds: []
    property bool isTracking: false

    Plugin {
        id: osmPlugin
        name: "osm"
    }

    Map {
        id: mapView
        anchors.fill: parent
        plugin: osmPlugin
        center: QtPositioning.coordinate(root.centerLat, root.centerLng)
        zoomLevel: 14.2

        // Full trail base polyline (shown before start or as background reference)
        MapPolyline {
            line.width: 4
            line.color: root.isTracking ? "#998A8A8E" : Theme.primaryGreen
            path: {
                var coords = []
                var src = root.isTracking ? root.remainingPath : root.fullPath
                for (var i = 0; i < src.length; i++) {
                    coords.push(QtPositioning.coordinate(src[i][0], src[i][1]))
                }
                return coords
            }
        }

        // Walked trail solid polyline during hike
        MapPolyline {
            visible: root.isTracking && root.walkedPath.length > 1
            line.width: 6
            line.color: Theme.primaryGreen
            path: {
                var coords = []
                for (var i = 0; i < root.walkedPath.length; i++) {
                    coords.push(QtPositioning.coordinate(root.walkedPath[i][0], root.walkedPath[i][1]))
                }
                return coords
            }
        }

        // Current hiker position marker
        MapQuickItem {
            coordinate: QtPositioning.coordinate(root.centerLat, root.centerLng)
            anchorPoint.x: 11
            anchorPoint.y: 11
            sourceItem: Rectangle {
                width: 22
                height: 22
                radius: 11
                color: Theme.accentOrange
                border.color: "#FFFFFF"
                border.width: 3
            }
        }
    }

    // Visual vector fallback overlay if OSM network tiles are loading/blocked
    Canvas {
        id: fallbackTrailOverlay
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var pts = root.fullPath
            if (!pts || pts.length < 2) return

            var minLat = 999, maxLat = -999, minLng = 999, maxLng = -999
            for (var i = 0; i < pts.length; i++) {
                minLat = Math.min(minLat, pts[i][0])
                maxLat = Math.max(maxLat, pts[i][0])
                minLng = Math.min(minLng, pts[i][1])
                maxLng = Math.max(maxLng, pts[i][1])
            }
            var spanLat = Math.max(0.008, maxLat - minLat)
            var spanLng = Math.max(0.008, maxLng - minLng)

            function toXY(lat, lng) {
                var pad = 48
                var x = pad + ((lng - minLng) / spanLng) * (width - pad * 2)
                var y = height - pad - ((lat - minLat) / spanLat) * (height - pad * 2)
                return [x, y]
            }

            // Dashed remaining route
            ctx.beginPath()
            ctx.setLineDash([6, 4])
            ctx.lineWidth = 3
            ctx.strokeStyle = "#8A8A8E"
            for (var j = 0; j < pts.length; j++) {
                var p = toXY(pts[j][0], pts[j][1])
                if (j === 0) ctx.moveTo(p[0], p[1])
                else ctx.lineTo(p[0], p[1])
            }
            ctx.stroke()

            // Solid walked route
            var wpts = root.isTracking ? root.walkedPath : pts
            if (wpts && wpts.length >= 2) {
                ctx.beginPath()
                ctx.setLineDash([])
                ctx.lineWidth = 5
                ctx.strokeStyle = "#2F6B4F"
                for (var k = 0; k < wpts.length; k++) {
                    var wp = toXY(wpts[k][0], wpts[k][1])
                    if (k === 0) ctx.moveTo(wp[0], wp[1])
                    else ctx.lineTo(wp[0], wp[1])
                }
                ctx.stroke()
            }

            // Checkpoints
            var cps = root.checkpoints || []
            for (var c = 0; c < cps.length; c++) {
                var cpXY = toXY(cps[c].lat, cps[c].lng)
                var checked = root.checkedIds.indexOf(cps[c].id) !== -1
                ctx.beginPath()
                ctx.arc(cpXY[0], cpXY[1], 7, 0, Math.PI * 2)
                ctx.fillStyle = checked ? "#2F6B4F" : "#FFFFFF"
                ctx.fill()
                ctx.lineWidth = 2
                ctx.strokeStyle = "#E07A3F"
                ctx.stroke()
            }

            // Current position dot
            var cur = toXY(root.centerLat, root.centerLng)
            ctx.beginPath()
            ctx.arc(cur[0], cur[1], 8, 0, Math.PI * 2)
            ctx.fillStyle = "#E07A3F"
            ctx.fill()
        }
    }

    onCenterLatChanged: fallbackTrailOverlay.requestPaint()
    onCenterLngChanged: fallbackTrailOverlay.requestPaint()
    onFullPathChanged: fallbackTrailOverlay.requestPaint()
    onWalkedPathChanged: fallbackTrailOverlay.requestPaint()
    onCheckedIdsChanged: fallbackTrailOverlay.requestPaint()
}
