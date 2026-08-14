import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets

Item {
    id: root

    // Bar kendi ekranının adını buraya veriyor; özel çalışma alanı olayları
    // monitör bazlı geldiği için hangi monitörü dinleyeceğimizi bilmemiz gerekiyor.
    property string screenName: ""

    // Ekranda görünen özel çalışma alanının adı ("" ise görünen yok).
    // Hyprland'in activespecialv2 olayından geliyor: "id,isim,monitör"
    property string specialWorkspace: ""

    readonly property bool specialActive: specialWorkspace.length > 0

    readonly property string specialLabel: {
        let name = root.specialWorkspace.replace(/^special:/, "")
        if (name.length === 0)
            return "Special"
        return name.charAt(0).toUpperCase() + name.slice(1)
    }

    // Workspaces plus, when the spectrum strips are on, one on either side.
    // They are part of the width so the workspaces stay centred on the screen
    // instead of being pushed off by whichever side drew wider.
    readonly property bool workspacesShown: BarSettings.enabled("workspaces")

    readonly property int coreWidth: {
        if (!root.workspacesShown)
            return 0
        return specialActive ? specialBox.width : normalRow.implicitWidth
    }

    readonly property int cavaWidth: leftCava.visible ? leftCava.implicitWidth + 10 : 0

    implicitWidth: root.coreWidth + 2 * root.cavaWidth
    implicitHeight: 22

    // Nothing is drawn here — it is the anchor the strips hang off, so both
    // sides stay glued to the workspaces as they resize on hover.
    Item {
        id: core

        anchors.centerIn: parent
        width: root.coreWidth
        height: 22
    }

    CavaBar {
        id: leftCava

        mirrored: true
        anchors.right: core.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
    }

    CavaBar {
        anchors.left: core.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
    }

    Timer {
        interval: PerfMode.every(3000)
        running: true
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }

    // Bar açıldığında özel çalışma alanı zaten görünür olabilir
    Process {
        id: specialProbe

        running: true
        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            id: specialProbeCollector

            onStreamFinished: {
                try {
                    const monitors = JSON.parse(specialProbeCollector.text)
                    for (let i = 0; i < monitors.length; i++) {
                        const m = monitors[i]
                        if (root.screenName.length > 0 && m.name !== root.screenName)
                            continue
                        root.specialWorkspace = (m.specialWorkspace && m.specialWorkspace.name) || ""
                        return
                    }
                } catch (e) {
                    root.specialWorkspace = ""
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activespecialv2")
                return

            // "id,isim,monitör" — isim virgül içerebilir, o yüzden baştan ve sondan ayırıyoruz
            const parts = event.data.split(",")
            if (parts.length < 3)
                return

            const monitor = parts[parts.length - 1]
            const name = parts.slice(1, parts.length - 1).join(",")

            if (root.screenName.length > 0 && monitor !== root.screenName)
                return

            root.specialWorkspace = name
        }
    }

    // appId -> ikon yolu. Eşleştirme mantığı IconResolver'da (Alt+Tab
    // anahtarlayıcısı da aynı işlevi kullanıyor). Bulunamazsa "" döner ve
    // delegate harf döşemesi çiziyor.
    function resolveIcon(appId) {
        return IconResolver.iconForApp(appId)
    }

    function groupToplevels(list) {
        let groups = []
        let map = {}
        for (let i = 0; i < list.length; i++) {
            let t = list[i]
            let key = t.wayland?.appId ?? t.title ?? "unknown"
            if (map[key] === undefined) {
                map[key] = { name: key, count: 0 }
                groups.push(map[key])
            }
            map[key].count++
        }
        return groups
    }

    // ---------------- Normal çalışma alanları ----------------
    RowLayout {
        id: normalRow

        anchors.centerIn: parent
        spacing: 6

        opacity: root.specialActive ? 0 : 1
        visible: root.workspacesShown && opacity > 0
        scale: root.specialActive ? 0.85 : 1

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        Repeater {
            model: Hyprland.workspaces

            delegate: Rectangle {
                id: wsBox
                required property var modelData

                // Özel çalışma alanları normal listede yer almasın
                readonly property bool isSpecial: (modelData.name || "").startsWith("special")

                property bool active: modelData.active
                property bool hovered: mouseArea.containsMouse
                property var toplevels: Hyprland.toplevels.values.filter(
                    t => t.workspace && t.workspace.id === modelData.id
                )
                property var groupedApps: root.groupToplevels(toplevels)

                visible: !isSpecial
                Layout.preferredWidth: hovered ? (36 + groupedApps.length * 20) : 22
                Layout.preferredHeight: 22
                height: 22
                radius: Theme.radius
                // Resting state paints NOTHING rather than the bar's own colour.
                // The two were identical while the bar was always opaque, so
                // the difference never showed; the moment the bar goes
                // translucent an opaque box is a hole in the glass.
                color: active ? Theme.blue : (hovered ? Theme.surface0 : "transparent")
                border.color: Theme.surface1
                border.width: Theme.borderWidth

                z: hovered ? 10 : 0

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !wsBox.hovered
                    text: wsBox.modelData.name
                    color: wsBox.active ? Theme.textOn(Theme.blue) : Theme.text
                    font.pixelSize: 12
                    font.bold: true
                }

                Row {
                    anchors.centerIn: parent
                    visible: wsBox.hovered
                    spacing: 4

                    Repeater {
                        model: wsBox.groupedApps
                        delegate: Item {
                            id: appIcon

                            required property var modelData
                            width: 16
                            height: 16

                            IconImage {
                                id: appIconImage

                                anchors.fill: parent
                                source: root.resolveIcon(appIcon.modelData.name)
                                visible: source != "" && status === Image.Ready
                            }

                            // İkon bulunamazsa uygulama adının ilk harfi
                            Rectangle {
                                anchors.fill: parent
                                visible: !appIconImage.visible
                                color: Theme.surface1
                                radius: Theme.radius

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        const n = appIcon.modelData.name || "?"
                                        const seg = n.includes(".") ? n.split(".").pop() : n
                                        return (seg.charAt(0) || "?").toUpperCase()
                                    }
                                    color: Theme.text
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                visible: modelData.count > 1
                                width: 10
                                height: 10
                                radius: Theme.radiusUpTo(10)
                                color: Theme.red
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: -2
                                anchors.bottomMargin: -2

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.count
                                    color: Theme.textOn(Theme.red)
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        switchProc.command = ["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = " + wsBox.modelData.id + " })'"]
                        switchProc.running = true
                    }
                }

                Process {
                    id: switchProc
                    stderr: SplitParser {
                        onRead: data => console.log("hyprctl hata:", data)
                    }
                }
            }
        }
    }

    // ---------------- Özel çalışma alanı görünürken tek kutu ----------------
    Rectangle {
        id: specialBox

        anchors.centerIn: parent
        width: specialRow.implicitWidth + 18
        height: 22
        radius: Theme.radius
        color: Theme.mauve
        border.color: Theme.surface1
        border.width: Theme.borderWidth

        opacity: root.specialActive ? 1 : 0
        visible: root.workspacesShown && opacity > 0
        scale: root.specialActive ? 1 : 0.85

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }

        Row {
            id: specialRow

            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.specialLabel
                color: Theme.textOn(Theme.mauve)
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
