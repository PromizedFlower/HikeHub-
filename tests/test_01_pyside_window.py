"""Step 0 Probe 1: Verify PySide6 QGuiApplication + QML 390x844 Window Startup."""
import sys
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

QML = b"""
import QtQuick
import QtQuick.Window
Window {
    width: 390; height: 844; visible: true
    title: "HikeHub Step0 Probe 1 - PySide6 Window"
    color: "#F7F6F3"
    Text { anchors.centerIn: parent; text: "PySide6 390x844 Ready"; font.pixelSize: 20; color: "#2F6B4F" }
}
"""

if __name__ == "__main__":
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.loadData(QML)
    if not engine.rootObjects():
        sys.exit(1)
    print("[PASS] Step 0 Probe 1: PySide6 QML window initialized.")
    if "--headless-check" in sys.argv:
        sys.exit(0)
    sys.exit(app.exec())
