pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi: null

    //  Settings from Ryoku placement 
    readonly property var settings: (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings : ({})
    readonly property bool paused: settings.paused === true || settings.paused === "true"
    readonly property string position: (settings.position && settings.position.length > 0) ? settings.position : "bottom-center"
    readonly property int margin: (settings.margin !== undefined && settings.margin !== null) ? Number(settings.margin) : 67
    readonly property int lingerMs: (settings.lingerMs !== undefined && settings.lingerMs !== null) ? Number(settings.lingerMs) : 1000
    readonly property int historyCount: (settings.historyCount !== undefined && settings.historyCount !== null) ? Math.max(1, Math.min(5, Number(settings.historyCount))) : 1

    // Key History State
    // entries: array of { keys: string[], releasedAt: number }
    property var entries: []
    readonly property bool hasKeys: entries.length > 0 && !paused

    readonly property string _shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string _placeScript: (_shellDir && _shellDir.length > 0)
        ? _shellDir + "/quickshell/plugins/ryoku-plugins-place"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/ryoku-plugins-place"

    readonly property string statePath: {
        var rt = Quickshell.env("XDG_RUNTIME_DIR");
        return (rt && rt.length > 0 ? rt : "/tmp") + "/ryoku-key-visualizer.json";
    }

    //  Settings Mutation 
    Process { id: settingsProc }

    function setSetting(key, value) {
        var obj = {};
        obj[key] = value;
        settingsProc.running = false;
        settingsProc.command = [root._placeScript, "key-visualizer", "settings", JSON.stringify(obj)];
        settingsProc.running = true;
    }

    function togglePaused() {
        setSetting("paused", !root.paused);
    }

    function setPaused(p) {
        setSetting("paused", !!p);
    }

    //  Layout measurements 
    readonly property int cardPad: 10
    readonly property int chipGap: 8
    readonly property int entryGap: 6
    readonly property int chipPadX: 10
    readonly property int chipPadY: 5
    readonly property int chipHeight: Math.ceil(chipFontMetrics.height) + 2 * chipPadY
    readonly property var modMap: ({ "Super": true, "Ctrl": true, "Alt": true, "Shift": true, "Menu": true, "AltGr": true })

    FontMetrics { id: chipFontMetrics; font: chipFont }
    readonly property font chipFont: Qt.font({
        family: Theme.mono || "JetBrainsMono Nerd Font",
        pixelSize: 13,
        bold: true
    })

    function chipWidth(label) {
        return Math.ceil(chipFontMetrics.advanceWidth(String(label))) + 2 * chipPadX;
    }

    function rowWidth(keys) {
        if (!keys) return 0;
        var w = 0;
        for (var i = 0; i < keys.length; i++)
            w += chipWidth(keys[i]);
        return w + Math.max(0, keys.length - 1) * chipGap;
    }

    function contentWidth() {
        var w = 0;
        for (var i = 0; i < root.entries.length; i++)
            w = Math.max(w, rowWidth(root.entries[i].keys));
        return Math.max(w, 80);
    }

    function contentHeight() {
        var len = root.entries.length;
        if (len === 0) return 0;
        return len * root.chipHeight + (len - 1) * root.entryGap;
    }

    function entryOpacity(pos) {
        return Math.max(0.25, 1 - pos * 0.22);
    }

    function sameKeys(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        for (var i = 0; i < a.length; i++)
            if (a[i] !== b[i]) return false;
        return true;
    }

    function isSuperset(base, next) {
        if (!base || !next || next.length <= base.length) return false;
        for (var i = 0; i < base.length; i++)
            if (next.indexOf(base[i]) === -1) return false;
        return true;
    }

    function displayModel() {
        var list = [];
        var n = root.entries.length;
        if (root.position.indexOf("bottom") !== -1) {
            for (var i = n - 1; i >= 0; i--)
                list.push({ entry: root.entries[i], pos: i });
        } else {
            for (var j = 0; j < n; j++)
                list.push({ entry: root.entries[j], pos: j });
        }
        return list;
    }

    //  Key State Ingestion 
    property string _lastRaw: ""

    function applyState(rawText) {
        if (rawText === root._lastRaw) return;
        root._lastRaw = rawText;

        if (root.paused) {
            if (root.entries.length > 0) root.entries = [];
            return;
        }

        var next = [];
        try {
            var parsed = JSON.parse(rawText || "{}");
            if (parsed && Array.isArray(parsed.keys))
                next = parsed.keys;
        } catch (e) {
            return;
        }

        var es = root.entries;
        if (next.length === 0) {
            // Keys released: mark top entry with release timestamp
            if (es.length > 0 && es[0].releasedAt === 0) {
                var updated = es.slice();
                updated[0] = { keys: es[0].keys, releasedAt: Date.now() };
                root.entries = updated;
            }
        } else if (es.length > 0 && sameKeys(es[0].keys, next)) {
            if (es[0].releasedAt !== 0) {
                var refreshed = es.slice();
                refreshed[0] = { keys: es[0].keys, releasedAt: 0 };
                root.entries = refreshed;
            }
        } else if (es.length > 0 && es[0].releasedAt === 0 && isSuperset(es[0].keys, next)) {
            // Chord is growing while held
            var grown = es.slice();
            grown[0] = { keys: next, releasedAt: 0 };
            root.entries = grown;
        } else {
            // Fresh combo pressed
            var newList = [];
            newList.push({ keys: next, releasedAt: 0 });
            var maxHist = root.historyCount;
            for (var k = 0; k < es.length && newList.length < maxHist; k++) {
                var prev = es[k];
                if (prev.releasedAt === 0)
                    newList.push({ keys: prev.keys, releasedAt: Date.now() });
                else
                    newList.push(prev);
            }
            root.entries = newList;
        }
    }

    // Prune entries exceeding lingerMs
    Timer {
        id: historyTick
        interval: 150
        repeat: true
        running: root.entries.length > 0
        onTriggered: {
            var now = Date.now();
            var limit = root.lingerMs;
            var kept = [];
            for (var i = 0; i < root.entries.length; i++) {
                var e = root.entries[i];
                if (e.releasedAt === 0 || limit <= 0 || (now - e.releasedAt < limit))
                    kept.push(e);
            }
            if (kept.length !== root.entries.length)
                root.entries = kept;
        }
    }

    onPausedChanged: if (root.paused) root.entries = []

    //  Single Lightweight State FileView
    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyState(text())
        onFileChanged: reload()
    }

    //  IPC Handler 
    IpcHandler {
        target: "key-visualizer"
        function ping(): string { return "ok"; }
        function state(): string { return root.hasKeys ? "open" : "closed"; }
        function paused(): string { return root.paused ? "true" : "false"; }
        function pause(): string { root.setPaused(true); return "ok"; }
        function resume(): string { root.setPaused(false); return "ok"; }
        function toggle(): string { root.togglePaused(); return "ok"; }
    }

    //  Lightweight Overlay PanelWindow
    PanelWindow {
        id: overlay
        visible: root.hasKeys
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        WlrLayershell.namespace: "key-visualizer"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        Item {
            id: stage
            anchors.fill: parent

            Rectangle {
                id: card
                width: root.cardPad * 2 + root.contentWidth()
                height: root.cardPad * 2 + root.contentHeight()
                radius: 8

                color: Qt.rgba(14 / 255, 12 / 255, 10 / 255, 0.88)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.14)

                x: {
                    if (root.position.indexOf("left") !== -1)
                        return root.margin;
                    if (root.position.indexOf("right") !== -1)
                        return stage.width - width - root.margin;
                    return Math.round((stage.width - width) / 2);
                }

                y: {
                    if (root.position.indexOf("top") !== -1)
                        return root.margin;
                    if (root.position.indexOf("bottom") !== -1)
                        return stage.height - height - root.margin;
                    return Math.round((stage.height - height) / 2);
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: root.cardPad
                    spacing: root.entryGap

                    Repeater {
                        model: root.displayModel()

                        delegate: Row {
                            id: rowDelegate
                            required property var modelData
                            spacing: root.chipGap
                            opacity: root.entryOpacity(modelData.pos)

                            x: {
                                if (root.position.indexOf("left") !== -1)
                                    return 0;
                                if (root.position.indexOf("right") !== -1)
                                    return parent.width - width;
                                return Math.round((parent.width - width) / 2);
                            }

                            Repeater {
                                model: rowDelegate.modelData.entry.keys

                                delegate: Rectangle {
                                    id: chip
                                    required property string modelData
                                    width: root.chipWidth(modelData)
                                    height: root.chipHeight
                                    radius: 5

                                    readonly property bool isMod: !!root.modMap[modelData]

                                    color: isMod
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                        : Qt.rgba(1, 1, 1, 0.08)

                                    border.width: 1
                                    border.color: isMod
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                                        : Qt.rgba(255, 255, 255, 0.22)

                                    Text {
                                        anchors.centerIn: parent
                                        text: chip.modelData
                                        font: root.chipFont
                                        color: chip.isMod ? Theme.accent : Theme.cream
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
