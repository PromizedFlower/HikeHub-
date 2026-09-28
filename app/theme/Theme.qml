pragma Singleton
import QtQuick

QtObject {
    // 6-Color Minimalist Palette (Strictly <= 6 colors per spec)
    readonly property color primaryGreen: "#2F6B4F"
    readonly property color accentOrange: "#E07A3F"
    readonly property color bgCream: "#F7F6F3"
    readonly property color cardWhite: "#FFFFFF"
    readonly property color textPrimary: "#1C1C1E"
    readonly property color textSecondary: "#8A8A8E"

    // 3 Font Levels (Title 20 / Body 15 / Caption 12)
    readonly property int fontTitle: 20
    readonly property int fontBody: 15
    readonly property int fontCaption: 12

    // Unified Radius & Spacing
    readonly property int radiusCard: 12
    readonly property int spacingSm: 8
    readonly property int spacingMd: 12
    readonly property int spacingLg: 16
}
