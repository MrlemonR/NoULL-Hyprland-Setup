import QtQuick
import Quickshell
import Quickshell.Io

// Başlatıcı kutusu: üstte arama satırı, altında sekmeler, altında sonuç listesi.
// Files sekmesinde sağda önizleme paneli açılıyor.
Item {
    id: root

    signal requestClose

    readonly property int rowHeight: 46
    readonly property int listWidth: 560
    readonly property int previewWidth: 400
    readonly property bool previewOpen: LauncherService.activeProvider
        && LauncherService.activeProvider.hasPreview
        && LauncherService.results.length > 0

    implicitWidth: previewOpen ? listWidth + previewWidth : listWidth
    implicitHeight: 62 + tabRow.height + listArea.height + 12

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    function focusInput() {
        input.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.base
        border.color: Theme.surface0
        border.width: 1
        radius: 0

        // ---------------- Arama satırı ----------------
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
                font.family: "JetBrainsMono Nerd Font"
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
                selectedTextColor: Theme.crust
                clip: true
                focus: true

                text: LauncherService.query
                onTextChanged: LauncherService.query = text

                Keys.onUpPressed: LauncherService.move(-1)
                Keys.onDownPressed: LauncherService.move(1)
                Keys.onEscapePressed: root.requestClose()

                // Sol/sağ ok: sekmeler arasında geçiş.
                // Metin içinde imleç gezdirmek için Home/End ve Ctrl+ok var.
                Keys.onLeftPressed: event => {
                    // Ctrl/Shift ile metin içinde gezinme çalışmaya devam etsin
                    if (event.modifiers !== Qt.NoModifier) {
                        event.accepted = false
                        return
                    }
                    LauncherService.nextTab(-1)
                }

                Keys.onRightPressed: event => {
                    if (event.modifiers !== Qt.NoModifier) {
                        event.accepted = false
                        return
                    }
                    LauncherService.nextTab(1)
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (LauncherService.activateSelected())
                            root.requestClose()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        LauncherService.nextTab(event.modifiers & Qt.ShiftModifier ? -1 : 1)
                        event.accepted = true
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0
                    text: "Type to search apps, files, settings…"
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
                    model: LauncherService.providers

                    delegate: Rectangle {
                        id: tab

                        required property var modelData

                        readonly property bool current: tab.modelData.providerId === LauncherService.activeTab

                        width: tabLabel.implicitWidth + 26
                        height: 28
                        radius: 0
                        color: {
                            if (tab.current)
                                return Theme.peach
                            return tabArea.containsMouse ? Theme.surface0 : "transparent"
                        }

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            id: tabLabel

                            anchors.centerIn: parent
                            text: tab.modelData.label
                            color: tab.current ? Theme.crust : Theme.subtext0
                            font.pixelSize: 13
                            font.bold: tab.current
                        }

                        MouseArea {
                            id: tabArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LauncherService.setTab(tab.modelData.providerId)
                        }
                    }
                }
            }
        }

        // ---------------- İçerik ----------------
        Item {
            id: listArea

            anchors.top: tabRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            // Önizleme açıkken alan sonuç sayısına göre kısalmasın; tek sonuç
            // varken önizleme yarım kalıyordu
            height: {
                const natural = Math.min(6 * root.rowHeight, Math.max(root.rowHeight, list.contentHeight))
                return root.previewOpen ? Math.max(natural, 5 * root.rowHeight) : natural
            }

            Behavior on height {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            ListView {
                id: list

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root.previewOpen ? root.listWidth - 20 : parent.width
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: LauncherService.results
                currentIndex: LauncherService.selectedIndex
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: root.rowHeight
                preferredHighlightEnd: height - root.rowHeight

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                delegate: Rectangle {
                    id: resultRow

                    required property var modelData
                    required property int index

                    readonly property bool selected: resultRow.index === LauncherService.selectedIndex

                    width: list.width
                    height: root.rowHeight
                    radius: 0
                    color: {
                        if (resultRow.selected)
                            return Qt.rgba(Theme.peach.r, Theme.peach.g, Theme.peach.b, 0.14)
                        return rowArea.containsMouse ? Theme.hover : "transparent"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height - 16
                        radius: 0
                        color: Theme.peach
                        visible: resultRow.selected
                    }

                    Image {
                        id: rowIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        sourceSize.width: 52
                        sourceSize.height: 52
                        source: resultRow.modelData.icon || ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        visible: source != "" && status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: rowIcon
                        visible: !rowIcon.visible
                        text: resultRow.modelData.glyph
                            || (LauncherService.activeProvider ? LauncherService.activeProvider.glyph : "󰀻")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 17
                        color: resultRow.selected ? Theme.peach : Theme.overlay0
                    }

                    Column {
                        anchors.left: rowIcon.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: resultRow.modelData.title
                            color: Theme.text
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Text {
                            width: parent.width
                            text: resultRow.modelData.subtitle
                            color: Theme.overlay0
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            visible: text.length > 0
                        }
                    }

                    MouseArea {
                        id: rowArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onPositionChanged: LauncherService.selectedIndex = resultRow.index

                        onClicked: mouse => {
                            LauncherService.selectedIndex = resultRow.index
                            if (mouse.button === Qt.RightButton) {
                                // Sağ tık: favorilere ekle / çıkar
                                LauncherService.toggleFavorite(resultRow.modelData)
                                return
                            }
                            if (LauncherService.activateSelected())
                                root.requestClose()
                        }
                    }
                }
            }

            // ---------------- Önizleme (Files) ----------------
            LauncherPreview {
                anchors.left: list.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: root.previewOpen
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }
            }

            // Boş durum
            Text {
                anchors.centerIn: parent
                visible: LauncherService.results.length === 0
                text: {
                    if (LauncherService.query.length === 0)
                        return LauncherService.activeTab === "files"
                            ? "Start typing to search files"
                            : "Nothing here yet"
                    return "No results"
                }
                color: Theme.surface2
                font.pixelSize: 13
            }
        }
    }
}
