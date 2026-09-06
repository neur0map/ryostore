import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 220

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property int count: service ? service.connectedCount : 0
    readonly property string codec: service ? service.primaryCodec : ""
    readonly property bool isConnected: count > 0

    readonly property var cfg: (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings : ({})
    readonly property string badgeType: (cfg && cfg.barBadge !== undefined) ? cfg.barBadge : "codec"

    readonly property string badgeText: {
        if (!isConnected) return ""
        if (badgeType === "count") return String(count)
        if (badgeType === "codec") return codec
        return ""
    }

    implicitWidth: row.implicitWidth + 8 * root.s
    implicitHeight: Math.max(row.implicitHeight, 20 * root.s)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4 * root.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "bluetooth"
            width: 14 * root.s
            height: 14 * root.s
            color: root.isConnected ? Theme.accent : Theme.dim
            opacity: root.isConnected ? 1.0 : 0.4
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.badgeText.length > 0
            text: root.badgeText
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget - 20 * root.s) : implicitWidth
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
