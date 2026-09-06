import QtQuick
import Quickshell
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons
import "service" as Svc
import "content" as Views

ShellRoot {
    FloatingWindow {
        id: win
        title: "Bluetooth Profiles — Live Dev Preview"
        implicitWidth: 360
        implicitHeight: 640
        color: Theme.cardTop
        visible: true

        readonly property var mockApi: QtObject {
            property var mainInstance: serviceInst
            property var pluginSettings: ({
                barBadge: "codec",
                autoExpand: true
            })
            property string pluginDir: "."
            property string stateDir: "/tmp"
            property bool panelOpen: true
            function togglePanel() { panelOpen = !panelOpen }
            function closePanel() { panelOpen = false }
            function openPanel() { panelOpen = true }
            function saveSetting(key, val) {
                console.log("[DevPreview] saveSetting:", key, "=", val);
            }
        }

        Svc.Main {
            id: serviceInst
            pluginApi: win.mockApi
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Text {
                text: "BAR GLYPH PREVIEW"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.5
            }

            Rectangle {
                width: parent.width
                height: 38
                radius: 19
                color: Theme.tileBg
                border.color: Theme.border
                border.width: 1

                Views.Widget {
                    anchors.centerIn: parent
                    pluginApi: win.mockApi
                    density: "glyph"
                }
            }

            Text {
                text: "PANEL POPUP PREVIEW"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.5
            }

            Rectangle {
                width: parent.width
                height: panelView.implicitHeight + 24
                radius: 12
                color: Theme.tileBg
                border.color: Theme.border
                border.width: 1
                visible: win.mockApi.panelOpen
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Views.Panel {
                    id: panelView
                    anchors.fill: parent
                    anchors.margins: 12
                    pluginApi: win.mockApi
                    density: "full"
                    widthBudget: parent.width - 24
                }
            }
        }
    }
}
