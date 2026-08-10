pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which parts of the bar are drawn — the control centre's Topbar page.
//
// Separate from SettingsService on purpose: those toggles have to reach the
// compositor and therefore go through qs-settings and a Lua file, while these
// never leave the bar. Nothing outside quickshell reads bar.json, so there is
// no script in the middle and the file is written from here.
//
// The running cat is deliberately not in the list: it is the handle for this
// panel, and a switch that hides its own way back in is a trap.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/quickshell/bar.json"

    // In bar order, left to right — the page lists them the same way so the
    // switches map onto what you are looking at.
    readonly property var keys: [
        "date", "clock", "focusedApp",
        "workspaces", "cava",
        "media", "stats", "volume", "tray", "notifications"
    ]

    property var values: ({})

    // Everything ships on except cava, which is an extra and needs a package
    // that is not part of the base rice.
    readonly property var defaults: ({ "cava": false })

    function enabled(key) {
        if (root.values[key] !== undefined)
            return root.values[key] === true
        return root.defaults[key] !== undefined ? root.defaults[key] === true : true
    }

    function set(key, value) {
        const next = Object.assign({}, root.values)
        next[key] = value === true
        root.values = next
        file.setText(JSON.stringify(next, null, 2) + "\n")
    }

    function toggle(key) {
        root.set(key, !root.enabled(key))
    }

    FileView {
        id: file

        path: root.path
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            const raw = file.text()
            if (!raw || raw.trim().length === 0)
                return
            try {
                const parsed = JSON.parse(raw)
                if (parsed && typeof parsed === "object")
                    root.values = parsed
            } catch (e) {
                // Keep the last good values; a hand-broken file should not
                // blank the bar.
                console.warn("BarSettings: bar.json unreadable —", e)
            }
        }

        onFileChanged: file.reload()
    }
}
