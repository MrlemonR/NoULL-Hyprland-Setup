pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio spectrum for the two strips beside the workspaces.
//
// cava does the analysis and prints one line per frame in raw ASCII mode
// ("v;v;…;v", each 0..100 — see ~/.config/quickshell/cava.conf); all this does
// is keep the process alive while the strips are on and split the lines.
//
// The process runs only when the toggle is on, so the default install pays
// nothing for a feature it is not using. cava is not part of the base rice, so
// `available` gates the toggle as well — a switch that silently does nothing
// is worse than one that says why.
Singleton {
    id: root

    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/cava.conf"

    // Must match `bars` in cava.conf
    readonly property int barCount: 12

    property bool available: false

    property var levels: {
        const zeros = []
        for (let i = 0; i < root.barCount; i++)
            zeros.push(0)
        return zeros
    }

    readonly property bool wanted: BarSettings.enabled("cava")

    Process {
        id: probe

        running: true
        command: ["sh", "-c", "command -v cava >/dev/null && echo yes || echo no"]

        stdout: StdioCollector {
            id: probeCollector

            onStreamFinished: root.available = probeCollector.text.trim() === "yes"
        }
    }

    Process {
        id: cava

        running: root.available && root.wanted
        command: ["cava", "-p", root.configPath]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                const parts = data.split(";")
                const out = []
                for (let i = 0; i < root.barCount; i++) {
                    const value = Number(parts[i])
                    out.push(isNaN(value) ? 0 : Math.min(100, Math.max(0, value)))
                }
                root.levels = out
            }
        }

        stderr: SplitParser {
            onRead: data => console.warn("cava:", data)
        }

        // Falling back to flat rather than leaving the last frame frozen on
        // screen, which reads as the bar having hung.
        onExited: {
            const zeros = []
            for (let i = 0; i < root.barCount; i++)
                zeros.push(0)
            root.levels = zeros
        }
    }
}
