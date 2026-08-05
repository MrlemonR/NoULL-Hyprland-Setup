import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Tema seçici — Super+Ctrl+Z.
// Seçilen temayı qs-theme scripti quickshell, kitty, GTK, Kvantum ve nvim'e
// birlikte uyguluyor.
PanelWindow {
    id: root

    property bool shown: false
    property string query: ""
    property int selectedIndex: 0

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
        const count = root.results.length
        if (count === 0)
            return
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count
    }

    function apply() {
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
                font.family: "JetBrainsMono Nerd Font"
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
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.apply()
                        root.close()
                        event.accepted = true
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0
                    text: "Search themes…"
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
            height: Math.max(44, Math.min(6 * 44, list.contentHeight))

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                model: root.results
                boundsBehavior: Flickable.StopAtBounds

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
