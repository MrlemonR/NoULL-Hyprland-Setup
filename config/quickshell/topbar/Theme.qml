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

    /// The one config file. Colours, the active theme, fonts, effect settings
    /// and the bar's own state all live in it — see qs-config, which is the
    /// only thing that writes it. Read here, never written, so there is no
    /// loop to worry about.
    readonly property string configPath: Quickshell.env("HOME") + "/.config/quickshell/lemonrice.json"

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

    // Custom themes are the ones allowed to break the house rules — rounded
    // corners, gloss, translucency. They are kept in the same palettes.json so
    // every script keeps working unchanged (`qs-theme frutiger-aero` needs no
    // new code); the flag only decides which list the picker shows them in.
    function isCustomTheme(themeName) {
        const p = root.palettes[themeName]
        return !!(p && p.custom)
    }

    readonly property var themeNames:
        Object.keys(root.palettes).filter(n => !root.isCustomTheme(n))

    readonly property var customThemeNames:
        Object.keys(root.palettes).filter(n => root.isCustomTheme(n))

    function labelFor(themeName) {
        const p = root.palettes[themeName]
        return p && p.label ? p.label : themeName
    }

    // ---------------- Style ----------------
    // The second half of a theme: not what colour a surface is, but what shape
    // it has. Everything defaults to the house look — square, flat, opaque —
    // so the five standard themes render exactly as before and only a palette
    // carrying a `style` block changes anything.
    readonly property var fallbackStyle: ({
        radius: 0, radiusPanel: 0, gloss: 0, borderWidth: 1, panelOpacity: 1
    })

    readonly property var style: {
        const s = root.palette && root.palette.style
        if (!s)
            return root.fallbackStyle
        // Merged over the fallback, so a style block may set one key and leave
        // the rest at the house value.
        const out = {}
        for (const key in root.fallbackStyle)
            out[key] = (s[key] !== undefined) ? s[key] : root.fallbackStyle[key]
        return out
    }

    readonly property bool isCustom: root.isCustomTheme(root.name)

    /// Corner radius for rows, chips, swatches — the small stuff.
    readonly property int radius: root.style.radius
    /// Corner radius for panels and windows.
    readonly property int radiusPanel: root.style.radiusPanel
    // ---------------- Aero Glass ----------------
    // One switch that overrides the theme's own surface treatment. It is read
    // here rather than in each panel because every surface already goes
    // through `panelColor` and `gloss` — one place to change covers the bar,
    // all thirteen panels and anything added later.
    //
    // The compositor half is config/glass.lua; both read the same key.
    readonly property bool glass: SettingsService.enabled("aeroGlass")

    /// Scrim behind a panel. Under glass it drops to almost nothing: the blur
    /// already separates the pane from what is behind it, and a heavy scrim is
    /// also what made the compositor blur the WHOLE layer — the blur rule's
    /// `ignore_alpha` has to sit between the scrim and the pane, and it cannot
    /// if the scrim is the heavier of the two (gotcha #51).
    function backdropOpacity(normal) {
        return root.glass ? Math.min(normal, 0.16) : normal
    }

    /// How much of the blurred desktop shows through a glass surface. Low
    /// enough to read text over, high enough that the blur is the point.
    readonly property real glassOpacity: 0.55

    /// 0 = flat. Above 0, GlossOverlay draws an Aero-style specular highlight.
    /// Glass forces a sheen on even for themes that never asked for one — the
    /// highlight is what separates "glass" from "a translucent rectangle".
    readonly property real gloss: root.glass
        ? Math.max(root.style.gloss, 0.38)
        : root.style.gloss
    readonly property int borderWidth: root.style.borderWidth
    readonly property real panelOpacity: root.style.panelOpacity

    /// The fill for a panel surface, with the theme's translucency baked into
    /// the colour. Setting a Rectangle's `opacity` instead would fade the
    /// content sitting on top of it too — the text has to stay solid.
    readonly property color panelColor: root.glass
        ? Qt.rgba(root.base.r, root.base.g, root.base.b, root.glassOpacity)
        : Qt.rgba(root.base.r, root.base.g, root.base.b, root.panelOpacity)

    function luminanceOf(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    /// True when the palette is light. Kept here rather than in each caller,
    /// because a light theme is new territory in this shell and one test is
    /// easier to correct than a dozen.
    readonly property bool isLight: root.luminanceOf(root.base) > 0.5

    /// Readable foreground for text or an icon drawn **on top of** `bg`.
    ///
    /// The habit in this config was `Theme.crust`, and it worked for years
    /// only because crust is the darkest colour in a dark palette. In a light
    /// one it is among the lightest, so a mauve-filled chip with crust text
    /// came out light-on-light and the label disappeared. This picks whichever
    /// pole of the palette is further from `bg` in luminance, so it stays
    /// right whichever way round the palette is.
    function textOn(bg) {
        const target = root.luminanceOf(bg)
        const crustGap = Math.abs(root.luminanceOf(root.crust) - target)
        const textGap = Math.abs(root.luminanceOf(root.text) - target)
        return crustGap >= textGap ? root.crust : root.text
    }

    /// Radius capped to half of `size`. A 6px unread dot or a 3px accent bar
    /// given the full panel radius turns into a circle or swallows its own
    /// width, so anything small asks for its radius through here instead.
    function radiusUpTo(size) {
        return Math.min(root.radius, Math.floor(size / 2))
    }

    /// Radius/gloss of *another* theme, so the picker can preview a row in the
    /// shape that theme would give it without applying anything.
    function styleFor(themeName) {
        const p = root.palettes[themeName]
        const s = p && p.style
        if (!s)
            return root.fallbackStyle
        const out = {}
        for (const key in root.fallbackStyle)
            out[key] = (s[key] !== undefined) ? s[key] : root.fallbackStyle[key]
        return out
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
        id: configFile

        path: root.configPath
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            const raw = configFile.text()
            if (!raw || raw.trim().length === 0)
                return
            try {
                const parsed = JSON.parse(raw)
                if (!parsed || typeof parsed !== "object")
                    return

                if (parsed.palettes && Object.keys(parsed.palettes).length > 0)
                    root.palettes = parsed.palettes
                if (typeof parsed.theme === "string" && parsed.theme.length > 0)
                    root.name = parsed.theme

                const font = parsed.font || {}
                if (typeof font.mono === "string")
                    root.fontMono = font.mono
                if (typeof font.ui === "string")
                    root.fontUi = font.ui
                if (root.weightNames[font.weight] !== undefined)
                    root.fontWeight = root.weightNames[font.weight]
            } catch (e) {
                // Keep the last good values: a half-written file must not
                // leave the bar colourless.
                console.warn("Theme: lemonrice.json unreadable —", e)
            }
        }

        onFileChanged: configFile.reload()
    }
}
