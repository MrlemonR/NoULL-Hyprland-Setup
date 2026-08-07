# Quickshell Topbar — Project Reference

Custom Hyprland shell built on quickshell. This file is the handover document:
it lists every file, what it does, and — most importantly — the **environment
gotchas** that cost real debugging time. Read the gotchas before changing
anything; several of them fail *silently*.

- Config root: `~/.config/quickshell/topbar/`
- Helper scripts: `~/.local/bin/qs-*`
- Entry point: `shell.qml`
- Running instance: `quickshell -c topbar` (started from Hyprland autostart)

---

## 1. Hard-won environment facts (read first)

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
| 27 | **`hl.dsp.send_shortcut` silently does nothing without an explicit target window.** `{ mods = "CTRL", key = "V" }` and `window = "activewindow"` both return `ok` and go nowhere; `window = "address:0x…"` works. `qs-paste` reads the address from `hyprctl activewindow -j`. (This is how Super+V pastes without `wtype`/`ydotool`, which are still not installed.) |
| 26b | **GTK4 apps that don't use libadwaita (pavucontrol is gtkmm-4.0) ignore both** `@define-color` and the libadwaita variables — Adwaita's own GTK4 sheet hardcodes its colors. They only respond to direct widget rules, and the selectors had to be found by probing with garish colors: the background is painted by `viewport`/`stack` (not `window`), the volume bar by `scale > trough > highlight`, its knob by `scale > trough > slider`. |
| 26 | **libadwaita 1.9 is driven by CSS variables, not `@define-color`.** `:root { --window-bg-color: … }` in `~/.config/gtk-4.0/gtk.css` recolors the app; the old `@define-color` block alone changes nothing (it is kept for GTK3). The accent is separate again: `--accent-bg-color` loses to the system accent, so `gsettings set org.gnome.desktop.interface accent-color <named>` is also set. |
| 25 | **`GTK_THEME` in the environment disables user CSS entirely.** Not just the theme name — with it set, GTK never reads `~/.config/gtk-*/gtk.css`, so every theme switch was a no-op for pavucontrol / gnome-calculator / gnome-characters / the color picker. **Setting it to an empty string is not enough**, it has to be absent (verified: red test CSS only applied with `env -u GTK_THEME`). It was hardcoded to catppuccin in `environment.lua`; that line is gone, but Hyprland's Lua API cannot unset an env var at runtime (`hl.env` requires a string), so the fix only lands after a **re-login**. |
| 24 | **Zen: overriding `--zen-primary-color` / `--zen-branding-*` is not enough for the tab sidebar.** The sidebar sits on `#navigator-toolbox`, and behind it the workspace gradient is painted on layers whose variables JS writes *on the element*, so a `:root` override never reaches them. Paint `#navigator-toolbox` (and `.zen-browser-generic-background::after/::before`) directly. userChrome.css itself only loads at startup and only with `toolkit.legacyUserProfileCustomizations.stylesheets = true`, so theme switches need a Zen restart. Verified by running a throwaway instance: `MOZ_NO_REMOTE=1 zen-browser --new-instance --profile <dir>`. |
| 34 | **`cursor:no_warps` is global — it can't want two different things for two different keybinds.** Super+arrow is meant to warp the pointer to the newly focused window (Hyprland's default), Alt+Tab is meant to leave the pointer exactly where it was — both went through the same dispatcher family, so one `no_warps` value can't satisfy both. Solved by leaving `no_warps` at its default (off, so Super+arrow's native warp works) and having `WindowSwitcherWindow.qml`'s `focusWindow()` go through `qs-focus-keep-cursor` instead of a raw `hl.dsp.focus` — that script saves `hyprctl cursorpos`, focuses, then dispatches `hl.dsp.cursor.move` back to the saved point. Only Alt+Tab's commit path uses it. |
| — | **`input:mouse_refocus` was set to `false` for a while and is now back to its default.** It was a second guard for the same focus problem, but turning it off leaves pointer focus stale until the cursor crosses a window boundary — and a stale pointer focus can put a button press and its release on two different surfaces, which the application sees as a button that never came up (a click then reads as a drag). Its official description only exists in the Hyprland binary, not the Lua stub's doc comments: `strings /usr/bin/Hyprland \| grep mouse_refocus`. |
| 33 | **`hl.config` aborts the whole call on one unknown key, and reports it only on stderr.** Performance mode passed `misc.vfr`, which moved to `debug.vfr` in Hyprland 0.56 — so `hyprctl eval` answered `unknown config key 'misc.vfr'` and the rest of the table applied only partially, depending on Lua's table iteration order. `qs-mode` sent that to `/dev/null`, so the mode looked like it worked and mostly didn't. Check `hyprctl eval` output when a config change silently does nothing. |
| 32 | **`hyprctl reload` silently undoes everything applied with `hyprctl eval`.** It re-runs the Lua config, so any live tweak is reverted while whatever state file drove it still says it is active. Anything meant to survive a reload has to live *in* the config: `config/perfmode.lua` is required last from `hyprland.lua` and re-applies itself when its flag file exists. |
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

