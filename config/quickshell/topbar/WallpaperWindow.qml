import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Duvar kağıdı seçici — Super+Shift+Z.
// Yatay bir karusel: ortadaki büyük ve net, yanlar küçük ve soluk.
// Duvar kağıtları etkin temanın klasöründen geliyor (qs-wallpaper list).
PanelWindow {
    id: root

    property bool shown: false
    property var images: []
    property int currentIndex: 0

    // "static" = tema klasörü, "animated" = <tema>/Animated (video/gif).
    // Yukarı/aşağı ok tuşları ikisi arasında geçiyor.
    property string category: "static"

    readonly property bool animated: root.category === "animated"

    // Videonun önizleme karesi: qs-wallpaper aynı adı (yolun md5'i) üretiyor
    function thumbFor(path) {
        return Quickshell.env("HOME") + "/.cache/qs-wallpaper-thumbs/"
            + Qt.md5(path) + ".png"
    }

    function setCategory(value) {
        if (root.category === value)
            return
        root.category = value
        root.currentIndex = 0
        root.images = []
        listProc.running = true
    }

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-wallpaper"

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
    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open() {
        // Önce mevcut duvar kağıdını öğren, listeyi ondan sonra al ki
        // karusel şu an seçili olandan başlasın
        currentProc.running = true
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
        const count = root.images.length
        if (count === 0)
            return
        root.currentIndex = Math.max(0, Math.min(count - 1, root.currentIndex + delta))
        strip.positionViewAtIndex(root.currentIndex, ListView.Center)
    }

    function apply() {
        const img = root.images[root.currentIndex]
        if (!img)
            return
        // "show" quickshell animasyonunu tetikliyor, sonra kendisi uyguluyor
        Quickshell.execDetached([root.script, "show", img])
    }

    IpcHandler {
        target: "wallpaper"

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

    // Etkin duvar kağıdının yolu
    property string activePath: ""

    Process {
        id: currentProc

        command: [root.script, "current"]
        running: false

        stdout: StdioCollector {
            id: currentCollector

            // DİKKAT: listeyi onExited'da başlatmak yanlıştı — stdout bazen
            // çıkıştan sonra tamamlanıyor ve activePath boş kalıyordu.
            onStreamFinished: {
                root.activePath = currentCollector.text.trim()
                listProc.running = true
            }
        }
    }

    Process {
        id: listProc

        command: [root.script, root.animated ? "list-animated" : "list"]
        running: false

        stdout: StdioCollector {
            id: listCollector

            onStreamFinished: {
                const lines = listCollector.text.split("\n").map(v => v.trim()).filter(v => v.length > 0)
                root.images = lines

                // Şu an seçili duvar kağıdını bul, yoksa baştan başla
                let index = lines.indexOf(root.activePath)
                if (index < 0 && root.activePath.length > 0) {
                    // Yol farklı yazılmış olabilir, dosya adına göre dene
                    const name = root.activePath.split("/").pop()
                    index = lines.findIndex(v => v.split("/").pop() === name)
                }
                root.currentIndex = index >= 0 ? index : 0
                positionTimer.restart()
            }
        }
    }

    Timer {
        id: positionTimer

        interval: 80
        repeat: false
        onTriggered: strip.positionViewAtIndex(root.currentIndex, ListView.Center)
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

    Item {
        id: content

        anchors.fill: parent
        opacity: 0

        FocusScope {
            id: keyCatcher

            anchors.fill: parent
            focus: true

            Keys.onLeftPressed: root.move(-1)
            Keys.onRightPressed: root.move(1)
            Keys.onUpPressed: root.setCategory("static")
            Keys.onDownPressed: root.setCategory("animated")
            Keys.onEscapePressed: root.close()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.apply()
                    root.close()
                    event.accepted = true
                }
            }
        }

        // ---------------- Karusel ----------------
        ListView {
            id: strip

            anchors.centerIn: parent
            width: parent.width
            height: 460
            orientation: ListView.Horizontal
            spacing: 14
            clip: false
            model: root.images
            preferredHighlightBegin: width / 2 - 380
            preferredHighlightEnd: width / 2 + 380
            highlightRangeMode: ListView.ApplyRange
            currentIndex: root.currentIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: card

                required property string modelData
                required property int index

                readonly property bool current: card.index === root.currentIndex

                // Yatay ListView dikey yerleşimi delegate yüksekliğine göre
                // yapıyor; anchor kullanmak yerleşimle çakışıyordu.
                width: card.current ? 720 : 150
                height: strip.height

                Behavior on width {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    id: frame

                    anchors.centerIn: parent
                    width: parent.width
                    height: card.current ? strip.height : strip.height * 0.72
                    color: Theme.mantle
                    border.width: card.current ? 2 : 0
                    border.color: Theme.text
                    clip: true

                    Behavior on height {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: frame.border.width
                        source: "file://" + (root.animated ? root.thumbFor(card.modelData) : card.modelData)
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 1600
                        sourceSize.height: 900
                        asynchronous: true
                        cache: true
                        smooth: true
                        opacity: card.current ? 1 : 0.4

                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (!card.current) {
                            root.currentIndex = card.index
                            strip.positionViewAtIndex(card.index, ListView.Center)
                            return
                        }

                        root.apply()
                        root.close()
                    }
                }
            }
        }

        // ---------------- Bilgi ----------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: strip.bottom
            anchors.topMargin: 24
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const img = root.images[root.currentIndex]
                    if (!img)
                        return "No wallpapers found"
                    return img.split("/").pop()
                }
                color: Theme.text
                font.pixelSize: 15
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.images.length > 0
                    ? (root.currentIndex + 1) + " / " + root.images.length
                        + "   ·   " + Theme.labelFor(Theme.name)
                    : "Put images in ~/Pictures/Wallpapers/<theme>/"
                color: Theme.overlay0
                font.pixelSize: 11
            }

            // Kategori göstergesi: Static | Animated
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Text {
                    text: "Static"
                    color: root.animated ? Theme.surface2 : Theme.mauve
                    font.pixelSize: 12
                    font.bold: !root.animated
                }

                Text {
                    text: "·"
                    color: Theme.surface2
                    font.pixelSize: 12
                }

                Text {
                    text: "Animated"
                    color: root.animated ? Theme.mauve : Theme.surface2
                    font.pixelSize: 12
                    font.bold: root.animated
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "←→ browse   ↑↓ static/animated   ⏎ apply   esc close"
                color: Theme.surface2
                font.pixelSize: 10
            }
        }
    }

    ParallelAnimation {
        id: openAnim

        NumberAnimation { target: backdrop; property: "opacity"; to: 0.93; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InQuad }
            NumberAnimation { target: content; property: "opacity"; to: 0; duration: 130; easing.type: Easing.InQuad }
        }

        ScriptAction {
            script: root.visible = false
        }
    }
}
