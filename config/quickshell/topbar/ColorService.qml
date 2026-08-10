pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The colour picker behind the control centre's Color page.
//
// Picking itself is qs-color's job (hyprpicker + clipboard + history), and it
// is also what Super+Alt+X runs, so the keybind and the tile cannot behave
// differently. All this singleton does is read the history back and convert a
// hex string into the values the page shows.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-color"
    readonly property string storePath: Quickshell.env("HOME") + "/.local/share/quickshell/colors.json"

    // Newest first; [0] is the colour the page opens on.
    property var colors: []

    readonly property string current: root.colors.length > 0 ? root.colors[0] : ""

    function pick() {
        Quickshell.execDetached([root.script, "pick"])
    }

    function copy(hex) {
        if (!hex)
            return
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", hex])
    }

    function clear() {
        Quickshell.execDetached([root.script, "clear"])
    }

    // ---------------- Conversions ----------------
    //
    // Qt.color() parses the hex once and gives back floats in 0..1; going
    // through it beats parsing the string by hand and matches what the swatch
    // actually renders.

    function rgbText(hex) {
        if (!hex)
            return ""
        const c = Qt.color(hex)
        return "rgb(" + Math.round(c.r * 255) + ", "
            + Math.round(c.g * 255) + ", "
            + Math.round(c.b * 255) + ")"
    }

    function hslText(hex) {
        if (!hex)
            return ""
        const c = Qt.color(hex)

        // Qt reports hue as -1 for greys, which came out as "hsl(-360, 0%,
        // 100%)" for white. Undefined hue reads as 0.
        const hue = c.hslHue < 0 ? 0 : Math.round(c.hslHue * 360)

        return "hsl(" + hue + ", "
            + Math.round(c.hslSaturation * 100) + "%, "
            + Math.round(c.hslLightness * 100) + "%)"
    }

    /// Black or white, whichever stays readable on top of the swatch.
    function contrastText(hex) {
        if (!hex)
            return "#ffffff"
        const c = Qt.color(hex)
        const luma = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        return luma > 0.55 ? "#000000" : "#ffffff"
    }

    FileView {
        id: store

        path: root.storePath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            const raw = store.text()
            if (!raw || raw.trim().length === 0)
                return
            try {
                const parsed = JSON.parse(raw)
                if (Array.isArray(parsed))
                    root.colors = parsed
            } catch (e) {
                console.warn("ColorService: colors.json unreadable —", e)
            }
        }

        onFileChanged: store.reload()
    }
}
