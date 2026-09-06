import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 296
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property int count: service ? service.connectedCount : 0

    readonly property real contentW: widthBudget > 0 ? widthBudget : 296

    implicitWidth: root.contentW
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: root.contentW
        spacing: 8 * root.s

        // ── header + connected count + close button ──
        Item {
            width: parent.width
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth"
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 13 * root.s
                    font.letterSpacing: 2 * root.s
                    font.weight: Font.Medium
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.count > 0
                    spacing: 4 * root.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "bluetooth"
                        width: 13 * root.s
                        height: 13 * root.s
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(root.count)
                        color: Theme.accent
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Medium
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? Theme.accent : Theme.dim
                    font.pixelSize: 12 * root.s
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.pluginApi) root.pluginApi.closePanel()
                    }
                }
            }
        }

        // ── divider ──
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // ── refresh action button ──
        Rectangle {
            width: parent.width
            height: 28 * root.s
            radius: 8
            readonly property bool hovered: scanMa.containsMouse
            readonly property bool isBusy: root.service ? root.service.busy : false
            color: isBusy
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                : (hovered ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.08)
                           : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.04))
            border.color: (isBusy || hovered) ? Theme.accent : Theme.border
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: parent.isBusy ? "Scanning profiles…" : "Refresh devices"
                color: parent.isBusy ? Theme.accent : Theme.bright
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
            }

            MouseArea {
                id: scanMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.service) root.service.refresh()
            }
        }

        // ── error text ──
        Text {
            visible: !!(root.service && root.service.lastError && root.service.lastError.length > 0)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.service ? root.service.lastError : ""
            color: Theme.sun
            font.family: Theme.mono
            font.pixelSize: 10 * root.s
            wrapMode: Text.WordWrap
        }

        // ── device list ──
        Column {
            width: parent.width
            spacing: 6 * root.s

            Text {
                visible: root.count === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: (root.service && root.service.busy) ? "Scanning for devices…" : "No bluetooth audio devices found"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
                topPadding: 6 * root.s
                bottomPadding: 6 * root.s
            }

            Repeater {
                model: root.service ? root.service.cards : []
                delegate: Rectangle {
                    id: devTile
                    required property var modelData
                    property bool expanded: true
                    readonly property bool isCardActive: modelData.activeProfile !== "off"
                    readonly property bool hovered: tileHover.containsMouse || actionMa.containsMouse || infoMa.containsMouse
                    readonly property int rowHeight: 42 * root.s

                    width: col.width
                    height: rowHeight + (expanded ? profileCol.implicitHeight + 8 * root.s : 0)
                    radius: 8
                    clip: true
                    color: isCardActive ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                           : (hovered ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.08)
                                      : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.04))
                    border.color: isCardActive ? Theme.accent : (hovered ? Theme.accent : Theme.border)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: tileHover
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                    }

                    Item {
                        id: rowItem
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: devTile.rowHeight

                        MouseArea {
                            anchors.left: parent.left
                            anchors.right: infoPill.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            cursorShape: Qt.PointingHandCursor
                            onClicked: devTile.expanded = !devTile.expanded
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 8 * root.s
                            anchors.right: infoPill.left
                            anchors.rightMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1 * root.s

                            Text {
                                width: parent.width
                                text: devTile.modelData.description
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 11 * root.s
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: {
                                    var prefix = devTile.isCardActive ? "Connected" : "Disabled"
                                    if (devTile.modelData.batteryText.length > 0)
                                        return prefix + " · " + devTile.modelData.batteryText
                                    return prefix + " · " + devTile.modelData.activeShortCodec
                                }
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                                font.weight: Font.Medium
                                opacity: 0.85
                                elide: Text.ElideRight
                            }
                        }

                        // info toggle: reveals/hides profiles list
                        Rectangle {
                            id: infoPill
                            anchors.right: actionButton.left
                            anchors.rightMargin: 6 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18 * root.s
                            height: 18 * root.s
                            radius: 9 * root.s
                            color: devTile.expanded ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                                   : infoMa.containsMouse ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.12)
                                   : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.05)
                            border.color: (devTile.expanded || infoMa.containsMouse) ? Theme.accent : Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "!"
                                color: (devTile.expanded || infoMa.containsMouse) ? Theme.accent : Theme.dim
                                font.family: Theme.mono
                                font.pixelSize: 11 * root.s
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: infoMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: devTile.expanded = !devTile.expanded
                            }
                        }

                        // quick switch button (e.g. Disconnect or Quick Switch)
                        Rectangle {
                            id: actionButton
                            anchors.right: parent.right
                            anchors.rightMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: actionLabel.implicitWidth + 14 * root.s
                            height: 24 * root.s
                            radius: 8
                            color: actionMa.containsMouse ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.12)
                                                         : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.06)
                            border.color: actionMa.containsMouse ? Theme.accent : Theme.border
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: {
                                    if (devTile.modelData.quickTarget) {
                                        return devTile.modelData.quickTarget.group === "headset" ? "Headset" : "High-Fi"
                                    }
                                    return devTile.isCardActive ? "Disable" : "Enable"
                                }
                                color: actionMa.containsMouse ? Theme.accent : Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                            }

                            MouseArea {
                                id: actionMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.service) return
                                    if (devTile.modelData.quickTarget) {
                                        root.service.setProfile(devTile.modelData.name, devTile.modelData.quickTarget.name)
                                    } else {
                                        var target = devTile.isCardActive ? "off" : (devTile.modelData.profiles.length > 0 ? devTile.modelData.profiles[0].name : "off")
                                        root.service.setProfile(devTile.modelData.name, target)
                                    }
                                }
                            }
                        }
                    }

                    // ── profile selection list ──
                    Column {
                        id: profileCol
                        anchors.top: rowItem.bottom
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * root.s
                        spacing: 3 * root.s
                        visible: devTile.expanded
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.6)
                        }

                        Text {
                            text: "PROFILES"
                            color: Theme.dim
                            font.family: Theme.mono
                            font.pixelSize: 9 * root.s
                            font.letterSpacing: 1.5 * root.s
                            font.weight: Font.DemiBold
                            topPadding: 2 * root.s
                        }

                        Repeater {
                            model: devTile.modelData.profiles
                            delegate: Rectangle {
                                id: profTile
                                required property var modelData
                                readonly property bool isSelected: devTile.modelData.activeProfile === modelData.name
                                readonly property bool profHover: pMa.containsMouse

                                width: profileCol.width
                                height: 24 * root.s
                                radius: 6
                                color: isSelected
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
                                    : (profHover ? Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.08)
                                                 : Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.03))
                                border.color: isSelected ? Theme.accent : (profHover ? Theme.accent : Theme.border)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Item {
                                    anchors.fill: parent

                                    Text {
                                        id: bullet
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: profTile.isSelected ? "●" : "○"
                                        color: profTile.isSelected ? Theme.accent : Theme.dim
                                        font.family: Theme.mono
                                        font.pixelSize: 9 * root.s
                                    }

                                    Text {
                                        id: badge
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: profTile.isSelected ? "ACTIVE" : profTile.modelData.shortCodec
                                        color: profTile.isSelected ? Theme.accent : Theme.dim
                                        font.family: Theme.mono
                                        font.pixelSize: 9 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 1 * root.s
                                    }

                                    Text {
                                        anchors.left: bullet.right
                                        anchors.leftMargin: 6 * root.s
                                        anchors.right: badge.left
                                        anchors.rightMargin: 6 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: profTile.modelData.label
                                        color: profTile.isSelected ? Theme.bright : (profTile.profHover ? Theme.bright : Theme.dim)
                                        font.family: Theme.mono
                                        font.pixelSize: 10 * root.s
                                        font.weight: profTile.isSelected ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: pMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!profTile.isSelected && root.service) {
                                            root.service.setProfile(devTile.modelData.name, profTile.modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── divider ──
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
        }

        // ── bottom action button ──
        Rectangle {
            width: parent.width
            height: 28 * root.s
            radius: 8
            color: btSetMa.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "Bluetooth settings"
                color: Theme.cardTop
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
            }

            MouseArea {
                id: btSetMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.pluginApi) root.pluginApi.closePanel()
                    openSettingsProc.running = false
                    openSettingsProc.running = true
                }
            }
        }
    }

    Process {
        id: openSettingsProc
        command: ["ryoku-shell", "hub", "open", "connections"]
    }
}
