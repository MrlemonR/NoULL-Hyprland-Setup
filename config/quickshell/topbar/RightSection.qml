import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris

RowLayout {
    id: root
    spacing: 6

    function openBtop() {
        Quickshell.execDetached(["kitty", "--app-id", "FloatBtop", "-e", "btop"])
    }

    function adjustVolume(dir) {
        Quickshell.execDetached(["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%" + dir])
        volProc.running = true
    }

    function adjustBrightness(dir) {
        Quickshell.execDetached(["sh", "-c", "ddcutil setvcp 10 " + dir + " 5"])
        briProc.running = true
    }

    // ---------------- CPU ----------------
    property real cpuUsage: 0
    property real prevIdle: 0
    property real prevTotal: 0

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(/\s+/).slice(1).map(Number)
                let idle = parts[3] + parts[4]
                let total = parts.reduce((a, b) => a + b, 0)
                let diffIdle = idle - root.prevIdle
                let diffTotal = total - root.prevTotal
                if (diffTotal > 0)
                    root.cpuUsage = Math.round((1 - diffIdle / diffTotal) * 100)
                root.prevIdle = idle
                root.prevTotal = total
            }
        }
    }

    // ---------------- RAM ----------------
    property real ramUsage: 0

    Process {
        id: ramProc
        command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.0f\", $3/$2*100}'"]
        running: false
        stdout: SplitParser {
            onRead: data => root.ramUsage = Number(data.trim())
        }
    }

    // ---------------- Sıcaklık ----------------
    property real temperature: 0

    Process {
        id: tempProc
        // Önce `sensors` çıktısında yaygın CPU etiketlerini arar (Package id 0 / Tctl / Tdie / Core 0).
        // Bulamazsa thermal_zone0'a düşer. Sensörler doğru çalışmıyorsa `sudo sensors-detect` çalıştırman gerekebilir.
        command: ["sh", "-c", "v=$(sensors 2>/dev/null | grep -m1 -oP '(Package id 0|Tctl|Tdie|Core 0).*?\\+\\K[0-9]+'); if [ -z \"$v\" ]; then v=$(( $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0) / 1000 )); fi; echo $v"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let n = Number(data.trim())
                if (!isNaN(n)) root.temperature = n
            }
        }
    }

    // ---------------- Ses ----------------
    property real volume: 0
    property bool muted: false

    Process {
        id: volProc
        // LC_NUMERIC=C: yerel ayar ondalık ayracı virgül kullanıyorsa (tr_TR gibi) sayıyı
        // yanlış ayrıştırmamak için sayısal formatı zorla nokta yapıyoruz.
        command: ["sh", "-c", "LC_NUMERIC=C wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.muted = data.includes("MUTED")
                let m = data.match(/[\d.]+/)
                if (m) root.volume = Math.round(Number(m[0]) * 100)
            }
        }
    }

    // ---------------- Parlaklık ----------------
    property real brightness: 0

    Process {
        id: briProc
        command: ["sh", "-c", "ddcutil getvcp 10 --terse 2>/dev/null | awk '{print $4}'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let n = Number(data.trim())
                if (!isNaN(n)) root.brightness = n
            }
        }
    }

    // Beş süreç birden açıyor (ddcutil dahil, en pahalısı o);
    // performans modunda aralık uzuyor. Anything switched off in the control
    // centre's Topbar page also stops being polled — this is the most
    // expensive thing the bar does, and there is no point measuring what is
    // not on screen.
    Timer {
        interval: PerfMode.every(2000)
        running: statsRect.visible || volumeRect.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (statsRect.visible) {
                cpuProc.running = true
                ramProc.running = true
                tempProc.running = true
                briProc.running = true
            }
            if (volumeRect.visible)
                volProc.running = true
        }
    }



    // ---------------- Medya Oynatıcı (CPU/RAM'ın solunda) ----------------
    //
    // DİKKAT: eskiden Mpris.players.values[0] alınıyordu. Listenin başına
    // kdeconnect üzerinden gelen telefon oynatıcısı (şarkısı yok, çalmıyor)
    // düşünce medya alanı bomboş ama "görünür" kalıyor, sağındaki ayraç da
    // ortada asılı kalıyordu — üstelik gerçekten çalan YTM/Zen hiç
    // görünmüyordu. Artık: çalan varsa o, yoksa şarkısı olan (duraklatılmış
    // olabilir, oradan devam ettirilebilsin), o da yoksa hiçbiri.
    readonly property var activePlayer: {
        const list = Mpris.players.values
        let playing = null
        let withTrack = null

        for (let i = 0; i < list.length; i++) {
            const player = list[i]
            // Her ikisini de her turda okuyoruz ki bağımlılık kurulsun ve
            // biri çalmaya başlayınca bu bağlama yeniden değerlendirilsin
            const isPlaying = player.isPlaying
            const title = (player.trackTitle || "").trim()

            if (isPlaying && !playing)
                playing = player
            if (title.length > 0 && !withTrack)
                withTrack = player
        }

        return playing || withTrack || null
    }

    Rectangle {
        id: mediaRect
        visible: BarSettings.enabled("media") && root.activePlayer !== null
        color: mediaArea.containsMouse ? Theme.surface0 : "transparent"
        radius: 0
        implicitWidth: mediaRow.implicitWidth + 10
        implicitHeight: 22

        MouseArea {
            id: mediaArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaPopup.visible = !mediaPopup.visible
        }

        Row {
            id: mediaRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: ""
                color: Theme.pink
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous()
                }
            }

            Text {
                text: root.activePlayer && root.activePlayer.isPlaying ? "" : ""
                color: Theme.blue
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.activePlayer && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying()
                }
            }

            Text {
                text: ""
                color: Theme.pink
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next()
                }
            }

            Text {
                text: {
                    if (!root.activePlayer) return ""
                    let title = root.activePlayer.trackTitle || ""
                    let artist = root.activePlayer.trackArtist || ""
                    let full = artist ? (artist + " - " + title) : title
                    return full.length > 28 ? full.substring(0, 28) + "…" : full
                }
                color: Theme.text
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.activePlayer && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying()
                }
            }
        }
    }

    MediaPlayerPopup {
        id: mediaPopup
        player: root.activePlayer

        anchor.item: mediaRect
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
    }

    Rectangle {
        width: 1
        height: 14
        color: Theme.surface1
        visible: mediaRect.visible && statsRect.visible
    }

    Rectangle {
        id: statsRect
        visible: BarSettings.enabled("stats")
        color: sysArea.containsMouse ? Theme.surface0 : "transparent"
        radius: 0
        implicitWidth: sysRow.implicitWidth + 10
        implicitHeight: 22

        Row {
            id: sysRow
            anchors.centerIn: parent
            spacing: 6

            Row {
                spacing: 4
                Text { text: "󰻠"; color: Theme.text; font.pixelSize: 13 }
                Text { text: root.cpuUsage + "%"; color: Theme.text; font.pixelSize: 13 }
            }

            Row {
                spacing: 4
                Text { text: "󰍛"; color: Theme.text; font.pixelSize: 13 }
                Text { text: root.ramUsage + "%"; color: Theme.text; font.pixelSize: 13 }
            }

            Row {
                spacing: 4
                Text { text: "󰔏"; color: Theme.text; font.pixelSize: 13 }
                Text { text: root.temperature + "°C"; color: Theme.text; font.pixelSize: 13 }
            }
        }

        MouseArea {
            id: sysArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openBtop()
        }
    }

    Rectangle {
        width: 1
        height: 14
        color: Theme.surface1
        visible: statsRect.visible && volumeRect.visible
    }

    Rectangle {
        id: volumeRect
        visible: BarSettings.enabled("volume")
        color: volumeArea.containsMouse ? Theme.surface0 : "transparent"
        radius: 0
        implicitWidth: volumeRow.implicitWidth + 8
        implicitHeight: 22

        Row {
            id: volumeRow
            anchors.centerIn: parent
            spacing: 4
            Text { text: root.muted ? "󰝟" : "󰕾"; color: Theme.text; font.pixelSize: 13 }
            Text { text: root.volume + "%"; color: Theme.text; font.pixelSize: 13 }
        }

        MouseArea {
            id: volumeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["pwvucontrol"])
            onWheel: wheel => root.adjustVolume(wheel.angleDelta.y > 0 ? "+" : "-")
        }
    }


    Rectangle {
        width: 1
        height: 14
        color: Theme.surface1
        visible: volumeRect.visible && button.visible
    }

