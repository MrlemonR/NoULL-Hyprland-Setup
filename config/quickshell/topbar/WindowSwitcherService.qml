pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Alt+Tab anahtarlayıcısının pencere listesi.
//
// Liste MRU sırasında tutuluyor: 0 = şu an odaklı pencere, 1 = ondan önce
// odaklanılan… Alt+Tab'in en son kullanılan pencereye atlaması bu sıraya
// dayanıyor. Kaynak hyprctl'in focusHistoryID alanı.
//
// DİKKAT: liste sürekli sıcak tutuluyor, Alt+Tab anında açılsın diye. Panel
// açılırken hyprctl çalıştırmak 30-60ms gecikme demek olurdu ve tuşa basınca
// panelin geç gelmesi hissediliyor. Bunun yerine:
//   - activewindowv2 olayında sıra yerelde yeniden diziliyor (süreç yok),
//   - pencere açılma/kapanma/başlık/taşıma olaylarında hyprctl ile
//     ayrıntılar tazeleniyor (80ms debounce).
Singleton {
    id: root

    // [{ address, appId, title, workspaceId, workspaceName, monitor }] — MRU sıralı
    property var windows: []

    // Panel açıkken liste donduruluyor. Yoksa seçim gezinirken altındaki
    // sıra değişip Alt bırakıldığında yanlış pencereye gidiliyor.
    property bool frozen: false

    readonly property int count: root.windows.length

    // hyprctl adresleri "0x..." veriyor, olay akışı ise "0x" öneki olmadan.
    function normalize(address) {
        if (!address)
            return ""
        const s = String(address).trim()
        return s.startsWith("0x") ? s : "0x" + s
    }

    function indexOfAddress(address) {
        const addr = root.normalize(address)
        const list = root.windows
        for (let i = 0; i < list.length; i++) {
            if (list[i].address === addr)
                return i
        }
        return -1
    }

    // Verilen pencereyi listenin başına al — süreç açmadan, olay geldiği anda.
    function touch(address) {
        if (root.frozen)
            return

        const i = root.indexOfAddress(address)
        if (i <= 0)
            return // listede yok ya da zaten en başta

        const next = root.windows.slice()
        next.unshift(next.splice(i, 1)[0])
        root.windows = next
    }

    function refresh() {
        refreshTimer.restart()
    }

    // Panel açılırken çağrılıyor: bekleyen tazeleme varsa hemen uygulansın
    // diye değil (asenkron), listeyi olduğu gibi dondurmak için.
    function freeze() {
        root.frozen = true
    }

    function unfreeze() {
        root.frozen = false
    }

    // ---------------- Hyprland olayları ----------------
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "activewindowv2":
                // Katman yüzeyi odak aldığında boş adres gelebiliyor
                if (event.data && event.data.trim().length > 1)
                    root.touch(event.data)
                break
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "windowtitlev2":
            case "changefloatingmode":
                root.refresh()
                break
            }
        }
    }

    // Olay kaçarsa (ör. shell yeniden yüklendiğinde) liste yine de doğrulansın
    Timer {
        interval: PerfMode.every(5000)
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshTimer

        interval: 80
        repeat: false
        onTriggered: {
            // Süreç koşarken running'e tekrar true atamak işe yaramıyor;
            // biten sürecin onExited'ı kuyruğu boşaltıyor.
            if (clientsProc.running) {
                clientsProc.again = true
                return
            }
            clientsProc.running = true
        }
    }

    Process {
        id: clientsProc

        property bool again: false

        command: ["hyprctl", "-j", "clients"]
        running: true

        onExited: {
            if (clientsProc.again) {
                clientsProc.again = false
                refreshTimer.restart()
            }
        }

        stdout: StdioCollector {
            id: clientsCollector

            onStreamFinished: {
                if (root.frozen)
                    return

                let parsed
                try {
                    parsed = JSON.parse(clientsCollector.text)
                } catch (e) {
                    return
                }
                if (!Array.isArray(parsed))
                    return

                const usable = parsed.filter(c => c && c.mapped && !c.hidden)

                usable.sort((a, b) => (a.focusHistoryID !== undefined ? a.focusHistoryID : 9999)
                                    - (b.focusHistoryID !== undefined ? b.focusHistoryID : 9999))

                root.windows = usable.map(c => ({
                    address: c.address,
                    appId: c.class || "",
                    title: (c.title && c.title.length > 0) ? c.title : (c.class || "Untitled"),
                    workspaceId: c.workspace ? c.workspace.id : 0,
                    workspaceName: c.workspace ? String(c.workspace.name) : "",
                    monitor: c.monitor
                }))
            }
        }
    }
}
