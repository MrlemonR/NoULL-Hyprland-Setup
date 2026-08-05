pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pano görsellerinin küçük resim önbelleği. İstenen id için qs-clip thumb
// çalıştırıp yolu saklıyor; hazır olunca cache değiştiği için bindingler
// kendini yeniliyor.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-clip"

    // id -> yol ("" = üretilemedi)
    property var cache: ({})

    property var queue: []

    function pathFor(id) {
        if (!id)
            return ""

        const hit = root.cache[id]
        if (hit !== undefined)
            return hit.length > 0 ? "file://" + hit : ""

        if (root.queue.indexOf(id) < 0) {
            // Binding değerlendirmesi içinde durum değiştirmemek için ertele
            Qt.callLater(root.enqueue, id)
        }
        return ""
    }

    function enqueue(id) {
        if (root.cache[id] !== undefined || root.queue.indexOf(id) >= 0)
            return
        root.queue = root.queue.concat([id])
        root.pump()
    }

    function pump() {
        if (thumbProc.running || root.queue.length === 0)
            return

        const next = root.queue[0]
        root.queue = root.queue.slice(1)
        thumbProc.currentId = next
        thumbProc.command = [root.script, "thumb", next]
        thumbProc.running = true
    }

    Process {
        id: thumbProc

        property string currentId: ""

        running: false
        onExited: root.pump()

        stdout: StdioCollector {
            id: thumbCollector

            onStreamFinished: {
                let next = Object.assign({}, root.cache)
                next[thumbProc.currentId] = thumbCollector.text.trim()
                root.cache = next
            }
        }
    }
}
