pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Phone side of the control centre.
//
// Everything that touches adb lives in qs-adb — including the part that makes
// this useful, finding the phone at all. Android's wireless debugging picks a
// new random port every time it is switched on, this adb build has no mDNS
// support and avahi is not running, so the script does its own one-shot mDNS
// query and falls back to sweeping the LAN. That belongs in a script with
// threads, not in a QML binding.
//
// Polled only while the Phone page is open: `adb devices` spawns a process and
// this bar is watched for its own resource use.
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/bin/qs-adb"

    property bool polling: false

    property bool adbAvailable: true
    property bool scrcpyAvailable: true

    // { address, state, model, network }
    property var connectedDevices: []

    // { name, serial } from adb's known-hosts file
    property var pairedDevices: []

    readonly property bool connected: root.connectedDevices.length > 0
    readonly property var device: root.connected ? root.connectedDevices[0] : null

    readonly property string label: {
        if (root.device && root.device.model.length > 0)
            return root.device.model
        if (root.pairedDevices.length > 0)
            return root.pairedDevices[0].serial
        return "No device"
    }

    readonly property bool known: root.connected || root.pairedDevices.length > 0

    // Progress line from the last connect attempt — "scanning the network…"
    // and friends. The search can take a few seconds and a button that just
    // sits there reads as broken.
    property string busyText: ""

    readonly property bool busy: root.busyText.length > 0

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true
    }

    /// `port` is what the phone shows under Wireless debugging; it changes
    /// every time that switch is flipped, which is why it is typed in rather
    /// than searched for. Empty falls back to qs-adb's own search.
    function connect(port) {
        if (connectProc.running)
            return
        root.busyText = "connecting…"
        connectProc.command = port && String(port).length > 0
            ? [root.script, "connect", String(port)]
            : [root.script, "connect"]
        connectProc.running = true
    }

    function disconnect() {
        Quickshell.execDetached([root.script, "disconnect"])
        settleTimer.restart()
    }

    function action(name) {
        Quickshell.execDetached([root.script, name])
        settleTimer.restart()
    }

    Process {
        id: statusProc

        command: [root.script, "status"]
        running: false

        stdout: StdioCollector {
            id: statusCollector

            onStreamFinished: {
                let payload
                try {
                    payload = JSON.parse(statusCollector.text)
                } catch (e) {
                    return
                }

                root.adbAvailable = payload.adb === true
                root.scrcpyAvailable = payload.scrcpy === true
                root.connectedDevices = payload.connected || []
                root.pairedDevices = payload.paired || []
            }
        }
    }

    Process {
        id: connectProc

        // Set in connect(); the port has to travel on the command line
        command: [root.script, "connect"]
        running: false

        // Line by line rather than collected: the whole point is showing the
        // search as it happens.
        stdout: SplitParser {
            onRead: data => root.busyText = data.trim()
        }

        onExited: {
            root.busyText = ""
            root.refresh()
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.polling
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Catch-up after an action, so the row settles even if the page is closed
    // before the next poll.
    Timer {
        id: settleTimer

        interval: 400
        repeat: false
        onTriggered: root.refresh()
    }
}
