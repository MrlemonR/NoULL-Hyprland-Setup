import QtQuick
import Quickshell
import Quickshell.Io

// Takvimin dönüştüğü yatay not ekranı:
// üstte saat kaydırıcısı, altında dakika kaydırıcısı, altında not alanı ve
// resim ekleme. Sol üstte geri butonu, Enter kaydeder.
Item {
    id: root

    property string dateKey: ""

    signal back
    signal saved

    property int hour: 9
    property int minute: 0
    property var images: []

    // Resim seçici açıkken pencerenin odak yakalaması kapatılmalı, yoksa zenity
    // odağı alınca takvim kapanıp yazdıklarımız gidiyor
    readonly property bool busy: imagePicker.running

    implicitWidth: 620
    implicitHeight: 372

    function reset(key, initialHour, initialMinute) {
        root.dateKey = key
        root.hour = initialHour
        root.minute = initialMinute
        root.images = []
        noteText.text = ""
    }

    function focusText() {
        noteText.forceActiveFocus()
    }

    function startPicker() {
        imagePicker.running = true
    }

    function save() {
        CalendarService.addNote(root.dateKey, root.hour, root.minute, noteText.text, root.images)
        noteText.text = ""
        root.images = []
        root.saved()
    }

    // ---------------- Resim seçici ----------------
    Process {
        id: imagePicker

        command: ["zenity", "--file-selection", "--multiple", "--separator=\n",
                  "--title=Select an image to attach",
                  "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg"]

        stdout: StdioCollector {
            id: pickerCollector

            onStreamFinished: {
                const picked = pickerCollector.text
                    .split("\n")
                    .map(p => p.trim())
                    .filter(p => p.length > 0)

                if (picked.length > 0)
                    root.images = root.images.concat(picked)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelColor
        radius: Theme.radiusPanel

        // Aero sheen. Inert on the standard themes — Theme.gloss is 0 — and
        // declared first so it sits under the content rather than over it.
        GlossOverlay {
            anchors.fill: parent
            radius: parent.radius
            midline: 0.3
        }

        // ---------------- Başlık ----------------
        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44

            Rectangle {
                id: backButton

                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: backRow.implicitWidth + 14
                height: 26
                color: backArea.containsMouse ? Theme.surface0 : "transparent"

                Row {
                    id: backRow

                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "‹"
                        color: backArea.containsMouse ? Theme.mauve : Theme.text
                        font.pixelSize: 17
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Back"
                        color: backArea.containsMouse ? Theme.mauve : Theme.text
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: backArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.dateKey.length > 0
                    ? Qt.formatDate(CalendarService.keyToDate(root.dateKey), "dddd, d MMMM yyyy")
                    : ""
                color: Theme.text
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: (root.hour < 10 ? "0" : "") + root.hour + ":" + (root.minute < 10 ? "0" : "") + root.minute
                color: Theme.mauve
                font.pixelSize: 18
                font.bold: true
                font.family: Theme.fontMono
                font.weight: Theme.fontWeight
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.surface0
            }
        }

        // ---------------- Saat / dakika ----------------
        Column {
            id: sliders

            anchors.top: header.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 6

            HSlider {
                width: parent.width
                label: "HOUR"
                from: 0
                to: 23
                accent: Theme.mauve
                value: root.hour
                onValueChanged: root.hour = value
            }

            HSlider {
                width: parent.width
                label: "MINUTE"
                from: 0
                to: 59
                accent: Theme.blue
                value: root.minute
                onValueChanged: root.minute = value
            }
        }

        Rectangle {
            id: sliderSeparator

            anchors.top: sliders.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.surface0
        }

        // ---------------- Not metni ----------------
        Rectangle {
            id: noteBox

            anchors.top: sliderSeparator.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 74
            color: Theme.mantle
            border.width: Theme.borderWidth
            border.color: noteText.activeFocus ? Theme.mauve : Theme.surface0

            // Uzun notlarda kaydırılabilsin diye TextEdit bir Flickable içinde
            Flickable {
                id: noteFlick

                anchors.fill: parent
                anchors.margins: 9
                clip: true
                contentWidth: width
                contentHeight: noteText.contentHeight
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                // İmleç görünür kalsın
                function ensureCursorVisible() {
                    const r = noteText.cursorRectangle
                    if (r.y < contentY)
                        contentY = r.y
                    else if (r.y + r.height > contentY + height)
                        contentY = r.y + r.height - height
                }

                TextEdit {
                    id: noteText

                    width: noteFlick.width
                    color: Theme.text
                    font.pixelSize: 13
                    wrapMode: TextEdit.Wrap
                    selectionColor: Theme.mauve
                    selectedTextColor: Theme.base

                    onCursorRectangleChanged: noteFlick.ensureCursorVisible()

                    // Enter kaydeder, Shift+Enter alt satıra geçer
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (event.modifiers & Qt.ShiftModifier)
                                return
                            root.save()
                            event.accepted = true
                        }
                    }

                    Text {
                        anchors.fill: parent
                        visible: noteText.text.length === 0
                        text: "Write your note… (Enter saves, Shift+Enter for a new line)"
                        color: Theme.surface1
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        // ---------------- Resimler ----------------
        Item {
            id: imageRow

            anchors.top: noteBox.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 52

            Rectangle {
                id: addImage

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: 46
                color: addArea.containsMouse ? Theme.surface0 : Theme.mantle
                border.width: Theme.borderWidth
                border.color: addArea.containsMouse ? Theme.mauve : Theme.surface0

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: addArea.containsMouse ? Theme.mauve : Theme.overlay0
                    font.pixelSize: 22
                }

                MouseArea {
                    id: addArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startPicker()
                }
            }

            Row {
                anchors.left: addImage.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.images

                    delegate: Rectangle {
                        id: thumb

                        required property string modelData
                        required property int index

                        width: 46
                        height: 46
                        color: Theme.mantle
                        border.width: Theme.borderWidth
                        border.color: Theme.surface0
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: "file://" + thumb.modelData
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 92
                            sourceSize.height: 92
                            asynchronous: true
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            width: 14
                            height: 14
                            color: thumbArea.containsMouse ? Theme.red : Theme.crust
                            opacity: thumbArea.containsMouse ? 1 : 0.75

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Theme.fontMono
                                font.weight: Theme.fontWeight
                                font.pixelSize: 9
                                color: thumbArea.containsMouse ? Theme.base : Theme.text
                            }

                            MouseArea {
                                id: thumbArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.images = root.images.filter((_, i) => i !== thumb.index)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: saveButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: saveText.implicitWidth + 22
                height: 28
                color: saveArea.containsMouse ? Theme.mauve : Theme.surface0

                Text {
                    id: saveText

                    anchors.centerIn: parent
                    text: "Save ⏎"
                    color: saveArea.containsMouse ? Theme.base : Theme.text
                    font.pixelSize: 12
                    font.bold: true
                }

                MouseArea {
                    id: saveArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.save()
                }
            }
        }

        // ---------------- O günün kayıtlı notları ----------------
        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 42

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.surface0
            }

            Text {
                id: savedLabel

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "Saved"
                color: Theme.surface1
                font.pixelSize: 10
                font.bold: true
            }

            Text {
                anchors.left: savedLabel.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: dayNotes.count === 0
                text: "no notes for this day yet"
                color: Theme.surface1
                font.pixelSize: 11
            }

            ListView {
                id: dayNotes

                anchors.left: savedLabel.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.dateKey.length > 0 ? CalendarService.notesForDate(root.dateKey) : []

                delegate: Rectangle {
                    id: chip

                    required property var modelData

                    width: chipRow.implicitWidth + 14
                    height: 22
                    color: Theme.mantle
                    border.width: Theme.borderWidth
                    border.color: Theme.surface0

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: CalendarService.noteClock(chip.modelData)
                            color: Theme.mauve
                            font.pixelSize: 10
                            font.bold: true
                            font.family: Theme.fontMono
                            font.weight: Theme.fontWeight
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.text.length > 22
                                ? chip.modelData.text.substring(0, 22) + "…"
                                : chip.modelData.text
                            color: Theme.text
                            font.pixelSize: 11
                            textFormat: Text.PlainText
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: (chip.modelData.images || []).length > 0
                            text: "󰥶 " + (chip.modelData.images || []).length
                            color: Theme.blue
                            font.family: Theme.fontMono
                            font.weight: Theme.fontWeight
                            font.pixelSize: 9
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰅖"
                            font.family: Theme.fontMono
                            font.weight: Theme.fontWeight
                            font.pixelSize: 9
                            color: chipRemove.containsMouse ? Theme.red : Theme.surface2

                            MouseArea {
                                id: chipRemove

                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CalendarService.removeNote(chip.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