Rectangle {
    id: button
    visible: BarSettings.enabled("tray")
    width: 20
    height: 20

    color: "transparent"

    Image {
        id: trayArrow
        anchors.centerIn: parent
        width: 14
        height: 14
        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/arrow-right.svg"

        // popup açıkken 180° döner (Windows 11'deki tepsi oku gibi)
        rotation: popup.visible ? 90 : 0

        Behavior on rotation {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible = !popup.visible
    }
}

SystemTrayPopup {
    id: popup

    anchor.item: button
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
}


    Rectangle {
        width: 1
        height: 14
        color: Theme.surface1
        visible: button.visible && notifButton.visible
    }

    // ---------------- Bildirimler (en sağ) ----------------
    Rectangle {
        id: notifButton

        visible: BarSettings.enabled("notifications")

        color: notifArea.containsMouse ? Theme.surface0 : "transparent"
        radius: 0
        implicitWidth: 26
        implicitHeight: 22

        Text {
            anchors.centerIn: parent
            text: NotificationService.dnd ? "󰂛" : "󰂚"
            color: {
                if (NotificationService.dnd)
                    return Theme.overlay0
                return NotificationService.unreadCount > 0 ? Theme.mauve : Theme.text
            }
            font.pixelSize: 14
        }

        // Okunmamış bildirim rozeti — rahatsız etme açıkken gizlenir
        Rectangle {
            id: badge

            visible: !NotificationService.dnd && NotificationService.unreadCount > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2
            anchors.topMargin: 0
            width: Math.max(10, badgeText.implicitWidth + 4)
            height: 10
            radius: 0
            color: Theme.red

            Text {
                id: badgeText

                anchors.centerIn: parent
                text: NotificationService.badgeText
                color: Theme.base
                font.pixelSize: 8
                font.bold: true
            }
        }

        MouseArea {
            id: notifArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    notifPopup.visible = !notifPopup.visible
                else
                    NotificationService.toggleDnd()
            }
        }
    }

    NotificationsPopup {
        id: notifPopup

        anchor.item: notifButton
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
    }
}