## 2. QML files (`~/.config/quickshell/topbar/`)

### Core

| File | Purpose |
|---|---|
| `shell.qml` | Entry point. Instantiates `Bar`, `LauncherWindow`, `NotePreviewWindow`, `ClipboardWindow`, `WallpaperWindow`, `WallpaperTransition`, `ThemeWindow`, `ScreenshotWindow`, `WindowSwitcherWindow`. |
| `Bar.qml` | The 30px `PanelWindow` at the top. Passes `screen.name` to `CenterSection`. |
| `Theme.qml` | **Singleton.** All colors. Reads the palettes from `~/.config/quickshell/palettes.json` and the active theme name from `theme.txt`, both with `watchChanges: true` — theme switches *and* palette edits apply live with no restart. Keeps one inline fallback palette so a missing/broken JSON can't leave the bar colorless. Every other file uses `Theme.base`, `Theme.text`, `Theme.mauve`, … (~230 hardcoded hex values were replaced by these). |
| `PerfMode.qml` | **Singleton.** Whether performance mode is on, plus `every(ms)` — multiplies a polling interval by 4 while it is. The bar stays running in performance mode but there is no reason for it to keep spawning ~4-5 processes a second (`hyprctl activewindow` twice a second, five stat processes including `ddcutil` every two seconds, `dunstctl`, `hyprctl clients`). State arrives over IPC from `qs-mode`; on shell restart it is read once from the flag file. The clock is deliberately **not** scaled. |
| `IconResolver.qml` | **Singleton.** `iconFor(name)` → `file://` path. Batches unknown names to `qs-icon-resolve`. Exists because Qt's icon lookup is broken here (gotcha #8). Also owns the **appId → icon** matching (`iconForApp`): StartupWMClass → `.desktop` id/name → the appId as an icon name → app name contained in appId. `CenterSection` and the Alt+Tab switcher both call it, so there is one place to fix when an app comes out iconless. |

### Bar sections

