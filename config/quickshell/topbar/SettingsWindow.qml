import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The settings screen — Super+Z.
//
// Bottom-anchored and slides up, the same shape as the launcher and the
// clipboard, because those are the two panels this one sits next to in muscle
// memory. Not a popup off the bar: it is a place you go to, not a thing you
// glance at.
//
// **One box, pages that morph into each other**, the way the control centre and
// the calendar already work: pressing a category *becomes* that page rather
// than opening a second window. `page` drives the cross-fade and the height in
// one place, and resets to home on close so it never reopens mid-flow.
//
// The panel is a fixed-size window with `mask: Region { item: panel }` so only
// the panel takes clicks — resizing the window itself flashed white around the
// edges every frame the surface grew faster than the scene painted.
PanelWindow {
    id: root

    property bool shown: false

    // "" = home, otherwise the category id
    property string page: ""

    /// Keyboard cursor within the active page. Every page keeps its rows in a
    /// Column, so "the row at index n" is just childAt on that column — the
    /// alternative was a parallel model per page, kept in step by hand.
    property int cursor: 0

    /// Which prefab row has its Save/Reset pair open. Only one at a time —
    /// two open rows would make the page jump under the cursor.
    property string expandedPrefab: ""

    readonly property var activeColumn: {
        if (root.page === "appearance")
            return appearancePage
        if (root.page === "topbar")
            return topbarPage
        if (root.page === "prefab")
            return prefabPage
        return homePage
    }

    /// Only rows count — spacers and headings are skipped so Down never lands
    /// on something that cannot be acted on.
    function rowsOf(column) {
        const out = []
        for (let i = 0; i < column.children.length; i++) {
            const child = column.children[i]
            if (child && child.visible !== false && child.selectable === true)
                out.push(child)
        }
        return out
    }

    readonly property var rows: root.rowsOf(root.activeColumn)

    /// Stamp each row with its position once the page is built, so a row can
    /// bind `selected` to the cursor without the call site repeating a literal
    /// index that would rot the moment a row is inserted.
    function indexRows(column) {
        const rows = root.rowsOf(column)
        for (let i = 0; i < rows.length; i++)
            rows[i].rowIndex = i
    }

    function moveCursor(delta) {
        const n = root.rows.length
        if (n === 0)
            return
        root.cursor = ((root.cursor + delta) % n + n) % n
    }

    /// Enter: open a category, flip a switch. Sliders are moved with Left and
    /// Right instead, so Enter on one does nothing rather than something
    /// arbitrary.
    function activateCursor() {
        const row = root.rows[root.cursor]
        if (!row)
            return
        if (row.kind === "category")
            root.page = row.pageId
        else if (row.kind === "toggle")
            row.toggled()
    }

    function nudgeCursor(direction) {
        const row = root.rows[root.cursor]
        if (row && row.kind === "slider")
            row.nudge(direction)
    }

    onPageChanged: {
        root.cursor = 0
        root.expandedPrefab = ""
    }

    readonly property int bottomGap: 18
    readonly property int panelWidth: 560

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    // Only Ignore — assigning exclusiveZone would push the window down by the
    // bar's 30px zone (gotcha #19).
    exclusionMode: ExclusionMode.Ignore
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: panel }

    function open() {
        root.page = ""
        root.shown = true
    }

    function close() {
        root.shown = false
    }

    function toggle() {
        if (root.shown)
            root.close()
        else
            root.open()
    }

    IpcHandler {
        target: "settings"

        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }

        // Straight to a page, the way `launcher system` skips to a tab.
        function appearance(): void {
            root.open()
            root.page = "appearance"
        }

        function topbar(): void {
            root.open()
            root.page = "topbar"
        }

        function prefab(): void {
            root.open()
            root.page = "prefab"
        }
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

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        // A hidden PanelWindow lies about its height for the first few frames
        // (gotcha #20), so the slide animates `offset` and leaves this binding
        // alone rather than animating y directly.
        y: root.height - height - root.bottomGap + panel.offset

        property real offset: 0

        width: root.panelWidth
        height: header.height + body.height + 22
        color: Theme.panelColor
        border.color: Theme.surface0
        border.width: Theme.borderWidth
        radius: Theme.radiusPanel

        opacity: 0

        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        GlossOverlay {
            anchors.fill: parent
            radius: panel.radius
            midline: 0.22
        }

        // ---------------- Header ----------------

        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 2
            height: 52

            // Back arrow doubles as the title on the home page, so the header
            // never jumps between two layouts.
            Rectangle {
                id: backButton

                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: Theme.radiusUpTo(26)
                color: backArea.containsMouse ? Theme.surface0 : "transparent"
                opacity: root.page === "" ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                }

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 18
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
                anchors.left: parent.left
                anchors.leftMargin: root.page === "" ? 20 : 48
                anchors.verticalCenter: parent.verticalCenter
                text: root.page === "" ? "Settings" : root.page === "topbar" ? "Top Bar" : root.page === "prefab" ? "Prefab" : "Appearance"
                color: Theme.text
                font.pixelSize: 16
                font.bold: true

                Behavior on anchors.leftMargin {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: root.page === "" ? "Super+Z" : Theme.palette.label
                color: Theme.overlay0
                font.pixelSize: 11
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                height: 1
                color: Theme.divider
            }
        }

        // ---------------- Pages ----------------

        Item {
            id: body

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            // +6 so the last row's track is not flush against the panel edge.
            height: 6 + (root.page === "" ? homePage.implicitHeight
                : root.page === "topbar" ? topbarPage.implicitHeight
                : root.page === "prefab" ? prefabPage.implicitHeight
                : appearancePage.implicitHeight)

            // Home: the category grid
            Column {
                id: homePage

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 6

                opacity: root.page === "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                Component.onCompleted: root.indexRows(homePage)

                SettingsCategory {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    pageId: "appearance"
                    glyph: "󰸉"
                    title: "Appearance"
                    caption: SettingsService.effectsOn + "/5 effects on"
                    onClicked: root.page = "appearance"
                }

                SettingsCategory {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    pageId: "topbar"
                    glyph: "󰍺"
                    title: "Top Bar"
                    caption: BarSettings.floating ? "floating" : "docked"
                    onClicked: root.page = "topbar"
                }

                SettingsCategory {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    pageId: "prefab"
                    glyph: "󰆔"
                    title: "Prefab"
                    caption: {
                        const n = Object.keys(SettingsService.prefabs).length
                        return n === 0 ? "no themes saved" : n + " saved"
                    }
                    onClicked: root.page = "prefab"
                }
            }

            // Appearance: the ten rows, in the order they were asked for
            Column {
                id: appearancePage

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 2

                opacity: root.page === "appearance" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                Component.onCompleted: root.indexRows(appearancePage)

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Animations"
                    checked: SettingsService.enabled("animations")
                    onToggled: SettingsService.toggle("animations")
                }

                SettingsSlider {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Animation speed"
                    settingKey: "animationSpeed"
                    // A multiplier, so 1× is the configured speed rather than
                    // an arbitrary middle of the range.
                    display: value.toFixed(2).replace(/0+$/, "").replace(/\.$/, "") + "×"
                    enabled: SettingsService.enabled("animations")
                }

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Blur"
                    checked: SettingsService.enabled("blur")
                    // Aero glass and blur are two ways of painting the same
                    // surface, so turning one on takes the other off.
                    onToggled: {
                        const next = !SettingsService.enabled("blur")
                        SettingsService.set("blur", next)
                        if (next && SettingsService.enabled("aeroGlass"))
                            SettingsService.set("aeroGlass", false)
                    }
                }

                SettingsSlider {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Blur amount"
                    settingKey: "blurAmount"
                    display: Math.round(value)
                    enabled: SettingsService.enabled("blur")
                }

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Aero glass"
                    caption: "blur + transparency, tuned together"
                    checked: SettingsService.enabled("aeroGlass")
                    onToggled: {
                        const next = !SettingsService.enabled("aeroGlass")
                        SettingsService.set("aeroGlass", next)
                        // Glass IS blur plus transparency, tuned together —
                        // leaving either switch on would be two things
                        // fighting over the same surface.
                        if (next) {
                            if (SettingsService.enabled("blur"))
                                SettingsService.set("blur", false)
                            if (SettingsService.enabled("transparency"))
                                SettingsService.set("transparency", false)
                        }
                    }
                }

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Shadows"
                    checked: SettingsService.enabled("shadows")
                    onToggled: SettingsService.toggle("shadows")
                }

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Transparency"
                    checked: SettingsService.enabled("transparency")
                    onToggled: {
                        const next = !SettingsService.enabled("transparency")
                        SettingsService.set("transparency", next)
                        if (next && SettingsService.enabled("aeroGlass"))
                            SettingsService.set("aeroGlass", false)
                    }
                }

                SettingsSlider {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Window opacity"
                    settingKey: "transparencyAmount"
                    display: Math.round(value * 100) + "%"
                    enabled: SettingsService.enabled("transparency")
                }

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Window gaps"
                    checked: SettingsService.enabled("gaps")
                    onToggled: SettingsService.toggle("gaps")
                }

                SettingsSlider {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Gap size"
                    settingKey: "gapsAmount"
                    display: Math.round(value) + "px"
                    enabled: SettingsService.enabled("gaps")
                }
            }

            // Top Bar: how the strip looks, then what it holds. The widget
            // switches are the control centre's Topbar page — same
            // BarSettings singleton, so the two stay in step with no syncing.
            Column {
                id: topbarPage

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 2

                opacity: root.page === "topbar" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                Component.onCompleted: root.indexRows(topbarPage)

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Float"
                    caption: "detach from the top edge"
                    checked: BarSettings.enabled("floating")
                    onToggled: BarSettings.toggle("floating")
                }

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Transparent"
                    checked: BarSettings.enabled("transparent")
                    onToggled: BarSettings.toggle("transparent")
                }

                SettingsSlider {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Bar opacity"
                    settingKey: "barOpacity"
                    store: BarSettings
                    display: Math.round(value * 100) + "%"
                    enabled: BarSettings.enabled("transparent")
                }

                SettingsSection { width: parent.width; label: "Widgets" }

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Date"
                    checked: BarSettings.enabled("date")
                    onToggled: BarSettings.toggle("date")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Clock"
                    checked: BarSettings.enabled("clock")
                    onToggled: BarSettings.toggle("clock")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Focused app"
                    checked: BarSettings.enabled("focusedApp")
                    onToggled: BarSettings.toggle("focusedApp")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Workspaces"
                    checked: BarSettings.enabled("workspaces")
                    onToggled: BarSettings.toggle("workspaces")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Audio spectrum"
                    checked: BarSettings.enabled("cava")
                    onToggled: BarSettings.toggle("cava")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Media controls"
                    checked: BarSettings.enabled("media")
                    onToggled: BarSettings.toggle("media")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "CPU / RAM / temp"
                    checked: BarSettings.enabled("stats")
                    onToggled: BarSettings.toggle("stats")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Volume"
                    checked: BarSettings.enabled("volume")
                    onToggled: BarSettings.toggle("volume")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "System tray"
                    checked: BarSettings.enabled("tray")
                    onToggled: BarSettings.toggle("tray")
                }
                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Notifications"
                    checked: BarSettings.enabled("notifications")
                    onToggled: BarSettings.toggle("notifications")
                }

                SettingsToggle {
                    width: parent.width
                    selected: root.cursor === rowIndex
                    label: "Running cat"
                    caption: "also the control centre button"
                    checked: BarSettings.enabled("runcat")
                    onToggled: BarSettings.toggle("runcat")
                }
            }

            // Prefab: a saved look per theme.
            Column {
                id: prefabPage

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 2

                opacity: root.page === "prefab" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                Component.onCompleted: root.indexRows(prefabPage)

                Text {
                    width: parent.width
                    padding: 8
                    leftPadding: 18
                    text: "Set the look you want, then save it here. Switching back to that theme restores it."
                    color: Theme.overlay0
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: Theme.themeNames.concat(Theme.customThemeNames)

                    SettingsPrefabRow {
                        required property var modelData

                        width: prefabPage.width
                        themeName: modelData
                        label: Theme.labelFor(modelData)
                        isActive: modelData === Theme.name
                        hasPrefab: SettingsService.hasPrefab(modelData)
                        expanded: root.expandedPrefab === modelData
                        selected: root.cursor === rowIndex

                        onToggled: root.expandedPrefab =
                            (root.expandedPrefab === modelData) ? "" : modelData
                        onSaveRequested: {
                            SettingsService.savePrefab(modelData)
                            root.expandedPrefab = ""
                        }
                        onClearRequested: {
                            SettingsService.clearPrefab(modelData)
                            root.expandedPrefab = ""
                        }
                    }
                }
            }
        }

        // Esc closes, Left/Back steps out of a page first — the same two-level
        // escape the calendar and control centre use.
        Item {
            id: keyCatcher

            anchors.fill: parent
            focus: true

            Keys.onUpPressed: root.moveCursor(-1)
            Keys.onDownPressed: root.moveCursor(1)

            Keys.onReturnPressed: root.activateCursor()
            Keys.onEnterPressed: root.activateCursor()

            // Left/Right move a slider when the cursor is on one; on anything
            // else Left is the way back out, which is the same gesture the
            // theme picker uses between its sections.
            Keys.onRightPressed: root.nudgeCursor(1)
            Keys.onLeftPressed: {
                const row = root.rows[root.cursor]
                if (row && row.kind === "slider")
                    row.nudge(-1)
                else
                    root.page = ""
            }

            Keys.onEscapePressed: {
                if (root.page !== "")
                    root.page = ""
                else
                    root.close()
            }
        }
    }

    ParallelAnimation {
        id: openAnim

        NumberAnimation { target: backdrop; property: "opacity"; to: Theme.backdropOpacity(0.45); duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "offset"; from: 40; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: Theme.backdropOpacity(0); duration: 130; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "offset"; to: 40; duration: 130; easing.type: Easing.InQuad }
        }

        ScriptAction {
            script: {
                root.visible = false
                root.page = ""
            }
        }
    }
}
