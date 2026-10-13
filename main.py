#!/usr/bin/env python3
"""
行山腳 HikeHub · Application Entry Point
Project: COMP 7510 Group Project
Author: Member B (App Framework & Auth)

Viewport: Mobile aspect ratio 390 x 844 (iPhone 14 logical resolution)
Framework: Python + PySide6 (Qt 6.9) + Qt Quick (QML)
"""
import os
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from app.backend.bridge import ApiBridge


def resolve_app_dir() -> Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / "app"
    return Path(__file__).resolve().parent / "app"


def main() -> int:
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication(sys.argv)
    app.setApplicationName("行山腳 HikeHub")
    app.setOrganizationName("COMP7510-HikeHub")

    engine = QQmlApplicationEngine()
    api_bridge = ApiBridge()
    engine.rootContext().setContextProperty("api", api_bridge)

    app_dir = resolve_app_dir()
    engine.addImportPath(str(app_dir))
    main_qml = app_dir / "main.qml"
    engine.load(QUrl.fromLocalFile(str(main_qml)))

    if not engine.rootObjects():
        sys.stderr.write("Failed to load QML interface: app/main.qml\n")
        return 1

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
