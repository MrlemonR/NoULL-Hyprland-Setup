import QtQuick
import Quickshell

// Apps sekmesi: .desktop girdilerinden uygulama araması.
LauncherProvider {
    id: root

    providerId: "apps"
    label: "Apps"
    glyph: "󰀻"
    showsEmptyQuery: true

    results: {
        const apps = DesktopEntries.applications.values
        const q = root.query.trim().toLowerCase()
        const out = []

        for (let i = 0; i < apps.length; i++) {
            const entry = apps[i]
            if (!entry || entry.noDisplay)
                continue

            const name = entry.name || ""
            const comment = entry.comment || ""
            const lower = name.toLowerCase()

            let score = 0
            if (q.length === 0) {
                score = 1
            } else if (lower === q) {
                score = 1000
            } else if (lower.startsWith(q)) {
                score = 500 - lower.length
            } else if (lower.includes(q)) {
                score = 250 - lower.length
            } else if (comment.toLowerCase().includes(q)) {
                score = 100
            } else {
                continue
            }

            out.push({
                title: name,
                subtitle: comment,
                icon: IconResolver.iconFor(entry.icon),
                score: score,
                data: entry
            })
        }

        out.sort((a, b) => b.score - a.score || a.title.localeCompare(b.title))
        return out
    }

    activate: function (item) {
        if (item.data)
            item.data.execute()
        return true
    }
}
