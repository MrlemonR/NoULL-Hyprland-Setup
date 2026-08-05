import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Başlatıcıyı taşıyan tam ekran katman penceresi.
// Klavye odağı Exclusive: açılır açılmaz yazmaya başlanabiliyor.
//
// Aç/kapat:
//   quickshell ipc call launcher toggle
PanelWindow {
    id: root

    property bool shown: false

    // Panelin ekranın altından yüksekliği
    readonly property int bottomGap: 18

    // Açılışta panelin aşağıdan kayma payı. y'yi doğrudan animasyona sokmak
    // bağlamayı kırıyordu: pencere görünür olduğu ilk anda height henüz
    // gerçek değeri (1080) değil 500 raporluyor, animasyon from/to'yu ona göre
    // hesaplayınca panel ekranın dışına düşüyordu. Kaydırma payını ayrı bir
    // özellikte tutunca y bağlaması bozulmuyor.
    property real slideOffset: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    // DİKKAT: exclusiveZone'a değer atamak exclusionMode'u Normal'a çeviriyor,
    // pencere de bar'ın 30px'i kadar aşağı itiliyordu. Sadece Ignore bırak.
    exclusionMode: ExclusionMode.Ignore
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open() {
        LauncherService.reset()
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

    // Belirli bir sekmeyle aç (Super+Shift+C -> System)
    function openTab(tabId) {
        if (root.shown && LauncherService.activeTab === tabId) {
            root.close()
            return
        }
        LauncherService.reset()
        LauncherService.setTab(tabId)
        root.shown = true
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.toggle()
        }

        function open(): void {
            root.open()
        }

        function close(): void {
            root.close()
        }

        // Doğrudan System sekmesi
        function system(): void {
            root.openTab("system")
        }

        // Doğrudan Files sekmesi
        function files(): void {
            root.openTab("files")
        }
    }

    onShownChanged: {
        if (root.shown) {
            root.visible = true
            closeAnim.stop()
            openAnim.restart()
            panel.focusInput()
        } else if (root.visible) {
            openAnim.stop()
            closeAnim.restart()
        }
    }

    // ---------------- Arka plan ----------------
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

    // ---------------- Panel ----------------
    LauncherPanel {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        width: implicitWidth
        height: implicitHeight

        // Ekranın altına yakın dursun (Alt+Space menüsü)
        y: root.height - height - root.bottomGap + root.slideOffset

        opacity: 0
        scale: 0.94
        transformOrigin: Item.Center

        onRequestClose: root.close()
    }

    // ---------------- Animasyonlar ----------------
    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: backdrop
            property: "opacity"
            to: 0.55
            duration: 180
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: panel
            property: "opacity"
            to: 1
            duration: 160
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: panel
            property: "scale"
            to: 1
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 0.9
        }

        NumberAnimation {
            target: root
            property: "slideOffset"
            from: 26
            to: 0
            duration: 240
            easing.type: Easing.OutCubic
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
                target: panel
                property: "opacity"
                to: 0
                duration: 110
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: panel
                property: "scale"
                to: 0.94
                duration: 130
                easing.type: Easing.InQuad
            }
        }

        ScriptAction {
            script: {
                root.visible = false
                LauncherService.reset()
            }
        }
    }
}
