import QtQuick
import QtQuick.Controls
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons
import "components"

// The `content` for the emoji plugin: header, search, category chips, a live
// selection readout, and a pickable grid. One view for every host - the popout
// renders it at `full`, the desktop tile at `compact`. All state lives in the
// service (pluginApi.mainInstance); this file only reads it and forwards
// picks. The popout host pins the width to `widthBudget`; everything scales
// from it and from `s`. The surface floats on the host's popout blob, so the
// design here is one clean column of eyeliner type, a single inset grid well,
// and a hairline themed frame that recolours with the active theme.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    // ---- settings, read live from the persisted schema (guarded) ----
    function sval(key, def) {
        var s = pluginApi ? pluginApi.pluginSettings : null;
        var v = s ? s[key] : undefined;
        return (v === undefined || v === null || v === "") ? def : v;
    }
    function sbool(key, def) {
        var v = root.sval(key, def);
        if (typeof v === "boolean") return v;
        return v === "true" ? true : (v === "false" ? false : !!def);
    }
    function sclamp(value, lo, hi, def) {
        var n = Number(value);
        if (isNaN(n)) n = def;
        return Math.max(lo, Math.min(hi, Math.floor(n)));
    }

    readonly property int columns: root.sclamp(root.sval("columns", 8), 4, 16, 8)
    readonly property int rows: root.sclamp(root.sval("rows", 5), 2, 10, 5)
    readonly property real cellMin: root.sclamp(root.sval("cellSize", 44), 24, 72, 44)
    readonly property bool showChips: root.sbool("showGroupChips", true)
    readonly property bool showHint: root.sbool("showHint", true)
    readonly property bool resetOnOpen: root.sbool("resetOnOpen", true)

    // ---- grid selection ----
    property int sel: 0
    readonly property var selected: root.service && root.service.results.length > 0
        ? root.service.results[Math.min(root.sel, root.service.results.length - 1)] : null
    readonly property int resultCount: root.service ? root.service.results.length : 0
    readonly property int totalCount: root.service ? root.service.flat.length : 0

    function clampSel(v) {
        if (!root.service || root.service.results.length === 0) return 0;
        return Math.max(0, Math.min(root.service.results.length - 1, v));
    }
    function moveSel(d) { if (!root.resultCount) { root.sel = 0; return; } root.sel = root.clampSel(root.sel + d); root.posView(); }
    function stepHoriz(dir) {
        if (!root.resultCount) return;
        var c = root.cols;
        var cur = root.sel;
        var last = root.resultCount - 1;
        var col = cur % c;
        var row = Math.floor(cur / c);
        var rowEnd = Math.min(row * c + c - 1, last);
        // continuous flow: right past a row's end wraps to the next row's
        // first cell, left past the start wraps to the previous row's last
        // cell. The grid auto-scrolls to keep the selection visible.
        if (dir > 0) {
            if (col === c - 1 || cur === rowEnd) {
                var nx = row * c + c;
                root.sel = root.clampSel(nx <= last ? nx : cur);
            } else {
                root.sel = root.clampSel(cur + 1);
            }
        } else {
            if (col === 0) {
                var pv = row * c - 1;
                root.sel = root.clampSel(pv >= 0 ? pv : cur);
            } else {
                root.sel = root.clampSel(cur - 1);
            }
        }
        root.posView();
    }
    function pageMove(dir) {
        // a page = every fully visible ROW of cells. moveSel() steps items,
        // so the visible row count must be scaled by the grid's column count
        // or PgUp/PgDn crawl a few cells instead of flipping a page.
        var rowsVisible = Math.max(1, Math.floor(root.gridH / (root.cell + root.gap)));
        root.moveSel(dir * rowsVisible * root.cols);
    }
    function homeSel() { if (root.resultCount) root.sel = 0; root.posView(); }
    function endSel() { if (root.resultCount) root.sel = root.resultCount - 1; root.posView(); }
    function posView() {
        if (grid && root.resultCount)
            Qt.callLater(function () { grid.positionViewAtIndex(root.sel, GridView.VisiblePosition); });
    }
    function pickSel() { if (root.selected) root.service.pick(root.selected.e); }

    Connections {
        target: root.service ? root.service : null
        function onResultsChanged() { root.sel = 0; root.posView(); }
    }

    // ---- geometry ----
    readonly property real contentW: density === "glyph" ? 26 * s
        : (widthBudget > 0 ? widthBudget : (density === "full" ? 360 * s : 300 * s))
    readonly property real padA: 14 * s                     // panel padding rhythm
    readonly property real innerW: root.contentW - 2 * root.padA
    readonly property real gap: 6 * s
    readonly property real gridMargin: 8 * s
    readonly property real usableW: root.innerW - 2 * root.gridMargin
    // The cell is derived so that EXACTLY `columns` of them fill the grid
    // (cell + gap == usableW / columns). Nav then steps by `columns` and lands
    // on the same column one row down - no rounding, no drift, no diagonal.
    readonly property real cell: Math.min(root.cellMin * s,
        Math.max(8 * s, root.usableW / root.columns - root.gap))
    readonly property int cols: (root.cell <= root.usableW / root.columns - root.gap + 0.001)
        ? root.columns
        : Math.max(1, Math.floor((root.usableW + root.gap) / (root.cell + root.gap)))
    readonly property real maxScreenH: density === "full" && screen && screen.height > 0 ? screen.height * 0.92 * s : 0
    // The well is the rows the user asked for PLUS the grid's own inner
    // margins (GridView anchors.margins below), or the last row clips.
    readonly property real gridH: Math.min(root.rows * (root.cell + root.gap) + 2 * root.gridMargin,
        maxScreenH > 0 ? maxScreenH : 560 * s)
    readonly property bool popout: density === "full"

    implicitWidth: contentW
    implicitHeight: density === "glyph" ? 26 * s : col.y + col.implicitHeight + root.padA

    GlyphIcon {
        visible: root.density === "glyph"
        anchors.fill: parent
        name: "extension"
        color: Theme.iconDim
        stroke: 1.6
    }

    // ── themed frame: a hairline border + accent-tinted bed that recolours
    // live with the active theme, so the popout reads as a framed panel.
    Rectangle {
        visible: root.popout
        anchors.fill: parent
        radius: Motion.rSmall * 1.2 * root.s
        color: Theme.frameBg
        border.width: 1 * root.s
        border.color: Theme.frameBorder
    }

    Column {
        id: col
        visible: root.density !== "glyph"
        x: root.padA
        y: root.padA
        width: root.innerW
        spacing: 11 * root.s

        // ── header: identity eyebrow ──
        Row {
            visible: root.popout
            width: root.innerW
            height: 14 * root.s
            spacing: 8 * root.s
            Rectangle {
                width: 4.5 * root.s
                height: 4.5 * root.s
                radius: 1.5 * root.s
                color: Theme.brand
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Emoji")
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 3 * root.s
                font.capitalization: Font.AllUppercase
            }
        }

        // ── search with a focus underline ──
        Item {
            width: root.innerW
            height: 36 * root.s
            SearchField {
                id: search
                anchors.fill: parent
                s: root.s
                kanji: "$"
                placeholder: qsTr("Search emoji\u2026")
                text: root.service ? root.service.query : ""
                onTextChanged: if (root.service) root.service.setQuery(text)
                onAccepted: root.pickSel()
                onDismissed: {
                    if (root.service) {
                        if (root.resultCount === root.totalCount && root.service.query === "")
                            root.service.close();
                        else
                            root.service.setQuery("");
                    }
                }
                // All navigation happens here and every arrow is accepted so
                // nothing else (the caret, the grid, a popup) also reacts -
                // an arrow ONLY moves the selection. Left/right step a single
                // cell and clamp/wrap at row ends. Up/down arrive through
                // SearchField's "moved" signal: its Keys.onUp/onDownPressed
                // handlers consume those keys BEFORE the generic pressed ever
                // fires, so onKeyPressed never sees them - scale by the grid's
                // real column count here to land in the same column one row
                // away.
                onMoved: root.moveSel(delta * root.cols)
                onKeyPressed: function (event) {
                    var k = event.key;
                    if (k === Qt.Key_Left) { root.stepHoriz(-1); event.accepted = true; }
                    else if (k === Qt.Key_Right) { root.stepHoriz(1); event.accepted = true; }
                    else if (k === Qt.Key_PageUp) { root.pageMove(-1); event.accepted = true; }
                    else if (k === Qt.Key_PageDown) { root.pageMove(1); event.accepted = true; }
                    else if (k === Qt.Key_Home) { root.homeSel(); event.accepted = true; }
                    else if (k === Qt.Key_End) { root.endSel(); event.accepted = true; }
                }
            }
            // the field floats on the surface; focus is drawn as a hairline
            // that lights up with the accent, not a box.
            Rectangle {
                width: parent.width
                height: 1 * root.s
                anchors.bottom: parent.bottom
                color: search.input && search.input.activeFocus ? Qt.alpha(Theme.brand, 0.7) : Theme.hair
                radius: 1 * root.s
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }

        // ── category chips: All + the emoji groups, wheel-scrollable ──
        Flickable {
            visible: root.showChips
            width: root.innerW
            height: root.showChips ? chipRow.implicitHeight : 0
            contentWidth: chipRow.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: chipRow
                spacing: 6 * root.s
                Repeater {
                    model: root.service ? root.service.groups : ["All"]
                    delegate: Chip {
                        label: modelData
                        count: root.service ? root.service.count(modelData) : 0
                        on: root.service && root.service.group === modelData
                        s: root.s
                        onPicked: if (root.service) root.service.setGroup(modelData)
                    }
                }
            }
        }

        // ── live readout of the highlighted emoji ──
        Item {
            visible: root.popout && root.showHint && root.resultCount > 0 && root.selected
            width: root.innerW
            height: 24 * root.s
            Text {
                id: selGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 24 * root.s
                text: root.selected ? root.selected.e : ""
                font.pixelSize: 16 * root.s
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                anchors.left: selGlyph.right
                anchors.leftMargin: 8 * root.s
                anchors.right: selCounter.left
                anchors.rightMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.selected ? root.selected.n : ""
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 11.5 * root.s
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                id: selCounter
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "%1/%2".arg(root.sel + 1).arg(root.resultCount)
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.features: { "tnum": 1 }
                verticalAlignment: Text.AlignVCenter
            }
        }

        // ── the grid well ──
        Item {
            width: root.innerW
            height: root.gridH
            Rectangle {
                anchors.fill: parent
                radius: Motion.rSmall * 1.2 * root.s
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.hair
                clip: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: root.gridMargin
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: root.cell + root.gap
                    cellHeight: root.cell + root.gap
                    model: root.service ? root.service.results : []
                    currentIndex: root.sel

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        visible: false   // drawn manually below so it never hides
                        interactive: false
                    }

                    delegate: Rectangle {
                        id: cell
                        required property int index
                        required property var modelData
                        readonly property bool selected: index === root.sel
                        readonly property bool hot: cellClick.containsMouse || cellClick.pressed
                        width: root.cell
                        height: root.cell
                        radius: Motion.rSmall * root.s
                        color: selected ? Qt.alpha(Theme.brand, 0.30)
                            : (hot ? Qt.alpha(Theme.brand, 0.14) : "transparent")
                        border.width: selected ? 1.5 * root.s : 1
                        border.color: selected ? Theme.brand : Theme.hair
                        scale: selected ? 1.06 : 1
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                        Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.e
                            // no forced render type: Text.QtRendering blanks
                            // CBDT color emoji (Noto Color Emoji), so let the
                            // platform default paint them.
                            font.pixelSize: Math.max(13 * root.s, Math.min(26 * root.s, root.cell * 0.5))
                        }

                        // pick action from settings, or force-copy on right-click.
                        // right-click is only taken in the popout (full density);
                        // the desktop tile leaves it to the host's grip menu.
                        MouseArea {
                            id: cellClick
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: root.popout
                                ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                if (!root.service) return;
                                if (mouse.button === Qt.RightButton)
                                    root.service.copyOnly(modelData.e);
                                else
                                    root.service.pick(modelData.e);
                            }
                        }
                    }

                    // scrollwheel over the grid nudges the selection, so a user
                    // who leaves the search box can keep driving by wheel.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: function (wheel) {
                            if (Math.abs(wheel.angleDelta.y) > 0)
                                root.moveSel(wheel.angleDelta.y < 0 ? 1 : -1);
                        }
                    }
                }

                // loading / empty states sit centred in the well.
                Text {
                    anchors.centerIn: parent
                    visible: !root.service || !root.service.loaded
                    text: qsTr("Loading catalogue\u2026")
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1.5
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.service && root.service.loaded && root.resultCount === 0
                    text: qsTr("No emoji found")
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 1.5
                }

                // the real scrollbar - drawn on the well's hairline margin so a
                // long grid always shows it exists. Track/height derived from
                // the grid's live content geometry each frame.
                Rectangle {
                    id: vbarTrack
                    visible: root.resultCount > 0 && grid.contentHeight > grid.height + 4 * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 3 * root.s
                    anchors.top: parent.top
                    anchors.topMargin: 4 * root.s
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4 * root.s
                    width: 3 * root.s
                    radius: 1.5 * root.s
                    color: "transparent"
                    Rectangle {
                        id: vbar
                        width: parent.width
                        radius: parent.radius
                        color: Qt.alpha(Theme.bright, 0.30)
                        height: {
                            var g = grid;
                            if (!g || g.contentHeight <= g.height) return 0;
                            return Math.max(20 * root.s, vbarTrack.height * (g.height / g.contentHeight));
                        }
                        y: {
                            var g = grid;
                            if (!g || g.contentHeight <= g.height) return 0;
                            return (g.contentY / (g.contentHeight - g.height)) * (vbarTrack.height - height);
                        }
                    }
                }
            }
        }

        // ── footer status bar ──
        Rectangle {
            visible: root.popout && root.showHint
            width: root.innerW
            height: 1 * root.s
            color: Theme.hair
        }
        Item {
            visible: root.popout && root.showHint
            width: root.innerW
            height: 16 * root.s
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.55
                text: {
                    if (!root.service) return ""
                    var mode = root.service.actionMode()
                    return mode === "insert"
                        ? qsTr("Enter types into the window behind")
                        : mode === "both"
                            ? qsTr("Enter copies and types behind")
                            : qsTr("Enter copies to clipboard")
                }
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("\u2191\u2193\u2190\u2192 move  \u00b7  Esc clears, again closes")
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9.5 * root.s
                font.features: { "tnum": 1 }
                verticalAlignment: Text.AlignVCenter
            }
        }

        MicroLabel {
            visible: root.service && root.service.loadError !== ""
            label: qsTr("Emoji catalogue: %1").arg(root.service ? root.service.loadError : "")
            s: root.s
        }
    }

    // focus search as soon as the popout opens, so it is type-to-search
    // immediately. resetOnOpen clears the query AND the group, so a category
    // picked last time can never leave the next open staring at an empty set.
    onActiveChanged: {
        if (active && root.popout && search.input) {
            if (root.resetOnOpen && root.service)
                root.service.clearQuery();
            Qt.callLater(() => search.input.forceActiveFocus());
        }
    }
}