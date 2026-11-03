# -*- mode: python ; coding: utf-8 -*-
# ============================================================================
# 行山腳 HikeHub · PyInstaller Packaging Spec (Windows exe)
# Author: Member A (Data Architect)
# Command: pyinstaller build.spec --noconfirm
# Acceptance: Double-click dist/HikeHub.exe on a Windows machine without Python
#             installed; reads .env from exe directory and renders all QML pages.
# ============================================================================

block_cipher = None

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('app', 'app'),
        ('supabase', 'supabase'),
        ('.env.example', '.'),
    ],
    hiddenimports=[
        'PySide6.QtCore',
        'PySide6.QtGui',
        'PySide6.QtQml',
        'PySide6.QtQuick',
        'PySide6.QtQuickControls2',
        'PySide6.QtLocation',
        'PySide6.QtPositioning',
        'supabase',
        'dotenv',
        'PIL',
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
    console=False,   # --windowed mode (no black console window)
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
