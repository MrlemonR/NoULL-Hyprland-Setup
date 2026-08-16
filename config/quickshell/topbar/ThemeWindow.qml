import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Theme and font picker — Super+Ctrl+Z.
//
// Three sections side by side, Left/Right moves between them:
//   Custom  themes that break the house rules — rounded corners, gloss,
//           translucency. Same palettes.json, marked `"custom": true`.
//   Themes  the standard set, applied by qs-theme across quickshell, kitty,
//           GTK, Kvantum, nvim
//   Fonts   applied by qs-font across nine targets; Space on a row cycles the
//           weight through Thin…ExtraBold without leaving the row
//
// Themes is the middle one on purpose: it is the section that gets opened, and
// from it both neighbours are one key away.
//
// Up/Down walks the active section, Enter applies and closes. Typing searches
// the theme lists; the font list is short enough not to need it.
PanelWindow {
    id: root

    property bool shown: false
    property string query: ""
    property int selectedIndex: 0
    property int customIndex: 0

    readonly property int sectionCustom: 0
    readonly property int sectionThemes: 1
    readonly property int sectionFonts: 2

    property int section: root.sectionThemes
    property int fontIndex: 0

    readonly property bool onCustom: root.section === root.sectionCustom
    readonly property bool onFonts: root.section === root.sectionFonts
    readonly property bool onThemes: root.section === root.sectionThemes
    readonly property var fontList: FontService.families

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-theme"

    readonly property int bottomGap: 18

    /// Shared by both theme lists — they differ only in which names go in.
    function searchNames(names) {
        const q = root.query.trim().toLowerCase()
        const out = []
        for (let i = 0; i < names.length; i++) {
            const label = Theme.labelFor(names[i])
            if (q.length > 0 && label.toLowerCase().indexOf(q) < 0 && names[i].indexOf(q) < 0)
                continue
            out.push({ name: names[i], label: label })
        }
        return out
    }

    readonly property var results: root.searchNames(Theme.themeNames)
    readonly property var customResults: root.searchNames(Theme.customThemeNames)

    /// Whichever list the active section is showing.
    readonly property var activeResults: root.onCustom ? root.customResults : root.results
    readonly property int activeIndex: root.onCustom ? root.customIndex : root.selectedIndex

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    // DİKKAT: exclusiveZone'a değer atamak exclusionMode'u Normal'a çeviriyor;
    // pencere bar'ın 30px exclusive zone'u kadar aşağı iniyor ve tam ekran
    // olmuyordu. Sadece Ignore bırakıyoruz.
    exclusionMode: ExclusionMode.Ignore
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-theme"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open() {
        root.query = ""

        // Etkin temanın üstünden başla
        let index = 0
        for (let i = 0; i < root.results.length; i++) {
            if (root.results[i].name === Theme.name)
                index = i
        }
        root.selectedIndex = index

        root.customIndex = 0
        for (let i = 0; i < root.customResults.length; i++) {
            if (root.customResults[i].name === Theme.name)
                root.customIndex = i
        }

        // Open on the section the active theme actually lives in, so the
        // picker never opens with the cursor somewhere the current theme is
        // not — the same reason it opens on the active row rather than row 0.
        root.section = Theme.isCustom ? root.sectionCustom : root.sectionThemes

        // Start the font cursor on the family in use
        root.fontIndex = 0
        FontService.refresh()
        for (let i = 0; i < root.fontList.length; i++) {
            if (root.fontList[i] === Theme.fontMono)
                root.fontIndex = i
        }

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

    function move(delta) {
        if (root.onFonts) {
            const fonts = root.fontList.length
            if (fonts === 0)
                return
            root.fontIndex = ((root.fontIndex + delta) % fonts + fonts) % fonts
            return
        }
        const count = root.activeResults.length
        if (count === 0)
            return
        const next = ((root.activeIndex + delta) % count + count) % count
        if (root.onCustom)
            root.customIndex = next
        else
            root.selectedIndex = next
    }

    function setSection(next) {
        if (next === root.section || next < root.sectionCustom || next > root.sectionFonts)
            return
        root.section = next
    }

    /// Space on a font row: step the weight, applying immediately so the
    /// result is visible without leaving the picker.
    function cycleWeight() {
        FontService.applyWeight(FontService.nextWeight(root.weightName))
    }

    // Theme.fontWeight is a number; the config and qs-font speak face names.
    readonly property string weightName: {
        const names = FontService.weights
        for (let i = 0; i < names.length; i++) {
            if (Theme.weightNames[names[i]] === Theme.fontWeight)
                return names[i]
        }
        return "Regular"
    }

    function apply() {
        if (root.onFonts) {
            FontService.applyFamily(root.fontList[root.fontIndex])
            return
        }
        const item = root.activeResults[root.activeIndex]
        if (!item)
            return
        // Custom themes go through the same qs-theme call as the rest: they
        // live in the same palettes.json, so every helper already handles
        // them and there is no second code path to keep in step.
        Quickshell.execDetached([root.script, item.name])
    }

    IpcHandler {
        target: "theme"

        function toggle(): void {
            root.toggle()
        }

        function open(): void {
            root.open()
        }

        // Straight to a section, the way `launcher system` skips to a tab.
        // Also the only way to reach them without a keyboard.
        function fonts(): void {
            root.open()
            root.section = root.sectionFonts
        }

        function custom(): void {
            root.open()
            root.section = root.sectionCustom
        }

        function close(): void {
            root.close()
        }
    }

    onShownChanged: {
        if (root.shown) {
            root.visible = true
            closeAnim.stop()
            openAnim.restart()
            input.forceActiveFocus()
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
        // Slides up from below, like the launcher and the settings screen.
        // A hidden PanelWindow reports the wrong height for the first few
        // frames (gotcha #20), so the animation moves a separate offset and
        // leaves this binding alone rather than animating `y` directly.
        y: root.height - height - root.bottomGap + panel.offset

        property real offset: 0
        width: 440
        height: 60 + listArea.height + 12
        color: Theme.panelColor
        border.color: Theme.surface0
        border.width: Theme.borderWidth
        radius: Theme.radiusPanel

        opacity: 0

        // Sits under the content, over the fill: the sheen is part of the
        // surface, not something laid across the rows. Inert unless the active
        // theme carries a gloss value.
        GlossOverlay {
            anchors.fill: parent
            radius: panel.radius
            // Falls off well before the list starts — the highlight belongs to
            // the search row, which is the top edge of the "glass".
            midline: 0.28
        }

        Item {
            id: searchRow

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 58

            Text {
                id: searchIcon

                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                font.family: Theme.fontMono
                font.weight: Theme.fontWeight
                font.pixelSize: 17
                color: Theme.overlay0
            }

            TextInput {
                id: input

                anchors.left: searchIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.pixelSize: 15
                selectionColor: Theme.mauve
                selectedTextColor: Theme.textOn(Theme.mauve)
                clip: true
                focus: true

                text: root.query
                onTextChanged: {
                    root.query = text
                    root.selectedIndex = 0
                }

                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)
                Keys.onEscapePressed: root.close()

                // Left/Right move between sections rather than the text
                // cursor: the search box only serves the theme lists, and
                // walking a name character by character is not worth a key.
                // Relative now that there are three — custom ← themes → fonts.
                Keys.onLeftPressed: root.setSection(root.section - 1)
                Keys.onRightPressed: root.setSection(root.section + 1)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.apply()
                        root.close()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Space && root.onFonts) {
                        // Space is a weight step here, not a character —
                        // there is nothing to search on the font side.
                        root.cycleWeight()
                        event.accepted = true
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0
                    text: {
                        if (root.onFonts)
                            return "Fonts — space cycles weight, ← back to themes"
                        if (root.onCustom)
                            return "Custom themes…    → standard"
                        return "← custom    Search themes…    → fonts"
                    }
                    color: Theme.surface2
                    font.pixelSize: 15
                }
            }
        }

        Item {
            id: listArea

            anchors.top: searchRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            // A property binding may be a block; an argument to Math.min may
            // not, so the pick is hoisted out of the expression.
            readonly property real activeContentHeight: {
                if (root.onFonts)
                    return fontList.contentHeight
                if (root.onCustom)
                    return customList.contentHeight
                return list.contentHeight
            }

            height: Math.max(44, Math.min(6 * 44, listArea.activeContentHeight))

            Behavior on height {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                model: root.results
                boundsBehavior: Flickable.StopAtBounds

                opacity: root.onThemes ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                }

                delegate: Rectangle {
                    id: themeRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: themeRow.index === root.selectedIndex
                    readonly property bool active: themeRow.modelData.name === Theme.name

                    width: list.width
                    height: 44
                    radius: Theme.radius
                    color: {
                        if (themeRow.selected)
                            return Theme.surface0
                        return themeArea.containsMouse ? Theme.hover : "transparent"
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: themeRow.modelData.label
                        color: themeRow.active ? Theme.mauve : Theme.text
                        font.pixelSize: 14
                        font.bold: themeRow.selected || themeRow.active
                    }

                    // Palet önizlemesi
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: {
                                const p = Theme.palettes[themeRow.modelData.name]
                                if (!p)
                                    return []
                                return [p.red, p.yellow, p.green, p.blue, p.mauve, p.text]
                            }

                            delegate: Rectangle {
                                required property var modelData
                                width: 10
                                height: 10
                                radius: Math.min(5, Theme.radius)
                                color: modelData
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 104
                        anchors.verticalCenter: parent.verticalCenter
                        visible: themeRow.active
                        text: "active"
                        color: Theme.overlay0
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: themeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.selectedIndex = themeRow.index
                        onClicked: {
                            root.selectedIndex = themeRow.index
                            root.apply()
                            root.close()
                        }
                    }
                }
            }

            // ---------------- Custom themes ----------------
            // Each row is drawn in the shape the theme it names would give it
            // — its corner radius, its gloss. Same idea as the font list
            // drawing every family in its own face: the list previews itself,
            // so the thing that makes a custom theme custom is visible before
            // applying it rather than described in a label.
            ListView {
                id: customList

                anchors.fill: parent
                clip: true
                model: root.customResults
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.customIndex

                opacity: root.onCustom ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                }

                delegate: Item {
                    id: customRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: customRow.index === root.customIndex
                    readonly property bool active: customRow.modelData.name === Theme.name
                    readonly property var rowStyle: Theme.styleFor(customRow.modelData.name)
                    readonly property var rowPalette: Theme.palettes[customRow.modelData.name]

                    width: customList.width
                    height: 44

                    Rectangle {
                        id: customBg

                        // Inset so a rounded row does not touch its neighbours
                        // — at radius 0 this collapses back to the flat look.
                        anchors.fill: parent
                        anchors.topMargin: customRow.rowStyle.radius > 0 ? 2 : 0
                        anchors.bottomMargin: customRow.rowStyle.radius > 0 ? 2 : 0
                        radius: customRow.rowStyle.radius
                        color: {
                            if (customRow.selected)
                                return Theme.surface0
                            return customArea.containsMouse ? Theme.hover : "transparent"
                        }

                        GlossOverlay {
                            anchors.fill: parent
                            radius: customBg.radius
                            // Only under the cursor: a sheen on every row at
                            // rest turns the list into a wall of glass.
                            strength: (customRow.selected || customArea.containsMouse)
                                ? customRow.rowStyle.gloss : 0
                            bounce: false

                            Behavior on strength {
                                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: customRow.modelData.label
                        color: customRow.active ? Theme.mauve : Theme.text
                        font.pixelSize: 14
                        font.bold: customRow.selected || customRow.active
                    }

                    // Palette preview, in this theme's own corner radius
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: {
                                const p = customRow.rowPalette
                                if (!p)
                                    return []
                                return [p.red, p.yellow, p.green, p.blue, p.mauve, p.text]
                            }

                            delegate: Rectangle {
                                required property var modelData
                                width: 10
                                height: 10
                                radius: Math.min(5, customRow.rowStyle.radius)
                                color: modelData
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 104
                        anchors.verticalCenter: parent.verticalCenter
                        visible: customRow.active
                        text: "active"
                        color: Theme.overlay0
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: customArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.customIndex = customRow.index
                        onClicked: {
                            root.customIndex = customRow.index
                            root.apply()
                            root.close()
                        }
                    }
                }
            }

            // ---------------- Fonts ----------------
            ListView {
                id: fontList

                anchors.fill: parent
                clip: true
                model: root.fontList
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.fontIndex
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 44
                preferredHighlightEnd: height - 44

                opacity: root.onFonts ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                }

                delegate: Rectangle {
                    id: fontRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: fontRow.index === root.fontIndex
                    readonly property bool active: fontRow.modelData === Theme.fontMono

                    width: fontList.width
                    height: 44
                    radius: Theme.radius
                    color: {
                        if (fontRow.selected)
                            return Theme.surface0
                        return fontArea.containsMouse ? Theme.hover : "transparent"
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        // Drawn in the font it names, so the list previews itself
                        text: fontRow.modelData.replace(/ Nerd Font$/, "")
                        color: fontRow.active ? Theme.mauve : Theme.text
                        font.family: fontRow.modelData
                        font.weight: fontRow.active ? Theme.fontWeight : Font.Normal
                        font.pixelSize: 14
                    }

                    // Weight, only on the active family — it is a global
                    // setting, so showing it on every row would imply
                    // otherwise.
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: fontRow.active
                        text: root.weightName
                        color: fontRow.selected ? Theme.blue : Theme.overlay0
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !fontRow.active && fontRow.selected
                        text: "enter to use"
                        color: Theme.overlay0
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: fontArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: root.fontIndex = fontRow.index
                        onClicked: {
                            root.fontIndex = fontRow.index
                            root.apply()
                            root.close()
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: openAnim

        NumberAnimation { target: backdrop; property: "opacity"; to: Theme.backdropOpacity(0.5); duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "offset"; from: 48; to: 0; duration: 280; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: Theme.backdropOpacity(0); duration: 130; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "offset"; to: 48; duration: 150; easing.type: Easing.InCubic }
        }

        ScriptAction {
            script: root.visible = false
        }
    }
}