| File | Purpose |
|---|---|
| `LeftSection.qml` | Date (click → calendar), time, focused-app name (hidden when empty, along with its separator), runcat. |
| `CenterSection.qml` | Workspaces. Hides numbered workspaces and shows a single "Special" box when a special workspace is visible (driven by Hyprland's `activespecialv2` event, filtered by monitor). Hover expands a box to show app icons; `resolveIcon()` matches by `StartupWMClass` → id/name → icon name, and falls back to a letter tile. |
| `RightSection.qml` | Media controls, CPU/RAM/temp (click → btop), volume, system tray, notification bell with unread badge. **Player pick:** first one that is playing, else first one with a track title, else none — `Mpris.players.values[0]` used to land on the kdeconnect phone player (no track, not playing), which hid the real player and left the section's separator floating with nothing next to it. Reading `isPlaying`/`trackTitle` of *every* player in the binding is deliberate: an early return would not re-evaluate when a later player starts. |

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
| `WallpaperWindow.qml` | Coverflow carousel. **↑/↓ switches Static ↔ Animated**; animated wallpapers live in `<theme>/Animated/` (mp4/webm/mkv/mov/gif) and their cards show a frame extracted by ffmpeg — the thumb filename is `md5(path).png`, computed identically by the script and by `Qt.md5()` in QML, so no IPC is needed to pair them. Opens on the **currently set** wallpaper. Left-click centre = apply (animated). Lists the active theme's folder, but the choice itself is theme-independent (see §4). |
| `WallpaperTransition.qml` | `WlrLayer.Bottom` (above hyprpaper, below windows), `mask: Region {}` so it's click-through. Three random effects: circular reveal (80 clipped bands), block/pixelate fade, crossfade. Applies the wallpaper *after* the animation so there's no flash. |
| `ThemeWindow.qml` | Bottom-anchored picker with **two sections, Left/Right between them**: themes (palette swatches, opens on the active one) and fonts. Up/Down walks the active section, Enter applies and closes, typing searches the theme list. On the font side **Space cycles the weight** through Thin…ExtraBold and applies at once, so the effect is visible without leaving the picker; each row is drawn in the font it names. Arrow keys are taken from the search box's text cursor on purpose — the box only serves the theme list. |
| `FontService.qml` | **Singleton.** The font side's data: installed families from `qs-font families` (only what fontconfig can see, since an absent family silently falls back and loses every bar icon), the eight weight names in OS/2 order, and `applyFamily` / `applyWeight` which both go back through `qs-font` rather than writing any config themselves. |
| `ScreenshotWindow.qml` | Screenshot UI. Stages: `pick` → `selecting` → `confirm`. Shows a **frozen full-screen grab** as its background so the screen appears frozen; drops keyboard focus during `selecting` so slurp works. The bar is part of the frozen frame on purpose — since the overlay sits above it, the clock and runcat stay frozen while the UI is open. |

### Window switcher (Alt+Tab)

| File | Purpose |
|---|---|
| `WindowSwitcherService.qml` | **Singleton.** The window list, kept in **MRU order** (0 = focused, 1 = previous…) from `hyprctl clients -j`'s `focusHistoryID`. Held warm on purpose: running `hyprctl` at open time added a visible 30–60ms lag to Alt+Tab. `activewindowv2` reorders the array in place with no process at all; open/close/title/move events trigger an 80ms-debounced `hyprctl` refresh; a 5s timer catches anything missed. `frozen` is set while the panel is open — otherwise the row reshuffles under the selection and Alt lands on the wrong window. |
| `WindowSwitcherWindow.qml` | The overlay: a row of cards (icon, app name, workspace badge) plus the selected window's title. Commit calls `hl.dsp.focus({ window = "address:0x…" })`, which switches to that window's workspace as well. Focus is dispatched **before** the panel drops its keyboard grab so the old window can't get focus back in between. Animations are deliberately short (90–130ms) — Alt+Tab has to feel instant. |

**How the key handling splits in two:** Tab never reaches the panel — Hyprland's `ALT + Tab` bind swallows it — so stepping arrives over IPC (`qs-alt-tab next/prev`). The **Alt release** does reach it: while open, the layer surface holds `WlrKeyboardFocus.Exclusive`, so Qt sees `Key_Alt` release even though the press happened before the grab. That is the commit path. The `bindr`-style release bind in `keybinds.lua` is a second, independent route to the same IPC call; if both fire the later one is a no-op. Escape cancels, Enter/click commits, mouse hover moves the selection.

### Misc

| File | Purpose |
|---|---|
| `MediaPlayerPopup.qml` | MPRIS popup (cover, title, controls, progress). |
| `SystemTrayPopup.qml` | Tray icons popup. |

**Corners:** everything is `radius: 0` by user preference. The media player's circular control buttons are the only round elements left (they predate this work).

**Language:** everything written — on-screen strings, code comments, docs and
commit messages — is **English** (asked for on 2026-08-04). The Turkish comments
still in these QML files predate that and were not rewritten; anything new is English.

---

## 3. Scripts (`~/.local/bin/`)

| Script | Purpose |
|---|---|
| `qs-palette` | **Single source of truth for colors** — reads `~/.config/quickshell/palettes.json`. `list`, `labels`, `get <theme> <key>…`, `json <theme>`, `env <theme>` (shell-eval'able `BASE=…`, `MAUVE=…`). Every theme script goes through it; `Theme.qml` reads the same JSON directly. **Adding a theme = adding one block to that file, nothing else.** |
| `qs-theme` | Master theme applier. `qs-theme` prints current, `qs-theme list`, `qs-theme <name>`. Writes quickshell state, kitty (incl. `*-theme.auto.conf`), then delegates to the helpers below (GTK, Kvantum, KDE, dunst, btop, YouTube Music, Hyprland, Zen), then switches to **that theme's last wallpaper**. |
| `qs-theme-gtk` | GTK 3/4 `@define-color` block. Replaces the gtk-4.0 symlink with a real file that imports the base theme (gotcha #13). |
| `qs-theme-kvantum` | Qt/KDE widget style. For monochrome it **generates** `qs-monochrome` by copying the catppuccin Kvantum theme and converting every hex color to grayscale by luminance. |
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
| `qs-font` | **Single source of truth for fonts**, the way `qs-palette` is for colours. `qs-font` prints the current pair, `qs-font list` lists installed families, `qs-font <mono> [ui]` sets them. Pushes one choice into nine places that each store fonts their own way: GTK3/4 `settings.ini`, gsettings (libadwaita ignores settings.ini), qt6ct's QFont string, `KittyLemon.conf`, `dunstrc`, hyprlock (by re-running `qs-theme-hyprlock`) and `font.conf` itself. `mono` **must be a Nerd Font** — every bar icon is a Nerd Font glyph and a plain family leaves empty boxes. |
| `qs-mode` | Super+Shift+P — `performance` / `normal` / `toggle` / `status`. Stops the wallpaper processes (mpvpaper ~250 MB PSS, hyprpaper ~44 MB) and `qs-wallpaper-watch` with them, applies `config/perfmode.lua`, and tells the bar to throttle. Measured on this machine: **678 → 372 MB PSS and 7.8% → 4.5% CPU** across Hyprland + bar + wallpaper. Flag: `$XDG_RUNTIME_DIR/qs-mode.performance`. **The refresh rate is deliberately left alone** — 60 Hz instead of 180 nearly halves Hyprland's CPU again (9.2% → 3.5%, measured) but the refresh rate is the point of the machine. |
| `qs-maximize` | Super+H — "fullscreen with the bar still visible". Doesn't maximize one window: it zeroes `gaps_in`/`gaps_out`/`border_size` so every window on the workspace fills the screen together. **Scoped to the workspace it was pressed on** via `hl.workspace_rule` (gotcha #30); each workspace toggles independently, state in `$XDG_RUNTIME_DIR/qs-maximize.ws.<name>`. Restores the values from `decorations.lua` (3/8/2). A leftover `qs-maximize.on` from the old global version is detected and undone on the next press. **`qs-wallpaper-watch` reads the same per-workspace files** — changing that naming breaks the animated wallpaper's pause. |
| `qs-focus-keep-cursor` | Focuses a window by address without the pointer following, by saving `hyprctl cursorpos` and restoring it after the focus dispatch. `cursor:no_warps` is deliberately off globally so Super+arrow keeps its native pointer-follows-focus warp; this script is the one exception, used only by the Alt+Tab commit path. See gotcha #34. |
| `qs-alt-tab` | Hyprland ↔ switcher bridge: `next`, `prev`, `commit`, `cancel`. The commit bind fires on **every** Alt release (Alt+Space, in-app Alt use, …), so open/closed state is kept in `$XDG_RUNTIME_DIR/qs-switcher-open` — `next`/`prev` create the flag, `commit` needs it and removes it. Without the flag every Alt release would spawn a pointless `qs` process. A stale flag (panel closed with Escape) costs one wasted no-op IPC call. |
| `qs-paste` | Sends the paste shortcut to the focused window via `hl.dsp.send_shortcut` (gotcha #27). Uses Ctrl+Shift+V for terminals, Ctrl+V elsewhere. Called by the clipboard panel after a pick. |
| `qs-ytmd-titlebar` | **Runs as root.** Rebuilds `/opt/ytmdesktop/resources/app.asar` with the app's own title-bar colors patched (see §7). Keeps `app.asar.qs-backup` and always patches from it, so re-runs don't stack; `--restore` puts the original back. Must be re-run after every app update; `qs-theme-ytmd` prints a reminder once a backup exists. |
| `qs-grub-windows` | **Runs as root.** Writes `/etc/grub.d/35_lemonrice-windows` (a chainloader entry for `bootmgfw.efi`, id `lemonrice-windows`) and regenerates `grub.cfg`. Deliberately not os-prober: Windows sits on the same ESP as Arch here. Scores the candidate ESPs — system ESP > root disk > fixed disk — because a *removable* disk's ESP would give a menu entry that dies when the disk is unplugged. `--check` lists candidates, `--remove` deletes the entry. |
| `qs-boot-windows` | Launcher's **Boot to Windows** — one-shot, nothing permanent. Arms `efibootmgr --bootnext <Windows>` so the *firmware* goes straight to Windows on the next boot (GRUB never appears), falls back to `grub-reboot lemonrice-windows` where Windows has no NVRAM entry, then `systemctl reboot`. Writing EFI variables needs root and the launcher runs its entries detached with no terminal and no polkit agent, so `sudo qs-boot-windows --install` puts a root-owned copy in `/usr/local/bin` and a NOPASSWD rule for `--set` only in `/etc/sudoers.d/lemonrice-boot-windows` (validated with `visudo -c` first — a bad file there breaks sudo entirely). **The rule must point at the `/usr/local/bin` copy**: `~/.local/bin` is user-writable, so a rule pointing there would be free root for anything that can drop a file in it. Re-run `--install` after editing the script. From a terminal it works without the install, asking for the password. |
| `qs-file-search` | `find`-based home search, skips dotdirs/node_modules/etc. |
| `qs-file-preview` | Image passthrough, PDF first page via `pdftoppm`. |
| `qs-note-reminder` | Calendar reminder notification: notepad icon, `timeout 0`, `[ 󰈈 Preview ]` action. dunst can't draw real buttons, so the whole notification is clickable via `mouse_left_click = do_action`. |
| `qs-notif-dismiss-watch` | Watches `NotificationClosed`; reason 2 (user dismissed) → `dunstctl history-rm`, so clicked notifications don't linger in the notification center. Started from Hyprland autostart. |
| `qs-kb-layout` | Switches xkb layout and shows a keyboard-icon notification with the new layout name. |

---

## 4. State & data files

| Path | Contents |
|---|---|
| `~/.config/quickshell/font.conf` | **The font choice**, `key = value` with `#` comments: `mono`, `ui`, `size`, `weight` (a face name — Pango wants the word appended to the family, Qt/QML the OS/2 number, kitty it as a separate `style=` key, and "Regular" must be omitted from Pango strings entirely). Watched live by `Theme.qml` (so the bar restyles with no restart) and read by `qs-font`, `qs-theme-hyprlock` and `install.sh`. Nothing else reads it — every other target is rewritten in place by `qs-font`. |
| `~/.config/quickshell/palettes.json` | **Every theme's colors, in one place.** Per theme: the 21 UI colors, `label`, plus `gtkThemeName` / `gtkAccentName` / `kvantumTheme` / `nvimScheme`. Watched live by `Theme.qml`; read by every script via `qs-palette`. NB the GTK theme key is `gtkThemeName`, not `gtkTheme` — `qs-palette env` would otherwise export `GTK_THEME` and re-break gotcha #25. |
| `~/.config/quickshell/theme.txt` | Active theme name. Watched live by `Theme.qml`. |
| `~/.config/quickshell/wallpapers.conf` | `<theme> = /path/to/image.png` per line — **each theme's last used wallpaper**, rewritten by `qs-wallpaper set` for whichever theme is active. Switching themes switches to that theme's entry; `qs-wallpaper restore` re-applies it at login. Missing entry → first image in the theme's folder. (`wallpaper.txt` and `wallpaper-defaults.conf` are earlier iterations; `wallpaper.txt` is still read as a fallback, `wallpaper-defaults.conf` is not.) |
| `~/.config/hypr/config/theme.lua` | Generated Hyprland border colors; `decorations.lua` requires it with a fallback. |
| `~/.config/quickshell/favorites.json` | Launcher favorites (`.desktop` ids). |
| `~/.config/quickshell/clipboard-pins.json` | Pinned clipboard entry ids. |
| `~/.config/quickshell/generated/ytmdesktop.css` | Generated YouTube Music CSS. |
| `~/.local/share/quickshell/calendar-notes.json` | Calendar notes. |
| `~/.cache/quickshell-notif-seen` | Last-seen notification id. |
| `~/.cache/qs-note-preview` | Note id handoff (IPC can't take args). |
| `~/.cache/qs-wallpaper-pending` | Wallpaper path handoff. |
| `$XDG_RUNTIME_DIR/qs-mode.performance` | Performance mode flag. Read by `config/perfmode.lua` (so a reload re-applies the mode) and by `PerfMode.qml` at startup. In the runtime dir on purpose: the mode should not survive a reboot. |
| `~/.cache/qs-screenshot-freeze.png` | Frozen frame while the screenshot UI is open. |
| `~/.cache/qs-screenshot-pending.png` | Captured shot awaiting save/discard. |
| `~/.cache/qs-clip/` | Clipboard thumbnails. |
| `~/Pictures/Wallpapers/<Theme>/` | Wallpapers per theme (`CatpuccinMocha`, `Monochrome`). |
| `~/Pictures/Screenshots/` | Saved screenshots. |

---

## 5. Keybinds (`~/.config/hypr/config/keybinds.lua`)

| Keys | Action |
|---|---|
| `Alt + Tab` (hold Alt) | Window switcher — Tab steps forward, Shift+Tab back, releasing Alt jumps to the selected window and its workspace. Replaced `hl.dsp.window.cycle_next()`. |
| `Alt + Space` | Launcher (Apps/Files/Favorites/System) |
| `Super + V` | Clipboard history |
| `Super + Shift + S` | Screenshot UI (freezes the screen) |
| `Super + Shift + Z` | Wallpaper picker |
| `Super + Ctrl + Z` | Theme **and font** picker — `←`/`→` between the two sections, `Space` cycles font weight |
| `Super + Alt + C` | Launcher, System tab |
| `Super + Shift + P` | Performance mode toggle (wallpaper, blur, shadows, animations off; bar polls slower) |
| `Super + K` | Keyboard layout switch |
| `Super + H` | Close the gaps on **this workspace only** (bar stays visible) — toggle |
| `Super + S` | Toggle special workspace |

Calendar has no keybind — click the date in the bar. IPC equivalents:
`qs -c topbar ipc call <target> <function>` where targets are
`launcher, clipboard, calendar, notePreview, theme, wallpaper, wallpaperFx, screenshot,
switcher`. A few skip straight to a section: `launcher system`, `launcher files`,
`theme fonts`.

---

## 6. dunst integration (`~/.config/dunst/dunstrc`)

- Square corners (`corner_radius = 0`), `history_length = 100`, `show_indicators = false`.
- `mouse_left_click = do_action, close_current` — needed for the reminder Preview button.
- `icon_path` includes `devices` dirs (for the keyboard icon).
- Rules: `[forward_all_notifications]` (pre-existing proxy → `dunst-forward` → `dunst-notify`), `[proxy_notifications]`, `[qs_reminder]` (appname `DunstProxy` + category `qs.reminder`, `timeout = 0`, no progress bar).
- **Because of the proxy, every history entry has appname `DunstProxy` and urgency `NORMAL`** — the notification center hides the app name and the urgency stripe is always the accent color.
- **`dunst-forward` de-duplicates before forwarding.** A phone message arrives twice when a desktop client for the same service is running: the client posts `"Sender" / "message"` and KDE Connect relays the phone's copy as `"WhatsApp" / "Sender: message"` (KDE Connect's `ticker` property is literally `"title: text"`). The second shape is folded onto the first so both hash alike, first arrival wins, and the loser is dropped — signatures live in `~/.cache/dunst-proxy-icons/dedup`, claimed atomically via `noclobber`. Cross-shape matches hold for 15 s but only across *different* app names, so one app repeating itself still gets its own popup. Identical re-posts collapse within 3 s, which also catches `replaces_id` updates — the proxy always builds a fresh popup instead of updating the original.
- Colors in this file are rewritten by `qs-theme-dunst`; don't hand-edit them.

---

## 7. Known limitations / open items

- **Monochrome has no GTK or Kvantum upstream theme.** GTK falls back to `Adwaita-dark` plus our color overrides (catppuccin keeps its own theme package); Kvantum is generated by grayscaling. A real Tokyo-Night-style package would need `yay -S`.
- **YouTube Music Desktop's own title bar** is the app's window chrome (`.titlebar { background-color: #000 }` in the bundled renderer CSS), not the YouTube web view — `customCSSPath` is only injected into the web view, so no CSS we write can reach it. `qs-ytmd-titlebar` patches the asar itself (root, undone by app updates). The rebuild was verified round-trip: every other file in the archive stays byte-identical.
- **btop** is skipped while `~/.config/btop` is root-owned. Fix: `sudo chown -R mrlemon:mrlemon ~/.config/btop ~/.config/fish ~/.config/kitty ~/.local/share/kservices5`.
- **Zen Browser is themed again** (asked for on 2026-07-31, after an earlier revert). `qs-theme-zen` writes a managed block in `chrome/userChrome.css` for every profile in `profiles.ini` plus the legacy-stylesheets pref in `user.js`. It flattens the workspace gradient to the theme color; if the gradient picker is wanted back, drop the `#navigator-toolbox` / `.zen-browser-generic-background` rules. **Colors only appear after Zen restarts** — there is no live reload path from outside the browser.
- **Clipboard entries have no timestamps** — cliphist doesn't store them, so no "2m ago" labels (deliberately not faked).
- **Icons for old notifications disappear**: `dunst-icon-cache` prunes PNGs after `MAX_AGE = 180` seconds, so history items older than ~3 min fall back to a generic bell.
- **wl-clip-persist** is installed and in autostart (keeps clipboard after the source app closes).
