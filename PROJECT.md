# LemonRice — Project Reference

Custom Hyprland desktop built on quickshell. This is the handover document.
**Section 1 explains how the whole thing fits together — read that first.**
Section 2 is the list of environment gotchas that cost real debugging time;
several of them fail *silently*, so read them before changing anything.

- Config root: `~/.config/quickshell/topbar/`
- Helper scripts: `~/.local/bin/qs-*`
- Entry point: `shell.qml`
- Running instance: `quickshell -c topbar` (started from Hyprland autostart)

---

## 1. How it fits together

### One config file

Everything configurable lives in **`~/.config/quickshell/lemonrice.json`**:

```
{
  "theme":    "frutiger-aero",     which palette is active
  "font":     { mono, ui, size, weight },
  "settings": { animations, blur, shadows, transparency, gaps, aeroGlass,
                animationSpeed, blurAmount, transparencyAmount, gapsAmount },
  "bar":      { floating, transparent, barOpacity, widgets: { … } },
  "palettes": { "catppuccin-mocha": {…}, "frutiger-aero": {…}, … }
}
```

It replaced five separate files (`palettes.json`, `theme.txt`, `settings.json`,
`bar.json`, `font.conf`), each of which had grown its own parser — `load_palette`
existed in six copies. There is now one file and one accessor.

### One accessor: `qs-config`

**Nothing writes that file except `qs-config`.** Everything else either calls it
or reads the file and watches it.

```
qs-config theme                    the active theme's name
qs-config get settings.blur        one value        (on/off/number/string)
qs-config set bar.floating on      write it         (flock'd, validated)
qs-config env [theme]              BASE=… MAUVE=…   (bash: eval "$(...)")
qs-config palette|style [theme]    the palette / just its style block
qs-config themes [--custom|--standard]
```

