import QtQuick
import QtLocation
import QtPositioning
import "../theme"

MapPolyline {
    property var coordinatesList: []
    property bool walked: true
    line.width: walked ? 5 : 3
    line.color: walked ? Theme.primaryGreen : Theme.textSecondary
    path: {
        var out = []
        for (var i = 0; i < coordinatesList.length; i++) {
            out.push(QtPositioning.coordinate(coordinatesList[i][0], coordinatesList[i][1]))
        }
        return out
    }
}
