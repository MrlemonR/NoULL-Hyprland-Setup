import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Pano geçmişi paneli — Super+V.
//
//   qs -c topbar ipc call clipboard toggle
PanelWindow {
    id: root

    property bool shown: false

    readonly property int bottomGap: 18

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
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open() {
        ClipboardService.reset()
        ClipboardService.refresh()
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

    // Seçileni panoya al, paneli kapat ve odaklı pencereye yapıştır.
    // Girdi geçmişten SİLİNMİYOR; panoya kopyalandığı için de en üstteki
    // (son kopyalanan) kayıt hâline geliyor.
    function activateSelected() {
        if (!ClipboardService.copySelected())
            return
        root.close()
        // Panel kapanıp odak eski pencereye dönene kadar bekle, sonra Ctrl+V
        pasteTimer.restart()
    }

    readonly property string pasteScript: Quickshell.env("HOME") + "/.local/bin/qs-paste"

    Timer {
        id: pasteTimer

        interval: 260
        repeat: false
        onTriggered: Quickshell.execDetached([root.pasteScript])
    }

    IpcHandler {
        target: "clipboard"

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

        readonly property int rowHeight: 74

        anchors.horizontalCenter: parent.horizontalCenter
        // Slides up from below, like the launcher and the settings screen.
        // A hidden PanelWindow reports the wrong height for the first few
        // frames (gotcha #20), so the animation moves a separate offset and
        // leaves this binding alone rather than animating `y` directly.
        y: root.height - height - root.bottomGap + panel.offset

        property real offset: 0
        width: 560
        height: 62 + tabRow.height + listArea.height + 12
        color: Theme.panelColor
        border.color: Theme.surface0
        border.width: Theme.borderWidth
        radius: Theme.radiusPanel

        // Aero sheen. Inert on the standard themes — Theme.gloss is 0 — and
        // declared first so it sits under the content rather than over it.
        GlossOverlay {
            anchors.fill: parent
            radius: parent.radius
            midline: 0.3
        }

        opacity: 0

        // ---------------- Arama ----------------
        Item {
            id: searchRow

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 60

            Text {
                id: searchIcon

                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                font.family: Theme.fontMono
                font.weight: Theme.fontWeight
                font.pixelSize: 18
                color: Theme.overlay0
            }

            TextInput {
                id: input

                anchors.left: searchIcon.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.pixelSize: 16
                selectionColor: Theme.mauve
                selectedTextColor: Theme.textOn(Theme.mauve)
                clip: true
                focus: true

                text: ClipboardService.query
                onTextChanged: ClipboardService.query = text

                Keys.onUpPressed: ClipboardService.move(-1)
                Keys.onDownPressed: ClipboardService.move(1)
                Keys.onEscapePressed: root.close()

                // Sol/sağ ok: All / Text / Images arasında geçiş
                Keys.onLeftPressed: event => {
                    // Ctrl/Shift ile metin içinde gezinme çalışmaya devam etsin
                    if (event.modifiers !== Qt.NoModifier) {
                        event.accepted = false
                        return
                    }
                    ClipboardService.nextTab(-1)
                }

                Keys.onRightPressed: event => {
                    if (event.modifiers !== Qt.NoModifier) {
                        event.accepted = false
                        return
                    }
                    ClipboardService.nextTab(1)
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activateSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        ClipboardService.nextTab(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                        event.accepted = true
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0
                    text: "Search clipboard…"
                    color: Theme.surface2
                    font.pixelSize: 16
                }
            }
        }

        // ---------------- Sekmeler ----------------
        Item {
            id: tabRow

            anchors.top: searchRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: ClipboardService.tabs

                    delegate: Rectangle {
                        id: tab

                        required property var modelData

                        readonly property bool current: tab.modelData.id === ClipboardService.activeKind

                        width: tabLabel.implicitWidth + 26
                        height: 28
                        radius: Theme.radius
                        color: "transparent"

                        ButtonSurface {
                            anchors.fill: parent
                            radius: parent.radius
                            hovered: tabArea.containsMouse
                            active: tab.current
                            accentColor: Theme.surface1
                            restingColor: "transparent"
                        }

                        Text {
                            id: tabLabel

                            anchors.centerIn: parent
                            text: tab.modelData.label
                            color: tab.current ? Theme.text : Theme.subtext0
                            font.pixelSize: 13
                            font.bold: tab.current
                        }

                        MouseArea {
                            id: tabArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardService.setKind(tab.modelData.id)
                        }
                    }
                }
            }

            // Wipe the history, on the same line as the tabs. Two presses:
            // the first turns it into a confirmation, so a stray click on a
            // row that sits right next to Images cannot erase everything.
            Rectangle {
                id: clearButton

                property bool confirming: false

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: clearLabel.implicitWidth + 20
                height: 24
                radius: Theme.radius
                color: {
                    if (clearButton.confirming)
                        return clearArea.containsMouse ? Theme.red : Theme.dangerBg
                    return clearArea.containsMouse ? Theme.surface0 : "transparent"
                }
                // Tied to the whole history, not the filtered view: on the
                // Images tab with no images the history is still there to
                // delete, and hiding the button then would say otherwise.
                visible: ClipboardService.entries.length > 0 || clearButton.confirming

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    id: clearLabel

                    anchors.centerIn: parent
                    text: clearButton.confirming ? "Sure?" : "Delete all"
                    color: {
                        if (clearButton.confirming)
                            return clearArea.containsMouse ? Theme.base : Theme.red
                        return clearArea.containsMouse ? Theme.red : Theme.subtext0
                    }
                    font.pixelSize: 12
                    font.bold: clearButton.confirming
                }

                // Give up on the confirmation rather than leaving it armed
                Timer {
                    id: confirmTimer

                    interval: 3000
                    repeat: false
                    onTriggered: clearButton.confirming = false
                }

                MouseArea {
                    id: clearArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (clearButton.confirming) {
                            clearButton.confirming = false
                            confirmTimer.stop()
                            ClipboardService.clearAll()
                        } else {
                            clearButton.confirming = true
                            confirmTimer.restart()
                        }
                    }
                }
            }
        }

        // ---------------- Girdiler ----------------
        Item {
            id: listArea

            anchors.top: tabRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            height: Math.min(4.4 * panel.rowHeight, Math.max(panel.rowHeight, list.contentHeight))

            Behavior on height {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: ClipboardService.results
                currentIndex: ClipboardService.selectedIndex
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: panel.rowHeight
                preferredHighlightEnd: height - panel.rowHeight

                delegate: Rectangle {
                    id: entryRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: entryRow.index === ClipboardService.selectedIndex
                    readonly property bool isImage: entryRow.modelData.kind === "image"

                    width: list.width
                    height: panel.rowHeight
                    radius: Theme.radius
                    color: {
                        if (entryRow.selected)
                            return Theme.selected
                        return entryArea.containsMouse ? Theme.hover : Theme.mantle
                    }

                    // Sol vurgu şeridi
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - 18
                        radius: Theme.radiusUpTo(3)
                        color: Theme.green
                        visible: entryRow.selected
                    }

                    // Metin önizlemesi
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: metaColumn.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !entryRow.isImage
                        text: entryRow.modelData.preview
                        color: entryRow.selected ? Theme.text : Theme.subtext0
                        font.pixelSize: 13
                        font.bold: entryRow.selected
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    // Görsel önizlemesi
                    Item {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: metaColumn.left
                        anchors.rightMargin: 10
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        visible: entryRow.isImage

                        Image {
                            id: thumb

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: Math.min(parent.width, height * 1.7)
                            source: entryRow.isImage ? ClipboardService.thumbFor(entryRow.modelData.id) : ""
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 480
                            sourceSize.height: 480
                            asynchronous: true
                            smooth: true
                            visible: source != "" && status === Image.Ready
                        }

                        Text {
                            anchors.left: thumb.visible ? thumb.right : parent.left
                            anchors.leftMargin: thumb.visible ? 10 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: entryRow.modelData.preview
                            color: Theme.overlay0
                            font.pixelSize: 11
                        }
                    }

                    // Sabitleme ve sil
                    Column {
                        id: metaColumn

                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            anchors.right: parent.right
                            text: "󰐃"
                            font.family: Theme.fontMono
                            font.weight: Theme.fontWeight
                            font.pixelSize: 12
                            color: entryRow.modelData.pinned ? Theme.yellow : Theme.surface1
                            visible: entryRow.modelData.pinned || entryArea.containsMouse

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClipboardService.togglePin(entryRow.modelData.id)
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            text: "󰅖"
                            font.family: Theme.fontMono
                            font.weight: Theme.fontWeight
                            font.pixelSize: 11
                            color: Theme.surface1
                            visible: entryArea.containsMouse

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ClipboardService.remove(entryRow.modelData.id)
                            }
                        }
                    }

                    MouseArea {
                        id: entryArea

                        anchors.fill: parent
                        anchors.rightMargin: 34
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: ClipboardService.selectedIndex = entryRow.index
                        onClicked: {
                            ClipboardService.selectedIndex = entryRow.index
                            root.activateSelected()
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: ClipboardService.results.length === 0
                text: ClipboardService.query.length > 0 ? "No matches" : "Clipboard is empty"
                color: Theme.surface2
                font.pixelSize: 13
            }
        }
    }

    // ---------------- Animasyonlar ----------------
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
            script: {
                root.visible = false
                ClipboardService.reset()
            }
        }
    }
}
