pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    property var cards: []
    property int connectedCount: cards.length
    property bool busy: listProc.running || setProc.running
    property string lastError: ""

    property string primaryCodec: ""
    property string primaryDeviceName: ""
    property string primaryProfileLabel: ""

    function formatProfileLabel(name, desc) {
        var k = String(name || "").toLowerCase();
        var d = String(desc || "");
        if (k === "off") return "Audio Off";

        var codec = "";
        if (k.indexOf("sbc_xq") >= 0 || /sbc-xq/i.test(d)) codec = "SBC-XQ";
        else if (k.indexOf("sbc") >= 0 || /codec sbc\b/i.test(d)) codec = "SBC";
        else if (k.indexOf("aac") >= 0 || /codec aac\b/i.test(d) || (k === "a2dp-sink" && /aac/i.test(d))) codec = "AAC";
        else if (k.indexOf("ldac") >= 0 || /ldac/i.test(d)) codec = "LDAC";
        else if (k.indexOf("aptx_hd") >= 0 || /aptx-hd/i.test(d)) codec = "aptX HD";
        else if (k.indexOf("aptx_ll") >= 0 || /aptx-ll/i.test(d)) codec = "aptX LL";
        else if (k.indexOf("aptx") >= 0 || /aptx/i.test(d)) codec = "aptX";
        else if (k.indexOf("opus") >= 0 || /opus/i.test(d)) codec = "Opus";
        else if (k.indexOf("lc3") >= 0 || /lc3/i.test(d)) codec = "LC3";

        if (k.indexOf("a2dp") >= 0) {
            return codec ? "High Fidelity (" + codec + ")" : "High Fidelity (A2DP)";
        }
        if (k.indexOf("headset") >= 0 || k.indexOf("hfp") >= 0 || k.indexOf("hsp") >= 0) {
            if (/msbc/i.test(k) || /msbc/i.test(d)) return "Headset (HFP mSBC)";
            if (/cvsd/i.test(k) || /cvsd/i.test(d)) return "Headset (HFP CVSD)";
            return "Headset / Mic (HSP/HFP)";
        }
        if (d && d !== "(null)" && d.length > 0) return d;
        return name;
    }

    function shortCodec(name, desc) {
        var k = String(name || "").toLowerCase();
        var d = String(desc || "");
        if (k === "off") return "OFF";
        if (k.indexOf("sbc_xq") >= 0 || /sbc-xq/i.test(d)) return "SBC-XQ";
        if (k.indexOf("sbc") >= 0 || /codec sbc\b/i.test(d)) return "SBC";
        if (k.indexOf("aac") >= 0 || /codec aac\b/i.test(d) || (k === "a2dp-sink" && /aac/i.test(d))) return "AAC";
        if (k.indexOf("ldac") >= 0 || /ldac/i.test(d)) return "LDAC";
        if (k.indexOf("aptx_hd") >= 0 || /aptx-hd/i.test(d)) return "aptX-HD";
        if (k.indexOf("aptx") >= 0 || /aptx/i.test(d)) return "aptX";
        if (k.indexOf("opus") >= 0 || /opus/i.test(d)) return "Opus";
        if (k.indexOf("lc3") >= 0 || /lc3/i.test(d)) return "LC3";
        if (k.indexOf("headset") >= 0 || k.indexOf("hfp") >= 0 || k.indexOf("hsp") >= 0) return "HFP";
        if (k.indexOf("a2dp") >= 0) return "A2DP";
        return "BT";
    }

    function profileGroup(name) {
        var k = String(name || "").toLowerCase();
        if (k === "off") return "off";
        if (k.indexOf("a2dp") >= 0) return "a2dp";
        if (k.indexOf("headset") >= 0 || k.indexOf("hfp") >= 0 || k.indexOf("hsp") >= 0) return "headset";
        return "other";
    }

    function refresh() {
        if (!listProc.running) {
            listProc.running = true;
        }
    }

    function setProfile(cardName, profileName) {
        if (!cardName || !profileName || setProc.running) return;
        svc.lastError = "";

        // Optimistic UI update
        var updatedList = [];
        for (var i = 0; i < svc.cards.length; i++) {
            var item = svc.cards[i];
            if (item.name === cardName) {
                var copy = Object.assign({}, item);
                copy.activeProfile = profileName;
                copy.activeProfileLabel = svc.formatProfileLabel(profileName, "");
                copy.activeShortCodec = svc.shortCodec(profileName, "");
                updatedList.push(copy);
            } else {
                updatedList.push(item);
            }
        }
        svc.cards = updatedList;
        if (updatedList.length > 0 && updatedList[0].name === cardName) {
            svc.primaryCodec = updatedList[0].activeShortCodec;
            svc.primaryProfileLabel = updatedList[0].activeProfileLabel;
        }

        setProc.command = ["pactl", "set-card-profile", cardName, profileName];
        setProc.running = true;
    }

    function parseCards(jsonText) {
        if (!jsonText || jsonText.trim() === "") return;
        var raw = [];
        try {
            raw = JSON.parse(jsonText);
        } catch (e) {
            return;
        }
        if (!Array.isArray(raw)) return;

        var result = [];
        var btVals = (Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : [];

        for (var i = 0; i < raw.length; i++) {
            var c = raw[i];
            if (!c) continue;
            var props = c.properties || {};
            var isBt = props["device.bus"] === "bluetooth" || (c.name && c.name.indexOf("bluez_card.") === 0);
            if (!isBt) continue;

            var mac = String(props["api.bluez5.address"] || props["device.string"] || "");
            var devName = String(props["device.description"] || props["device.alias"] || c.name || "Bluetooth Device");
            var activeProf = String(c.active_profile || "");

            // Look up battery and name from BlueZ if available
            var battStr = "";
            for (var b = 0; b < btVals.length; b++) {
                var bd = btVals[b];
                if (bd && bd.address && bd.address.toUpperCase() === mac.toUpperCase()) {
                    if (bd.name && bd.name.length > 0) devName = bd.name;
                    if (bd.batteryAvailable && bd.battery >= 0) {
                        battStr = Math.round(bd.battery * 100) + "%";
                    }
                    break;
                }
            }

            // Extract profiles
            var profObj = c.profiles || {};
            var profList = [];
            for (var pKey in profObj) {
                var pData = profObj[pKey];
                if (!pData) continue;
                if (pData.available === false) continue;
                profList.push({
                    name: pKey,
                    description: pData.description || "",
                    label: svc.formatProfileLabel(pKey, pData.description),
                    shortCodec: svc.shortCodec(pKey, pData.description),
                    priority: pData.priority || 0,
                    group: svc.profileGroup(pKey)
                });
            }

            // Sort profiles: A2DP first (by priority desc), then Headset, then Off
            profList.sort(function(p1, p2) {
                var gOrder = { "a2dp": 0, "headset": 1, "off": 2, "other": 3 };
                var g1 = gOrder[p1.group] !== undefined ? gOrder[p1.group] : 3;
                var g2 = gOrder[p2.group] !== undefined ? gOrder[p2.group] : 3;
                if (g1 !== g2) return g1 - g2;
                return (p2.priority || 0) - (p1.priority || 0);
            });

            var activeLabel = svc.formatProfileLabel(activeProf, profObj[activeProf] ? profObj[activeProf].description : "");
            var activeShort = svc.shortCodec(activeProf, profObj[activeProf] ? profObj[activeProf].description : "");

            // Quick switch target (if A2DP -> switch to headset; if headset -> switch to A2DP)
            var quickTarget = null;
            if (activeProf.indexOf("headset") >= 0 || activeProf.indexOf("hfp") >= 0) {
                for (var q = 0; q < profList.length; q++) {
                    if (profList[q].group === "a2dp") { quickTarget = profList[q]; break; }
                }
            } else {
                for (var q2 = 0; q2 < profList.length; q2++) {
                    if (profList[q2].group === "headset") { quickTarget = profList[q2]; break; }
                }
            }

            result.push({
                index: c.index,
                name: c.name,
                mac: mac,
                description: devName,
                activeProfile: activeProf,
                activeProfileLabel: activeLabel,
                activeShortCodec: activeShort,
                batteryText: battStr,
                profiles: profList,
                quickTarget: quickTarget
            });
        }

        svc.cards = result;
        if (result.length > 0) {
            svc.primaryCodec = result[0].activeShortCodec;
            svc.primaryDeviceName = result[0].description;
            svc.primaryProfileLabel = result[0].activeProfileLabel;
        } else {
            svc.primaryCodec = "";
            svc.primaryDeviceName = "";
            svc.primaryProfileLabel = "";
        }
    }

    Process {
        id: listProc
        command: ["pactl", "--format=json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: svc.parseCards(text)
        }
    }

    Process {
        id: setProc
        command: []
        onExited: function(code, status) {
            if (code !== 0) {
                svc.lastError = "Failed to switch profile (exit code " + code + ")";
            }
            debounceTimer.restart();
        }
    }

    Process {
        id: subscribeProc
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var l = String(line || "");
                if (l.indexOf("card") >= 0 || l.indexOf("Karte") >= 0 || l.indexOf("server") >= 0 || l.indexOf("Server") >= 0) {
                    debounceTimer.restart();
                }
            }
        }
    }

    Timer {
        id: debounceTimer
        interval: 150
        repeat: false
        onTriggered: svc.refresh()
    }

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: svc.refresh()
    }

    Component.onCompleted: svc.refresh()
}
