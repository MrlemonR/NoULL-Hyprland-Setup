import QtQuick
import Quickshell
import Quickshell.Io

// Files sekmesindeki önizleme paneli: dosya adı, yolu, boyutu ve varsa
// görsel önizlemesi (resimler doğrudan, PDF'lerin ilk sayfası).
Item {
    id: root

    readonly property var item: LauncherService.selectedItem
    readonly property string filePath: root.item && root.item.data && root.item.data.path
        ? root.item.data.path
        : ""

    property string previewImage: ""

    readonly property string previewScript: Quickshell.env("HOME") + "/.local/bin/qs-file-preview"

    onFilePathChanged: {
        root.previewImage = ""
        if (root.filePath.length === 0)
            return
        previewDebounce.restart()
    }

    Timer {
        id: previewDebounce

        interval: 140
        repeat: false
        onTriggered: {
            if (previewProc.running)
                previewProc.running = false
            previewProc.command = [root.previewScript, root.filePath]
            previewProc.running = true
        }
    }

    Process {
        id: previewProc

        running: false

        stdout: StdioCollector {
            id: previewCollector

            onStreamFinished: {
                const path = previewCollector.text.trim()
                root.previewImage = path.length > 0 ? path : ""
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
        clip: true

        // ---- Başlık ----
        Column {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 2

            Text {
                width: parent.width
                text: root.item ? root.item.title : ""
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                text: root.item ? root.item.subtitle : ""
                color: Theme.overlay0
                font.pixelSize: 11
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                text: root.item && root.item.data && root.item.data.size ? root.item.data.size : ""
                color: Theme.surface2
                font.pixelSize: 10
                visible: text.length > 0
            }
        }

        Rectangle {
            id: headerLine

            anchors.top: header.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.surface0
        }

        // ---- Görsel önizleme ----
        Item {
            anchors.top: headerLine.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12

            Image {
                id: preview

                anchors.fill: parent
                source: root.previewImage.length > 0 ? "file://" + root.previewImage : ""
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 900
                sourceSize.height: 900
                asynchronous: true
                smooth: true
                visible: source != "" && status === Image.Ready
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: !preview.visible

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰈔"
                    font.family: Theme.fontMono
                    font.weight: Theme.fontWeight
                    font.pixelSize: 32
                    color: Theme.surface1
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.previewImage.length > 0 && preview.status === Image.Loading
                        ? "Loading preview…"
                        : "No preview available"
                    color: Theme.surface2
                    font.pixelSize: 11
                }
            }
        }
    }
}