`set` refuses a path that does not already exist, so a typo cannot quietly
add a key nothing reads. Writes take an exclusive lock: two read-modify-writes
racing used to leave a second `}` on the end of the file (gotcha #49).

### Two ways a value reaches the thing it affects

This is the distinction that makes the rest obvious:

**PULL — the consumer reads the file itself and watches it.** Applies instantly,
no script involved.

| who | what it takes |
|---|---|
| `Theme.qml` | palettes, active theme, font → the bar and all 13 panels |
| `BarSettings.qml` | the `bar` section |
| `SettingsService.qml` | the `settings` section |
| `colors/lemon.lua` (nvim) | palettes + active theme |
| `config/settings.lua` (Hyprland) | the `settings` section, on reload |

**PUSH — `qs-theme` writes the colours into each application's own config.**
Takes effect when that application next starts (except kitty, dunst and
YouTube Music, which reload themselves).

```
qs-theme <name>
   ├─ qs-config set theme <name>        ← the pull side needs nothing more
   ├─ kitty        current-theme.conf + SIGUSR1
   └─ 12 helpers:  gtk · kvantum · qt6ct · kde · dunst · btop · ytmd
                   hypr · hyprlock · zen · grub · sddm
```

**Adding a theme is still one block in `lemonrice.json`'s section and nothing
else.** Every helper reads it through `qs-config`.

### Who owns which compositor setting

**One file applies them: `config/effects.lua`.** blur, opacity, shadows,
animation on/off, gaps, rounding, window border. It is required **last** from
`hyprland.lua`, so `hyprctl reload` always lands the full correct state and
there is exactly one way anything gets applied.

It builds one table in four layers, later winning:

| layer | comes from | does |
|---|---|---|
| base | `theme.lua` + the user's sliders | what "on" means |
| glass | `settings.aeroGlass` | takes over blur, opacity and the border |
| switches | `settings.blur/shadows/…` | only ever turns things **off** |
| perf mode | `$XDG_RUNTIME_DIR/qs-mode.performance` | turns everything off |

The one exception is **ownership**: while glass is on, blur and transparency
belong to it and the switch layer does not touch them. That is not a special
case bolted on — the settings screen switches those two *off* when glass goes
on (three switches over one surface would be meaningless), so the stored "off"
is glass's own footprint, not the user saying they want no blur. Reading it as
intent is what used to switch glass back off a fraction of a second after
applying it.

This replaced four files that each wrote the same keys — `decorations.lua`,
`glass.lua`, `toggles.lua`, `perfmode.lua` — where the winner was decided by
require order and every new effect needed another "don't touch this" exception
somewhere else. `decorations.lua` now only holds group colours and the mouse
grab area.

Sliders (`blurAmount`, `gapsAmount`, …) are read here too. A number changes
what "on" *means*, so it belongs with the on-values rather than being layered
on afterwards — which is why moving a slider goes through `hyprctl reload`.

---

## 2. Hard-won environment facts (read first)

These are properties of *this machine*, not of quickshell in general. Each one
produced a bug that looked like something else.

| # | Fact | Symptom it caused |
|---|---|---|
| 1 | **quickshell 0.3.0 `ipc call` silently rejects arguments** even though `--help` documents them. | "The following argument was not expected". Workaround: pass data through a file (`~/.cache/qs-note-preview`, `~/.cache/qs-wallpaper-pending`). |
| 2 | **An IPC function named `show` does not register.** | `Target not found` / function list printed instead of running. Renamed to `preview`. Avoid `show` as an IpcHandler function name. |
| 3 | **`import Qt5Compat.GraphicalEffects` makes the whole component fail to register — with no error at all.** | `wallpaperFx` IPC target just missing. The circular wallpaper reveal is therefore hand-drawn with clipped horizontal bands, not `OpacityMask`. |
| 4 | **Hyprland runs the Lua config**, so `hyprctl dispatch` takes Lua: `hl.dsp.focus({ workspace = 2 })`, `hl.dsp.exec_cmd("...")`. Classic dispatcher syntax errors out. |
| 5 | **`hyprctl hyprpaper wallpaper "$MON,$IMG"` fails** ("invalid hyprpaper request") when monitor+path are inside *one* quoted string. Must be `"$MONITOR",cover:"$IMG"`. Without `cover:` the wallpaper is letterboxed instead of filling. |
| 6 | **`FileView.reload()` is async.** Calling `text()` right after returns the *previous* content. Read in `onLoaded` instead. |
| 7 | **`FileView` also loads once at startup**, firing `onLoaded`. Any window that opens itself from `onLoaded` will pop open on shell start. Both `NotePreviewWindow` and `WallpaperTransition` guard this with a `showRequested` / `playRequested` bool. This bug once left an invisible fullscreen overlay with Exclusive keyboard focus on top, which broke screenshots for an entire session. |
| 8 | **`QT_QPA_PLATFORMTHEME=qt6ct` is set but qt6ct is not configured**, so Qt's icon-theme lookup fails for anything only in `hicolor` (e.g. Claude). `Quickshell.iconPath(name, true)` returns `""`, and the unchecked form returns a URL that won't load. Icons are resolved by scanning the filesystem instead (`qs-icon-resolve` + `IconResolver.qml`). |
| 9 | **`slurp` only does free selection when stdin is a TTY.** Otherwise it parses stdin as a predefined box list: an open pipe (what quickshell's `Process` gives) makes it wait for EOF forever and never draw; `/dev/null` makes it exit instantly. Fix: feed it monitor rectangles and **do not** pass `-r`. |
| 10 | **A layer surface holding `WlrKeyboardFocus.Exclusive` blocks `slurp`** — it exits immediately with "selection cancelled". The screenshot overlay drops to `WlrKeyboardFocus.None` while selecting. |
| 11 | **A PanelWindow reports `width`/`height` as 100×100 while `visible: false`.** Animation geometry must come from `root.screen.width/height`. |
| 12 | **kitty auto-theme overrides the included theme.** If `~/.config/kitty/dark-theme.auto.conf` exists, kitty applies it in dark mode and ignores `current-theme.conf`. `qs-theme` writes both. |
| 13 | **libadwaita apps (gnome-calculator, gnome-characters, gnome color picker) ignore the GTK theme name** and read only `~/.config/gtk-4.0/gtk.css`. Superseded in detail by #25–#27: that file must **not** `@import` the catppuccin theme (it hardcodes its colors in 56 places), and on libadwaita 1.9 `@define-color` alone does nothing. |
| 14 | **KDE apps (gwenview) take colors from `kdeglobals`, not Kvantum.** Kvantum only sets the widget style. |
| 15 | **Several config dirs are owned by root** (from past `sudo` runs): `~/.config/btop`, `~/.config/fish`, `~/.local/share/kservices5`, some `~/.config/kitty` files. `~/.config/nvim` was fixed by the user. Scripts skip gracefully when a target isn't writable. |
| 16 | **No input-simulation tools** (`wtype`, `ydotool`) are installed. Clicking/typing in live layer surfaces cannot be driven from the CLI. Verify layout by rendering offscreen (`QT_QPA_PLATFORM=offscreen` + `grabToImage`) and live state with `grim -g`. |
| 17 | **Reading state in a binding while mutating it causes binding-loop warnings.** `IconResolver` and `ThumbCache` defer queue mutations with `Qt.callLater`. |
| 18 | **dunst has no `include` directive**, so theme colors are rewritten in place in `dunstrc` by key+section. |
| 19 | **Assigning `exclusiveZone` overrides `exclusionMode: ExclusionMode.Ignore`.** A window with both was pushed down by the bar's 30px zone (measured: `0,30 1920x1050`). Ignore alone gives the full `0,0 1920x1080`. This is why the screenshot freeze frame and the wallpaper transition were drawn ~15px too low. Fullscreen overlays must set **only** `exclusionMode: ExclusionMode.Ignore`. |
| 20 | **A hidden PanelWindow reports `height` as 500** (not 100) and only gets its real height a few frames after `visible = true`. Never compute animation `from`/`to` from `root.height` at open time — the launcher panel was animated to y ≈ -386 and popped into place later. Animate a separate offset property and leave the `y` binding intact. |
| 21 | **`hyprctl keyword` does not work here** — the config is Lua, so it answers "keyword can't work with non-legacy parsers. Use eval." Live changes go through `hyprctl eval 'hl.config({...})'`. The Lua parser also **rejects gradient colors** (`"rgba(a) rgba(b) 45deg"` → `invalid color`); single colors only. |
| 22 | **YouTube Music Desktop watches the custom CSS file** (`fs.watch`): a `change` event re-injects the CSS live, but a `rename` event makes it **null out `customCSSPath`** and stop watching. So write the CSS in place (truncate+write) — never via temp-file+rename. And don't rewrite `config.json` while the app runs: it stores its own state (`lastVideoId`, `windowBounds`) there and the racing write is what crashed it on theme switches. |
| 35 | **A `PopupWindow` with `grabFocus: true` cannot be opened from anything but a click on its parent.** An xdg_popup grab needs an input serial, so the compositor refuses it — `qt.qpa.wayland: Failed to create grabbing popup. Ensure popup … parent window has received input` — and the window silently never appears. This is why the control centre opened fine from the cat but not from `Super+Ctrl+C`, and why `qs-color` could not bring it back after a pick (by then the last input belonged to hyprpicker's surface). The fix is the pattern the calendar already used: a **`PanelWindow` with `mask: Region { item: panel }` plus `HyprlandFocusGrab`**, which needs no serial. Anything opened by IPC must not be a grabbing popup. |
| 36 | **A running quickshell can serve a stale scene while still logging "Configuration Loaded".** Several rounds of "my edit is not applying" were exactly this: `qs ipc` talked to the new config while the visible surfaces were the old ones. When a change refuses to show up, `qs kill -c topbar` and relaunch before believing anything about the code. |
| 37 | **nvim-treesitter's `main` branch accepts the old option table and ignores it.** `setup({ ensure_installed, auto_install, highlight, indent })` returns without a word — on `main` those are not options at all; `setup()` takes only `install_dir`, and the three jobs moved to `require("nvim-treesitter").install(langs)`, `vim.treesitter.start(buf, lang)` and `'indentexpr'`. The config had been running this way for months with **zero parsers installed**, so treesitter highlighting was off for every language except the handful Neovim bundles itself (c, lua, markdown, query, vim, vimdoc) — which is exactly why it looked like it was working. `main` also builds every parser with the tree-sitter CLI, so **`tree-sitter-cli` is a hard dependency**: without it nothing installs. |
| 38 | **A Lua colorscheme that doesn't set `g:colors_name` leaves it `nil`** — `:colorscheme` does not set it for you, the file has to. `colors/ayu-red.lua` never did, so lualine's `theme = "auto"` had nothing to look up and fell back to its own defaults. Without `highlight clear` + `syntax reset` at the top, each scheme also paints *over* the previous one instead of replacing it, so whatever groups the new one doesn't define keep the old colors. |
| 39 | **Setting `'background'` inside a colorscheme re-sources that colorscheme** (measured: the file runs twice). A colorscheme that flips light/dark must therefore clear `g:colors_name` before assigning `'background'`, or the second pass repeats every `nvim_set_hl` call it is in the middle of making. |
| 40 | **Two palette keys can hold the same hex.** Everforest's `mauve` and `green` are both `#a7c080`, Gruvbox's `mauve` and `pink` are both `#d3869b`. Harmless in the bar, where those two never sit next to each other — fatal in an editor, where it makes keywords and strings the same color. `lua/lemon/highlights.lua` resolves collisions with `distinct()` for the syntax roles only; the UI accent stays whatever `mauve` is, because it has to match the bar. |
| 41 | **A lualine theme table may contain nothing but modes.** lualine walks it with a nested `pairs()` and never checks what it found, so one extra scalar field — a theme name kept for debugging, a stray color — becomes `bad argument #1 to 'pairs' (table expected, got string)` thrown out of `lualine/highlight.lua:208` during `setup()`, before the statusline is ever drawn. Worth knowing how to *test*: `require("lualine.themes.lemon")` succeeds and its fields read back fine, so a probe that only inspects the table proves nothing. Only `require("lualine").setup()` walks it, and lualine is `event = "VeryLazy"`, so a batch `nvim -c … -c qa!` can exit before it ever loads. Force it with `require("lazy").load({ plugins = { "lualine.nvim" } })`. |
| 42 | **A `PopupWindow` paints an opaque background unless told not to.** Every `PanelWindow` in this config already sets `color: "transparent"`; the three popups (`NotificationsPopup`, `SystemTrayPopup`, `MediaPlayerPopup`) never did, and nobody noticed for as long as every corner was square. The moment a theme rounded them, the rounded Rectangle inside was sitting on a square opaque fill and the corners read as sharp — the panel looked un-themed while its colors were perfectly correct. |
| 43 | **Kvantum only styles widgets — the actual colors come from qt6ct, and `color_scheme_path` was hardcoded.** `~/.config/qt6ct/qt6ct.conf` pointed at `colors/catppuccin-mocha-mauve.conf` and **no theme script ever touched it**, so every Qt app got catppuccin's palette whatever the theme was. Five dark, catppuccin-ish themes hid this completely; the first light theme left FeatherPad's text area dark on a light menu bar. `qs-theme-qt6ct` now generates the scheme. Two traps inside it: the 22 columns are `QPalette::ColorRole` order (13 = HighlightedText, which was `crust` and is the same light-on-light bug as gotcha #38), and **`icon_theme` matters too** — `breeze-dark`'s monochrome icons are light, so on a light background Dolphin's sidebar icons vanished. **qt6ct is read at app start**, so nothing already running changes. |
| 44 | **YouTube Music hardcodes white text on list and header components.** The `--yt-spec-text-*` variables `qs-theme-ytmd` sets are honoured by the nav and player bars but not by `ytmusic-responsive-list-item-renderer`, the guide entries or the playlist header — those assume the cover-art layer behind them is dark. Overriding them needs `color: inherit !important` on the children to beat the hardcoded value, then the secondary rows dimmed back explicitly or the whole list flattens to one tone. Verified by grabbing the running app: it hot-reloads the CSS (gotcha #22), so the edit-and-look loop works without restarting it. |
| 45 | **A theme is not only colours — three separate places hardcoded the *shape*.** Hyprland's `decoration:rounding` was never set (windows square), `dunstrc`'s `corner_radius = 0` was only ever read, never written, and the shell's own `radius: 0` (gotcha above). All three now come from the palette's `style` block. Two traps: `rounding` lives under **`decoration`**, not `general` — putting it in the wrong table makes `hl.config` abort the *whole* call and say so only on stderr (gotcha #33) — and `decorations.lua` has to read it back from `theme.lua`, or `hyprctl reload` silently reverts the live value (gotcha #32). |
| 46 | **Every "colour on an accent" in this project was `crust`, and every one of them broke on the first light theme.** Found in four independent places: `Theme.qml` (mauve chips), `lua/lemon/highlights.lua`, `qs-theme-kde` (`accent_text` → Dolphin's selected row) and `qs-theme-qt6ct` (QPalette's HighlightedText). It only ever worked because crust is the *darkest* colour in a dark palette. The fix is the same everywhere: pick whichever pole of the palette is further from the background in luminance. **A second, quieter variant:** `ForegroundInactive` was `overlay0`, which is a fine dim tone on a dark base and drops to ~3:1 contrast on a light one — `qs-theme-kde` now falls back to `subtext0` when the gap is too small. |
| 47 | **Themes that only set backgrounds look correct until the palette flips.** `qs-theme-zen` set a dozen `--zen-*` and `--toolbar-bgcolor` variables and no text colour at all; Firefox's own chrome kept deciding "dark", so every tab title and the URL bar went light-on-light. Same shape as the YouTube Music bug (gotcha #44). When adding a target, the question to ask is not "did I set its background" but "does it decide its foreground from something I control". |
| 48 | **A layer surface is not blurred however translucent it is.** Aero Glass makes the shell's panels see-through, but without `hl.layer_rule({ blur = true })` per namespace the compositor draws the desktop through them unblurred — you could read the text behind a panel. Two traps in that rule: **`match.namespace` is a REGEX, not a Lua pattern** — written as `"^quickshell%-settings$"` it is silently accepted, listed by `hyprctl layerrules`, and matches nothing — and `ignore_alpha` is needed so the fully transparent region around a masked panel is left out of the blur. |
| 49 | **`qs-settings` was a read-modify-write with no lock.** Two calls landing together (the settings screen writing while the CLI does, which Aero Glass made routine by touching three keys at once) left a second `}` stapled onto `settings.json` — after which every later write refuses, by design, until a human fixes it. Now serialised with `flock`. A temp file + rename would have been the other fix and is **wrong here**: the bar watches this path and a rename swaps the inode out from under the watch (same reason as the ytmd CSS, gotcha #22). |
| 50 | **An opaque fill that matches the background is invisible until the background moves.** The resting workspace box was painted `Theme.base` — identical to the bar, so it looked right for as long as the bar was always opaque. The moment the bar went translucent every box was a hole in the glass. Anything meant to read as "nothing" should paint nothing. |
| 51 | **A layer blur rule blurs the WHOLE layer surface, not the visible panel.** Every one of these windows is full-screen with `mask: Region { item: panel }`, so blurring the layer blurred the entire desktop into a wash the moment any panel opened. `ignore_alpha` is the threshold *below* which a pixel is skipped, and it has to land **between** the two translucent things such a window draws: the full-screen backdrop (0.45) and the pane itself (`Theme.glassOpacity`, 0.55). 0.1 caught both; 0.5 catches only the pane. Changing either of those two numbers means revisiting this one. |
| 52 | **(Fixed by the `effects.lua` merge — kept because the shape recurs.)** `toggles.lua` ran after `glass.lua` and had the last word. Aero Glass switches blur and transparency *off* — deliberately, so the settings screen shows one truth rather than three switches over the same surface — and `toggles.lua` then acted on that "off" and forced `active_opacity` back to 1, undoing glass a fraction of a second after it was applied. It now skips blur and opacity entirely while glass is on: those are not its to touch. The general shape of this trap is that a file which only ever turns things *off* still fights anything that turns the same thing *on* later. |
| 53 | **`read_current` could not see an animated wallpaper.** It read the `path =` line out of `hyprpaper.conf`, but an animated wallpaper runs under **mpvpaper** and never reaches hyprpaper (a video path in its config would be invalid — gotcha #5's neighbour). So while a video was on screen it reported the last *still* image instead, and `qs-wallpaper apply-theme` compared the incoming theme's wallpaper against that stale answer, decided "already on this image" and did nothing. Switching to a theme whose wallpaper is a still, from one whose wallpaper is a video, left the old video playing. It now asks `pgrep -a mpvpaper` first and only falls back to `hyprpaper.conf`. |
| 54 | **A compositor cannot lay a gradient over a window.** Aero's glass sheen is drawn by `GlossOverlay` on the shell's own surfaces, but an application window is the application's to paint — Hyprland has blur, opacity and borders, and no gradient. kitty is the one app here that can do it itself (`background_image` + `background_tint`), so `qs-theme` generates one in the theme's colours and includes it. Everything else is out of reach. **The `include`d file is emptied rather than deleted when glass is off**: kitty refuses to start if an included file is missing. |
| 55 | **`xdg-desktop-portal-gtk` caches the light/dark preference for its whole lifetime.** The GTK file chooser stayed dark for two sessions after `color-scheme` was fixed (gotcha #43's neighbour) — not because the setting was wrong, but because the portal is a long-running user service that had read it at login and never looked again. `gtk.css` was correct the whole time. `systemctl --user restart xdg-desktop-portal-gtk` fixes it; nothing in the theme scripts can, so it belongs in the "needs a re-login" bucket alongside `GTK_THEME` (#25). |
| 56 | **A wide blur over a very transparent window reads as mush, not glass.** Aero Glass first used `size = 8, passes = 3` with `active_opacity 0.85`. Dropping the window to 0.72 and the blur to `size = 3, passes = 2` looks *more* like frosted glass, not less: the point is that shapes behind stay recognisable while detail goes. A big radius plus high transparency just averages the desktop into a colour field. |
| 57 | **A `background_image` makes kitty opaque.** The Aero gradient was handed to kitty through `background_image` + `background_tint`; kitty then ignores `background_opacity` entirely and the terminal goes flat matte — the transparency that made it glass in the first place is gone. Reverted: the glass is worth more than the gradient. The `include`d `gloss.conf` is **emptied rather than deleted**, because kitty refuses to start when an included file is missing. |
| 58 | **Nothing in the shell can recolour an SVG.** The media player's transport buttons were `Image` elements with the colour baked into the file, so they could only be made visible by filling the button behind them with `Theme.text` — which reads as a light chip on a dark theme and a black blob on a light one. Recolouring would need `Qt5Compat.GraphicalEffects`, which makes the whole component fail to register with no error (gotcha #3). They are Nerd Font glyphs now: a glyph is text, and text takes a colour. |
| 59 | **A progress bar drawn as text has no colours to theme.** The media popup's bar was `"█".repeat(filled) .. "░".repeat(empty)` in a single `Text`, so the filled/empty distinction came from the *glyphs*, not from colour. On a dark palette that reads; on a light one both glyphs are dark and the bar collapses into one flat strip. It is two Rectangles now, like every other slider in the shell. |
| 60 | **YouTube Music's splash screen is in the asar too, in a different file from the title bar.** `customCSSPath` only reaches the web view, and the splash (red button + loading bars) is drawn before it — a Vue component in `renderer/assets/main_window-*.css` with three hardcoded colours: `#000` background, `#969696` status text, `#fff` loader bars. The white bars are the one that matters: on a light palette they vanish entirely. `qs-ytmd-titlebar` patches this file alongside `TitleBar-*.css` now. |
| 61 | **A prefab can only be saved for the theme that is currently active.** The values a prefab stores are the *live* ones, so writing them under another theme's name would record a look that theme never had. Every theme is still listed on the page — greyed, with whether it holds a prefab — because the point is seeing which are set up; only the active row is pressable. Restore happens in `qs-theme` **before** the helpers run, so anything reading a setting (`effects.lua` via `hyprctl reload`, the bar via its FileView) sees the incoming theme's values rather than the outgoing theme's. |
| 62 | **The running cat can be switched off now, and that used to be a trap.** It is the control centre's handle, so a switch that hid it hid its own way back in — which is why it stayed out of the widget list for years. The settings screen has its own keybind (Super+Z), so the cat is no longer the only door and the objection is gone. Any future widget that is *also* a way into settings inherits the same question. |
| 65 | **A `Repeater` over a computed JS array rebuilds every delegate, every time the binding runs.** The array is a new object, so the model "changed" — even when the ids in it are identical. The workspace overview's columns re-evaluated on any workspace change at all, which destroyed and recreated every card several times a second; a card the mouse had picked up was deleted out from under the drag and the window appeared to vanish. Fix: keep an explicitly assigned snapshot (`columns`) beside the binding (`liveColumns`) and only resync it when it is safe to. Quickshell's own `ObjectModel`s (`Hyprland.workspaces`, `workspace.toplevels`) do **not** have this problem — their objects keep identity, so a Repeater on one only builds what actually appeared. |
| 64 | **`hl.dsp.window.move` drags the view along with the window.** Moving a window to workspace 8 by address, from a keybind or an overview, also switches the monitor to 8 — the old `movetoworkspacesilent` split does not exist in the Lua API and `silent = true` is ignored. The option is **`follow = false`**: `hl.dsp.window.move({ workspace = 8, window = "address:0x…", follow = false })`. Verified on a throwaway window, both ways round. |
| 63 | **Two quickshell instances answer `qs ipc` and neither one wins.** After a `qs kill -c topbar` that did not take, a second instance was launched alongside the first; `qs -c topbar ipc show` then hung until it timed out rather than reporting the ambiguity. `quickshell list --all` is what shows it. `pkill -x quickshell` and start one — and check the count afterwards, because this is invisible from the screen: two instances draw one bar on top of another. |
| 27 | **`hl.dsp.send_shortcut` silently does nothing without an explicit target window.** `{ mods = "CTRL", key = "V" }` and `window = "activewindow"` both return `ok` and go nowhere; `window = "address:0x…"` works. `qs-paste` reads the address from `hyprctl activewindow -j`. (This is how Super+V pastes without `wtype`/`ydotool`, which are still not installed.) |
| 26b | **GTK4 apps that don't use libadwaita (pavucontrol is gtkmm-4.0) ignore both** `@define-color` and the libadwaita variables — Adwaita's own GTK4 sheet hardcodes its colors. They only respond to direct widget rules, and the selectors had to be found by probing with garish colors: the background is painted by `viewport`/`stack` (not `window`), the volume bar by `scale > trough > highlight`, its knob by `scale > trough > slider`. |
| 26 | **libadwaita 1.9 is driven by CSS variables, not `@define-color`.** `:root { --window-bg-color: … }` in `~/.config/gtk-4.0/gtk.css` recolors the app; the old `@define-color` block alone changes nothing (it is kept for GTK3). The accent is separate again: `--accent-bg-color` loses to the system accent, so `gsettings set org.gnome.desktop.interface accent-color <named>` is also set. |
| 25 | **`GTK_THEME` in the environment disables user CSS entirely.** Not just the theme name — with it set, GTK never reads `~/.config/gtk-*/gtk.css`, so every theme switch was a no-op for pavucontrol / gnome-calculator / gnome-characters / the color picker. **Setting it to an empty string is not enough**, it has to be absent (verified: red test CSS only applied with `env -u GTK_THEME`). It was hardcoded to catppuccin in `environment.lua`; that line is gone, but Hyprland's Lua API cannot unset an env var at runtime (`hl.env` requires a string), so the fix only lands after a **re-login**. |
| 24 | **Zen: overriding `--zen-primary-color` / `--zen-branding-*` is not enough for the tab sidebar.** The sidebar sits on `#navigator-toolbox`, and behind it the workspace gradient is painted on layers whose variables JS writes *on the element*, so a `:root` override never reaches them. Paint `#navigator-toolbox` (and `.zen-browser-generic-background::after/::before`) directly. userChrome.css itself only loads at startup and only with `toolkit.legacyUserProfileCustomizations.stylesheets = true`, so theme switches need a Zen restart. Verified by running a throwaway instance: `MOZ_NO_REMOTE=1 zen-browser --new-instance --profile <dir>`. |
| 34 | **`cursor:no_warps` is global — it can't want two different things for two different keybinds.** Super+arrow is meant to warp the pointer to the newly focused window (Hyprland's default), Alt+Tab is meant to leave the pointer exactly where it was — both went through the same dispatcher family, so one `no_warps` value can't satisfy both. Solved by leaving `no_warps` at its default (off, so Super+arrow's native warp works) and having `WindowSwitcherWindow.qml`'s `focusWindow()` go through `qs-focus-keep-cursor` instead of a raw `hl.dsp.focus` — that script saves `hyprctl cursorpos`, focuses, then dispatches `hl.dsp.cursor.move` back to the saved point. Only Alt+Tab's commit path uses it. |
| — | **`input:mouse_refocus` was set to `false` for a while and is now back to its default.** It was a second guard for the same focus problem, but turning it off leaves pointer focus stale until the cursor crosses a window boundary — and a stale pointer focus can put a button press and its release on two different surfaces, which the application sees as a button that never came up (a click then reads as a drag). Its official description only exists in the Hyprland binary, not the Lua stub's doc comments: `strings /usr/bin/Hyprland \| grep mouse_refocus`. |
| 33 | **`hl.config` aborts the whole call on one unknown key, and reports it only on stderr.** Performance mode passed `misc.vfr`, which moved to `debug.vfr` in Hyprland 0.56 — so `hyprctl eval` answered `unknown config key 'misc.vfr'` and the rest of the table applied only partially, depending on Lua's table iteration order. `qs-mode` sent that to `/dev/null`, so the mode looked like it worked and mostly didn't. Check `hyprctl eval` output when a config change silently does nothing. |
| 32 | **`hyprctl reload` silently undoes everything applied with `hyprctl eval`.** It re-runs the Lua config, so any live tweak is reverted while whatever state file drove it still says it is active. Anything meant to survive a reload has to live *in* the config: `config/effects.lua` is required last from `hyprland.lua` and re-derives the whole state every time. |
| 31 | **`grabToImage` on a window's `contentItem` fails** with "item has no QML engine" — quickshell's `ProxyWindowContentItem` isn't engine-bound. Offscreen verification (gotcha #16) has to grab an Item *declared in QML*: wrap the thing under test in a `Rectangle { id: shot }` and grab that. Recipe: put a throwaway `_probe_*.qml` next to `shell.qml`, run `QT_QPA_PLATFORM=offscreen qs -p <file>`, save with `res.saveToFile(...)`, delete it after. Note the running instance reloads every time a file appears or changes in the config dir. |
| 30 | **`hl.config({ general = … })` is global — there is no "current workspace" version of it.** Super+H closing the gaps this way closed them on *every* workspace. The per-workspace path is `hl.workspace_rule({ workspace = "4", gaps_in = 0, gaps_out = 0, border_size = 0 })`, which applies live with no reload. Two follow-ons: `hyprctl workspacerules` returns `[]` for rules created this way (it only lists config-file rules), so the toggle state cannot be read back from Hyprland and is kept in per-workspace files; and `gaps_out` on a **non-visible** workspace only takes effect when that workspace is next shown (`gaps_in`/`border_size` apply immediately). Harmless here since Super+H always acts on the visible workspace. |
| 29 | **A window class is not always reverse-DNS.** Taking `appId.split(".").pop()` to turn `com.anthropic.Claude` into `Claude` also turns `Minecraft* 26.2` into `2` — the Alt+Tab cards showed a window called "2". `WindowSwitcherWindow.prettyName()` only strips the prefix when the whole id matches `^[A-Za-z0-9_-]+(\.[…])+$` and the last segment starts with a letter. |
| 28 | **Synthetic keys never go through Hyprland's keybind processing.** `hl.dsp.send_key_state` / `send_shortcut` inject straight at the target window, so they cannot be used to test a bind — a release bind that works for real key presses looks dead when probed this way. (Also: `send_key_state` requires `mods`, even empty: `{ mods = "", key = "Alt_L", state = "down", window = "address:0x…" }`.) There is still no `wtype`/`ydotool`, so **binds can only be verified by a human pressing the key**; verify everything else by driving the IPC directly and `grim`-ing the result. |
| 23 | **`ytmusic-browse-response` has only two light-DOM children**: `#background.immersive-background` and `.background-gradient` — and the whole page content lives *inside* `.background-gradient`. `display: none` on either wipes the playlist. The cover-art gradient is not reachable as a background (`background-image: none !important` on `*`, `visibility` inheritance and shadow-DOM tricks all failed); the fix is to give the `.background-gradient` sibling an **opaque theme-colored background** so it covers the gradient underneath it. |

### Useful commands while debugging

```bash
quickshell list --all                                   # running instances
LOG=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1)
quickshell log "$LOG" | tail -40                        # errors (config keeps last good on failure)
qs -c topbar ipc show                                   # registered IPC targets
hyprctl layers -j                                       # which layer surfaces are mapped
```

---

## 3. QML files (`~/.config/quickshell/topbar/`)

### Core

| File | Purpose |
|---|---|
| `shell.qml` | Entry point. Instantiates `Bar`, `LauncherWindow`, `NotePreviewWindow`, `ClipboardWindow`, `WallpaperWindow`, `WallpaperTransition`, `ThemeWindow`, `ScreenshotWindow`, `WindowSwitcherWindow`. |
| `Bar.qml` | The 30px `PanelWindow` at the top. Passes `screen.name` to `CenterSection`. |
| `Theme.qml` | **Singleton.** All colors **and now the shape**. Reads the palettes and the active theme name from `~/.config/quickshell/lemonrice.json` with `watchChanges: true` — theme switches *and* palette edits apply live with no restart. Keeps one inline fallback palette so a missing/broken JSON can't leave the bar colorless. Every other file uses `Theme.base`, `Theme.text`, `Theme.mauve`, … (~230 hardcoded hex values were replaced by these). **The style half** (`Theme.radius`, `radiusPanel`, `gloss`, `borderWidth`, `panelOpacity`) comes from an optional `style` block in the palette, merged over a fallback that is exactly the house look — square, flat, opaque — so the five standard themes render byte-identically and only a theme carrying `style` changes anything. `themeNames` / `customThemeNames` split the list for the picker; `styleFor(name)` gives *another* theme's shape so a row can preview itself. `isLight` is the luminance test, kept here rather than in each caller. Three helpers do the work the old hardcoded values used to: **`textOn(bg)`** picks a readable foreground for text drawn *on* an accent fill — the habit was `Theme.crust`, which worked for years only because crust is the darkest colour in a dark palette and made mauve chips light-on-light the moment a light theme existed; **`radiusUpTo(size)`** caps the radius at half an element's size, so a 6px unread dot or a 3px accent bar rounds proportionally instead of becoming a circle; **`panelColor`** is `base` with `panelOpacity` baked into the colour, because putting it on a Rectangle's `opacity` would fade the text on top too. |
| `PerfMode.qml` | **Singleton.** Whether performance mode is on, plus `every(ms)` — multiplies a polling interval by 4 while it is. The bar stays running in performance mode but there is no reason for it to keep spawning ~4-5 processes a second (`hyprctl activewindow` twice a second, five stat processes including `ddcutil` every two seconds, `dunstctl`, `hyprctl clients`). State arrives over IPC from `qs-mode`; on shell restart it is read once from the flag file. The clock is deliberately **not** scaled. |
| `IconResolver.qml` | **Singleton.** `iconFor(name)` → `file://` path. Batches unknown names to `qs-icon-resolve`. Exists because Qt's icon lookup is broken here (gotcha #8). Also owns the **appId → icon** matching (`iconForApp`): StartupWMClass → `.desktop` id/name → the appId as an icon name → app name contained in appId. `CenterSection` and the Alt+Tab switcher both call it, so there is one place to fix when an app comes out iconless. |

### Bar sections

| File | Purpose |
|---|---|
| `LeftSection.qml` | Date (click → calendar), time, focused-app name (hidden when empty, along with its separator), runcat. The **cat is the control centre button** — it was the only decorative thing in the bar with room to be one. Hover highlight and a mauve cat while the panel is open are the whole affordance; a chevron badge was tried and removed. |
| `CenterSection.qml` | Workspaces. Hides numbered workspaces and shows a single "Special" box when a special workspace is visible (driven by Hyprland's `activespecialv2` event, filtered by monitor). Hover expands a box to show app icons; `resolveIcon()` matches by `StartupWMClass` → id/name → icon name, and falls back to a letter tile. |
| `RightSection.qml` | Media controls, CPU/RAM/temp (click → btop), volume, system tray, notification bell with unread badge. **Player pick:** first one that is playing, else first one with a track title, else none — `Mpris.players.values[0]` used to land on the kdeconnect phone player (no track, not playing), which hid the real player and left the section's separator floating with nothing next to it. Reading `isPlaying`/`trackTitle` of *every* player in the binding is deliberate: an early return would not re-evaluate when a later player starts. |

### Control centre

| File | Purpose |
|---|---|
| `SettingsService.qml` | **Singleton.** Two kinds of state that behave differently on purpose. **Stored:** `animations`, `blur`, `shadows`, `transparency`, `gaps` in `lemonrice.json` — written by shelling out to `qs-settings` rather than from QML, so the CLI and the panel cannot drift apart, and read back through a watched `FileView`, so `qs-settings set` in a terminal moves the switch in the bar. Absent key = on, so a fresh install looks normal instead of switched off. **Probed:** encrypted DNS and the microphone are owned by the system, so they are asked for, and only while the panel is open (`polling`) — this bar is watched for its own resource use. Switches move optimistically on click because `qs-settings` shells out to `hyprctl` and a lagging switch reads as broken. |
| `AdbService.qml` | **Singleton.** State for the Phone page: `adb devices -l`, the paired list, and the progress line of a running connect. Every bit of adb logic is in `qs-adb`, including the search — this only polls and displays. Polled while the Phone page is open, plus a single refresh when the panel opens so the tile caption is right; an adb process every two seconds for a caption would not be. |
| `BarSettings.qml` | **Singleton.** How the bar looks (`floating`, `transparent`, `barOpacity`) and which parts of it are drawn, in `lemonrice.json`'s `bar` section. Separate from `SettingsService` because these never leave quickshell — nothing else reads the file, so it is written straight from QML with `FileView.setText` and no script in the middle. Everything defaults on except `cava`. **The running cat is deliberately not in the list**: it is the handle for the panel, and a switch that hides its own way back in is a trap. |
| `CavaService.qml` / `CavaBar.qml` | **Singleton + widget.** Optional audio spectrum either side of the workspaces. cava does the analysis and prints one line per frame in raw ASCII mode (`~/.config/quickshell/cava.conf`); the service keeps the process alive only while the toggle is on, so an install that does not use it pays nothing. `available` gates the toggle as well, because cava is a package you may not have and a switch that silently does nothing is worse than one that says why. The right-hand strip is mirrored so the pair reads outward from the centre, and both are part of `CenterSection`'s width, so the workspaces stay centred instead of being shoved sideways. |
| `ColorService.qml` | **Singleton.** The colour history from `~/.local/share/quickshell/colors.json` (watched, newest first) plus the conversions the page shows. `rgbText`/`hslText`/`contrastText` go through `Qt.color()` rather than parsing the hex by hand, so the numbers match what the swatch actually renders. Picking is **not** done here — it is `qs-color`, which is also what the keybind runs. |
| `ControlCenterPopup.qml` | The panel under the cat, a **masked `PanelWindow` + `HyprlandFocusGrab`, not a `PopupWindow`** — see gotcha #35, it is the reason the colour page used to go nowhere. `anchorX` is pushed in by `LeftSection` because the bar's left side changes width with the focused-app name. **One box, several pages that morph into each other** the way the calendar's month grid becomes the note editor: the home page is a landscape 3x2 grid of tiles (Appearance, System, Top Bar, Phone, Color, Reload) and pressing one *becomes* that page rather than opening a second window. `page` drives the cross-fade, the header swap and the height in one place; every page is always built and stacked, only the container height animates. `page` resets to home on close, so the panel never reopens mid-flow. The window is transparent and fixed-height with `mask: Region { item: panel }`, so only the panel takes clicks and the morph resizes a Rectangle rather than a window — resizing the window itself flashed white around the edges every frame the surface grew faster than the scene painted. **Reload calls `Quickshell.reload(true)`** — spawning `quickshell -c topbar` left the old instance running and put a second bar on the screen. IPC target `controlCenter`: `toggle`/`open`/`close`, plus `color`, which is how `qs-color` lands the panel on the picked colour. |

**Encrypted DNS needs root** and there is no polkit authentication agent in this session (only `polkitd`), so the row opens `kitty --app-id FloatDns` running `sudo …/scripts/dns-toggle.sh`, where sudo can actually prompt. `--status` is the one mode the bar calls directly — reading the conf file needs no root. A window rule floats and centres `FloatDns`.

**The colour round trip** is worth following once, because it is shaped entirely by gotcha #1 (`ipc call` rejects arguments). The Color tile and `Super+Alt+X` both run `qs-color pick`; the tile closes the panel first, since a layer surface holding focus over hyprpicker's frozen screen is the same thing that breaks `slurp` (#10). hyprpicker copies the hex to the clipboard itself, `qs-color` prepends it to `colors.json`, and only then calls `ipc call controlCenter color` — the colour travels in the file, the IPC call only says which page to open. `ColorService` is already watching that file, so the page is populated before it appears.

### Notifications

| File | Purpose |
|---|---|
| `NotificationService.qml` | **Singleton.** Polls `dunstctl history` / `is-paused` / `/proc/uptime` every 2s in one shell command. Tracks unread via `lastSeenId` persisted to `~/.cache/quickshell-notif-seen`. Strips pango markup and the `░` countdown bar that `dunst-notify` appends. |
| `NotificationsPanel.qml` | Panel body, **two pages that morph into each other** (like the calendar's grid ↔ editor): the list (title, DND toggle, count, "Clear all", per-item dismiss, unread dots) and a **detail page** opened by clicking a row. The list elides the title and caps the body at 3 lines; the detail page wraps both in full and scrolls when the message is longer than the panel, with `‹ Back`, `Copy` (summary + body → `wl-copy`) and `Dismiss`. The header strip is shared and cross-fades between the two. The detail holds a **copy** of the entry, not its id — history is re-read every 2s, so looking it up each time would make the message vanish mid-read if it aged out. |
| `NotificationsPopup.qml` | `PopupWindow` wrapper anchored to the bell. |

### Calendar & notes

| File | Purpose |
|---|---|
| `CalendarService.qml` | **Singleton.** Notes in `~/.local/share/quickshell/calendar-notes.json`. Note shape: `{id, date:"YYYY-MM-DD", hour, minute, text, images:[], fired}`. Reminder timer (20s) fires due notes via `qs-note-reminder`; notes overdue by >12h are marked fired silently. Bulk delete helpers: `removeDate/removeMonth/removeYear`, `countFor*`. Needs `preload: true` on its FileView or it never reads. |
| `CalendarPanel.qml` | Two pages in one box that morphs between them: month grid ↔ note editor (280ms). Month/year pickers. **Right-click** on a day / title / month cell / year cell → bulk delete with a confirmation overlay. |
| `NoteEditor.qml` | Landscape note screen: Back button, hour slider, minute slider, note text (Flickable so long notes scroll; Enter saves, Shift+Enter newline), `+` image picker via zenity, saved-notes chips. Exposes `busy` while the picker runs. |
| `HSlider.qml` | Segmented progress-bar-style value picker. Current segment is a different color and taller. |
| `CalendarWindow.qml` | Layer window under the date. Fixed size with `mask: Region { item: panel }` so clicks outside the visible panel pass through. Focus grab disabled while `panel.busy` (zenity) plus a 700ms guard — otherwise the picker stealing focus closed the calendar and lost the note. |
| `NotePreviewWindow.qml` | Opened by the reminder notification's Preview action. Reads the note id from `~/.cache/qs-note-preview`. IPC function is `preview`, **not** `show` (gotcha #2). The header has one button — **Delete** (no confirmation, deletes and closes); closing is Esc or a click outside. |

### Launcher

| File | Purpose |
|---|---|
| `LauncherService.qml` | **Singleton.** Tabs, query distribution, result merging, `activateSelected()`, `toggleFavorite()`. |
| `LauncherProvider.qml` | Base type: `providerId`, `label`, `glyph`, `showsEmptyQuery`, `hasPreview`, `query`, `results`, `activate`. |
| `LauncherAppsProvider.qml` | Apps from `DesktopEntries`, scored by name/comment match. |
| `LauncherFilesProvider.qml` | Async file search via `qs-file-search`, debounced 180ms. |
| `LauncherFavoritesProvider.qml` | Pinned apps in `~/.config/quickshell/favorites.json`. |
| `LauncherSystemProvider.qml` | Lock / log out / suspend / reboot / boot to Windows / shut down / performance mode / reload shell / audio / btop. |
| `LauncherPanel.qml` | Search row, tab chips, results list, Files preview pane. List area keeps ≥5 rows of height while the preview is open so a single result doesn't cut it off. |
| `LauncherPreview.qml` | File preview: name, path, size + image (direct) or PDF first page (`qs-file-preview`). |
| `LauncherWindow.qml` | Bottom-anchored overlay, `bottomGap: 18`. IPC: `toggle`, `open`, `close`, `system`, `files`. |

### Clipboard / wallpaper / theme / screenshot

| File | Purpose |
|---|---|
| `ClipboardService.qml` | **Singleton.** Reads `qs-clip list`. Tabs All/Text/Images, pins in `~/.config/quickshell/clipboard-pins.json`. |
| `ThumbCache.qml` | **Singleton.** Clipboard image thumbnails via `qs-clip thumb`, one process at a time. |
| `ClipboardWindow.qml` | Bottom-anchored panel. Left/Right arrows switch tabs (plain only — Ctrl/Shift still move the text cursor). Picking an entry copies it, closes the panel and **pastes into the window underneath** (260ms later, once focus is back — see `qs-paste`). The entry is never removed from history; copying also makes it the newest one. |
| `WallpaperWindow.qml` | Coverflow carousel. **↑/↓ switches Static ↔ Animated**; animated wallpapers live in `<theme>/Animated/` (mp4/webm/mkv/mov/gif) and their cards show a frame extracted by ffmpeg — the thumb filename is `md5(path).png`, computed identically by the script and by `Qt.md5()` in QML, so no IPC is needed to pair them. Opens on the **currently set** wallpaper. Left-click centre = apply (animated). Lists the active theme's folder, but the choice itself is theme-independent (see §5). |
| `WallpaperTransition.qml` | `WlrLayer.Bottom` (above hyprpaper, below windows), `mask: Region {}` so it's click-through. Three random effects: circular reveal (80 clipped bands), block/pixelate fade, crossfade. Applies the wallpaper *after* the animation so there's no flash. |
| `ThemeWindow.qml` | Bottom-anchored picker with **three sections, Left/Right between them**: custom themes, the standard themes (palette swatches, opens on the active one) and fonts. Themes is the middle one because it is the one that gets opened, so both neighbours are one key away; the picker opens on whichever section the *active* theme lives in. Up/Down walks the active section, Enter applies and closes, typing searches either theme list. On the font side **Space cycles the weight** through Thin…ExtraBold and applies at once, so the effect is visible without leaving the picker; each row is drawn in the font it names. Arrow keys are taken from the search box's text cursor on purpose — the box only serves the theme lists. IPC: `theme custom` / `theme fonts` skip straight to a section. |
| `ButtonSurface.qml` | The chip every button sits on, pulled out of `SettingsCategory` where the look was arrived at: a **resting fill** rather than a transparent rectangle, the theme's radius, a sheen that comes up under the cursor, a bright top rim. The resting fill is the part that matters — a button that only appears on hover reads as a hit-box, and once the surface behind it went to glass there was nothing to say a button was there at all. Inert on the standard themes (radius 0, gloss 0), so it collapses to the flat rectangle these buttons already were. The caller keeps its own MouseArea and passes `hovered`; half of them need the clicks and positions for other things too. |
| `GlossOverlay.qml` | The Aero specular highlight — a bright band across the top of a surface with a **hard step at the midline**, because a smooth fade reads as a washed-out surface and the abrupt one reads as glass. Plain `Gradient`, no `Qt5Compat.GraphicalEffects` (gotcha #3). Inert on the standard themes: `Theme.gloss` is 0 without a `style` block, and `visible` follows it, so it can be dropped into shared components without changing anything today. `enabled: false` — it must never eat a click meant for the surface under it. Two stacked passes: the specular sweep is the component's own gradient, and a child Rectangle draws the **rising tint** from the bottom edge up. One `Gradient` cannot both rise from the bottom and break sharply at the midline, and Aero's glass was never a flat wash — without the rising tint a translucent panel reads as "faded" rather than as a pane with depth. |
| `FontService.qml` | **Singleton.** The font side's data: installed families from `qs-font families` (only what fontconfig can see, since an absent family silently falls back and loses every bar icon), the eight weight names in OS/2 order, and `applyFamily` / `applyWeight` which both go back through `qs-font` rather than writing any config themselves. |
| `ScreenshotWindow.qml` | Screenshot UI. Stages: `pick` → `selecting` → `confirm`. Shows a **frozen full-screen grab** as its background so the screen appears frozen; drops keyboard focus during `selecting` so slurp works. The bar is part of the frozen frame on purpose — since the overlay sits above it, the clock and runcat stay frozen while the UI is open. |

### Workspace overview (Alt+Ctrl+Tab)

| File | Purpose |
|---|---|
| `WorkspaceOverview.qml` | Drops out of the bar and lays every workspace out side by side with the windows on it. **Drag a card onto another column to move that window, drop it *between* two columns to move it to a workspace that does not exist yet, hover a card for an X in its corner to close it.** Clicking a card focuses that window and closes the overview. The cards are **real window contents** — `ScreencopyView` (Quickshell.Wayland) on `HyprlandToplevel.wayland`; icon plus title only stands in until the first frame lands. The list is `Hyprland.workspaces` → each workspace's own `toplevels`, and `.address` off those objects is what the dispatchers target. IPC target `overview`. |

**Size.** The panel is built out of fixed 182×162 cells, one per workspace, and is only ever as wide as the cells it holds — capped at **52% of the monitor**, which is the bar's own free span between the running cat and the media title. Workspaces past that wrap onto a second row, centred under the first. `cellX`/`cellY` place the columns and `columnAt`/`dropTargetAt` read them back, so layout and hit testing cannot disagree.

**Five things that had to be got right:**

- `hl.dsp.window.move` **follows the view unless you say otherwise** — see gotcha #64. Every move from here passes `follow = false`.
- The columns model is a **snapshot**, resynced only when nothing is being dragged (gotcha #65). This is what fixed cards vanishing mid-drag.
- **Nothing is reparented.** The card stays in its column and a single `ghost` Rectangle owned by the panel follows the cursor. A card that is destroyed mid-drag (window closed) therefore cannot take the drag down with it — it only calls `cancelDrag` from `Component.onDestruction`.
- The drag is driven from the card's own `MouseArea` (press → threshold → `beginDrag`/`updateDrag`/`endDrag`), **not** `Drag`/`DropArea`. With an internal `Drag`, setting `Drag.active` false *cancels* rather than drops, so a `Drag.active: mouseArea.drag.active` binding races the `onActiveChanged` handler that calls `drop()` — and the drop can be swallowed.
- Dropping on the workspace the window is already on is **skipped**, not dispatched: to Hyprland that is a real move.

**The trailing `+ N` column is deliberate.** Hyprland only reports workspaces that exist, so without a spare slot there would be no way to drag a window *out* to a fresh workspace. It is drawn as an outline rather than a filled column so it reads as somewhere to put something. The same reasoning drives the **gap drop**: with 3 and 7 on screen there is nowhere to aim for 4, so the 22px either side of the border between two columns whose numbers are not consecutive targets the first free number between them, and a marker with `+ 4` on it appears in the gutter.

### Window switcher (Alt+Tab)

| File | Purpose |
|---|---|
| `WindowSwitcherService.qml` | **Singleton.** The window list, kept in **MRU order** (0 = focused, 1 = previous…) from `hyprctl clients -j`'s `focusHistoryID`. Held warm on purpose: running `hyprctl` at open time added a visible 30–60ms lag to Alt+Tab. `activewindowv2` reorders the array in place with no process at all; open/close/title/move events trigger an 80ms-debounced `hyprctl` refresh; a 5s timer catches anything missed. `frozen` is set while the panel is open — otherwise the row reshuffles under the selection and Alt lands on the wrong window. |
| `WindowSwitcherWindow.qml` | The overlay: a row of cards (icon, app name, workspace badge) plus the selected window's title. Commit calls `hl.dsp.focus({ window = "address:0x…" })`, which switches to that window's workspace as well. Focus is dispatched **before** the panel drops its keyboard grab so the old window can't get focus back in between. Animations are deliberately short (90–130ms) — Alt+Tab has to feel instant. |

**How the key handling splits in two:** Tab never reaches the panel — Hyprland's `ALT + Tab` bind swallows it — so stepping arrives over IPC (`qs-alt-tab next/prev`). The **Alt release** does reach it: while open, the layer surface holds `WlrKeyboardFocus.Exclusive`, so Qt sees `Key_Alt` release even though the press happened before the grab. That is the commit path. The `bindr`-style release bind in `keybinds.lua` is a second, independent route to the same IPC call; if both fire the later one is a no-op. Escape cancels, Enter/click commits, mouse hover moves the selection.

### Settings screen

| File | Purpose |
|---|---|
| `SettingsWindow.qml` | **Super+Z.** Bottom-anchored and slides up, the same shape as the launcher and the clipboard because that is the family it belongs to — a place you go to, not a thing you glance at. One box, pages that morph into each other (the control centre / calendar pattern): `page` drives the cross-fade and the height in one place and resets to home on close. `mask: Region { item: panel }` so only the panel takes clicks. Esc steps out of a page first and closes from home. IPC target `settings`: `toggle`/`open`/`close`/`appearance`/`topbar`. **Keyboard:** Up/Down walk the rows, Enter opens a category or flips a switch, Left/Right move a slider (and Left steps back out when the cursor is not on one), Esc leaves the page then closes. Rows are found by walking the active Column for children marked `selectable` — a heading (`SettingsSection`) is not, so Down never lands somewhere Enter does nothing. `indexRows()` stamps each row with its position on completion, so a row binds `selected` to the cursor without the call site repeating a literal index that would rot the moment a row is inserted. |
| `Bar.qml` | Two shapes, chosen by `BarSettings`: **docked** (a 30px strip flush against the top, square, opaque — the default and what it has always been) or **floating** (inset on three sides with the theme's panel radius). The window is always full width and always claims the gap as part of its height, so the exclusive zone keeps windows out either way; only the visible Rectangle moves. The window itself is `color: "transparent"` — when floating, the gap has to show the wallpaper, and an opaque window would fill it. Square while docked **whatever the theme says**: a rounded corner against the screen edge reads as a rendering fault rather than a choice. |
| `SettingsCategory.qml` / `SettingsToggle.qml` / `SettingsSlider.qml` / `SettingsSection.qml` / `SettingsPrefabRow.qml` | The three row shapes. The slider is the one with a rule in it: **drag previews, release applies.** A numeric setting lives in `animations.lua`/`decorations.lua` and only lands on `hyprctl reload`, so pushing every pixel of a drag would reload the compositor dozens of times for one gesture — `SettingsService.preview()` moves the fill, `commit()` writes once on release. A row whose toggle is off is dimmed and inert rather than hidden, so the list does not jump. |


**Aero glass is stored and deliberately not applied** (asked for that way). It is mutually exclusive with blur in the UI — two ways of painting the same surface — and it is the one key that **defaults off**: everything else defaults on so a fresh install looks normal, but an opt-in effect claiming to be enabled before it exists would be a lie. `SettingsService.defaultOff` and `qs-settings`' `DEFAULT_OFF` have to stay in step.

### Misc

| File | Purpose |
|---|---|
| `MediaPlayerPopup.qml` | MPRIS popup (cover, title, controls, progress). |
| `SystemTrayPopup.qml` | Tray icons popup. |

**Corners:** nothing says `radius: 0` any more — every surface asks `Theme` for
its radius (`Theme.radius` for rows, chips and badges, `Theme.radiusPanel` for
panels and windows, `Theme.radiusUpTo(n)` for anything small enough that the
full radius would round it away). The five standard themes resolve all of them
to 0, so the house look is unchanged; a custom theme's `style` block is what
makes them round. **63 literals across 17 files** were replaced in one pass,
plus 26 `border.width: 1` → `Theme.borderWidth` and 13 panel fills →
`Theme.panelColor`. The media player's circular control buttons are the only
hand-rounded elements left (they predate this work).

**Gloss:** the 13 panel surfaces and the bar each carry a `GlossOverlay`,
declared as the **first child** so it sits under the content rather than over
it. `enabled: false` on the overlay keeps it out of the input path.

**Language:** everything written — on-screen strings, code comments, docs and
commit messages — is **English** (asked for on 2026-08-04). The Turkish comments
still in these QML files predate that and were not rewritten; anything new is English.

---

## 4. Scripts (`~/.local/bin/`)

| Script | Purpose |
|---|---|
| `qs-config` | **The single accessor for `lemonrice.json`** — colours *and* settings. `theme`, `get <path>`, `set <path> <value>`, `json [path]`, `themes [--custom\|--standard]`, `palette [theme]`, `style [theme]`, `env [theme]` (shell-eval'able `BASE=…`, `MAUVE=…`). Replaced `qs-config` and the six hand-rolled JSON readers that had accumulated in the theme helpers. `set` validates the path against the file, so a typo cannot add a key nothing reads, and takes an exclusive lock — two racing read-modify-writes used to corrupt the file (gotcha #49). `env` skips dict/list values (a theme's `style` block would otherwise export a Python repr) and normalises booleans to `true`/`false`. |
| `qs-theme` | Master theme applier. `qs-theme` prints current, `qs-theme list`, `qs-theme <name>`. Writes quickshell state, kitty (incl. `*-theme.auto.conf`), then delegates to the helpers below (GTK, Kvantum, KDE, dunst, btop, YouTube Music, Hyprland, Zen), then switches to **that theme's last wallpaper**. **nvim is not in that list on purpose** — it reads `lemonrice.json` and `theme.txt` itself and watches both (§8), so there is nothing to push; the `lua/qs-theme.lua` it writes is only a backstop for an unreadable `theme.txt`. |
| `qs-theme-gtk` | GTK 3/4 `@define-color` block. Replaces the gtk-4.0 symlink with a real file that imports the base theme (gotcha #13). |
| `qs-theme-kvantum` | Qt/KDE widget style. For monochrome it **generates** `qs-monochrome` by copying the catppuccin Kvantum theme and converting every hex color to grayscale by luminance. |
| `qs-theme-qt6ct` | **The Qt colour palette.** Kvantum gives Qt apps their widget *style*; the colours — text-area background, list rows, selection — come from `QPalette`, and under `QT_QPA_PLATFORMTHEME=qt6ct` that is qt6ct's job. Generates `~/.config/qt6ct/colors/qs-<theme>.conf` (22 columns, `QPalette::ColorRole` order) and patches `color_scheme_path` **in place** — the rest of `qt6ct.conf` is fonts, owned by `qs-font`. Also swaps `icon_theme` between a light and a dark set, since a dark icon theme's monochrome icons disappear on a light background. See gotcha #43 for why this did not exist before. |
| `qs-theme-kde` | Writes `[Colors:*]` sections in `kdeglobals` (gwenview etc.), preserving non-color sections. |
| `qs-theme-dunst` | Rewrites dunst colors in place by (section, key), then `dunstctl reload`. |
| `qs-theme-btop` | Generates `~/.config/btop/themes/qs-<theme>.theme` and points `color_theme` at it. |
| `qs-theme-ytmd` | Generates `~/.config/quickshell/generated/ytmdesktop.css`. The app hot-reloads it, so **no restart** — but only because the file is written in place and `config.json` is left alone unless the path is actually wrong (gotcha #22). |
| `qs-theme-hypr` | Window border colors. Writes `~/.config/hypr/config/theme.lua` (read by `decorations.lua` on reload) and applies the same colors live via `hyprctl eval` (gotcha #21). |
| `qs-theme-zen` | Zen Browser chrome colors. Writes a managed block in each profile's `chrome/userChrome.css` plus the `toolkit.legacyUserProfileCustomizations.stylesheets` pref in `user.js`. **Needs a Zen restart** (gotcha #24). |
| `qs-wallpaper` | Animated wallpapers need **mpvpaper** (`set` starts it for video/gif and kills it when going back to a still image; hyprpaper only ever gets stills, a video path in its config would be invalid). `list-animated [theme]`, `list [theme]`, `current`, `set <path>`, `show <path>` (animated via quickshell), `for-theme [theme]`, `apply-theme [theme]` (called by `qs-theme`), `restore` (runs from Hyprland autostart once hyprpaper is up). Theme folder matching is fuzzy: lowercase, strip non-alphanumerics, collapse repeated letters — so `CatpuccinMocha` matches `catppuccin-mocha`. |
| `qs-wallpaper-watch` | Pauses the **animated** wallpaper when nothing of it is visible, so mpv stops burning GPU behind a covering window. Listens on Hyprland's event socket and sets mpv's `pause` over its IPC socket (killing mpvpaper would mean reloading the video on the way back). Pauses when a visible workspace has a fullscreen window, **or** has gaps closed *and* at least one window — both checked **per visible workspace**, so leaving a gaps-closed workspace for a normal one resumes playback. Super+H produces no Hyprland event, so `qs-maximize` calls it with `--once` to force a re-evaluation. Started from Hyprland autostart. |
| `qs-screenshot` | `freeze`, `region`, `window`, `screen`, `save`, `discard`, `cancel`. Crops from the frozen frame when present. Kills stale slurp instances first (they wedge all later selections). |
| `qs-clip` | cliphist wrapper: `list` (JSON), `thumb <id>`, `copy <id>`, `delete <id>`, `wipe`. Image decode is piped into `magick -` (a `.raw` extension made ImageMagick think it was a camera RAW). |
| `qs-icon-resolve` | Icon name → real file path by scanning icon theme dirs. Roots include the **flatpak export dirs** (`/var/lib/flatpak/exports/share/icons`, `~/.local/share/flatpak/...`) — without them any flatpak with no Papirus equivalent (Sober) came out iconless. |
| `qs-font` | **Single source of truth for fonts**, the way `qs-config` is for colours. `qs-font` prints the current pair, `qs-font list` lists installed families, `qs-font <mono> [ui]` sets them. Pushes one choice into nine places that each store fonts their own way: GTK3/4 `settings.ini`, gsettings (libadwaita ignores settings.ini), qt6ct's QFont string, `KittyLemon.conf`, `dunstrc`, hyprlock (by re-running `qs-theme-hyprlock`) and `font.conf` itself. `mono` **must be a Nerd Font** — every bar icon is a Nerd Font glyph and a plain family leaves empty boxes. |
| `qs-mode` | Super+Shift+P — `performance` / `normal` / `toggle` / `status`. Stops the wallpaper processes (mpvpaper ~250 MB PSS, hyprpaper ~44 MB) and `qs-wallpaper-watch` with them, sets its flag file (`config/effects.lua` reads it) and tells the bar to throttle. Measured on this machine: **678 → 372 MB PSS and 7.8% → 4.5% CPU** across Hyprland + bar + wallpaper. Flag: `$XDG_RUNTIME_DIR/qs-mode.performance`. **The refresh rate is deliberately left alone** — 60 Hz instead of 180 nearly halves Hyprland's CPU again (9.2% → 3.5%, measured) but the refresh rate is the point of the machine. |
| `qs-adb` | Phone side of the control centre. Android's wireless debugging picks a **new random port every time it is switched on** and advertises the pair over mDNS, but `adb mdns services` is not compiled into the Arch build ("mdns is not supported by this version of adb") and avahi-daemon is not running either. **`connect <port>`** is what the panel calls — the phone shows the port right next to the switch, and the script pairs it with the last address that worked or the LAN neighbours (gateway excluded). `connect <ip:port>` spells it out. Bare **`connect`** keeps an automatic search for command-line use: cached address -> a **one-shot mDNS query written by hand** (one multicast packet, no daemon, no root) -> a **threaded port sweep** of the ARP neighbours over 5555 + 30000-49999, which finds the phone in ~0.4s here. The sweep is not what the panel uses, because an open port that is not adb's just fails slowly. Then `status` (JSON for the panel), `disconnect`, `stream` (scrcpy, 480px borderless, phone screen off), `screenshot`, `push`, `shell`, `reboot`. |
| `qs-color` | The control centre's colour picker. `pick` runs `hyprpicker -a -l -q -f hex` (it copies to the clipboard itself), prepends the hex to `~/.local/share/quickshell/colors.json` — newest first, deduplicated, capped at 24 — and then opens the panel on its colour page. `list` / `clear` for the history. Bound to `Super+Alt+X`, replacing gcolor3. **Nothing is parsed positionally**: the first `#rrggbb` in the output wins, and if the build printed nothing at all it reads the clipboard, which `-a` always fills. That is not defensive programming for its own sake — `-q` was in the command line at first and swallowed the result, so the colour reached the clipboard and the panel never opened. The exit code is checked *before* the clipboard fallback, or a cancelled pick would "succeed" with the previous colour. |
| `qs-settings` | The control centre's compositor toggles. `qs-settings` lists, `get`/`set <key> on\|off`/`toggle`/`apply`. Deliberately thin: storage and locking are `qs-config`'s job, and the work is handed to `config/toggles.lua`, the only place that knows what a key means. Turning something **off** runs that file via `hyprctl eval`; turning it back **on** is `hyprctl reload`, which restores `animations.lua`/`decorations.lua` and then runs `toggles.lua` again at the end of `hyprland.lua` for whatever is still off — so the "on" values are never duplicated and cannot drift from the config. Everything goes through `hyprctl eval` because `hyprctl keyword` does not work with the Lua config parser at all (gotcha #21) — the same reason `qs-mode` drives `perfmode.lua` that way. |
| `qs-maximize` | Super+H — "fullscreen with the bar still visible". Doesn't maximize one window: it zeroes `gaps_in`/`gaps_out`/`border_size` so every window on the workspace fills the screen together. **Scoped to the workspace it was pressed on** via `hl.workspace_rule` (gotcha #30); each workspace toggles independently, state in `$XDG_RUNTIME_DIR/qs-maximize.ws.<name>`. Restores the values from `decorations.lua` (3/8/2). A leftover `qs-maximize.on` from the old global version is detected and undone on the next press. **`qs-wallpaper-watch` reads the same per-workspace files** — changing that naming breaks the animated wallpaper's pause. |
| `qs-focus-keep-cursor` | Focuses a window by address without the pointer following, by saving `hyprctl cursorpos` and restoring it after the focus dispatch. `cursor:no_warps` is deliberately off globally so Super+arrow keeps its native pointer-follows-focus warp; this script is the one exception, used only by the Alt+Tab commit path. See gotcha #34. |
| `qs-alt-tab` | Hyprland ↔ switcher bridge: `next`, `prev`, `commit`, `cancel`. The commit bind fires on **every** Alt release (Alt+Space, in-app Alt use, …), so open/closed state is kept in `$XDG_RUNTIME_DIR/qs-switcher-open` — `next`/`prev` create the flag, `commit` needs it and removes it. Without the flag every Alt release would spawn a pointless `qs` process. A stale flag (panel closed with Escape) costs one wasted no-op IPC call. |
| `qs-paste` | Sends the paste shortcut to the focused window via `hl.dsp.send_shortcut` (gotcha #27). Uses Ctrl+Shift+V for terminals, Ctrl+V elsewhere. Called by the clipboard panel after a pick. |
| `qs-ytmd-titlebar` | **Runs as root.** Rebuilds `/opt/ytmdesktop/resources/app.asar` with the app's own title-bar colors patched (see §9). Keeps `app.asar.qs-backup` and always patches from it, so re-runs don't stack; `--restore` puts the original back. **`--if-stale`** does nothing unless the marker file (`app.asar.qs-theme`) disagrees with `theme.txt` *or* the asar is newer than the backup — which is how an app update, that silently drops the patch, is detected. **`--install`** puts a root-owned copy in `/usr/local/bin` plus a NOPASSWD rule scoped to `--if-stale` only, validated with `visudo -c` first; the rule must point at that copy and never at `~/.local/bin`, which is user-writable (same reasoning as `qs-boot-windows`). |
| `qs-ytmd` | Launch wrapper for YouTube Music: runs `--if-stale`, **then** execs the app. The order is the whole point — Electron reads the asar at startup, so patching afterwards would only show up on the next launch. `~/.local/share/applications/youtube-music-desktop-app.desktop` overrides the system entry to point here, with an **absolute path** because Hyprland's PATH has no `~/.local/bin`. If the sudo rule is not installed, `sudo -n` fails, the wrapper shrugs and launches anyway: a wrong title bar beats an app that will not start. |
| `qs-grub-windows` | **Runs as root.** Writes `/etc/grub.d/35_lemonrice-windows` (a chainloader entry for `bootmgfw.efi`, id `lemonrice-windows`) and regenerates `grub.cfg`. Deliberately not os-prober: Windows sits on the same ESP as Arch here. Scores the candidate ESPs — system ESP > root disk > fixed disk — because a *removable* disk's ESP would give a menu entry that dies when the disk is unplugged. `--check` lists candidates, `--remove` deletes the entry. |
| `qs-boot-windows` | Launcher's **Boot to Windows** — one-shot, nothing permanent. Arms `efibootmgr --bootnext <Windows>` so the *firmware* goes straight to Windows on the next boot (GRUB never appears), falls back to `grub-reboot lemonrice-windows` where Windows has no NVRAM entry, then `systemctl reboot`. Writing EFI variables needs root and the launcher runs its entries detached with no terminal and no polkit agent, so `sudo qs-boot-windows --install` puts a root-owned copy in `/usr/local/bin` and a NOPASSWD rule for `--set` only in `/etc/sudoers.d/lemonrice-boot-windows` (validated with `visudo -c` first — a bad file there breaks sudo entirely). **The rule must point at the `/usr/local/bin` copy**: `~/.local/bin` is user-writable, so a rule pointing there would be free root for anything that can drop a file in it. Re-run `--install` after editing the script. From a terminal it works without the install, asking for the password. |
| `qs-file-search` | `find`-based home search, skips dotdirs/node_modules/etc. |
| `qs-file-preview` | Image passthrough, PDF first page via `pdftoppm`. |
| `qs-note-reminder` | Calendar reminder notification: notepad icon, `timeout 0`, `[ 󰈈 Preview ]` action. dunst can't draw real buttons, so the whole notification is clickable via `mouse_left_click = do_action`. |
| `qs-notif-dismiss-watch` | Watches `NotificationClosed`; reason 2 (user dismissed) → `dunstctl history-rm`, so clicked notifications don't linger in the notification center. Started from Hyprland autostart. |
| `qs-kb-layout` | Switches xkb layout and shows a keyboard-icon notification with the new layout name. |

---

## 5. State & data files

| Path | Contents |
|---|---|
| `~/.config/quickshell/lemonrice.json` | **Everything configurable** — the active theme, fonts, effect settings, the bar's own state and every palette. See §1. Written only by `qs-config`; watched live by `Theme.qml`, `BarSettings.qml`, `SettingsService.qml` and nvim's `colors/lemon.lua`, read on reload by Hyprland's `config/settings.lua`. **In the repo** — the palettes are the theme definitions, so a fresh install needs them; the runtime keys in it are just the defaults someone starts from. |
| `~/.config/quickshell/cava.conf` | cava's own config for the spectrum strips: 12 bars, 30fps, raw ASCII to stdout. Read by cava, not by quickshell — `CavaService` only passes the path. |
| `~/.local/share/quickshell/colors.json` | **The picked-colour history**, a plain array of hex strings, newest first, capped at 24. Written only by `qs-color`, watched live by `ColorService.qml`. Also the channel that carries a fresh pick into the bar, since `ipc call` cannot take arguments (§2 #1). |
| `~/.config/quickshell/scripts/dns-toggle.sh` | Encrypted DNS (DNS-over-TLS via systemd-resolved → Quad9/Cloudflare/Google), for networks where the ISP resolver answers blocked domains with a sentinel IP (`195.175.254.2`). `--on` / `--off` / bare toggle need root; `--status` prints `on`/`off` from the presence of `/etc/systemd/resolved.conf.d/99-encrypted-dns.conf` and is the only mode the bar runs itself. Lives here rather than in `~/.local/bin` because the control centre calls it by path. |
| `~/.config/quickshell/wallpapers.conf` | `<theme> = /path/to/image.png` per line — **each theme's last used wallpaper**, rewritten by `qs-wallpaper set` for whichever theme is active. Switching themes switches to that theme's entry; `qs-wallpaper restore` re-applies it at login. Missing entry → first image in the theme's folder. (`wallpaper.txt` and `wallpaper-defaults.conf` are earlier iterations; `wallpaper.txt` is still read as a fallback, `wallpaper-defaults.conf` is not.) |
| `~/.config/hypr/config/theme.lua` | Generated Hyprland border colors; `decorations.lua` requires it with a fallback. |
| `~/.config/quickshell/favorites.json` | Launcher favorites (`.desktop` ids). |
| `~/.config/quickshell/clipboard-pins.json` | Pinned clipboard entry ids. |
| `~/.config/quickshell/generated/ytmdesktop.css` | Generated YouTube Music CSS. |
| `~/.local/share/quickshell/calendar-notes.json` | Calendar notes. |
| `~/.cache/quickshell-notif-seen` | Last-seen notification id. |
| `~/.cache/qs-note-preview` | Note id handoff (IPC can't take args). |
| `~/.cache/qs-wallpaper-pending` | Wallpaper path handoff. |
| `$XDG_RUNTIME_DIR/qs-mode.performance` | Performance mode flag. Read by `config/effects.lua` (so a reload re-applies the mode) and by `PerfMode.qml` at startup. In the runtime dir on purpose: the mode should not survive a reboot. |
| `~/.cache/qs-screenshot-freeze.png` | Frozen frame while the screenshot UI is open. |
| `~/.cache/qs-screenshot-pending.png` | Captured shot awaiting save/discard. |
| `~/.cache/qs-clip/` | Clipboard thumbnails. |
| `~/Pictures/Wallpapers/<Theme>/` | Wallpapers per theme (`CatpuccinMocha`, `Monochrome`). |
| `~/Pictures/Screenshots/` | Saved screenshots. |

---

## 6. Keybinds (`~/.config/hypr/config/keybinds.lua`)

| Keys | Action |
|---|---|
| `Alt + Tab` (hold Alt) | Window switcher — Tab steps forward, Shift+Tab back, releasing Alt jumps to the selected window and its workspace. Replaced `hl.dsp.window.cycle_next()`. |
| `Alt + Space` | Launcher (Apps/Files/Favorites/System) |
| `Super + V` | Clipboard history |
| `Super + Shift + S` | Screenshot UI (freezes the screen) |
| `Super + Shift + Z` | Wallpaper picker |
| `Super + Ctrl + Z` | Theme **and font** picker — `←`/`→` between the two sections, `Space` cycles font weight |
| `Super + Ctrl + C` | Control centre — the same panel the running cat opens |
| `Super + Ctrl + C` -> Phone | adb: connect (finds the phone itself), stream via scrcpy, screenshot, send file, shell, reboot |
| `Super + Alt + X` | Colour picker — hyprpicker over the frozen screen, then the control centre opens on the colour page with the hex (already in the clipboard) |
| `Super + Alt + C` | Launcher, System tab |
| `Super + Shift + P` | Performance mode toggle (wallpaper, blur, shadows, animations off; bar polls slower) |
| `Super + K` | Keyboard layout switch |
| `Super + H` | Close the gaps on **this workspace only** (bar stays visible) — toggle |
| `Super + S` | Toggle special workspace |

Calendar has no keybind — click the date in the bar. IPC equivalents:
`qs -c topbar ipc call <target> <function>` where targets are
`launcher, clipboard, calendar, notePreview, theme, wallpaper, wallpaperFx, screenshot,
switcher, controlCenter`. A few skip straight to a section: `launcher system`, `launcher files`,
`theme fonts`.

---

## 7. dunst integration (`~/.config/dunst/dunstrc`)

- Square corners (`corner_radius = 0`), `history_length = 100`, `show_indicators = false`.
- `mouse_left_click = do_action, close_current` — needed for the reminder Preview button.
- `icon_path` includes `devices` dirs (for the keyboard icon).
- Rules: `[forward_all_notifications]` (pre-existing proxy → `dunst-forward` → `dunst-notify`), `[proxy_notifications]`, `[qs_reminder]` (appname `DunstProxy` + category `qs.reminder`, `timeout = 0`, no progress bar).
- **Because of the proxy, every history entry has appname `DunstProxy` and urgency `NORMAL`** — the notification center hides the app name and the urgency stripe is always the accent color.
- **`dunst-forward` de-duplicates before forwarding.** A phone message arrives twice when a desktop client for the same service is running: the client posts `"Sender" / "message"` and KDE Connect relays the phone's copy as `"WhatsApp" / "Sender: message"` (KDE Connect's `ticker` property is literally `"title: text"`). The second shape is folded onto the first so both hash alike, first arrival wins, and the loser is dropped — signatures live in `~/.cache/dunst-proxy-icons/dedup`, claimed atomically via `noclobber`. Cross-shape matches hold for 15 s but only across *different* app names, so one app repeating itself still gets its own popup. Identical re-posts collapse within 3 s, which also catches `replaces_id` updates — the proxy always builds a fresh popup instead of updating the original.
- Colors in this file are rewritten by `qs-theme-dunst`; don't hand-edit them.

---

## 8. nvim (`~/.config/nvim/`)

The editor is themed the same way everything else is: **not by shipping one
colorscheme per theme, but by reading `lemonrice.json` directly.** There is a
single colorscheme, `lemon`, and it renders whichever theme `theme.txt` names.
Adding a theme is still one block in `lemonrice.json` and nothing else — the
editor picks it up with no new file, exactly like kitty, dunst and btop.

Before this there were two: `catppuccin-mocha` mapped to the catppuccin plugin,
`monochrome` mapped to the built-in `quiet`, and every other theme fell through
to `ayu-red` — so switching to Gruvbox, Nord or Everforest left the editor on
the old red palette while the rest of the desktop moved.

| File | Purpose |
|---|---|
| `lua/lemon/palette.lua` | Reads `lemonrice.json` + `theme.txt`. Keeps one inline fallback palette for the same reason `Theme.qml` does — a broken JSON must not leave the editor colorless. Every key is merged over that fallback, so a half-written theme block still opens instead of throwing on a `nil` color. Also holds `blend()` / `luminance()`, the only color math in the config. |
| `lua/lemon/highlights.lua` | Palette → the full highlight table: editor UI, legacy syntax, the `@…` treesitter groups, `@lsp.type.*` semantic tokens, diagnostics, and every installed plugin (gitsigns, neo-tree, telescope, bufferline, cmp, notify, noice, todo-comments, trouble, flash, alpha, lazy, mason, toggleterm). Roles are fixed — mauve is the accent, blue functions, green strings — plus `distinct()` for gotcha #40. |
| `colors/lemon.lua` | The colorscheme itself. Drops both modules from `package.loaded` on every load, so a theme switch or a hand edit of `lemonrice.json` is picked up rather than served from cache. Publishes `g:lemon_palette`. |
| `lua/lualine/themes/lemon.lua` | Statusline colors from the same palette, one accent per mode. `theme = "auto"` guessed wrong on half the themes. Modes claim their accent in order and fall through to an unused one, so gotcha #40 cannot put normal and insert in the same green. Nothing but mode tables may live in this file — gotcha #41. |
| `lua/plugins/colorscheme.lua` | Loads it and **watches `theme.txt` and `lemonrice.json` with `vim.uv.new_fs_event`**, so `Super+Ctrl+Z` restyles every open editor live, like the bar and kitty. The watcher re-arms after each event: a theme switch can replace the file rather than truncate it, and the old handle would then be watching an inode nothing writes to. |
| `colors/ayu-red.lua` | The old default. Still selectable (`:colorscheme ayu-red`), no longer automatic. |

- `:LemonTheme <name>` pins one theme **in that editor only** — a system switch
  will not override it. `:LemonTheme` with no argument releases the pin.
- The catppuccin plugin is still installed but `lazy = true` and never loaded;
  `:colorscheme catppuccin-mocha` gets the upstream flavour if wanted.

**Treesitter needs `tree-sitter-cli`** — see gotcha #37. Until
`sudo pacman -S tree-sitter-cli` runs, no parser can be built and the theme's
syntax colors only show on the parsers Neovim ships. The config says so once at
startup instead of failing per file.

---

## 9. Known limitations / open items

- **`xdg-desktop-portal-gtk` must be restarted after a light↔dark switch** —
  `systemctl --user restart xdg-desktop-portal-gtk`. It serves the GTK file
  chooser and caches the preference for its lifetime (gotcha #55).
- **Qt apps and GTK apps only pick up a theme change when they restart** — qt6ct
  and `kdeglobals` are read at startup. Anything already open keeps the old
  palette until relaunched. YouTube Music is the exception (it hot-reloads its
  CSS), and quickshell/kitty/dunst/nvim are live by design.
- **The YouTube Music title bar needs one setup command.** It is the app's
  window chrome, baked into the asar, not the web view. `sudo
  ~/.local/bin/qs-ytmd-titlebar --install` installs the root helper and the
  NOPASSWD rule; after that `qs-ytmd` repatches it automatically whenever the
  theme moved or the app updated, on every launch. Until that runs, the wrapper
  falls through and the title bar stays whatever it was.
- **Backdrops lighten instead of dimming on a light theme.** The full-screen
  scrim behind the launcher, clipboard, theme picker, wallpaper picker, switcher
  and screenshot UI is `Theme.crust` at `opacity: 0.5` — on a dark palette that
  darkens the desktop, on Frutiger Aero it frosts it white. It reads fine (it
  is arguably *more* Aero that way) and it still separates the panel from what
  is behind it, so it is left alone — but it is the one place where "crust is
  the dark one" is still baked in. `Theme.isLight` is the flag if it ever needs
  to branch.
- **The wallpaper transition effects were not re-checked on a light palette.**
  `WallpaperTransition.qml` draws its own crust-colored bands.
- **`tree-sitter-cli` is not installed**, so nvim-treesitter (`main`) cannot
  build parsers and only Neovim's bundled ones are active (gotcha #37). One
  command fixes it: `sudo pacman -S tree-sitter-cli`, then `:TSUpdate`. It is
  left out of `install.sh` because that script installs no system packages.
- **Monochrome has no GTK or Kvantum upstream theme.** GTK falls back to `Adwaita-dark` plus our color overrides (catppuccin keeps its own theme package); Kvantum is generated by grayscaling. A real Tokyo-Night-style package would need `yay -S`.
- **YouTube Music Desktop's own title bar** is the app's window chrome (`.titlebar { background-color: #000 }` in the bundled renderer CSS), not the YouTube web view — `customCSSPath` is only injected into the web view, so no CSS we write can reach it. `qs-ytmd-titlebar` patches the asar itself (root, undone by app updates). The rebuild was verified round-trip: every other file in the archive stays byte-identical.
- **btop** is skipped while `~/.config/btop` is root-owned. Fix: `sudo chown -R mrlemon:mrlemon ~/.config/btop ~/.config/fish ~/.config/kitty ~/.local/share/kservices5`.
- **Zen Browser is themed again** (asked for on 2026-07-31, after an earlier revert). `qs-theme-zen` writes a managed block in `chrome/userChrome.css` for every profile in `profiles.ini` plus the legacy-stylesheets pref in `user.js`. It flattens the workspace gradient to the theme color; if the gradient picker is wanted back, drop the `#navigator-toolbox` / `.zen-browser-generic-background` rules. **Colors only appear after Zen restarts** — there is no live reload path from outside the browser.
- **Clipboard entries have no timestamps** — cliphist doesn't store them, so no "2m ago" labels (deliberately not faked).
- **Icons for old notifications disappear**: `dunst-icon-cache` prunes PNGs after `MAX_AGE = 180` seconds, so history items older than ~3 min fall back to a generic bell.
- **wl-clip-persist** is installed and in autostart (keeps clipboard after the source app closes).
