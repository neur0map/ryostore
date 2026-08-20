pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

Item {
    id: widget

    property var pluginApi: null
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 220
    property bool active: true
    property var screen: null

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var settings: (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings : ({})

    readonly property bool paused: service ? service.paused : (settings.paused === true || settings.paused === "true")

    readonly property string _shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string _placeScript: (_shellDir && _shellDir.length > 0)
        ? _shellDir + "/quickshell/plugins/ryoku-plugins-place"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/ryoku-plugins-place"

    Process { id: placeProc }

    function setSetting(key, val) {
        if (service && typeof service.setSetting === "function") {
            service.setSetting(key, val);
            return;
        }
        var obj = {};
        obj[key] = val;
        placeProc.running = false;
        placeProc.command = [widget._placeScript, "key-visualizer", "settings", JSON.stringify(obj)];
        placeProc.running = true;
    }

    function togglePaused() {
        if (service && typeof service.togglePaused === "function") service.togglePaused();
        else setSetting("paused", !widget.paused);
    }

    implicitWidth: 30 * widget.s
    implicitHeight: 24 * widget.s

    Rectangle {
        anchors.fill: parent
        radius: 4 * widget.s
        color: glyphMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text: "\uDB80\uDF0C" // Nerd Font keyboard icon
            font.family: Theme.mono || "JetBrainsMono Nerd Font"
            font.pixelSize: 14 * widget.s
            color: widget.paused ? Theme.faint : Theme.accent
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: glyphMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: widget.togglePaused()
    }
}

