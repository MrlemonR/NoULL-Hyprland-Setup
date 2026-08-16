import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Alt+Tab pencere anahtarlayıcısı.
//
// Alt basılı tutulurken Tab'e her basışta seçim ilerliyor, Alt bırakılınca
// seçili pencereye geçiliyor (workspace'i de dahil — hl.dsp.focus adresle
// çağrıldığında Hyprland o pencerenin çalışma alanına da atlıyor).
//
// Tuş yolu iki parçalı:
//   1) Tab basışları Hyprland keybind'i tarafından yutuluyor (ALT+Tab bize
//      hiç ulaşmaz), o yüzden ilerletme IPC ile geliyor: qs-alt-tab next/prev.
//   2) Alt BIRAKMA'sı bu pencereye ulaşıyor — panel açıkken katman yüzeyi
//      Exclusive klavye odağını tuttuğu için Qt, Key_Alt release olayını
//      görüyor. Emniyet kemeri olarak qs-alt-tab da bir release bind'inden
//      "commit" çağırıyor; panel kapalıyken ikisi de zararsız.
//
//   qs -c topbar ipc call switcher next | prev | commit | cancel
PanelWindow {
    id: root

    property bool shown: false
    property int selectedIndex: 0

    readonly property var windows: WindowSwitcherService.windows
    readonly property int count: root.windows.length

    readonly property var selected: (root.selectedIndex >= 0 && root.selectedIndex < root.count)
        ? root.windows[root.selectedIndex] : null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    // DİKKAT: exclusiveZone'a değer atamak exclusionMode'u Normal'a çeviriyor
    // ve pencere bar'ın 30px'i kadar aşağı iniyor. Sadece Ignore bırak.
    exclusionMode: ExclusionMode.Ignore
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-switcher"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---------------- Davranış ----------------

    // Alt+Tab: açık değilse aç ve bir öncekini seç, açıksa ilerlet.
    function next() {
        root.step(1)
    }

    // Alt+Shift+Tab: açık değilse aç ve en eskiyi seç, açıksa geri git.
    function prev() {
        root.step(-1)
    }

    function step(delta) {
        if (root.shown) {
            if (root.count === 0)
                return
            root.selectedIndex = (root.selectedIndex + delta + root.count) % root.count
            return
        }

        // Tek pencere varken (ya da hiç yokken) geçilecek bir şey yok
        if (WindowSwitcherService.count < 2)
            return

        WindowSwitcherService.freeze()
        // 0 = şu anki pencere; ileri gidince bir önceki, geri gidince en eski
        root.selectedIndex = delta > 0 ? 1 : WindowSwitcherService.count - 1
        root.shown = true
    }

    // Seçili pencereye geç. Panel kapanmadan önce odak veriliyor: katman
    // yüzeyi hâlâ Exclusive tuttuğu için araya eski pencere girmiyor.
    function commit() {
        if (!root.shown)
            return

        const target = root.selected
        root.close()

        if (target)
            root.focusWindow(target.address)
    }

    function cancel() {
        root.close()
    }

    function close() {
        root.shown = false
        WindowSwitcherService.unfreeze()
    }

    // "com.anthropic.Claude" -> "Claude", ama "Minecraft* 26.2" olduğu gibi
    // kalsın. Son parçayı almak yalnızca appId gerçekten ters-DNS biçimindeyse
    // doğru; sürüm numarası içeren sınıf adlarında "2" kalıyordu.
    function prettyName(appId) {
        const n = appId || ""
        if (n.length === 0)
            return ""

        if (!n.includes(" ") && /^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)+$/.test(n)) {
            const last = n.split(".").pop()
            if (/^[A-Za-z]/.test(last))
                return last
        }
        return n
    }

    // The list is the service's — MRU order is the whole point of it — but a
    // preview needs the wayland handle, and only Hyprland's own toplevel
    // objects carry one. Matched on address, which both sides have.
    function toplevelFor(address) {
        const want = String(address || "").replace(/^0x/, "")
        if (want === "")
            return null

        const list = Hyprland.toplevels.values
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].address) === want)
                return list[i]
        }
        return null
    }

    readonly property string focusScript: Quickshell.env("HOME") + "/.local/bin/qs-focus-keep-cursor"

    function focusWindow(address) {
        // cursor:no_warps is off globally so Super+arrow's focus-follows-
        // pointer warp works; Alt+Tab is the one path that wants the pointer
        // to stay put, so it goes through a script that saves/restores it
        // around the focus dispatch instead.
        Quickshell.execDetached([root.focusScript, address])
    }

    IpcHandler {
        target: "switcher"

        function next(): void {
            root.next()
        }

        function prev(): void {
            root.prev()
        }

        function commit(): void {
            root.commit()
        }

        function cancel(): void {
            root.cancel()
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

    // Liste altımızdan boşalırsa (pencere kapandı vb.) seçimi sınırda tut
    onCountChanged: {
        if (root.shown && root.selectedIndex >= root.count)
            root.selectedIndex = Math.max(0, root.count - 1)
    }

    // ---------------- Arka plan ----------------
    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Theme.crust
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    // ---------------- Klavye ----------------
    //
    // Tab buraya gelmiyor (Hyprland bind'i yutuyor); asıl iş Alt bırakma.
    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: true

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                event.accepted = true
                root.commit()
            }
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                event.accepted = true
                root.cancel()
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                event.accepted = true
                root.commit()
                break
            case Qt.Key_Right:
            case Qt.Key_Down:
            case Qt.Key_Tab:
                event.accepted = true
                root.next()
                break
            case Qt.Key_Left:
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                event.accepted = true
                root.prev()
                break
            }
        }
    }

    // ---------------- Panel ----------------
    Rectangle {
        id: panel

        readonly property int cardWidth: 168
        readonly property int cardHeight: 118
        readonly property int cardSpacing: 8
        readonly property int padding: 16
        /// Icon and app name under the preview.
        readonly property int labelHeight: 22

        // DİKKAT: gizliyken PanelWindow width/height'ı gerçek değerini
        // vermiyor (gotcha #11/#20). Ölçüleri ekrandan al.
        readonly property int screenWidth: root.screen ? root.screen.width : 1920

        readonly property int maxRowWidth: panel.screenWidth - 120
        readonly property int fullRowWidth: root.count * panel.cardWidth
            + Math.max(0, root.count - 1) * panel.cardSpacing
        readonly property int rowWidth: Math.max(panel.cardWidth,
            Math.min(panel.maxRowWidth, panel.fullRowWidth))

        anchors.centerIn: parent
        width: panel.rowWidth + panel.padding * 2
        height: panel.padding + panel.cardHeight + 12 + captionColumn.height + panel.padding
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
        scale: 0.97
        transformOrigin: Item.Center

        // ---------------- Kartlar ----------------
        ListView {
            id: cards

            anchors.top: parent.top
            anchors.topMargin: panel.padding
            anchors.horizontalCenter: parent.horizontalCenter
            width: panel.rowWidth
            height: panel.cardHeight

            orientation: ListView.Horizontal
            clip: true
            spacing: panel.cardSpacing
            boundsBehavior: Flickable.StopAtBounds
            model: root.windows
            currentIndex: root.selectedIndex

            // Seçim her zaman görünür kalsın (çok pencere varken kayıyor)
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: panel.cardWidth
            preferredHighlightEnd: width - panel.cardWidth
            highlightMoveDuration: 130

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                readonly property bool current: card.index === root.selectedIndex
                readonly property var toplevel: root.toplevelFor(card.modelData.address)

                width: panel.cardWidth
                height: panel.cardHeight

                Rectangle {
                    id: cardSurface

                    anchors.fill: parent
                    color: card.current ? Theme.selected
                                        : (cardArea.containsMouse ? Theme.hover : Theme.mantle)
                    border.color: card.current ? Theme.blue : "transparent"
                    border.width: card.current ? 2 : 0
                    radius: Theme.radius
                    clip: true

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }

                    // ---- preview ----
                    //
                    // Same capture path as the workspace overview: one frame per
                    // opening off the toplevel's wayland handle, which works for
                    // windows on workspaces that are not on screen. The icon
                    // stands in until the frame lands, and for anything with no
                    // handle at all.
                    Item {
                        id: previewBox

                        anchors.fill: parent
                        anchors.bottomMargin: panel.labelHeight
                        clip: true

                        Connections {
                            target: root

                            function onShownChanged() {
                                if (root.shown && preview.captureSource)
                                    preview.captureFrame()
                            }
                        }

                        Component.onCompleted: {
                            if (root.shown && preview.captureSource)
                                preview.captureFrame()
                        }

                        ScreencopyView {
                            id: preview

                            captureSource: card.toplevel ? card.toplevel.wayland : null
                            live: false
                            paintCursor: false

                            readonly property real fit: {
                                const w = preview.sourceSize.width
                                const h = preview.sourceSize.height
                                if (w <= 0 || h <= 0)
                                    return 0
                                return Math.min(previewBox.width / w, previewBox.height / h)
                            }

                            anchors.centerIn: parent
                            width: preview.sourceSize.width * preview.fit
                            height: preview.sourceSize.height * preview.fit
                            visible: preview.hasContent && preview.fit > 0
                        }

                        IconImage {
                            id: fallbackIcon

                            anchors.centerIn: parent
                            implicitSize: 40
                            width: 40
                            height: 40
                            source: IconResolver.iconForApp(card.modelData.appId)
                            visible: !preview.visible && status === Image.Ready
                        }

                        // Harf döşemesi — ikon da yoksa
                        Rectangle {
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            visible: !preview.visible && !fallbackIcon.visible
                            color: Theme.surface1
                            radius: Theme.radius

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    const n = root.prettyName(card.modelData.appId) || card.modelData.title || "?"
                                    return (n.charAt(0) || "?").toUpperCase()
                                }
                                color: Theme.text
                                font.pixelSize: 20
                                font.bold: true
                            }
                        }
                    }

                    // ---- uygulama adı ----
                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: panel.labelHeight

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.mantle
                            opacity: card.current ? 0.75 : 0.92
                        }

                        IconImage {
                            id: cardIcon

                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 14
                            width: 14
                            height: 14
                            source: IconResolver.iconForApp(card.modelData.appId)
                            visible: source != "" && status === Image.Ready
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: cardIcon.visible ? 25 : 6
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.prettyName(card.modelData.appId)
                            color: card.current ? Theme.text : Theme.subtext0
                            font.pixelSize: 11
                            font.bold: card.current
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }
                }

                // Pencerenin çalışma alanı — hangi workspace'e gidileceği
                // kartın üstünden okunabilsin
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 4
                    width: wsLabel.implicitWidth + 10
                    height: 16
                    color: card.current ? Theme.blue : Theme.surface1
                    radius: Theme.radiusUpTo(16)
                    z: 2

                    Text {
                        id: wsLabel

                        anchors.centerIn: parent
                        text: card.modelData.workspaceName
                        color: card.current ? Theme.base : Theme.subtext0
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                MouseArea {
                    id: cardArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: root.selectedIndex = card.index
                    onClicked: {
                        root.selectedIndex = card.index
                        root.commit()
                    }
                }
            }
        }

        // ---------------- Seçili pencerenin künyesi ----------------
        Column {
            id: captionColumn

            anchors.top: cards.bottom
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: panel.padding
            anchors.rightMargin: panel.padding
            spacing: 3

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.selected ? root.selected.title : ""
                color: Theme.text
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.selected
                    ? "Workspace " + root.selected.workspaceName + "  ·  " + (root.selectedIndex + 1) + "/" + root.count
                    : ""
                color: Theme.overlay0
                font.pixelSize: 11
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }

    // ---------------- Animasyonlar ----------------
    //
    // Kısa tutuluyor: Alt+Tab'in anında hissedilmesi gerekiyor.
    ParallelAnimation {
        id: openAnim

        NumberAnimation { target: backdrop; property: "opacity"; to: Theme.backdropOpacity(0.45); duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: 130; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeAnim

        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: Theme.backdropOpacity(0); duration: 90; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 80; easing.type: Easing.InQuad }
            NumberAnimation { target: panel; property: "scale"; to: 0.97; duration: 90; easing.type: Easing.InQuad }
        }

        ScriptAction {
            script: root.visible = false
        }
    }
}
