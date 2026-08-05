import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Hatırlatma bildirimindeki "Önizle" tıklanınca açılan not penceresi:
// notun tam metni ve eklenen resimler.
//
// Not kimliği ~/.cache/qs-note-preview dosyasından okunuyor:
//   qs -c topbar ipc call notePreview preview
PanelWindow {
    id: root

    property bool shown: false
    property string noteId: ""

    readonly property var note: root.noteId.length > 0 ? CalendarService.noteById(root.noteId) : null
    readonly property var images: root.note ? (root.note.images || []) : []

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
    WlrLayershell.namespace: "quickshell-note-preview"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // quickshell 0.3.0'da "ipc call" argüman kabul etmiyor, bu yüzden hangi
    // notun açılacağını script bu dosyaya yazıyor, biz de burada okuyoruz.
    readonly property int bottomGap: 18

    readonly property string handoffPath: Quickshell.env("HOME") + "/.cache/qs-note-preview"

    FileView {
        id: handoffFile

        path: root.handoffPath
        blockLoading: false
        printErrors: false

        onLoaded: {
            if (!root.showRequested)
                return
            root.showRequested = false
            root.showId(handoffFile.text().trim())
        }
    }

    // DİKKAT: FileView açılışta da yükleniyor ve onLoaded tetikleniyor.
    // Bu bayrak olmadan pencere quickshell başlar başlamaz kendiliğinden
    // açılıyor ve Exclusive klavye odağıyla her şeyi (slurp dahil) kilitliyordu.
    property bool showRequested: false

    function show() {
        // reload() eşzamansız; not kimliğini FileView.onLoaded içinde alıyoruz
        root.showRequested = true
        handoffFile.reload()
    }

    function showId(id) {
        root.noteId = id
        root.shown = true
    }

    function close() {
        root.shown = false
    }

    // Notu sil ve pencereyi kapat (onay sorulmuyor, istenen davranış bu)
    function removeNote() {
        if (root.noteId.length > 0)
            CalendarService.removeNote(root.noteId)
        root.close()
    }

    IpcHandler {
        target: "notePreview"

        function preview(): void {
            root.show()
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
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - root.bottomGap
        width: 560
        height: Math.min(root.height * 0.7, cardHeader.height + contentColumn.implicitHeight + 46)
        color: Theme.base
        border.color: Theme.surface0
        border.width: 1
        radius: 0

        opacity: 0
        scale: 0.94
        transformOrigin: Item.Center

        focus: true
        Keys.onEscapePressed: root.close()

        // ---------------- Başlık ----------------
        Item {
            id: cardHeader

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 48

            Text {
                id: headerIcon

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "󰎞"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                color: Theme.blue
            }

            Column {
                anchors.left: headerIcon.right
                anchors.leftMargin: 12
                anchors.right: deleteButton.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: root.note
                        ? Qt.formatDate(CalendarService.keyToDate(root.note.date), "dddd, d MMMM yyyy")
                        : "Note not found"
                    color: Theme.text
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.note !== null
                    text: root.note ? CalendarService.noteClock(root.note) : ""
                    color: Theme.mauve
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            // Tek buton: notu sil. Pencereyi kapatmak için Esc ya da dışarı
            // tıklamak var, ayrı bir kapat düğmesi istenmedi.
            Rectangle {
                id: deleteButton

                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: deleteRow.implicitWidth + 22
                height: 26
                color: deleteArea.containsMouse ? Theme.red : Theme.surface0
                visible: root.note !== null

                Behavior on color {
                    ColorAnimation { duration: 110 }
                }

                Row {
                    id: deleteRow

                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰩹"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: deleteArea.containsMouse ? Theme.base : Theme.subtext0
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Delete"
                        font.pixelSize: 12
                        font.bold: true
                        color: deleteArea.containsMouse ? Theme.base : Theme.subtext0
                    }
                }

                MouseArea {
                    id: deleteArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removeNote()
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.surface0
            }
        }

        // ---------------- İçerik ----------------
        Flickable {
            anchors.top: cardHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            clip: true
            contentHeight: contentColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentColumn

                width: parent.width
                spacing: 14
                topPadding: 16
                bottomPadding: 16
                leftPadding: 16
                rightPadding: 16

                Text {
                    width: parent.width - 32
                    text: root.note ? root.note.text : "This note may have been deleted."
                    color: Theme.text
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    visible: text.length > 0
                }

                Repeater {
                    model: root.images

                    delegate: Rectangle {
                        id: imageBox

                        required property string modelData

                        width: contentColumn.width - 32
                        height: 240
                        color: Theme.mantle
                        border.width: 1
                        border.color: Theme.surface0
                        clip: true

                        Image {
                            id: preview

                            anchors.fill: parent
                            anchors.margins: 1
                            source: "file://" + imageBox.modelData
                            fillMode: Image.PreserveAspectFit
                            // SVG'ler kendi küçük boyutlarında kalmasın
                            sourceSize.width: 1024
                            sourceSize.height: 1024
                            asynchronous: true
                            smooth: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: preview.status === Image.Error
                            text: "Could not load image"
                            color: Theme.surface2
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }

    // ---------------- Animasyonlar ----------------
    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: backdrop
            property: "opacity"
            to: 0.5
            duration: 170
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: card
            property: "opacity"
            to: 1
            duration: 160
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: card
            property: "scale"
            to: 1
            duration: 250
            easing.type: Easing.OutBack
            easing.overshoot: 0.9
        }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "opacity"
                to: 0
                duration: 130
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: card
                property: "opacity"
                to: 0
                duration: 110
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: card
                property: "scale"
                to: 0.94
                duration: 130
                easing.type: Easing.InQuad
            }
        }

        ScriptAction {
            script: {
                root.visible = false
                root.noteId = ""
            }
        }
    }
}
