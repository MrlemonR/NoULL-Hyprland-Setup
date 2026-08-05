import QtQuick
import Quickshell
import Quickshell.Io

// Files sekmesi: ev dizininde dosya araması (qs-file-search).
// Asenkron çalıştığı için results'ı Process bitince dolduruyoruz.
LauncherProvider {
    id: root

    providerId: "files"
    label: "Files"
    glyph: "󰈔"
    showsEmptyQuery: false
    hasPreview: true

    readonly property string searchScript: Quickshell.env("HOME") + "/.local/bin/qs-file-search"

    results: []

    function humanSize(bytes) {
        const n = Number(bytes)
        if (isNaN(n))
            return ""
        if (n < 1024)
            return n + " B"
        if (n < 1024 * 1024)
            return (n / 1024).toFixed(1) + " KB"
        if (n < 1024 * 1024 * 1024)
            return (n / 1024 / 1024).toFixed(1) + " MB"
        return (n / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }

    function shortPath(path) {
        const home = Quickshell.env("HOME")
        return path.startsWith(home) ? "~" + path.slice(home.length) : path
    }

    onQueryChanged: {
        const q = root.query.trim()
        if (q.length < 2) {
            root.results = []
            debounce.stop()
            return
        }
        debounce.restart()
    }

    activate: function (item) {
        if (item.data && item.data.path)
            Quickshell.execDetached(["xdg-open", item.data.path])
        return true
    }

    property var debounce: Timer {
        interval: 180
        repeat: false
        onTriggered: {
            if (searchProc.running)
                searchProc.running = false
            searchProc.command = [root.searchScript, root.query.trim(), "60"]
            searchProc.running = true
        }
    }

    property var searchProc: Process {
        running: false

        stdout: StdioCollector {
            id: searchCollector

            onStreamFinished: {
                const lines = searchCollector.text.split("\n")
                const out = []
                const q = root.query.trim().toLowerCase()

                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t")
                    if (parts.length < 3 || parts[0].length === 0)
                        continue

                    const path = parts[0]
                    const name = path.split("/").pop()

                    // Ad ile eşleşenler öne
                    const lower = name.toLowerCase()
                    let score = 0
                    if (lower === q)
                        score = 1000
                    else if (lower.startsWith(q))
                        score = 500
                    else if (lower.includes(q))
                        score = 250
                    else
                        score = 50

                    out.push({
                        title: name,
                        subtitle: root.shortPath(path.substring(0, path.length - name.length - 1)),
                        icon: "",
                        score: score - Math.min(200, path.split("/").length * 5),
                        data: {
                            path: path,
                            size: root.humanSize(parts[1]),
                            modified: Number(parts[2])
                        }
                    })
                }

                out.sort((a, b) => b.score - a.score)
                root.results = out
            }
        }
    }
}
