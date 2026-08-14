import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Ekran görüntüsü arayüzü — Super+Shift+S.
//
// İki aşama:
//   1) mod seçimi: pencere / alan / tüm ekran
//   2) yakalanan görüntünün önizlemesi + "kaydedilsin mi?"
//      Evet -> Pictures/Screenshots + pano,  Hayır -> yalnızca pano
PanelWindow {
    id: root

    // "" = kapalı, "pick" = mod seçimi, "selecting" = slurp çalışıyor,
    // "confirm" = kaydetme sorusu
    property string stage: ""

    property string shotPath: ""
    property string savedPath: ""

    // Arayüz açılırken alınan tam ekran görüntüsü — arka planda gösterilince
    // ekran donmuş görünüyor. Seçimler de canlı ekrandan değil bundan
    // kırpılıyor, yani gördüğün kare ile kaydedilen kare aynı.
    property string freezePath: ""

    readonly property bool shown: stage.length > 0
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-screenshot"

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
    WlrLayershell.namespace: "quickshell-screenshot"
    // DİKKAT: "selecting" sırasında odağı bırakmak zorundayız. Katman
    // exclusive klavye odağını tutarsa slurp girdi alamıyor ve anında
    // "selection cancelled" ile çıkıyor.
    WlrLayershell.keyboardFocus: {
        if (root.stage === "pick" || root.stage === "confirm")
            return WlrKeyboardFocus.Exclusive
        return WlrKeyboardFocus.None
    }

    function open() {
        root.shotPath = ""
        root.savedPath = ""
        root.freezePath = ""

        // Bar da kareye giriyor: arayüz açıkken üstte donmuş kare durduğu
        // için bar canlı değil, o andaki hâliyle sabit görünüyor.
        freezeProc.command = [root.script, "freeze"]
        freezeProc.running = true
    }

    function close() {
        if (root.stage === "confirm")
            Quickshell.execDetached([root.script, "cancel"])
        root.dismiss()
    }

    // Mod seçildi: arayüzü gizle (kendimizi çekmeyelim), sonra yakala.
    //
    // DİKKAT: katmanı kaldırmayı kapanış animasyonuna bırakmıyoruz. Animasyon
    // bir sebeple tamamlanmazsa katman üstte asılı kalıyor, exclusive klavye
    // odağıyla slurp'ün girdi almasını engelliyor ve slurp anında
    // "selection cancelled" deyip çıkıyor. Bu yüzden hemen ve doğrudan
    // gizliyoruz.
    function capture(mode) {
        // Katman açık kalıyor: donmuş kare arka planda dururken slurp onun
        // üstünde seçim yaptırıyor. Sadece odağı ve panelleri bırakıyoruz.
        root.stage = "selecting"
        captureTimer.mode = mode
        captureTimer.restart()
    }

    function save() {
        saveProc.command = [root.script, "save"]
        saveProc.running = true
        root.dismiss()
    }

    function clipboardOnly() {
        Quickshell.execDetached([root.script, "discard"])
        root.dismiss()
    }

    // Paneli kapat ve katmanın gerçekten kalktığından emin ol
    function dismiss() {
        root.stage = ""
        openAnim.stop()
        closeAnim.restart()
        hideGuard.restart()
    }

    IpcHandler {
        target: "screenshot"

        function open(): void {
            root.open()
        }

        function close(): void {
            root.close()
        }


        function toggle(): void {
            if (root.shown)
                root.close()
            else
                root.open()
        }
    }

    // Kapanış animasyonu tamamlanmazsa katmanı yine de kaldır
    Timer {
        id: hideGuard

        interval: 260
        repeat: false
        onTriggered: {
            if (!root.shown)
                root.visible = false
        }
    }

    // Katmanın gerçekten kaybolması için bir kare bekliyoruz
    Timer {
        id: captureTimer

        property string mode: "region"

        interval: 180
        repeat: false
        onTriggered: {
            captureProc.command = [root.script, captureTimer.mode]
            captureProc.running = true
        }
    }

    Process {
        id: freezeProc

        running: false

        stdout: StdioCollector {
            id: freezeCollector

            onStreamFinished: {
                root.freezePath = freezeCollector.text.trim()
                root.stage = "pick"
            }
        }
    }

    Process {
        id: captureProc

        running: false

        stdout: StdioCollector {
            id: captureCollector

            onStreamFinished: {
                const path = captureCollector.text.trim()
                if (path.length === 0) {
                    // Kullanıcı seçimi iptal etti
                    root.stage = ""
                    return
                }
                root.shotPath = path
                root.stage = "confirm"
            }
        }
    }

    Process {
        id: saveProc

        running: false

        stdout: StdioCollector {
            id: saveCollector

            onStreamFinished: root.savedPath = saveCollector.text.trim()
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

    // Donmuş ekran görüntüsü — arka planda tam ekran
    Image {
        id: freezeImage

        anchors.fill: parent
        source: root.freezePath.length > 0 ? "file://" + root.freezePath : ""
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false
        visible: source != "" && status === Image.Ready
    }

    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Theme.crust
        opacity: 0

        // Seçim sırasında tıklamalar slurp'e gitmeli
        MouseArea {
            anchors.fill: parent
            enabled: root.stage === "pick" || root.stage === "confirm"
            onClicked: root.close()
        }
    }

    FocusScope {
        id: keyCatcher

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.close()
        Keys.onPressed: event => {
            if (root.stage === "pick") {
                if (event.key === Qt.Key_1 || event.key === Qt.Key_W) {
                    root.capture("window")
                    event.accepted = true
                } else if (event.key === Qt.Key_2 || event.key === Qt.Key_R) {
                    root.capture("region")
                    event.accepted = true
                } else if (event.key === Qt.Key_3 || event.key === Qt.Key_F) {
                    root.capture("screen")
                    event.accepted = true
                }
                return
            }

            if (root.stage === "confirm") {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Y) {
                    root.save()
                    event.accepted = true
                } else if (event.key === Qt.Key_N) {
                    root.clipboardOnly()
                    event.accepted = true
                }
            }
        }
    }

    // ---------------- 1. aşama: mod seçimi ----------------
    Rectangle {
        id: pickPanel

        anchors.centerIn: parent
        width: 520
        height: 190
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
        visible: root.stage === "pick"

        opacity: 0
        scale: 0.94
        transformOrigin: Item.Center

        Text {
            id: pickTitle

            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Take a screenshot"
            color: Theme.text
            font.pixelSize: 15
            font.bold: true
        }

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 12
            spacing: 14

            Repeater {
                model: [
                    { glyph: "󰖯", label: "Window", key: "1", mode: "window" },
                    { glyph: "󰆞", label: "Region", key: "2", mode: "region" },
                    { glyph: "󰍹", label: "Full screen", key: "3", mode: "screen" }
                ]

                delegate: Rectangle {
                    id: modeButton

                    required property var modelData

                    width: 148
                    height: 92
                    color: "transparent"
                    
                    ButtonSurface {
                        anchors.fill: parent
                        radius: parent.radius
                        hovered: modeArea.containsMouse
                        restingColor: Theme.mantle
                    }
                    border.width: Theme.borderWidth
                    border.color: modeArea.containsMouse ? Theme.mauve : Theme.surface0

                    Behavior on color {
                        ColorAnimation { duration: 110 }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modeButton.modelData.glyph
                            font.family: Theme.fontMono
                            font.weight: Theme.fontWeight
                            font.pixelSize: 24
                            color: modeArea.containsMouse ? Theme.mauve : Theme.subtext0
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modeButton.modelData.label
                            color: Theme.text
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modeButton.modelData.key
                            color: Theme.surface2
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: modeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.capture(modeButton.modelData.mode)
                    }
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: "esc cancel"
            color: Theme.surface2
            font.pixelSize: 10
        }
    }

    // ---------------- 2. aşama: kaydetme sorusu ----------------
    Rectangle {
        id: confirmPanel

        anchors.centerIn: parent
        width: 560
        height: 460
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
        visible: root.stage === "confirm"

        opacity: 0
        scale: 0.94
        transformOrigin: Item.Center

        Text {
            id: confirmTitle

            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Save this screenshot?"
            color: Theme.text
            font.pixelSize: 15
            font.bold: true
        }

        Rectangle {
            id: previewBox

            anchors.top: confirmTitle.bottom
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            height: 300
            color: Theme.mantle
            border.width: Theme.borderWidth
            border.color: Theme.surface0
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: root.shotPath.length > 0 ? "file://" + root.shotPath : ""
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 1200
                sourceSize.height: 1200
                asynchronous: true
                cache: false
                smooth: true
            }
        }

        Row {
            anchors.top: previewBox.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                width: 190
                height: 40
                color: yesArea.containsMouse ? Theme.green : Theme.surface0

                Behavior on color {
                    ColorAnimation { duration: 110 }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Yes — save to folder"
                        color: yesArea.containsMouse ? Theme.textOn(Theme.green) : Theme.text
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Screenshots + clipboard"
                        color: yesArea.containsMouse ? Theme.textOn(Theme.green) : Theme.overlay0
                        font.pixelSize: 9
                    }
                }

                MouseArea {
                    id: yesArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.save()
                }
            }

            Rectangle {
                width: 190
                height: 40
                color: "transparent"
                
                ButtonSurface {
                    anchors.fill: parent
                    radius: parent.radius
                    hovered: noArea.containsMouse
                    restingColor: Theme.surface0
                }

                Behavior on color {
                    ColorAnimation { duration: 110 }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No — clipboard only"
                        color: Theme.text
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Nothing written to disk"
                        color: Theme.overlay0
                        font.pixelSize: 9
                    }
                }

                MouseArea {
                    id: noArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clipboardOnly()
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⏎ / y save     n clipboard only     esc discard"
            color: Theme.surface2
            font.pixelSize: 10
        }
    }

    // ---------------- Animasyonlar ----------------
    ParallelAnimation {
        id: openAnim

        NumberAnimation { target: backdrop; property: "opacity"; to: 0.55; duration: 170; easing.type: Easing.OutQuad }
        NumberAnimation { target: pickPanel; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: pickPanel; property: "scale"; to: 1; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
        NumberAnimation { target: confirmPanel; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: confirmPanel; property: "scale"; to: 1; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: pickPanel; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
            NumberAnimation { target: pickPanel; property: "scale"; to: 0.94; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: confirmPanel; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
            NumberAnimation { target: confirmPanel; property: "scale"; to: 0.94; duration: 120; easing.type: Easing.InQuad }
        }

        ScriptAction {
            script: root.visible = false
        }
    }
}
