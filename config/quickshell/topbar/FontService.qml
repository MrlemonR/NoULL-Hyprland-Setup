pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The font side of the theme picker (Super+Ctrl+Z).
//
// The family list comes from `qs-font families`, which reports the Nerd Font
// families fontconfig can actually see — offering a font that is not installed
// would silently fall back and lose every bar icon.
//
// Applying goes through qs-font as well, so the picker and the CLI push the
// change into the same nine places rather than each knowing the list.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-font"

    // Installed Nerd Font families
    property var families: []

    // Cycled by Space on a font row. Same order as the OS/2 weight scale, so
    // stepping through them reads as progressively heavier.
    readonly property var weights: [
        "Thin", "ExtraLight", "Light", "Regular",
        "Medium", "SemiBold", "Bold", "ExtraBold"
    ]

    function weightIndex(name) {
        const i = root.weights.indexOf(name)
        return i < 0 ? root.weights.indexOf("Regular") : i
    }

    function nextWeight(name) {
        return root.weights[(root.weightIndex(name) + 1) % root.weights.length]
    }

    function refresh() {
        familiesProc.running = true
    }

    /// Set the family, keeping the current weight.
    function applyFamily(family) {
        if (!family)
            return
        Quickshell.execDetached([root.script, family])
    }

    /// Set the weight, keeping the current families.
    function applyWeight(weight) {
        if (!weight)
            return
        Quickshell.execDetached([root.script, "--weight", weight])
    }

    Process {
        id: familiesProc

        running: true
        command: [root.script, "families"]

        stdout: StdioCollector {
            id: familiesCollector

            onStreamFinished: {
                const out = []
                const lines = familiesCollector.text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const name = lines[i].trim()
                    if (name.length > 0)
                        out.push(name)
                }
                root.families = out
            }
        }
    }
}
