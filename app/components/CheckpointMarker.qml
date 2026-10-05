import QtQuick
import QtLocation
import QtPositioning
import "../theme"

MapCircle {
    property double lat: 22.2369
    property double lng: 114.2431
    property bool checked: false
    center: QtPositioning.coordinate(lat, lng)
    radius: 35.0
    color: checked ? Theme.primaryGreen : Theme.cardWhite
    border.color: Theme.accentOrange
    border.width: 2
}
