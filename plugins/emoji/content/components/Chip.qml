import QtQuick
import Ryoku.PluginKit.Singletons

Rectangle {
    id: chop
    property string label: ""
    property int count: 0
    property bool on: false
    property real s: 1
    signal picked

    width: row.implicitWidth + 20 * chop.s
    height: 24 * chop.s
    radius: Motion.rSmall * chop.s
    color: on ? Theme.brand : "transparent"
    border.width: 1
    border.color: on ? Theme.brand : Theme.hair
    Behavior on color { ColorAnimation { duration: Motion.fast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5 * chop.s
        Text {
            id: chipLabel
            text: chop.label
            color: on ? Theme.cream : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10 * chop.s
            font.letterSpacing: 0.4
        }
        Text {
            visible: chop.count > 0
            text: chop.count.toString()
            color: on ? Qt.alpha(Theme.cream, 0.85) : Qt.alpha(Theme.faint, 0.6)
            font.family: Theme.mono
            font.pixelSize: 8.5 * chop.s
            font.features: { "tnum": 1 }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chop.picked()
    }
}