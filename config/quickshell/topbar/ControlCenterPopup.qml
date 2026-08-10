import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Control centre — opens under the running cat on the left of the bar.
//
// The cat was decoration; it is the only thing in the bar with room to be a
// button, so it became the handle for settings that otherwise live behind
// keybinds nobody remembers. The keybinds still work; this is a second way in.
//
// One box, several pages, morphing into each other the way the calendar's month
// grid turns into the note editor: the home page is a landscape grid of
// buttons, and pressing one *becomes* that page rather than opening a second
// window. `page` drives the cross-fade, the header swap and the height, so
// there is a single place that decides what is on screen.
//
// Colour is the odd one out: pressing it closes the panel, runs hyprpicker over
// the frozen screen, and qs-color reopens it on the colour page afterwards.
// Super+Alt+X runs the same script, so both routes behave identically.
//
// A layer surface, NOT a PopupWindow, and that is the whole reason the colour
// page used to go nowhere. An xdg_popup with `grabFocus` needs an input serial
// from its parent, so the compositor refuses it with "Failed to create grabbing
// popup … parent window has received input" whenever the bar has not just been
// clicked. Opening from a keybind never worked, and neither did the way back
// from hyprpicker — by then the last input belonged to hyprpicker's surface.
// The calendar already had the answer: a masked PanelWindow plus
// HyprlandFocusGrab, which needs no serial at all.
PanelWindow {
    id: root

    property bool shown: false

    // Where the running cat is, pushed in by LeftSection — the bar's left side
    // changes width with the focused-app name, so this cannot be a constant.
    property real anchorX: 12

    // Ignore the click right after an outside-click close, or pressing the cat
    // to dismiss the panel would close and immediately reopen it.
    property double lastCleared: 0

    readonly property int panelWidth: 440
    readonly property int contentWidth: root.panelWidth - 2 * 10

    // "" (home) | "appearance" | "system" | "topbar" | "phone" | "color"
    property string page: ""

    readonly property string pageTitle: {
        if (root.page === "appearance")
            return "Appearance"
        if (root.page === "system")
            return "System"
        if (root.page === "topbar")
            return "Top Bar"
        if (root.page === "phone")
            return "Phone"
        if (root.page === "color")
            return "Color Picker"
        return ""
    }

    anchors {
        top: true
        left: true
        right: true
    }

    // Fixed and generous: the panel inside is what resizes while morphing, and
    // the mask keeps the empty remainder click-through.
    implicitHeight: 640

    color: "transparent"
    focusable: true
    exclusiveZone: 0
    visible: false

    WlrLayershell.namespace: "quickshell-controlcenter"

    mask: Region {
        item: panel
    }

    function toggle() {
        if (!root.shown && Date.now() - root.lastCleared < 250)
            return
        root.shown = !root.shown
    }

    function close() {
        root.shown = false
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.shown

        onCleared: {
            root.lastCleared = Date.now()
            root.shown = false
        }
    }

    onShownChanged: {
        // The probed rows only poll while this is open. Each poll timer fires
        // on start, so there is no separate refresh here.
        SettingsService.polling = root.shown
        AdbService.polling = root.shown && root.page === "phone"

        if (root.shown) {
            // One shot on open so the Phone tile's caption is right without the
            // page being open — polling it the whole time would spawn an adb
            // process every two seconds for a caption.
            AdbService.refresh()

            root.visible = true
            closeAnim.stop()
            openAnim.restart()
            panel.forceActiveFocus()
        } else {
            root.page = ""
            phonePage.expanded = false
            phonePage.entering = false
            if (root.visible) {
                openAnim.stop()
                closeAnim.restart()
            }
        }
    }

    onPageChanged: {
        AdbService.polling = root.shown && root.page === "phone"
        if (root.page !== "phone") {
            phonePage.expanded = false
            phonePage.entering = false
        }
    }

    ParallelAnimation {
        id: openAnim

        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "y"; to: 0; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "y"; to: -8; duration: 110; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "scale"; to: 0.97; duration: 110; easing.type: Easing.InQuad }
        }

        // Unmap the surface once it has faded, not before — `shown` is already
        // false by now, this is the window itself going away.
        ScriptAction {
            script: root.visible = false
        }
    }

    //   qs -c topbar ipc call controlCenter toggle
    //
    // `color` is how qs-color hands the pick back: quickshell 0.3 `ipc call`
    // rejects arguments, so the colour itself travels through colors.json and
    // this only has to say which page to land on.
    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            root.toggle()
        }

        function open(): void {
            root.shown = true
        }

        function close(): void {
            root.shown = false
        }

        function color(): void {
            root.page = "color"
            root.shown = true
        }
    }

    // ---------------- Building blocks ----------------

    component SectionLabel: Text {
        color: Theme.overlay0
        font.family: Theme.fontMono
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1
    }

    component Tile: Rectangle {
        id: tile

        property string glyph: ""
        property string label: ""
        property string caption: ""

        // Optional tint carrying information — the Color tile wears the colour
        // it last picked. Hover still wins, so the button keeps its feedback.
        property color accent: "transparent"

        signal activated

        width: (root.contentWidth - 2 * 8) / 3
        height: 72
        radius: 0
        color: tileArea.containsMouse ? Theme.surface0 : Theme.mantle

        Column {
            anchors.centerIn: parent
            spacing: 3

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.glyph
                color: {
                    if (tileArea.containsMouse)
                        return Theme.mauve
                    return tile.accent.a > 0 ? tile.accent : Theme.text
                }
                font.family: Theme.fontMono
                font.pixelSize: 21
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.caption
                visible: tile.caption.length > 0
                color: Theme.overlay0
                font.family: Theme.fontMono
                font.pixelSize: 8
            }
        }

        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.activated()
        }
    }

    component ToggleRow: Rectangle {
        id: row

        property string glyph: ""
        property string label: ""
        property string hint: ""
        property bool checked: false

        signal activated

        width: root.contentWidth
        height: 30
        radius: 0
        color: rowArea.containsMouse ? Theme.hover : "transparent"

        Text {
            id: rowGlyph

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            text: row.glyph
            color: row.checked ? Theme.mauve : Theme.overlay0
            font.family: Theme.fontMono
            font.pixelSize: 13
        }

        Text {
            anchors.left: rowGlyph.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 12
        }

        // Only drawn when a row has something to say — an always-present
        // "on"/"off" next to the switch is noise.
        Text {
            anchors.right: track.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.hint
            visible: row.hint.length > 0
            color: Theme.overlay0
            font.family: Theme.fontMono
            font.pixelSize: 9
        }

        // Sharp-cornered switch: everything else in this rice is radius 0, and
        // a pill here would be the only rounded thing on screen.
        Rectangle {
            id: track

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 14
            radius: 0
            color: row.checked ? Theme.mauve : Theme.surface1

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Rectangle {
                width: 10
                height: 10
                radius: 0
                y: 2
                x: row.checked ? track.width - width - 2 : 2
                color: row.checked ? Theme.base : Theme.subtext0

                Behavior on x {
                    NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                }
            }
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }

    // A row that does something instead of holding a state. Same metrics as
    // ToggleRow so the two stack without the list looking ragged.
    component ActionRow: Rectangle {
        id: action

        property string glyph: ""
        property string label: ""
        property string hint: ""
        property bool accent: false

        signal activated

        width: root.contentWidth
        height: 28
        radius: 0
        color: actionArea.containsMouse ? Theme.hover : "transparent"

        Text {
            id: actionGlyph

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            text: action.glyph
            color: action.accent ? Theme.mauve : Theme.subtext0
            font.family: Theme.fontMono
            font.pixelSize: 13
        }

        Text {
            anchors.left: actionGlyph.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: action.label
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: 12
            font.bold: action.accent
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: action.hint
            visible: action.hint.length > 0
            color: Theme.overlay0
            font.family: Theme.fontMono
            font.pixelSize: 9
        }

        MouseArea {
            id: actionArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.activated()
        }
    }

    component WideButton: Rectangle {
        id: wide

        property string glyph: ""
        property string label: ""

        signal activated

        width: root.contentWidth
        height: 32
        radius: 0
        color: wideArea.containsMouse ? Theme.surface0 : Theme.mantle

        Row {
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: wide.glyph
                color: wideArea.containsMouse ? Theme.mauve : Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 13
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: wide.label
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: wideArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wide.activated()
        }
    }

    // ---------------- Copy feedback ----------------
    //
    // Copying a colour is otherwise completely silent, and the clipboard is not
    // somewhere you can glance at to check it worked.
    property string copied: ""

    function copyColor(hex) {
        if (!hex)
            return
        ColorService.copy(hex)
        root.copied = hex
        copiedTimer.restart()
    }

    Timer {
        id: copiedTimer

        interval: 1100
        repeat: false
        onTriggered: root.copied = ""
    }

    // ---------------- Panel ----------------

    Rectangle {
        id: panel

        // Centred under the cat, but never hanging off either screen edge
        x: Math.max(0, Math.min(root.width - root.panelWidth,
            root.anchorX + 20 - root.panelWidth / 2))
        y: -8
        width: root.panelWidth
        height: body.implicitHeight + 20

        color: Theme.base
        border.color: Theme.surface0
        border.width: 1
        radius: 0

        opacity: 0
        scale: 0.97
        transformOrigin: Item.Top

        focus: true
        Keys.onEscapePressed: root.close()

        Column {
            id: body

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 10
            anchors.leftMargin: 10
            width: root.contentWidth
            spacing: 8

            // ---------------- Header ----------------
            //
            // Two headers in the same strip, cross-faded like the pages under
            // them, so the title changes without the row jumping.
            Item {
                width: parent.width
                height: 20

                Item {
                    anchors.fill: parent
                    opacity: root.page === "" ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 140 }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰒓  Control Center"
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.labelFor(Theme.name)
                        color: Theme.overlay0
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: root.page === "" ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 140 }
                    }

                    Rectangle {
                        id: backButton

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 0
                        color: backArea.containsMouse ? Theme.surface0 : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            color: backArea.containsMouse ? Theme.mauve : Theme.subtext0
                            font.family: Theme.fontMono
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: backArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = ""
                        }
                    }

                    Text {
                        anchors.left: backButton.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pageTitle
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.divider
            }

            // ---------------- Pages ----------------
            //
            // All four are always built and stacked; only the height animates,
            // which is what makes one page look like it turns into the next.
            Item {
                id: pages

                width: parent.width
                clip: true

                height: {
                    if (root.page === "appearance")
                        return appearancePage.implicitHeight
                    if (root.page === "system")
                        return systemPage.implicitHeight
                    if (root.page === "topbar")
                        return topbarPage.implicitHeight
                    if (root.page === "phone")
                        return phonePage.implicitHeight
                    if (root.page === "color")
                        return colorPage.implicitHeight
                    return homePage.implicitHeight
                }

                Behavior on height {
                    NumberAnimation { duration: 210; easing.type: Easing.OutQuad }
                }

                // ---------------- Home ----------------
                Grid {
                    id: homePage

                    width: parent.width
                    columns: 3
                    spacing: 8

                    readonly property bool shown: root.page === ""

                    opacity: homePage.shown ? 1 : 0
                    visible: opacity > 0
                    scale: homePage.shown ? 1 : 0.96

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                    }

                    Tile {
                        glyph: "󰃟"
                        label: "Appearance"
                        caption: SettingsService.effectsOn + "/" + SettingsService.keys.length + " on"
                        onActivated: root.page = "appearance"
                    }

                    Tile {
                        glyph: "󰒓"
                        label: "System"
                        caption: SettingsService.dnsOn ? "DNS on" : "DNS off"
                        onActivated: root.page = "system"
                    }

                    Tile {
                        glyph: "󱂬"
                        label: "Top Bar"
                        caption: BarSettings.enabled("cava") ? "cava on" : "widgets"
                        onActivated: root.page = "topbar"
                    }

                    Tile {
                        glyph: "󰄜"
                        label: "Phone"
                        caption: {
                            if (AdbService.connected)
                                return "connected"
                            return AdbService.known ? "paired" : "adb"
                        }
                        accent: AdbService.connected ? Theme.green : "transparent"
                        onActivated: root.page = "phone"
                    }

                    // Closes first: hyprpicker freezes the screen and a layer
                    // surface holding focus over it is exactly what breaks
                    // slurp too (PROJECT.md §1 #10). qs-color reopens the panel
                    // on the colour page once the pick is in.
                    Tile {
                        glyph: "󰈋"
                        label: "Color"
                        caption: ColorService.current.length > 0 ? ColorService.current : "hyprpicker"
                        accent: ColorService.current.length > 0 ? ColorService.current : "transparent"
                        onActivated: {
                            root.close()
                            ColorService.pick()
                        }
                    }

                    // Quickshell.reload(true) rebuilds the config in place.
                    // Spawning `quickshell -c topbar` instead left the old
                    // instance running and put a second bar on the screen.
                    Tile {
                        glyph: "󰑓"
                        label: "Reload"
                        caption: "hard reload"
                        onActivated: {
                            root.close()
                            Quickshell.reload(true)
                        }
                    }
                }

                // ---------------- Appearance ----------------
                Column {
                    id: appearancePage

                    width: parent.width
                    spacing: 0

                    readonly property bool shown: root.page === "appearance"

                    opacity: appearancePage.shown ? 1 : 0
                    visible: opacity > 0
                    x: appearancePage.shown ? 0 : 16

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    Behavior on x {
                        NumberAnimation { duration: 190; easing.type: Easing.OutQuad }
                    }

                    ToggleRow {
                        glyph: "󰐎"
                        label: "Animations"
                        checked: SettingsService.enabled("animations")
                        onActivated: SettingsService.toggle("animations")
                    }

                    ToggleRow {
                        glyph: "󰂶"
                        label: "Blur"
                        checked: SettingsService.enabled("blur")
                        onActivated: SettingsService.toggle("blur")
                    }

                    ToggleRow {
                        glyph: "󰅶"
                        label: "Shadows"
                        checked: SettingsService.enabled("shadows")
                        onActivated: SettingsService.toggle("shadows")
                    }

                    ToggleRow {
                        glyph: "󱡓"
                        label: "Transparency"
                        checked: SettingsService.enabled("transparency")
                        onActivated: SettingsService.toggle("transparency")
                    }

                    ToggleRow {
                        glyph: "󰠟"
                        label: "Window Gaps"
                        checked: SettingsService.enabled("gaps")
                        onActivated: SettingsService.toggle("gaps")
                    }
                }

                // ---------------- System ----------------
                Column {
                    id: systemPage

                    width: parent.width
                    spacing: 0

                    readonly property bool shown: root.page === "system"

                    opacity: systemPage.shown ? 1 : 0
                    visible: opacity > 0
                    x: systemPage.shown ? 0 : 16

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    Behavior on x {
                        NumberAnimation { duration: 190; easing.type: Easing.OutQuad }
                    }

                    // Needs root, so it opens a terminal where sudo can prompt
                    ToggleRow {
                        glyph: "󰛳"
                        label: "Encrypted DNS"
                        hint: "sudo"
                        checked: SettingsService.dnsOn
                        onActivated: {
                            root.close()
                            SettingsService.toggleDns()
                        }
                    }

                    // Turning this on switches several Appearance rows off —
                    // qs-mode owns those while it is active (see perfmode.lua)
                    ToggleRow {
                        glyph: "󰓅"
                        label: "Performance Mode"
                        checked: PerfMode.active
                        onActivated: {
                            root.close()
                            Quickshell.execDetached(["sh", "-c",
                                Quickshell.env("HOME") + "/.local/bin/qs-mode toggle"])
                        }
                    }

                    ToggleRow {
                        glyph: SettingsService.micMuted ? "󰍭" : "󰍬"
                        label: "Microphone"
                        checked: !SettingsService.micMuted
                        onActivated: SettingsService.toggleMic()
                    }
                }

                // ---------------- Top bar ----------------
                //
                // Listed in bar order, left to right, so the switches map onto
                // what you are looking at. The running cat is missing on
                // purpose: it is the handle for this panel, and hiding it would
                // hide the way back in.
                Column {
                    id: topbarPage

                    width: parent.width
                    spacing: 0

                    readonly property bool shown: root.page === "topbar"

                    opacity: topbarPage.shown ? 1 : 0
                    visible: opacity > 0
                    x: topbarPage.shown ? 0 : 16

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    Behavior on x {
                        NumberAnimation { duration: 190; easing.type: Easing.OutQuad }
                    }

                    ToggleRow {
                        glyph: "󰃭"
                        label: "Date"
                        checked: BarSettings.enabled("date")
                        onActivated: BarSettings.toggle("date")
                    }

                    ToggleRow {
                        glyph: "󰥔"
                        label: "Clock"
                        checked: BarSettings.enabled("clock")
                        onActivated: BarSettings.toggle("clock")
                    }

                    ToggleRow {
                        glyph: "󰖯"
                        label: "Focused App"
                        checked: BarSettings.enabled("focusedApp")
                        onActivated: BarSettings.toggle("focusedApp")
                    }

                    ToggleRow {
                        glyph: "󰕰"
                        label: "Workspaces"
                        checked: BarSettings.enabled("workspaces")
                        onActivated: BarSettings.toggle("workspaces")
                    }

                    // The extra: two spectrum strips either side of the
                    // workspaces. Off by default and needs a package the base
                    // rice does not install, so it says why when it cannot run.
                    ToggleRow {
                        glyph: "󰗅"
                        label: "Cava Visualizer"
                        hint: CavaService.available ? "" : "install cava"
                        checked: BarSettings.enabled("cava") && CavaService.available
                        onActivated: {
                            if (CavaService.available)
                                BarSettings.toggle("cava")
                        }
                    }

                    ToggleRow {
                        glyph: "󰝚"
                        label: "Media Player"
                        checked: BarSettings.enabled("media")
                        onActivated: BarSettings.toggle("media")
                    }

                    ToggleRow {
                        glyph: "󰻠"
                        label: "System Stats"
                        checked: BarSettings.enabled("stats")
                        onActivated: BarSettings.toggle("stats")
                    }

                    ToggleRow {
                        glyph: "󰕾"
                        label: "Volume"
                        checked: BarSettings.enabled("volume")
                        onActivated: BarSettings.toggle("volume")
                    }

                    ToggleRow {
                        glyph: "󰀻"
                        label: "System Tray"
                        checked: BarSettings.enabled("tray")
                        onActivated: BarSettings.toggle("tray")
                    }

                    ToggleRow {
                        glyph: "󰂚"
                        label: "Notifications"
                        checked: BarSettings.enabled("notifications")
                        onActivated: BarSettings.toggle("notifications")
                    }
                }

                // ---------------- Phone ----------------
                //
                // One device row that changes shape: Connect while it is out of
                // reach, then the model name and address with a chevron that
                // unfolds the adb actions. The search behind Connect can take a
                // few seconds (see qs-adb), so the row narrates it rather than
                // sitting still.
                Column {
                    id: phonePage

                    width: parent.width
                    spacing: 0

                    readonly property bool shown: root.page === "phone"

                    opacity: phonePage.shown ? 1 : 0
                    visible: opacity > 0
                    x: phonePage.shown ? 0 : 16

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    Behavior on x {
                        NumberAnimation { duration: 190; easing.type: Easing.OutQuad }
                    }

                    // Folded away with the panel, so reopening never lands on a
                    // half-expanded row for a phone that has since dropped off.
                    property bool expanded: false

                    // Connect pressed: the button is a port field right now
                    property bool entering: false

                    Rectangle {
                        width: parent.width
                        height: 46
                        radius: 0
                        color: Theme.mantle

                        Text {
                            id: phoneGlyph

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰄜"
                            color: AdbService.connected ? Theme.green : Theme.overlay0
                            font.family: Theme.fontMono
                            font.pixelSize: 19
                        }

                        Column {
                            anchors.left: phoneGlyph.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: AdbService.label
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                text: {
                                    if (AdbService.busy)
                                        return AdbService.busyText
                                    if (AdbService.connected)
                                        return "connected · " + AdbService.device.address
                                    if (!AdbService.adbAvailable)
                                        return "adb is not installed"
                                    if (AdbService.known)
                                        return "paired · not connected"
                                    return "nothing paired — pair it in wireless debugging"
                                }
                                color: AdbService.connected ? Theme.green : Theme.overlay0
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                            }
                        }

                        // Three states in one spot: chevron when the phone is
                        // here, Connect when it is not, and a port field once
                        // Connect is pressed.
                        //
                        // Typing the port beats searching for it. Wireless
                        // debugging picks a new one every time it is switched
                        // on, the phone puts it on screen right next to the
                        // switch, and a sweep that guesses wrong just fails
                        // slowly.
                        Rectangle {
                            id: connectButton

                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: {
                                if (AdbService.connected)
                                    return 26
                                return phonePage.entering ? 124 : 74
                            }
                            height: 24
                            radius: 0
                            color: {
                                if (phonePage.entering)
                                    return Theme.surface0
                                if (connectArea.containsMouse)
                                    return Theme.surface1
                                return AdbService.connected ? "transparent" : Theme.surface0
                            }
                            visible: AdbService.adbAvailable && (AdbService.known || AdbService.connected)

                            border.width: phonePage.entering ? 1 : 0
                            border.color: Theme.mauve

                            Behavior on width {
                                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !phonePage.entering
                                text: {
                                    if (AdbService.connected)
                                        return "󰅀"
                                    return AdbService.busy ? "…" : "Connect"
                                }
                                color: connectArea.containsMouse ? Theme.mauve : Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: AdbService.connected ? 13 : 11

                                rotation: AdbService.connected && phonePage.expanded ? 180 : 0

                                Behavior on rotation {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                }
                            }

                            TextInput {
                                id: portInput

                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                visible: phonePage.entering

                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                selectionColor: Theme.mauve
                                selectedTextColor: Theme.crust
                                clip: true

                                // The phone shows a plain port; ip:port is
                                // accepted too and qs-adb sorts out which it got
                                inputMethodHints: Qt.ImhNoPredictiveText
                                validator: RegularExpressionValidator {
                                    regularExpression: /[0-9.:]{0,21}/
                                }

                                onAccepted: {
                                    if (portInput.text.trim().length === 0)
                                        return
                                    AdbService.connect(portInput.text.trim())
                                    phonePage.entering = false
                                }

                                Keys.onEscapePressed: phonePage.entering = false

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: portInput.text.length === 0
                                    text: "port  ⏎"
                                    color: Theme.overlay0
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: connectArea

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !phonePage.entering
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (AdbService.connected) {
                                        phonePage.expanded = !phonePage.expanded
                                        return
                                    }
                                    phonePage.entering = true
                                    portInput.text = ""
                                    portInput.forceActiveFocus()
                                }
                            }
                        }
                    }

                    // The actions themselves. Height animates from zero so the
                    // row unfolds instead of the panel jumping.
                    Item {
                        width: parent.width
                        clip: true
                        height: phonePage.expanded && AdbService.connected ? actions.implicitHeight + 6 : 0

                        Behavior on height {
                            NumberAnimation { duration: 190; easing.type: Easing.OutQuad }
                        }

                        Column {
                            id: actions

                            y: 6
                            width: parent.width
                            spacing: 0

                            // First because it is what the phone is connected
                            // for. scrcpy with the phone's own screen off, in a
                            // small borderless window.
                            ActionRow {
                                glyph: "󰹑"
                                label: "Stream"
                                accent: true
                                hint: AdbService.scrcpyAvailable ? "" : "install scrcpy"
                                onActivated: {
                                    if (!AdbService.scrcpyAvailable)
                                        return
                                    root.close()
                                    AdbService.action("stream")
                                }
                            }

                            ActionRow {
                                glyph: "󰄀"
                                label: "Screenshot"
                                hint: "~/Pictures/Screenshots"
                                onActivated: AdbService.action("screenshot")
                            }

                            ActionRow {
                                glyph: "󰈑"
                                label: "Send File"
                                hint: "/sdcard/Download"
                                onActivated: {
                                    root.close()
                                    AdbService.action("push")
                                }
                            }

                            ActionRow {
                                glyph: "󰆍"
                                label: "Shell"
                                onActivated: {
                                    root.close()
                                    AdbService.action("shell")
                                }
                            }

                            ActionRow {
                                glyph: "󰜉"
                                label: "Reboot Phone"
                                onActivated: AdbService.action("reboot")
                            }

                            ActionRow {
                                glyph: "󰅖"
                                label: "Disconnect"
                                onActivated: {
                                    phonePage.expanded = false
                                    AdbService.disconnect()
                                }
                            }
                        }
                    }
                }

                // ---------------- Color ----------------
                Column {
                    id: colorPage

                    width: parent.width
                    spacing: 8

                    readonly property bool shown: root.page === "color"
                    readonly property string hex: ColorService.current

                    opacity: colorPage.shown ? 1 : 0
                    visible: opacity > 0
                    x: colorPage.shown ? 0 : 16

                    Behavior on opacity {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    Behavior on x {
                        NumberAnimation { duration: 190; easing.type: Easing.OutQuad }
                    }

                    // The swatch is the hex field too — clicking anywhere on it
                    // copies, which is the only thing anyone wants from a
                    // colour picker afterwards.
                    Rectangle {
                        width: parent.width
                        height: 84
                        radius: 0
                        color: colorPage.hex.length > 0 ? colorPage.hex : Theme.mantle
                        border.width: 1
                        border.color: Theme.surface0

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (colorPage.hex.length === 0)
                                    return "no color picked yet"
                                return root.copied === colorPage.hex ? "copied" : colorPage.hex
                            }
                            color: colorPage.hex.length > 0
                                ? ColorService.contrastText(colorPage.hex)
                                : Theme.overlay0
                            font.family: Theme.fontMono
                            font.pixelSize: 17
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: colorPage.hex.length > 0
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor
                            onClicked: root.copyColor(colorPage.hex)
                        }
                    }

                    Repeater {
                        model: colorPage.hex.length > 0
                            ? [ColorService.rgbText(colorPage.hex), ColorService.hslText(colorPage.hex)]
                            : []

                        delegate: Rectangle {
                            id: valueRow

                            required property var modelData

                            width: colorPage.width
                            height: 22
                            radius: 0
                            color: valueArea.containsMouse ? Theme.hover : "transparent"

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: valueRow.modelData
                                color: Theme.subtext0
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.copied === valueRow.modelData ? "copied" : "󰆏"
                                color: root.copied === valueRow.modelData ? Theme.green : Theme.overlay0
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: valueArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyColor(valueRow.modelData)
                            }
                        }
                    }

                    WideButton {
                        glyph: "󰈋"
                        label: colorPage.hex.length > 0 ? "Pick another color" : "Pick a color"
                        onActivated: {
                            root.close()
                            ColorService.pick()
                        }
                    }

                    Item {
                        width: parent.width
                        height: 14
                        visible: ColorService.colors.length > 1

                        SectionLabel {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "RECENT"
                        }

                        Text {
                            id: clearButton

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "clear"
                            color: clearArea.containsMouse ? Theme.red : Theme.overlay0
                            font.family: Theme.fontMono
                            font.pixelSize: 9

                            MouseArea {
                                id: clearArea

                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ColorService.clear()
                            }
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: 5
                        visible: ColorService.colors.length > 1

                        Repeater {
                            model: ColorService.colors

                            delegate: Rectangle {
                                id: swatch

                                required property var modelData

                                width: 25
                                height: 25
                                radius: 0
                                color: swatch.modelData
                                border.width: 1
                                border.color: {
                                    if (swatchArea.containsMouse)
                                        return Theme.mauve
                                    return swatch.modelData === colorPage.hex
                                        ? Theme.subtext0
                                        : Theme.surface0
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.copied === swatch.modelData
                                    text: "󰄬"
                                    color: ColorService.contrastText(swatch.modelData)
                                    font.family: Theme.fontMono
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: swatchArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copyColor(swatch.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
