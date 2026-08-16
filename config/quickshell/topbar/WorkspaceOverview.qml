import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Wayland

// Workspace overview — Alt+Ctrl+Tab.
//
// Drops down from the top edge, out of the bar's workspace boxes, and shows
// every workspace side by side with the windows on it. Things you can do here
// that you cannot do from the bar:
//
//   * drag a window card onto another workspace to move it
//   * drop it *between* two of them to move it to a workspace that does not
//     exist yet — between 3 and 7 puts it on 4
//   * hover a card and press the X in its corner to close that window
//
// The panel is only as wide as it needs to be, up to the bar's own free span
// between the running cat and the media title; workspaces past that wrap onto
// a second row.
//
// The cards show live window contents. Quickshell 0.3.0 does have a screencopy
// binding — `ScreencopyView` — and a `HyprlandToplevel` carries the `wayland`
// handle it needs, so a window is captured through the compositor even when it
// sits on a workspace that is not on screen. Icon and title stay as the
// fallback for the moment before the first frame arrives.
//
// The window list comes straight from `Hyprland.workspaces`. Each workspace
// owns a live ObjectModel of its toplevels, and those objects keep their
// identity across updates — which is what makes dragging survivable. The old
// source (WindowSwitcherService) rebuilt a plain JS array on every refresh, so
// every card in the overview was destroyed and recreated a few times a second;
// a card picked up by the mouse was deleted out from under the drag.
PanelWindow {
    id: root

    property bool shown: false

    // ---------------- Drag state ----------------
    //
    // The card itself never leaves its column. What follows the cursor is
    // `ghost`, a single item owned by the panel. Nothing about the drag lives
    // on the delegate, so a card that gets destroyed mid-drag (its window
    // closed, its workspace went away) cannot take the drag down with it.

    /// Address of the window being dragged, "" when nothing is.
    property string dragAddress: ""
    /// Workspace the drag started on, so a drop back onto it is a no-op.
    property int dragSourceWorkspace: -1
    /// Where inside the card the cursor grabbed it, in grid coordinates.
    property point dragGrab: Qt.point(0, 0)

    /// Workspace id a drop would land on right now, -1 for none.
    property int hoverWorkspace: -1
    /// True when that workspace is one that does not exist yet, because the
    /// cursor is between two columns with a number free between them.
    property bool hoverIsGap: false
    property real hoverGapX: 0
    property real hoverGapY: 0

    readonly property string dispatch: "hyprctl"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    // Only Ignore — assigning exclusiveZone would push the window down by the
    // bar's own zone (gotcha #19).
    exclusionMode: ExclusionMode.Ignore
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---------------- Data ----------------

    /// The columns the panel is laid out from — a snapshot of `liveColumns`,
    /// resynced whenever that changes and the mouse is empty.
    ///
    /// It has to be a snapshot. `liveColumns` is a fresh JS array every time it
    /// is evaluated, so the Repeater on it throws away every column delegate
    /// and builds new ones — including the card under the cursor — and it
    /// re-evaluates on any workspace change at all, which during a drag means
    /// several times a second. That is what used to make a dragged window
    /// disappear: not the drop, the rebuild underneath it. Freezing for the
    /// length of the drag also keeps the grid from reshuffling under a card
    /// that is already in the air.
    property var columns: []

    /// Non-special workspaces, in id order, plus one empty slot on the end so
    /// there is always somewhere to drop a window that should get a workspace
    /// of its own. Hyprland only reports workspaces that exist, so without the
    /// spare slot you could never drag a window *out* to a fresh one.
    readonly property var liveColumns: {
        const out = []
        const list = Hyprland.workspaces.values
        for (let i = 0; i < list.length; i++) {
            const ws = list[i]
            const name = String(ws.name || "")
            if (name.startsWith("special"))
                continue
            out.push({ id: ws.id, name: name, active: ws.active, spare: false, ws: ws })
        }
        out.sort((a, b) => a.id - b.id)

        let next = 1
        for (let i = 0; i < out.length; i++)
            next = Math.max(next, out[i].id + 1)
        out.push({ id: next, name: String(next), active: false, spare: true, ws: null })
        return out
    }

    onLiveColumnsChanged: root.syncColumns()
    Component.onCompleted: root.syncColumns()

    function syncColumns() {
        if (root.dragAddress !== "")
            return
        root.columns = root.liveColumns
    }

    // ---------------- Geometry ----------------
    //
    // One cell per workspace. The panel is sized from the cells, not the other
    // way round: it is only ever as wide as it needs to be, and never wider
    // than the bar's own free span — the gap between the running cat on the
    // left and the media title on the right. Workspaces past that wrap onto a
    // second row.

    readonly property int cellWidth: 182
    readonly property int cellHeight: 162
    readonly property int cellSpacing: 8
    readonly property int panelPadding: 12
    /// Name and window count, and the cards start under them.
    readonly property int headerHeight: 40

    readonly property int maxPanelWidth: Math.round(root.width * 0.52)

    readonly property int perRow: {
        const fits = Math.floor((root.maxPanelWidth - 2 * root.panelPadding + root.cellSpacing)
                                / (root.cellWidth + root.cellSpacing))
        return Math.max(1, Math.min(root.columns.length, fits))
    }

    readonly property int rowCount: Math.max(1, Math.ceil(root.columns.length / root.perRow))

    readonly property int panelWidth: 2 * root.panelPadding + root.perRow * root.cellWidth
                                      + (root.perRow - 1) * root.cellSpacing
    readonly property int panelHeight: 2 * root.panelPadding + root.rowCount * root.cellHeight
                                       + (root.rowCount - 1) * root.cellSpacing

    function columnsInRow(row) {
        return Math.min(root.perRow, Math.max(0, root.columns.length - row * root.perRow))
    }

    // cellX/cellY place the columns and columnAt reads them back. Both sides of
    // the drag use the same three functions, so a card can never be dropped
    // somewhere the layout does not agree with.
    function cellX(i) {
        const row = Math.floor(i / root.perRow)
        const n = root.columnsInRow(row)
        const rowWidth = n * root.cellWidth + (n - 1) * root.cellSpacing
        const gridWidth = root.perRow * root.cellWidth + (root.perRow - 1) * root.cellSpacing
        // A short last row sits centred under the full ones above it.
        return Math.round((gridWidth - rowWidth) / 2)
               + (i % root.perRow) * (root.cellWidth + root.cellSpacing)
    }

    function cellY(i) {
        return Math.floor(i / root.perRow) * (root.cellHeight + root.cellSpacing)
    }

    /// Index of the column under a point in `grid` coordinates, -1 for none —
    /// the gutters between cells included.
    function columnAt(x, y) {
        for (let i = 0; i < root.columns.length; i++) {
            const cx = root.cellX(i)
            const cy = root.cellY(i)
            if (x >= cx && x < cx + root.cellWidth && y >= cy && y < cy + root.cellHeight)
                return i
        }
        return -1
    }

    /// How far either side of a border between two columns still counts as
    /// "between them" rather than "on one of them".
    readonly property int gapZone: 22

    /// Where a drop at this point would put the window.
    ///
    ///   { ws: -1 }                      nowhere — the drop is a no-op
    ///   { ws: n }                       onto the workspace that column shows
    ///   { ws: n, gap: true, x, y }      onto workspace n, which does not exist
    ///                                   yet: the point is between two columns
    ///                                   with room between their numbers, so
    ///                                   dropping between 3 and 7 lands on 4
    ///
    /// Hyprland creates a workspace the moment a window is moved to it, so the
    /// gap case needs nothing else from us.
    function dropTargetAt(x, y) {
        const none = { ws: -1, gap: false, x: 0, y: 0 }

        const row = Math.floor(y / (root.cellHeight + root.cellSpacing))
        if (row < 0 || row >= root.rowCount)
            return none

        const rowY = row * (root.cellHeight + root.cellSpacing)
        if (y < rowY || y >= rowY + root.cellHeight)
            return none // in the gutter between two rows

        const first = row * root.perRow
        const last = first + root.columnsInRow(row) - 1

        // Well inside a cell: that column, no argument.
        for (let i = first; i <= last; i++) {
            const cx = root.cellX(i)
            if (x >= cx + root.gapZone && x < cx + root.cellWidth - root.gapZone)
                return { ws: root.columns[i].id, gap: false, x: 0, y: 0 }
        }

        // Near a border between two columns.
        for (let i = first; i < last; i++) {
            const border = (root.cellX(i) + root.cellWidth + root.cellX(i + 1)) / 2
            if (Math.abs(x - border) > root.gapZone + root.cellSpacing)
                continue

            const missing = root.columns[i].id + 1
            if (missing < root.columns[i + 1].id)
                return { ws: missing, gap: true, x: border, y: rowY }

            // 3 and 4 sit next to each other — there is nothing to put between
            // them, so the drop goes to whichever of the two is nearer. Landing
            // in the eight pixels of gutter should not throw the drag away.
            const near = x < border ? i : i + 1
            return { ws: root.columns[near].id, gap: false, x: 0, y: 0 }
        }

        // The outer edges of a cell, and the margins at the ends of a row.
        const i = root.columnAt(x, y)
        return i >= 0 ? { ws: root.columns[i].id, gap: false, x: 0, y: 0 } : none
    }

    /// hyprctl reports addresses without the 0x, the dispatchers want it.
    function addressOf(toplevel) {
        if (!toplevel || !toplevel.address)
            return ""
        const s = String(toplevel.address)
        return s.startsWith("0x") ? s : "0x" + s
    }

    // ---------------- Actions ----------------

    /// Move a window to a workspace. Targets by address so the window does not
    /// have to be focused, and `follow = false` keeps the view where it is —
    /// without it the dispatcher drags the monitor along to the workspace the
    /// window landed on, which is not what dropping a card in an overview
    /// should ever do.
    function moveWindow(address, workspaceId) {
        Quickshell.execDetached([root.dispatch, "dispatch",
            "hl.dsp.window.move({ workspace = " + workspaceId
            + ", window = \"address:" + address + "\", follow = false })"])
    }

    function closeWindow(address) {
        Quickshell.execDetached([root.dispatch, "dispatch",
            "hl.dsp.window.close({ window = \"address:" + address + "\" })"])
    }

    function focusWindow(address) {
        Quickshell.execDetached([root.dispatch, "dispatch",
            "hl.dsp.focus({ window = \"address:" + address + "\" })"])
        root.close()
    }

    // ---------------- Drag ----------------

    function beginDrag(item, address, workspaceId, appId, title, origin) {
        const at = item.mapToItem(grid, 0, 0)

        // The ghost is a label, not a copy of the card: a card from a column
        // with four windows in it is 82px wide and would carry an unreadable
        // one.
        ghost.width = Math.max(150, item.width)
        ghost.height = 44
        ghost.appId = appId
        ghost.title = title

        // Hold it where it was picked up, proportionally, so the cursor stays
        // on the same part of the thing it grabbed.
        root.dragGrab = Qt.point((origin.x - at.x) / Math.max(1, item.width) * ghost.width,
                                 (origin.y - at.y) / Math.max(1, item.height) * ghost.height)
        root.dragSourceWorkspace = workspaceId
        root.dragAddress = address
        root.updateDrag(origin)
    }

    function updateDrag(point) {
        if (root.dragAddress === "")
            return
        ghost.x = point.x - root.dragGrab.x
        ghost.y = point.y - root.dragGrab.y

        const target = root.dropTargetAt(point.x, point.y)
        root.hoverWorkspace = target.ws
        root.hoverIsGap = target.gap
        root.hoverGapX = target.x
        root.hoverGapY = target.y
    }

    function endDrag(point) {
        if (root.dragAddress === "")
            return
        const address = root.dragAddress
        const source = root.dragSourceWorkspace
        const target = root.dropTargetAt(point.x, point.y)

        // Dropped between two rows, on a header, or off the panel entirely: the
        // card goes home and nothing is dispatched. Dropped back on the
        // workspace it came from: also nothing — moving a window to the
        // workspace it is already on is a real move to Hyprland and used to
        // yank the view across with it.
        if (target.ws >= 0 && target.ws !== source)
            root.moveWindow(address, target.ws)

        root.cancelDrag()
    }

    function cancelDrag() {
        root.dragAddress = ""
        root.dragSourceWorkspace = -1
        root.hoverWorkspace = -1
        root.hoverIsGap = false
        // Whatever the workspaces did while the drag was up, take it now.
        root.syncColumns()
    }

    // ---------------- Open / close ----------------

    function open() {
        root.cancelDrag()
        root.shown = true
    }

    function close() {
        root.cancelDrag()
        root.shown = false
    }

    function toggle() {
        if (root.shown)
            root.close()
        else
            root.open()
    }

    IpcHandler {
        target: "overview"

        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }
    }

    onShownChanged: {
        if (root.shown) {
            root.visible = true
            closeAnim.stop()
            openAnim.restart()
            keyCatcher.forceActiveFocus()
        } else if (root.visible) {
            openAnim.stop()
            closeAnim.restart()
        }
    }

    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Theme.crust
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // ---------------- Panel ----------------

    Rectangle {
        id: panel

        x: Math.round((root.width - root.panelWidth) / 2)

        // Drops down out of the bar. A hidden PanelWindow reports the wrong
        // height for the first few frames (gotcha #20), so the animation moves
        // a separate offset and leaves this binding alone.
        y: BarSettings.barHeight + BarSettings.floatGap + 8 + panel.offset

        property real offset: 0

        width: root.panelWidth
        height: root.panelHeight
        color: Theme.panelColor
        border.color: Theme.surface0
        border.width: Theme.borderWidth
        radius: Theme.radiusPanel

        opacity: 0

        GlossOverlay {
            anchors.fill: parent
            radius: panel.radius
            midline: 0.22
        }

        Item {
            id: grid

            x: root.panelPadding
            y: root.panelPadding
            width: panel.width - 2 * root.panelPadding
            height: panel.height - 2 * root.panelPadding

            Repeater {
                model: root.columns

                delegate: Rectangle {
                    id: column

                    required property int index
                    required property var modelData

                    readonly property var toplevels: modelData.ws ? modelData.ws.toplevels : null
                    readonly property int windowCount: column.toplevels ? column.toplevels.values.length : 0
                    readonly property bool isTarget: root.hoverWorkspace === modelData.id && !root.hoverIsGap

                    /// Cards tile the space under the header, so a workspace
                    /// with four windows on it takes up exactly as much room as
                    /// one with a single window. Two windows go side by side
                    /// rather than stacked: half a cell's width still leaves a
                    /// preview you can recognise, half its height does not.
                    readonly property int cardColumns: column.windowCount <= 1 ? 1
                                                     : (column.windowCount <= 4 ? 2 : 3)
                    readonly property int cardRows: Math.max(1, Math.ceil(column.windowCount / column.cardColumns))
                    readonly property real zoneWidth: root.cellWidth - 12
                    readonly property real zoneHeight: root.cellHeight - root.headerHeight - 6
                    readonly property real cardWidth: Math.floor((column.zoneWidth - (column.cardColumns - 1) * 6)
                                                                 / column.cardColumns)
                    readonly property real cardHeight: Math.floor((column.zoneHeight - (column.cardRows - 1) * 6)
                                                                  / column.cardRows)

                    x: root.cellX(index)
                    y: root.cellY(index)
                    width: root.cellWidth
                    height: root.cellHeight
                    radius: Theme.radius

                    color: {
                        if (column.isTarget)
                            return Theme.selected
                        if (modelData.spare)
                            return "transparent"
                        return modelData.active ? Theme.hover : "transparent"
                    }
                    border.color: {
                        if (column.isTarget)
                            return Theme.mauve
                        if (modelData.active)
                            return Theme.surface1
                        // The spare slot is drawn as an outline so it reads as
                        // "somewhere to put something", not as a workspace that
                        // already exists.
                        return modelData.spare ? Theme.surface0 : "transparent"
                    }
                    border.width: column.isTarget ? 2 : Theme.borderWidth

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    // Header
                    Text {
                        id: columnLabel

                        anchors.top: parent.top
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: column.modelData.spare ? "+ " + column.modelData.name
                                                     : column.modelData.name
                        color: {
                            if (column.modelData.spare)
                                return Theme.overlay0
                            return column.modelData.active ? Theme.mauve : Theme.text
                        }
                        font.pixelSize: 13
                        font.bold: column.modelData.active
                    }

                    Text {
                        anchors.top: columnLabel.bottom
                        anchors.topMargin: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: column.windowCount === 0
                              ? (column.modelData.spare ? "drop here" : "empty")
                              : column.windowCount + (column.windowCount === 1 ? " window" : " windows")
                        color: Theme.overlay0
                        font.pixelSize: 9
                    }

                    // Cards
                    Grid {
                        id: cardGrid

                        anchors.top: parent.top
                        anchors.topMargin: root.headerHeight
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: column.cardColumns
                        spacing: 6

                        Repeater {
                            model: column.toplevels

                            delegate: Item {
                                id: card

                                required property var modelData

                                readonly property string address: root.addressOf(card.modelData)
                                readonly property string appId: {
                                    if (card.modelData.wayland && card.modelData.wayland.appId)
                                        return String(card.modelData.wayland.appId)
                                    if (card.modelData.lastIpcObject && card.modelData.lastIpcObject.class)
                                        return String(card.modelData.lastIpcObject.class)
                                    return ""
                                }
                                readonly property string title: String(card.modelData.title || card.appId || "Untitled")
                                readonly property bool lifted: root.dragAddress === card.address
                                /// A card too narrow for a readable title keeps
                                /// the icon and drops the text; the preview
                                /// stays whatever the size.
                                readonly property bool showTitle: column.cardWidth >= 118
                                readonly property real labelHeight: Math.min(20, Math.max(13, column.cardHeight * 0.2))

                                width: column.cardWidth
                                height: column.cardHeight

                                opacity: card.lifted ? 0.35 : 1

                                Behavior on opacity {
                                    NumberAnimation { duration: 100 }
                                }

                                // A card that goes away mid-drag — its window
                                // closed, its workspace was folded up — must not
                                // leave the ghost hanging over the panel.
                                Component.onDestruction: {
                                    if (root.dragAddress === card.address)
                                        root.cancelDrag()
                                }

                                Rectangle {
                                    id: cardSurface

                                    anchors.fill: parent
                                    radius: Theme.radius
                                    color: cardArea.containsMouse ? Theme.surface0 : Theme.mantle
                                    border.color: cardArea.containsMouse ? Theme.surface1 : "transparent"
                                    border.width: cardArea.containsMouse ? Theme.borderWidth : 0
                                    clip: true

                                    // ---- preview ----
                                    Item {
                                        id: previewBox

                                        anchors.fill: parent
                                        anchors.bottomMargin: card.labelHeight
                                        clip: true

                                        // One frame per opening, not a live
                                        // feed: an overview of eight windows
                                        // would otherwise have eight capture
                                        // streams running at monitor rate for
                                        // as long as it is on screen.
                                        Connections {
                                            target: root

                                            function onShownChanged() {
                                                if (root.shown && preview.captureSource)
                                                    preview.captureFrame()
                                            }
                                        }

                                        Component.onCompleted: {
                                            if (root.shown && preview.captureSource)
                                                preview.captureFrame()
                                        }

                                        ScreencopyView {
                                            id: preview

                                            captureSource: card.modelData.wayland ? card.modelData.wayland : null
                                            live: false
                                            paintCursor: false

                                            // Aspect fit. The capture comes in
                                            // at the window's own size, which is
                                            // nothing like the card's shape.
                                            readonly property real scale: {
                                                const w = preview.sourceSize.width
                                                const h = preview.sourceSize.height
                                                if (w <= 0 || h <= 0)
                                                    return 0
                                                return Math.min(previewBox.width / w, previewBox.height / h)
                                            }

                                            anchors.centerIn: parent
                                            width: preview.sourceSize.width * preview.scale
                                            height: preview.sourceSize.height * preview.scale
                                            visible: preview.hasContent && preview.scale > 0
                                        }

                                        // Until the first frame lands — and for
                                        // anything with no wayland handle at all
                                        // — the icon stands in for the window.
                                        IconImage {
                                            anchors.centerIn: parent
                                            width: Math.min(32, previewBox.height - 8)
                                            height: width
                                            source: IconResolver.iconForApp(card.appId)
                                            visible: !preview.visible && status === Image.Ready
                                        }
                                    }

                                    // ---- label ----
                                    Item {
                                        id: labelRow

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: card.labelHeight

                                        Rectangle {
                                            anchors.fill: parent
                                            color: Theme.mantle
                                            opacity: 0.92
                                        }

                                        IconImage {
                                            id: cardIcon

                                            anchors.left: card.showTitle ? parent.left : undefined
                                            anchors.leftMargin: 5
                                            anchors.horizontalCenter: card.showTitle ? undefined
                                                                                     : parent.horizontalCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(16, parent.height - 4)
                                            height: width
                                            source: IconResolver.iconForApp(card.appId)
                                            visible: source != "" && status === Image.Ready
                                        }

                                        // Falls back to the first letter, the way
                                        // the bar's workspace boxes do when an app
                                        // has no icon (gotcha #8 — Qt's lookup is
                                        // broken here).
                                        Rectangle {
                                            anchors.fill: cardIcon
                                            visible: !cardIcon.visible
                                            radius: Theme.radiusUpTo(cardIcon.width)
                                            color: Theme.surface1

                                            Text {
                                                anchors.centerIn: parent
                                                text: (card.appId || "?").charAt(0).toUpperCase()
                                                color: Theme.text
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            anchors.left: cardIcon.right
                                            anchors.leftMargin: 5
                                            anchors.right: parent.right
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: card.showTitle
                                            text: card.title
                                            color: Theme.text
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cardArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    // The drag is driven from here rather than
                                    // through Drag/DropArea: the press has to be
                                    // followed to a release that may land
                                    // anywhere on the panel, and hit testing the
                                    // grid myself is the same three lines with
                                    // none of the attached-property lifetime.
                                    preventStealing: true
                                    cursorShape: card.lifted ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                    property point pressPoint
                                    property bool armed: false
                                    property bool moved: false

                                    onPressed: mouse => {
                                        cardArea.pressPoint = card.mapToItem(grid, mouse.x, mouse.y)
                                        cardArea.armed = true
                                        cardArea.moved = false
                                    }

                                    onPositionChanged: mouse => {
                                        if (!cardArea.armed)
                                            return
                                        const p = card.mapToItem(grid, mouse.x, mouse.y)
                                        if (!cardArea.moved) {
                                            const dx = p.x - cardArea.pressPoint.x
                                            const dy = p.y - cardArea.pressPoint.y
                                            // Same 6px slop the old drag.threshold
                                            // had — a click that shivers is still
                                            // a click.
                                            if (dx * dx + dy * dy < 36)
                                                return
                                            cardArea.moved = true
                                            root.beginDrag(card, card.address, column.modelData.id,
                                                           card.appId, card.title, cardArea.pressPoint)
                                        }
                                        root.updateDrag(p)
                                    }

                                    onReleased: mouse => {
                                        cardArea.armed = false
                                        if (cardArea.moved)
                                            root.endDrag(card.mapToItem(grid, mouse.x, mouse.y))
                                    }

                                    onCanceled: {
                                        cardArea.armed = false
                                        if (cardArea.moved)
                                            root.cancelDrag()
                                        cardArea.moved = false
                                    }

                                    onClicked: {
                                        if (!cardArea.moved)
                                            root.focusWindow(card.address)
                                    }
                                }

                                // Close button — only under the cursor, so the
                                // grid is not a wall of X's at rest.
                                Rectangle {
                                    id: closeButton

                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.rightMargin: 3
                                    anchors.topMargin: 3
                                    width: 18
                                    height: 18
                                    radius: Theme.radiusUpTo(18)
                                    color: closeArea.containsMouse ? Theme.red : Theme.surface1
                                    opacity: (cardArea.containsMouse || closeArea.containsMouse)
                                             && root.dragAddress === "" ? 1 : 0
                                    visible: opacity > 0 && card.height >= 26
                                    z: 5

                                    Behavior on opacity {
                                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.family: Theme.fontMono
                                        font.pixelSize: 9
                                        color: closeArea.containsMouse
                                               ? Theme.textOn(Theme.red) : Theme.subtext0
                                    }

                                    MouseArea {
                                        id: closeArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.closeWindow(card.address)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---- "put it between these two" ----
            //
            // Shown when the cursor sits between two columns whose numbers have
            // room between them. The workspace on it does not exist yet; the
            // drop is what creates it.
            Rectangle {
                id: gapMarker

                visible: root.dragAddress !== "" && root.hoverIsGap
                z: 150
                x: root.hoverGapX - width / 2
                y: root.hoverGapY
                width: 28
                height: root.cellHeight
                radius: Theme.radius
                color: Qt.rgba(Theme.mauve.r, Theme.mauve.g, Theme.mauve.b, 0.18)
                border.color: Theme.mauve
                border.width: 2

                // At the top, where the ghost — which sits under the cursor,
                // usually around the middle of a cell — does not cover it.
                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "+\n" + root.hoverWorkspace
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 0.9
                    color: Theme.mauve
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            // ---- the thing that actually follows the cursor ----
            Rectangle {
                id: ghost

                property string appId: ""
                property string title: ""

                visible: root.dragAddress !== ""
                z: 200
                radius: Theme.radius
                color: Theme.surface0
                border.color: Theme.mauve
                border.width: 1
                opacity: 0.92

                IconImage {
                    id: ghostIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    source: IconResolver.iconForApp(ghost.appId)
                    visible: source != "" && status === Image.Ready
                }

                Text {
                    anchors.left: ghostIcon.visible ? ghostIcon.right : parent.left
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: ghost.title
                    color: Theme.text
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.close()
    }

    // ---------------- Animation ----------------

    ParallelAnimation {
        id: openAnim

        NumberAnimation { target: backdrop; property: "opacity"; to: Theme.backdropOpacity(0.45); duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "offset"; from: -root.panelHeight; to: 0; duration: 300; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: Theme.backdropOpacity(0); duration: 130; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "offset"; to: -root.panelHeight; duration: 160; easing.type: Easing.InCubic }
        }

        ScriptAction {
            script: root.visible = false
        }
    }
}
