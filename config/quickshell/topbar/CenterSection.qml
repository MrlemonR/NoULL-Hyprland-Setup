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

    implicitWidth: specialActive ? specialBox.width : normalRow.implicitWidth
    implicitHeight: 22

    Timer {
        interval: 3000
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

    // İkon adını gerçek bir dosya yoluna çevir (IconResolver üzerinden)
    function iconFor(entry) {
        if (!entry || !entry.icon || entry.icon.length === 0)
            return ""
        return IconResolver.iconFor(entry.icon)
    }

    function resolveIcon(appId) {
        // DİKKAT: bu okuma bilinçli. DesktopEntries açılışta boş geliyor ve
        // sonradan doluyor; burada okuyunca binding veritabanı yüklendiğinde
        // kendini yeniden hesaplıyor. Yoksa erken çözülen ikonlar (Claude gibi)
        // sonsuza kadar boş kalıyor.
        const apps = DesktopEntries.applications.values

        if (!appId || appId.length === 0)
            return ""

        if (apps.length === 0)
            return ""

        const lower = appId.toLowerCase()
        const lastSegment = appId.includes(".") ? appId.split(".").pop().toLowerCase() : lower

        // 1) StartupWMClass tam eşleşmesi — Hyprland'in verdiği appId ile
        //    .desktop dosyasını eşleştirmenin doğru yolu bu
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i]
            if (e.startupClass && e.startupClass.toLowerCase() === lower) {
                const icon = root.iconFor(e)
                if (icon.length > 0)
                    return icon
            }
        }

        // 2) .desktop kimliği / adı tam eşleşmesi
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i]
            const id = (e.id || "").toLowerCase().replace(/\.desktop$/, "")
            const name = (e.name || "").toLowerCase()
            if (id === lower || name === lower || id === lastSegment) {
                const icon = root.iconFor(e)
                if (icon.length > 0)
                    return icon
            }
        }

        // 3) appId'nin kendisi bir ikon adı olabilir
        const candidates = [appId, lower, lastSegment]
        for (let i = 0; i < candidates.length; i++) {
            const path = IconResolver.iconFor(candidates[i])
            if (path.length > 0)
                return path
        }

        // 4) Son çare: uygulama adı appId içinde geçiyor mu
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i]
            if (e.name && e.name.length > 2 && lower.includes(e.name.toLowerCase())) {
                const icon = root.iconFor(e)
                if (icon.length > 0)
                    return icon
            }
        }

        // Bulunamadı: delegate harf döşemesi çiziyor
        return ""
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
        visible: opacity > 0
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
                radius: 0
                color: active ? Theme.blue : (hovered ? Theme.surface0 : Theme.base)
                border.color: Theme.surface1
                border.width: 1

                z: hovered ? 10 : 0

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !wsBox.hovered
                    text: wsBox.modelData.name
                    color: wsBox.active ? Theme.base : Theme.text
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
                                radius: 0

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
                                radius: 0
                                color: Theme.red
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: -2
                                anchors.bottomMargin: -2

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.count
                                    color: Theme.base
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
        radius: 0
        color: Theme.mauve
        border.color: Theme.surface1
        border.width: 1

        opacity: root.specialActive ? 1 : 0
        visible: opacity > 0
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
                color: Theme.base
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
