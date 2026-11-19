# -*- mode: python ; coding: utf-8 -*-
# ============================================================================
# 行山腳 HikeHub · PyInstaller Packaging Spec (Windows one-file exe)
# Command: pyinstaller build.spec --noconfirm
# Acceptance: double-click dist/HikeHub.exe on a Windows machine without Python;
#             .env is resolved from the bundle, all 5 QML tabs and the OSM map work.
# ============================================================================
from pathlib import Path

import PySide6

PYSIDE_DIR = Path(PySide6.__file__).resolve().parent


def collect_tree(rel_src: str, rel_dest: str):
    """Collect every file of a PySide6 sub-tree, preserving its on-disk layout.

    Qt loads plugins / QML modules by path, so these must land under
    _MEIPASS/PySide6/... exactly where the Qt libraries expect them.
    """
    src = PYSIDE_DIR / rel_src
    if not src.is_dir():
        return []
    return [
        (str(item), str(Path(rel_dest) / item.relative_to(src).parent))
        for item in src.rglob("*")
        if item.is_file()
    ]


# QtLocation's OSM / items-overlay map plugins are NOT guaranteed to be picked
# up by PyInstaller's Qt hooks; collect them explicitly so the 出發 tab works.
qt_geoservices = collect_tree(
    "plugins/geoservices", "PySide6/plugins/geoservices"
)

# QML modules used by the 5 tabs (QtQuick.Controls / Layouts / Window live
# inside qml/QtQuick). Collected explicitly rather than relying on hook order.
qt_qml = []
for _module in (
    "Qt", "QtCore", "QtGui", "QtNetwork", "QtQml", "QtQuick",
    "QtLocation", "QtPositioning",
):
    qt_qml += collect_tree(f"qml/{_module}", f"PySide6/qml/{_module}")

# .env is optional at build time (the exe falls back to .env.example); both
# contain only the public anon key and are bundled for a zero-config launch.
env_files = [
    (str(_env), ".")
    for _env in (".env", ".env.example")
    if Path(_env).is_file()
]

block_cipher = None

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('app', 'app'),
        ('supabase', 'supabase'),
    ] + env_files + qt_geoservices + qt_qml,
    hiddenimports=[
        'PySide6.QtCore',
        'PySide6.QtGui',
        'PySide6.QtQml',
        'PySide6.QtQuick',
        'PySide6.QtQuickControls2',
        'PySide6.QtLocation',
        'PySide6.QtPositioning',
        'PySide6.QtNetwork',
        # supabase-py 2.x dependency chain (PostgREST + Auth + Storage)
        'supabase',
        'supabase.lib.client_options',
        'postgrest',
        'storage3',
        'realtime',
        'httpx',
        'httpcore',
        'h2',
        'pydantic',
        'dotenv',
        'PIL',
        'PIL.Image',
        # application modules (QML only sees them through the bridge object)
        'app.backend.bridge',
        'app.backend.remote_store',
        'app.backend.supabase_client',
        'app.backend.auth_service',
        'app.backend.post_service',
        'app.backend.social_service',
        'app.backend.trail_service',
        'app.backend.location_service',
        'app.backend.workers',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'flask', 'django', 'fastapi'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='HikeHub',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,   # --windowed: no black console window for end users
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
