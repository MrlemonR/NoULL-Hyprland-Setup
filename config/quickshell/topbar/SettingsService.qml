pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// State behind the control centre (the cat menu in the bar).
//
// Two kinds of switch live here and they work differently on purpose:
//
//   stored    animations, blur, shadows, transparency, gaps — kept in
//             ~/.config/quickshell/settings.json and pushed to Hyprland by
//             qs-settings. Written through the script rather than from here so
//             the CLI and the menu cannot drift apart, and read back through a
//             watched FileView so `qs-settings set` from a terminal moves the
//             switch in the bar.
//
//   probed    encrypted DNS, microphone mute — owned by the system, not by us.
//             There is nothing to store; we ask, and we only ask while the menu
//             is open (see `polling`), because this bar is watched for its own
//             resource use.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-settings"
    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/lemonrice.json"
    readonly property string dnsScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/dns-toggle.sh"

    // ---------------- Stored toggles ----------------

    readonly property var keys: ["animations", "blur", "shadows", "transparency", "gaps"]

    // Sliders. Ranges are duplicated from qs-settings on purpose — the script
    // clamps whatever arrives, so this copy only decides how far the handle
    // travels and cannot let a bad value through.
    readonly property var ranges: ({
        animationSpeed:     { min: 0.25, max: 4,  step: 0.25, def: 1 },
        blurAmount:         { min: 1,    max: 20, step: 1,    def: 5 },
        transparencyAmount: { min: 0.5,  max: 1,  step: 0.01, def: 0.95 },
        gapsAmount:         { min: 0,    max: 40, step: 1,    def: 8 }
    })

    property var values: ({})

    // For the Appearance tile's caption, so the menu says how much is on
    // without opening the page.
    readonly property int effectsOn: {
        let n = 0
        for (let i = 0; i < root.keys.length; i++) {
            if (root.enabled(root.keys[i]))
                n++
        }
        return n
    }

    // Absent means on: a fresh install has no settings.json and should look
    // normal, not like everything was switched off.
    //
    // The exception is anything that is not part of the normal look. Aero glass
    // is opt-in, so "no opinion recorded" has to mean off — inheriting the
    // default-on rule would have every fresh install claim it was enabled.
    readonly property var defaultOff: ["aeroGlass"]

    function enabled(key) {
        const value = root.values[key]
        if (typeof value === "boolean")
            return value
        return root.defaultOff.indexOf(key) < 0
    }

    function set(key, value) {
        // Move the switch now and let the file confirm it. qs-settings takes a
        // moment (it shells out to hyprctl), and a switch that lags behind the
        // click feels broken.
        const next = Object.assign({}, root.values)
        next[key] = value
        root.values = next

        Quickshell.execDetached([root.script, "set", key, value ? "on" : "off"])
    }

    function toggle(key) {
        root.set(key, !root.enabled(key))
    }

    /// A slider's current value, falling back to the range's default.
    function number(key) {
        const value = root.values[key]
        if (typeof value === "number")
            return value
        const range = root.ranges[key]
        return range ? range.def : 0
    }

    /// Sliders fire continuously while dragging and every write costs a
    /// `hyprctl reload`, so the value is shown at once and pushed once the
    /// handle settles. `commit` is what the release handler calls.
    function preview(key, value) {
        const next = Object.assign({}, root.values)
        next[key] = value
        root.values = next
    }

    function commit(key, value) {
        root.preview(key, value)
        Quickshell.execDetached([root.script, "set", key, String(value)])
    }

    FileView {
        id: settingsFile

        path: root.configPath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            const raw = settingsFile.text()
            if (!raw || raw.trim().length === 0)
                return
            try {
                const parsed = JSON.parse(raw)
                if (parsed && typeof parsed.settings === "object")
                    root.values = parsed.settings
                root.prefabs = (parsed && parsed.prefabs) || ({})
            } catch (e) {
                // Leave the last good values in place; qs-settings refuses to
                // write over a broken file, so it is a hand edit to fix.
                console.warn("SettingsService: lemonrice.json unreadable —", e)
            }
        }

        onFileChanged: settingsFile.reload()
    }

    // ---------------- Prefabs ----------------
    // A saved look per theme: switch to Frutiger Aero and the bar floats,
    // switch to Monochrome and it docks — because that is how each was saved.
    // Storage and restore both live in qs-config; this only reads and asks.

    property var prefabs: ({})

    function hasPrefab(theme) {
        return root.prefabs[theme] !== undefined
    }

    /// Only the ACTIVE theme can be saved. The values being written are the
    /// live ones, so saving them under another theme's name would record a
    /// look that theme never had.
    function savePrefab(theme) {
        Quickshell.execDetached([root.configScript, "prefab-save", theme])
    }

    function clearPrefab(theme) {
        Quickshell.execDetached([root.configScript, "prefab-clear", theme])
    }

    readonly property string configScript: Quickshell.env("HOME") + "/.local/bin/qs-config"

    // ---------------- Probed state ----------------

    // Only true while the menu is open. Nothing here changes behind the user's
    // back often enough to be worth a background poll.
    property bool polling: false

    property bool dnsOn: false
    property bool micMuted: false

    function refresh() {
        dnsProc.running = true
        micProc.running = true
    }

    /// Encrypted DNS needs root to change, so it goes through a terminal where
    /// sudo can actually prompt — there is no polkit agent in this session, and
    /// a menu switch that silently does nothing is worse than a visible prompt.
    function toggleDns() {
        const arg = root.dnsOn ? "--off" : "--on"
        Quickshell.execDetached(["kitty", "--app-id", "FloatDns", "-e", "bash", "-c",
            "sudo " + root.dnsScript + " " + arg
            + "; printf '\\nPress Enter to close…'; read -r _"])

        // The script restarts systemd-resolved and runs its own checks, so the
        // answer lands several seconds after the window opens.
        dnsSettleTimer.restart()
    }

    function toggleMic() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
        micMuted = !micMuted
        settleTimer.restart()
    }

    Process {
        id: dnsProc

        command: [root.dnsScript, "--status"]
        running: false

        stdout: StdioCollector {
            id: dnsCollector

            onStreamFinished: root.dnsOn = dnsCollector.text.trim() === "on"
        }
    }

    Process {
        id: micProc

        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null"]
        running: false

        stdout: StdioCollector {
            id: micCollector

            onStreamFinished: root.micMuted = micCollector.text.indexOf("MUTED") >= 0
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.polling
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Short catch-up after an action, so the row settles even if the menu is
    // closed before the next poll.
    Timer {
        id: settleTimer

        interval: 300
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: dnsSettleTimer

        interval: 8000
        repeat: false
        onTriggered: root.refresh()
    }
}
