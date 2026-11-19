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

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QColor, QGuiApplication, QPalette
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

    # Basic 樣式控件的文字色跟隨系統調色板；Windows 深色模式下會變白導致
    # 白色輸入框內文字不可見。此處固定為深色主題調色板（與 Theme.qml 一致）。
    palette = app.palette()
    dark_text = QColor("#1C1C1E")
    palette.setColor(QPalette.ColorRole.Text, dark_text)
    palette.setColor(QPalette.ColorRole.WindowText, dark_text)
    palette.setColor(QPalette.ColorRole.ButtonText, dark_text)
    palette.setColor(QPalette.ColorRole.PlaceholderText, QColor("#8A8A8E"))
    app.setPalette(palette)

    engine = QQmlApplicationEngine()
    api_bridge = ApiBridge()
    engine.rootContext().setContextProperty("api", api_bridge)

    app_dir = resolve_app_dir()
    engine.addImportPath(str(app_dir))
    main_qml = app_dir / "main.qml"
    engine.load(QUrl.fromLocalFile(str(main_qml)))

    diag_root = (
        Path(sys.executable).resolve().parent
        if getattr(sys, "frozen", False)
        else Path(__file__).resolve().parent
    )

    if not engine.rootObjects():
        message = (
            "HikeHub 啟動失敗：無法載入 QML 介面 app/main.qml\n"
            f"app_dir = {app_dir}\n"
            f"frozen = {getattr(sys, 'frozen', False)}\n"
        )
        sys.stderr.write(message)
        try:
            (diag_root / "HikeHub_startup_error.txt").write_text(
                message, encoding="utf-8"
            )
        except OSError:
            pass
        return 1

    # Opt-in startup diagnostics for frozen builds (no console window exists).
    if os.environ.get("HIKEHUB_DIAG") == "1":
        try:
            import json
            from app.backend.supabase_client import get_db, find_env_file
            meipass = Path(str(getattr(sys, "_MEIPASS", "")))
            (diag_root / "HikeHub_diag.json").write_text(
                json.dumps(
                    {
                        "frozen": getattr(sys, "frozen", False),
                        "app_dir": str(app_dir),
                        "meipass": str(meipass),
                        "env_file": str(find_env_file() or ""),
                        "osm_plugin": (
                            meipass / "PySide6/plugins/geoservices/qtgeoservices_osm.dll"
                        ).exists(),
                        "qml_location": (meipass / "PySide6/qml/QtLocation").exists(),
                        "qml_positioning": (meipass / "PySide6/qml/QtPositioning").exists(),
                        "status": get_db().get_status_summary(),
                        "qml_loaded": True,
                    },
                    ensure_ascii=False,
                    indent=2,
                ),
                encoding="utf-8",
            )
        except Exception:
            pass
        # Diagnostic mode terminates by itself; packaging checks need no
        # external kill and leave no orphan GUI process behind.
        QTimer.singleShot(1500, app.quit)

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
