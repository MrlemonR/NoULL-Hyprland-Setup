import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Takvimi taşıyan katman penceresi.
// Pencere sabit boyutta duruyor, içerik animasyonla açılıp kapanıyor; girdi
// bölgesi (mask) sadece görünen panele denk geliyor ki yanına tıklayınca kapansın.
PanelWindow {
    id: root

    property bool shown: false

    // Dışarı tıklayarak kapandıktan hemen sonraki tıklamayı yok say, yoksa
    // tarihe basınca kapanıp anında tekrar açılıyor.
    property double lastCleared: 0

    readonly property int topPad: 10

    function toggle() {
        if (!root.shown && Date.now() - root.lastCleared < 250)
            return
        root.shown = !root.shown
    }

    anchors {
        top: true
        left: true
    }

    margins.left: 12

    // Pencere en büyük sayfaya göre sabit; panel içeride büyüyüp küçülüyor
    implicitWidth: panel.maxWidth
    implicitHeight: panel.maxHeight + topPad

    color: "transparent"
    focusable: true
    exclusiveZone: 0
    visible: false

    WlrLayershell.namespace: "quickshell-calendar"

    mask: Region {
        item: panel
    }

    // Tuş kısayoluna bağlamak için:
    //   quickshell ipc call calendar toggle
    IpcHandler {
        target: "calendar"

        function toggle(): void {
            root.toggle()
        }

        function open(): void {
            root.shown = true
        }

        function close(): void {
            root.shown = false
        }
    }

    // Resim seçici (zenity) odağı aldığında odak yakalama kırılıyor ve takvim
    // kapanıyordu. Seçici çalışırken yakalamayı tamamen bırakıyoruz; ayrıca
    // yakalamayı kendimiz kapattığımızda da "cleared" geldiği için, seçici
    // kapandıktan kısa bir süre daha korumayı sürdürüyoruz.
    property bool pickerGuard: false

    Connections {
        target: panel

        function onBusyChanged() {
            if (panel.busy) {
                guardTimer.stop()
                root.pickerGuard = true
            } else {
                guardTimer.restart()
            }
        }
    }

    Timer {
        id: guardTimer

        interval: 700
        repeat: false
        onTriggered: root.pickerGuard = false
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.shown && !root.pickerGuard

        onCleared: {
            if (root.pickerGuard)
                return

            root.lastCleared = Date.now()
            root.shown = false
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

    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: panel
            property: "opacity"
            to: 1
            duration: 170
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: panel
            property: "y"
            to: root.topPad
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }

        NumberAnimation {
            target: panel
            property: "scale"
            to: 1
            duration: 190
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation {
                target: panel
                property: "opacity"
                to: 0
                duration: 120
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: panel
                property: "y"
                to: root.topPad - 8
                duration: 120
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: panel
                property: "scale"
                to: 0.97
                duration: 120
                easing.type: Easing.InQuad
            }
        }

        ScriptAction {
            script: {
                root.visible = false
                // Kapanınca gün paneli kapansın, bir dahakine temiz açılsın
                panel.selectedKey = ""
                panel.mode = 0
                panel.pendingDelete = null
                panel.goToday()
            }
        }
    }

    CalendarPanel {
        id: panel

        x: 0
        y: root.topPad - 8
        width: implicitWidth
        height: implicitHeight
        clip: false

        opacity: 0
        scale: 0.97
        transformOrigin: Item.TopLeft

        focus: true
        Keys.onEscapePressed: root.shown = false
    }
}
