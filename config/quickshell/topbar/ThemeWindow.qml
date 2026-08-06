import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Theme and font picker — Super+Ctrl+Z.
//
// Two sections side by side, Left/Right moves between them:
//   Themes  applied by qs-theme across quickshell, kitty, GTK, Kvantum, nvim
//   Fonts   applied by qs-font across nine targets; Space on a row cycles the
//           weight through Thin…ExtraBold without leaving the row
//
// Up/Down walks the active section, Enter applies and closes. Typing searches
// the theme list; the font list is short enough not to need it.
PanelWindow {
    id: root

    property bool shown: false
    property string query: ""
    property int selectedIndex: 0

    // 0 = themes, 1 = fonts
    property int section: 0
    property int fontIndex: 0

    readonly property bool onFonts: root.section === 1
    readonly property var fontList: FontService.families

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-theme"

    readonly property int bottomGap: 18

    readonly property var results: {
        const q = root.query.trim().toLowerCase()
        const out = []
        const names = Theme.themeNames

        for (let i = 0; i < names.length; i++) {
            const label = Theme.labelFor(names[i])
            if (q.length > 0 && label.toLowerCase().indexOf(q) < 0 && names[i].indexOf(q) < 0)
                continue
            out.push({ name: names[i], label: label })
        }
        return out
    }

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

        // Start the font cursor on the family in use
        root.section = 0
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
        const count = root.results.length
        if (count === 0)
            return
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count
    }

    function setSection(next) {
        if (next === root.section || next < 0 || next > 1)
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
        const item = root.results[root.selectedIndex]
        if (!item)
            return
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

        // Straight to the font section, the way `launcher system` skips to a
        // tab. Also the only way to reach it without a keyboard.
        function fonts(): void {
            root.open()
            root.section = 1
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
        y: root.height - height - root.bottomGap
        width: 440
        height: 60 + listArea.height + 12
        color: Theme.base
        border.color: Theme.surface0
        border.width: 1
        radius: 0

        opacity: 0
        scale: 0.94
        transformOrigin: Item.Center

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
                selectedTextColor: Theme.crust
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
                // cursor: the search box only serves the theme list, and
                // walking a name character by character is not worth a key.
                Keys.onLeftPressed: root.setSection(0)
                Keys.onRightPressed: root.setSection(1)

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
                    text: root.onFonts
                        ? "Fonts — space cycles weight, ← back to themes"
                        : "Search themes…    → fonts"
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
            height: Math.max(44, Math.min(6 * 44,
                root.onFonts ? fontList.contentHeight : list.contentHeight))

            Behavior on height {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                model: root.results
                boundsBehavior: Flickable.StopAtBounds

                opacity: root.onFonts ? 0 : 1
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
                    radius: 0
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
                                radius: 0
                                color: modelData
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 96
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
                    radius: 0
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

        NumberAnimation { target: backdrop; property: "opacity"; to: 0.5; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: 130; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 110; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "scale"; to: 0.94; duration: 130; easing.type: Easing.InQuad }
        }

        ScriptAction {
            script: root.visible = false
        }
    }
}
