import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi
    property var flat: []
    property var groups: ["All"]
    property string query: ""
    property string group: "All"
    property var results: []
    property bool loaded: false
    property string loadError: ""

    // "copy" (clipboard only) | "insert" (type into the window behind) |
    // "both" (clipboard + type). Read fresh on every call so a setting change
    // while the service is alive is picked up immediately.
    function normalizeAction(mode) {
        return (mode === "insert" || mode === "both") ? mode : "copy";
    }
    function actionMode() { return root.normalizeAction(setting("action", "copy")); }
    function needsWindow(mode) { return mode === "insert" || mode === "both"; }

    function setting(k, def) {
        var s = pluginApi ? pluginApi.pluginSettings : null;
        if (!s || s[k] === undefined || s[k] === null || s[k] === "") return def;
        return s[k];
    }
    function boolSetting(k, def) {
        var v = setting(k, def);
        if (typeof v === "boolean") return v;
        return v === "true" ? true : (v === "false" ? false : !!def);
    }

    // The host assigns pluginApi after construction (PluginObjectSlot.configure),
    // so the catalogue load has to wait for it.
    onPluginApiChanged: if (pluginApi) root.load()

    function load() {
        var dir = pluginApi ? pluginApi.pluginDir : "";
        if (!dir) return;
        catalog.path = dir + "/data/emojis.json";
    }
    FileView {
        id: catalog
        path: ""
        onLoaded: root.digest(text())
    }

    function digest(raw) {
        try {
            var parsed = JSON.parse(raw);
            var out = [];
            var names = ["All"];
            parsed.groups.forEach(function (g) {
                names.push(g.g);
                g.subs.forEach(function (sub) {
                    sub.l.forEach(function (item) {
                        out.push({ e: item.e, n: item.n, g: g.g });
                    });
                });
            });
            root.groups = names;
            root.flat = out;
            root.loaded = true;
            root.apply();
        } catch (e) {
            root.loadError = "parse: " + e;
        }
    }

    function count(name) {
        if (!name || name === "All") return root.flat.length;
        var n = 0, i;
        for (i = 0; i < root.flat.length; i++) if (root.flat[i].g === name) n++;
        return n;
    }

    function apply() {
        var q = root.query.toLowerCase().trim();
        var gr = root.group;
        var res = [];
        var src = root.flat;
        var i, it;
        for (i = 0; i < src.length; i++) {
            it = src[i];
            if (gr !== "All" && it.g !== gr) continue;
            if (q.length > 0) {
                if ((it.e.indexOf(q) >= 0) || (it.n.indexOf(q) >= 0)) res.push(it);
            } else {
                res.push(it);
            }
        }
        root.results = res;
    }

    function setQuery(q) { root.query = q; root.apply(); }
    function setGroup(g) { root.group = g; root.apply(); }

    // Where the popout sits is entirely the host's: the Hub's drag editor (and
    // the shell's own defaults framePopout block) write edges/align straight
    // into plugins.json, and PluginPopouts re-positions on every change. The
    // plugin never overrides it, so the drag editor stays the single source of
    // truth and there is no second, conflicting placement control.

    function close() { closeProc.running = true; }
    function clearQuery() { root.query = ""; root.group = "All"; root.apply(); }

    function act(mode, emoji) {
        var dir = pluginApi ? pluginApi.pluginDir : "";
        if (!dir) return;
        actProc.command = [dir + "/bin/ryoku-emoji", mode, emoji];
        actProc.running = true;
    }
    Process {
        id: actProc
        stderr: StdioCollector { onStreamFinished: if (text.trim().length > 0) console.warn("emoji: " + text.trim()) }
    }

    function pick(emoji) {
        var mode = root.actionMode();
        if (root.needsWindow(mode)) {
            // Typing must land in whatever window the user was in BEFORE the
            // popout took focus. Close the popout first, let the compositor
            // hand focus back, then type into the now-focused window.
            root._pendingEmoji = emoji;
            root._pendingMode = mode;
            root.close();
        } else {
            root.act(mode, emoji);
            // manifest default: keep the popout open after a plain copy so
            // users can pick several emojis in a row.
            if (root.boolSetting("closeAfterPick", false)) root.close();
        }
    }
    function copyOnly(emoji) { root.act("copy", emoji); }

    property string _pendingEmoji: ""
    property string _pendingMode: ""
    Timer {
        id: insertTimer
        interval: 220
        onTriggered: {
            if (root._pendingMode !== "") {
                root.act(root._pendingMode, root._pendingEmoji);
                root._pendingEmoji = "";
                root._pendingMode = "";
            }
        }
    }

    Process {
        id: closeProc
        command: ["ryoku-shell", "plugin", "emoji"]
        onExited: if (root._pendingMode !== "") insertTimer.start()
    }
}