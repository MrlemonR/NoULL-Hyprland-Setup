pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tüm quickshell arayüzünün renk kaynağı.
//
// Paletler artık burada DEĞİL, ~/.config/quickshell/palettes.json içinde —
// bütün tema scriptleri (qs-theme, qs-theme-gtk, -ytmd, -zen, -hypr, -btop,
// -dunst, qs-ytmd-titlebar) aynı dosyayı okuyor. Yeni bir tema eklemek için
// tek yapılacak oraya bir blok eklemek; hiçbir script düzenlemek gerekmiyor.
// (CLI tarafı: qs-palette list | get | env)
//
// Etkin temanın adı ~/.config/quickshell/theme.txt dosyasında duruyor; onu
// qs-theme yazıyor. İki dosyada da watchChanges açık, yani hem tema değişimi
// hem de palet düzenlemesi bar yeniden başlatılmadan uygulanıyor (buradan
// hiç yazmıyoruz, dolayısıyla döngü riski yok).
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/theme.txt"
    readonly property string palettesPath: Quickshell.env("HOME") + "/.config/quickshell/palettes.json"
    readonly property string fontPath: Quickshell.env("HOME") + "/.config/quickshell/font.conf"

    // ---------------- Fonts ----------------
    // Set by qs-font, watched live like the palette. fontMono must be a Nerd
    // Font: every icon in the bar is a Nerd Font glyph, so a plain family
    // leaves empty boxes everywhere.
    property string fontMono: "JetBrainsMono Nerd Font"
    property string fontUi: "JetBrainsMono Nerd Font"

    // QML weights are the same numbers as OS/2 (Font.Medium == 500), so the
    // config's style word maps straight across.
    property int fontWeight: Font.Normal

    readonly property var weightNames: ({
        "Thin": Font.Thin, "ExtraLight": Font.ExtraLight, "Light": Font.Light,
        "Regular": Font.Normal, "Medium": Font.Medium, "SemiBold": Font.DemiBold,
        "Bold": Font.Bold, "ExtraBold": Font.ExtraBold, "Black": Font.Black
    })

    property string name: "catppuccin-mocha"

    // palettes.json okunamazsa bar renksiz kalmasın diye asgari yedek
    readonly property var fallbackPalettes: ({
        "catppuccin-mocha": {
            label: "Catppuccin Mocha",
            base: "#1e1e2e", mantle: "#181825", crust: "#11111b",
            surface0: "#313244", surface1: "#45475a", surface2: "#585b70",
            overlay0: "#6c7086", subtext0: "#a6adc8", subtext1: "#bac2de",
            text: "#cdd6f4", mauve: "#cba6f7", blue: "#89b4fa",
            red: "#f38ba8", green: "#a6e3a1", yellow: "#f9e2af",
            peach: "#fab387", pink: "#f5c2e7", hover: "#232336",
            selected: "#2a2b3d", divider: "#292a3d", dangerBg: "#45293a"
        }
    })

    property var palettes: root.fallbackPalettes

    readonly property var palette: root.palettes[root.name]
        || root.palettes[Object.keys(root.palettes)[0]]
        || root.fallbackPalettes["catppuccin-mocha"]

    readonly property var themeNames: Object.keys(root.palettes)

    function labelFor(themeName) {
        const p = root.palettes[themeName]
        return p && p.label ? p.label : themeName
    }

    // ---------------- Renkler ----------------
    readonly property color base: root.palette.base
    readonly property color mantle: root.palette.mantle
    readonly property color crust: root.palette.crust
    readonly property color surface0: root.palette.surface0
    readonly property color surface1: root.palette.surface1
    readonly property color surface2: root.palette.surface2
    readonly property color overlay0: root.palette.overlay0
    readonly property color subtext0: root.palette.subtext0
    readonly property color subtext1: root.palette.subtext1
    readonly property color text: root.palette.text
    readonly property color mauve: root.palette.mauve
    readonly property color blue: root.palette.blue
    readonly property color red: root.palette.red
    readonly property color green: root.palette.green
    readonly property color yellow: root.palette.yellow
    readonly property color peach: root.palette.peach
    readonly property color pink: root.palette.pink
    readonly property color hover: root.palette.hover
    readonly property color selected: root.palette.selected
    readonly property color divider: root.palette.divider
    readonly property color dangerBg: root.palette.dangerBg

    FileView {
        id: palettesFile

        path: root.palettesPath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            const raw = palettesFile.text()
            if (!raw || raw.trim().length === 0)
                return
            try {
                const parsed = JSON.parse(raw)
                if (parsed && Object.keys(parsed).length > 0)
                    root.palettes = parsed
            } catch (e) {
                // Bozuk JSON: yedek palet devrede kalsın, bar çökmesin
                console.warn("Theme: palettes.json okunamadı —", e)
            }
        }

        onFileChanged: palettesFile.reload()
    }

    FileView {
        id: stateFile

        path: root.statePath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            const value = stateFile.text().trim()
            if (value.length > 0)
                root.name = value
        }

        onFileChanged: stateFile.reload()
    }

    FileView {
        id: fontFile

        path: root.fontPath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            // "key = value", '#' comments. Small enough that a parser here
            // beats another JSON file to keep in sync.
            const lines = fontFile.text().split("\n")
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].split("#")[0].trim()
                if (line.length === 0)
                    continue
                const eq = line.indexOf("=")
                if (eq < 0)
                    continue
                const key = line.slice(0, eq).trim()
                const value = line.slice(eq + 1).trim()
                if (value.length === 0)
                    continue
                if (key === "mono")
                    root.fontMono = value
                else if (key === "ui")
                    root.fontUi = value
                else if (key === "weight" && root.weightNames[value] !== undefined)
                    root.fontWeight = root.weightNames[value]
            }
        }

        onFileChanged: fontFile.reload()
    }
}
