import QtQuick
import Quickshell

// System sekmesi: oturum ve güç eylemleri.
LauncherProvider {
    id: root

    providerId: "system"
    label: "System"
    glyph: "󰒓"
    showsEmptyQuery: true

    readonly property var actions: [
        { title: "Lock Screen",   subtitle: "hyprlock",             glyph: "󰌾", cmd: ["sh", "-c", "hyprlock"] },
        { title: "Log Out",       subtitle: "End Hyprland session", glyph: "󰍃", cmd: ["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()' || loginctl terminate-user \"$USER\""] },
        { title: "Suspend",       subtitle: "Sleep",                glyph: "󰤄", cmd: ["systemctl", "suspend"] },
        { title: "Reboot",        subtitle: "Restart the machine",  glyph: "󰜉", cmd: ["systemctl", "reboot"] },
        { title: "Shut Down",     subtitle: "Power off",            glyph: "󰐥", cmd: ["systemctl", "poweroff"] },
        { title: "Performance Mode", subtitle: "Toggle wallpaper/blur/animations off", glyph: "󰓅", cmd: ["sh","-c","$HOME/.local/bin/qs-mode toggle"] },
        { title: "Reload Shell",  subtitle: "Restart quickshell",   glyph: "󰑓", cmd: ["sh", "-c", "quickshell -c topbar & disown"] },
        { title: "Audio Settings", subtitle: "pwvucontrol",         glyph: "󰕾", cmd: ["pwvucontrol"] },
        { title: "System Monitor", subtitle: "btop",                glyph: "󰻠", cmd: ["kitty", "--app-id", "FloatBtop", "-e", "btop"] }
    ]

    results: {
        const q = root.query.trim().toLowerCase()
        const out = []

        for (let i = 0; i < root.actions.length; i++) {
            const a = root.actions[i]
            if (q.length > 0 && !a.title.toLowerCase().includes(q) && !a.subtitle.toLowerCase().includes(q))
                continue

            out.push({
                title: a.title,
                subtitle: a.subtitle,
                icon: "",
                glyph: a.glyph,
                score: root.actions.length - i,
                data: a.cmd
            })
        }
        return out
    }

    activate: function (item) {
        if (item.data)
            Quickshell.execDetached(item.data)
        return true
    }
}
