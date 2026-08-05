pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pano geçmişi (cliphist) durumu. qs-clip scripti üzerinden okuyup yazıyoruz.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-clip"
    readonly property string pinPath: Quickshell.env("HOME") + "/.config/quickshell/clipboard-pins.json"

    // { id, kind, preview, width, height }
    property var entries: []

    property var pins: []

    property string query: ""
    property string activeKind: "all"
    property int selectedIndex: 0

    readonly property var tabs: [
        { id: "all", label: "All" },
        { id: "text", label: "Text" },
        { id: "image", label: "Images" }
    ]

    readonly property var results: {
        const q = root.query.trim().toLowerCase()
        const out = []

        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i]

            if (root.activeKind !== "all" && e.kind !== root.activeKind)
                continue
            if (q.length > 0 && e.preview.toLowerCase().indexOf(q) < 0)
                continue

            out.push({
                id: e.id,
                kind: e.kind,
                preview: e.preview,
                width: e.width,
                height: e.height,
                pinned: root.pins.indexOf(e.id) >= 0,
                order: i
            })
        }

        // Sabitlenenler üste
        out.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0) || a.order - b.order)
        return out
    }

    readonly property var selectedItem: root.results[root.selectedIndex] || null

    function refresh() {
        if (!listProc.running)
            listProc.running = true
    }

    function reset() {
        root.query = ""
        root.activeKind = "all"
        root.selectedIndex = 0
    }

    function setKind(kind) {
        if (root.activeKind === kind)
            return
        root.activeKind = kind
        root.selectedIndex = 0
    }

    function nextTab(delta) {
        let index = 0
        for (let i = 0; i < root.tabs.length; i++) {
            if (root.tabs[i].id === root.activeKind)
                index = i
        }
        const count = root.tabs.length
        root.setKind(root.tabs[((index + delta) % count + count) % count].id)
    }

    function move(delta) {
        const count = root.results.length
        if (count === 0)
            return
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count
    }

    // Seçili girdiyi panoya koy
    function copySelected() {
        const item = root.selectedItem
        if (!item)
            return false
        Quickshell.execDetached([root.script, "copy", item.id])
        return true
    }

    function remove(id) {
        root.entries = root.entries.filter(e => e.id !== id)
        Quickshell.execDetached([root.script, "delete", id])
        refreshTimer.restart()
    }

    function togglePin(id) {
        if (root.pins.indexOf(id) >= 0)
            root.pins = root.pins.filter(v => v !== id)
        else
            root.pins = root.pins.concat([id])

        pinFile.setText(JSON.stringify({ pins: root.pins }, null, 2))
    }

    function thumbFor(id) {
        return ThumbCache.pathFor(id)
    }

    onQueryChanged: root.selectedIndex = 0

    Timer {
        id: refreshTimer

        interval: 200
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: listProc

        command: [root.script, "list"]
        running: false

        stdout: StdioCollector {
            id: listCollector

            onStreamFinished: {
                try {
                    const payload = JSON.parse(listCollector.text)
                    root.entries = Array.isArray(payload) ? payload : []
                } catch (e) {
                    root.entries = []
                }
            }
        }
    }

    FileView {
        id: pinFile

        path: root.pinPath
        preload: true
        printErrors: false

        onLoaded: {
            try {
                const payload = JSON.parse(pinFile.text())
                if (payload && Array.isArray(payload.pins))
                    root.pins = payload.pins
            } catch (e) {
                root.pins = []
            }
        }

        onLoadFailed: root.pins = []
    }
}
