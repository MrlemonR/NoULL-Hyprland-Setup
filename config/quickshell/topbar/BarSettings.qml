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

    readonly property string path: Quickshell.env("HOME") + "/.config/quickshell/lemonrice.json"

    // In bar order, left to right — the page lists them the same way so the
    // switches map onto what you are looking at.
    readonly property var keys: [
        "date", "clock", "focusedApp",
        "workspaces", "cava",
        "media", "stats", "volume", "tray", "notifications"
    ]

    // How the bar itself looks, as opposed to which widgets it holds. Same
    // file: nothing outside quickshell reads bar.json either way, and a second
    // file would only add another thing to keep in step.
    readonly property var appearanceKeys: ["floating", "transparent"]

    /// Slider ranges, mirrored from the settings screen's own table.
    readonly property var ranges: ({
        barOpacity: { min: 0.3, max: 1, step: 0.01, def: 0.85 }
    })

    property var values: ({})

    // Everything ships on except cava, which is an extra and needs a package
    // that is not part of the base rice, and the two appearance switches —
    // "stuck to the top, opaque" is the look this bar has always had, so a
    // fresh install has to keep it.
    readonly property var defaults: ({ "cava": false, "floating": false, "transparent": false })

    function enabled(key) {
        if (root.values[key] !== undefined)
            return root.values[key] === true
        return root.defaults[key] !== undefined ? root.defaults[key] === true : true
    }

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-config"

    /// Which section of the file a key belongs to. Appearance is the bar
    /// itself; everything else is a widget.
    function pathFor(key) {
        return root.appearanceKeys.indexOf(key) >= 0 || root.ranges[key] !== undefined
            ? "bar." + key
            : "bar.widgets." + key
    }

    function set(key, value) {
        // Move the switch now, let the file confirm it — qs-config shells out
        // and a switch that lags behind the click reads as broken.
        const next = Object.assign({}, root.values)
        next[key] = value === true
        root.values = next
        Quickshell.execDetached([root.script, "set", root.pathFor(key), value ? "on" : "off"])
    }

    function toggle(key) {
        root.set(key, !root.enabled(key))
    }

    function number(key) {
        const value = root.values[key]
        if (typeof value === "number")
            return value
        const range = root.ranges[key]
        return range ? range.def : 0
    }

    /// Sliders write on every step here, unlike the compositor ones: this file
    /// is read by nothing but the bar, so a write costs a FileView reload and
    /// not a `hyprctl reload`.
    function setNumber(key, value) {
        const next = Object.assign({}, root.values)
        next[key] = value
        root.values = next
        Quickshell.execDetached([root.script, "set", root.pathFor(key), String(value)])
    }

    // The shape SettingsSlider expects. Both are the same write here: this
    // file costs a FileView reload, not a compositor reload, so there is
    // nothing to defer until the drag ends.
    function preview(key, value) { root.setNumber(key, value) }
    function commit(key, value) { root.setNumber(key, value) }

    // ---------------- Derived look ----------------

    readonly property int barHeight: 30
    /// Gap above and to the sides when floating.
    readonly property int floatGap: 6
    readonly property int floatSideGap: 8

    readonly property bool floating: root.enabled("floating")
    readonly property bool transparent: root.enabled("transparent")

    /// The strip's fill, with the transparency switch folded in. Applied to the
    /// colour rather than to `opacity`, or the clock and icons would fade too.
    // Glass wins over the bar's own transparency switch: it is the whole
    // desktop's surface treatment, and a bar left opaque inside it would be
    // the one thing that is not glass.
    readonly property color surface: Theme.glass
        ? Theme.panelColor
        : (root.transparent
            ? Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, root.number("barOpacity"))
            : Theme.base)

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
                if (!parsed || typeof parsed.bar !== "object")
                    return
                // Widgets sit one level deeper in the file; flattened here so
                // enabled("date") keeps working and every call site stays put.
                const flat = Object.assign({}, parsed.bar, parsed.bar.widgets || {})
                delete flat.widgets
                root.values = flat
            } catch (e) {
                // Keep the last good values; a hand-broken file should not
                // blank the bar.
                console.warn("BarSettings: lemonrice.json unreadable —", e)
            }
        }

        onFileChanged: file.reload()
    }
}
