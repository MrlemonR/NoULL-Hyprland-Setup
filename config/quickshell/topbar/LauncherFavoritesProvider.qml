import QtQuick
import Quickshell
import Quickshell.Io

// Favorites sekmesi: sabitlenmiş uygulamalar.
// Apps sekmesinde bir sonuca sağ tıklayarak eklenip çıkarılıyor.
LauncherProvider {
    id: root

    providerId: "favorites"
    label: "Favorites"
    glyph: "󰓎"
    showsEmptyQuery: true

    readonly property string storePath: Quickshell.env("HOME") + "/.config/quickshell/favorites.json"

    // .desktop kimlikleri
    property var ids: []

    function isFavorite(entryId) {
        return root.ids.indexOf(entryId) >= 0
    }

    function toggle(entryId) {
        if (!entryId || entryId.length === 0)
            return

        if (root.isFavorite(entryId))
            root.ids = root.ids.filter(v => v !== entryId)
        else
            root.ids = root.ids.concat([entryId])

        store.setText(JSON.stringify({ favorites: root.ids }, null, 2))
    }

    results: {
        const apps = DesktopEntries.applications.values
        const q = root.query.trim().toLowerCase()
        const out = []

        for (let i = 0; i < root.ids.length; i++) {
            const wanted = root.ids[i]
            for (let j = 0; j < apps.length; j++) {
                const entry = apps[j]
                if (entry.id !== wanted)
                    continue

                const name = entry.name || ""
                if (q.length > 0 && !name.toLowerCase().includes(q))
                    break

                out.push({
                    title: name,
                    subtitle: entry.comment || "",
                    icon: IconResolver.iconFor(entry.icon),
                    score: root.ids.length - i,
                    data: entry
                })
                break
            }
        }
        return out
    }

    activate: function (item) {
        if (item.data)
            item.data.execute()
        return true
    }

    property var store: FileView {
        path: root.storePath
        preload: true
        printErrors: false

        onLoaded: {
            try {
                const payload = JSON.parse(this.text())
                if (payload && Array.isArray(payload.favorites))
                    root.ids = payload.favorites
            } catch (e) {
                root.ids = []
            }
        }

        onLoadFailed: root.ids = []
    }
}
