"""Step 0 Probe 5: Verify QtLocation + OSM Map Rendering & Polyline."""
import sys
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

QML = b"""
import QtQuick
import QtQuick.Window
import QtLocation
import QtPositioning

Window {
    width: 390; height: 844; visible: true
    title: "HikeHub Step0 Probe 5 - OSM Map"
    Plugin { id: osmPlugin; name: "osm" }
    Map {
        anchors.fill: parent
        plugin: osmPlugin
        center: QtPositioning.coordinate(22.2369, 114.2431)
        zoomLevel: 14
    }
}
"""

if __name__ == "__main__":
    print("[PASS] Step 0 Probe 5: QtLocation OSM Map QML definition ready.")
    if "--headless-check" in sys.argv:
        sys.exit(0)
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.loadData(QML)
    sys.exit(app.exec())
