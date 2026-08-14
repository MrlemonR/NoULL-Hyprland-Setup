# LemonRice

A Hyprland rice built on [quickshell](https://quickshell.org). One script turns
a bare Arch install into the whole setup — bar, launcher, notifications,
theming across every app, wallpapers included.

```bash
git clone https://github.com/MrlemonR/LemonRice.git
cd LemonRice && ./install.sh
```

Log out and back in when it finishes.

## What you get

- **quickshell top bar** — workspaces, media controls, CPU/RAM/temperature,
  volume, system tray, notification centre, running cat
- **Control centre** (`Super+Ctrl+C`, or click the running cat) — buttons that
  turn the panel into the page you pressed: appearance effects, system toggles,
  which bar widgets are drawn, phone (adb), colour picker, reload
- **Colour picker** (`Super+Alt+X`) — hyprpicker over the frozen screen, then
  the panel shows the hex/RGB/HSL and a history you can copy from
- **Phone** — finds your paired Android over the network by itself, then
  streams it with scrcpy, takes screenshots, sends files, opens a shell
- **Launcher** (`Alt+Space`) — apps, file search, favourites, system actions
- **Clipboard history** (`Super+V`) — pick an entry and it is pasted straight
  into the focused window
- **Screenshot UI** (`Super+Shift+S`) — the screen freezes while you pick
- **Wallpaper picker** (`Super+Shift+Z`) — coverflow carousel, `↑/↓` switches
  between static and animated wallpapers
- **Theme picker** (`Super+Ctrl+Z`)
- **Calendar with reminders** — click the date in the bar
- **Animated wallpapers** via mpvpaper, automatically paused when something
  covers the screen
- **Gapless mode** (`Super+H`) and **performance mode** (`Super+Shift+P`)

## Themes

`catppuccin-mocha` · `monochrome` · `gruvbox` · `nord` · `everforest`

Plus **custom themes** — `frutiger-aero` — which deliberately break the house
rules (square corners, flat surfaces) with rounded corners, gloss and
translucency. They live in the same palettes file, marked `"custom": true` with
a `style` block, and the theme picker keeps them in their own section: `←` from
the theme list, `→` for fonts.

Every colour lives in one file: `config/quickshell/palettes.json`. Adding a
theme means adding one block there — the bar, GTK 3/4, Qt/Kvantum, KDE apps,
kitty, dunst, btop, Hyprland window borders, Zen Browser, YouTube Music Desktop
**and Neovim** all read from it.

Neovim gets the same treatment rather than a colorscheme plugin per theme: one
generated colorscheme renders whichever theme is active, and it watches the
palette files, so `Super+Ctrl+Z` restyles editors that are already open.

```bash
qs-theme nord          # apply a theme
qs-palette list        # list themes
```

## Control centre

Click the running cat in the bar (or `Super+Ctrl+C`). Pressing a button turns
the panel into that page instead of opening a window:

| Page | What is on it |
|---|---|
| **Appearance** | animations, blur, shadows, transparency, window gaps |
| **System** | encrypted DNS, performance mode, microphone |
| **Top Bar** | which bar widgets are drawn, plus an optional cava spectrum either side of the workspaces |
| **Phone** | type the port Wireless debugging shows, then stream / screenshot / send file / shell / reboot |
| **Color** | hyprpicker, then hex + RGB + HSL and a history to copy from |
| **Reload** | restart the shell in place |

Everything also works from the command line:

```bash
qs-settings                       # animations / blur / shadows / transparency / gaps
qs-settings toggle animations
qs-mode toggle                    # performance mode
qs-color pick                     # hyprpicker -> clipboard + the colour page
qs-adb connect 41709              # the port Wireless debugging shows
qs-adb connect                    # or let it search: cache -> mDNS -> port sweep
qs-adb stream                     # scrcpy, borderless, phone screen off
sudo ~/.config/quickshell/scripts/dns-toggle.sh --on   # encrypted DNS (DoT)
```

**About the phone:** wireless debugging picks a new random port every time it is
switched on, and this `adb` build has no mDNS support, so the panel simply asks
for the port — the phone shows it next to the switch. The command line can also
search for it (cached address, then a hand-rolled one-shot mDNS query, then a
threaded port sweep of the LAN, ~0.4s here) if you would rather not type it.

The effect toggles live in `~/.config/quickshell/settings.json` and are applied
by `config/hypr/config/toggles.lua`, which runs last in `hyprland.lua` — so
they survive a `hyprctl reload` instead of being silently switched back on.

**Encrypted DNS** points systemd-resolved at Quad9/Cloudflare over TLS, for
networks where the ISP resolver answers blocked domains with a sentinel IP. It
needs root, so the panel opens a terminal for the sudo prompt rather than
failing quietly.

## Layout

```
config/        → ~/.config          (hypr, quickshell, kitty, fish, …)
local/share/   → ~/.local/share     (fonts, themes, icons, dolphin)
bin/           → ~/.local/bin       (qs-* helper scripts)
wallpapers.zip → ~/Pictures/Wallpapers
wallpapers-animated.z01/.z02/.zip   (split archive, joined during install)
PROJECT.md     → how it all fits together + the gotchas
```

Anything the theme scripts can generate (`gtk.css`, `theme.lua`, btop themes,
Kvantum variants, kitty colours) is **not** in the repo — `install.sh` produces
it by running `qs-theme` at the end. Personal state (calendar notes, clipboard
history, favourites) is excluded as well.

## Notes

- Animated wallpapers ship as a **split zip** because the videos total ~200 MB
  and GitHub rejects single files over 100 MB. `install.sh` joins the parts
  automatically; you need all of `.z01`, `.z02` and `.zip`.
- Re-running `install.sh` never overwrites wallpapers you added yourself, and
  backs up any config it replaces as `.bak-<timestamp>`.
- If YouTube Music Desktop is installed, theme its title bar with
  `sudo ~/.local/bin/qs-ytmd-titlebar` (patches the app's asar, so re-run it
  after app updates).
- Zen Browser only reads `userChrome.css` at startup — restart it after a
  theme change.

## Keeping the repo in sync

`qs-export` regenerates this repo from a running system:

```bash
qs-export ~/Projects/LemonRice
```

It copies the configs, scripts, fonts and wallpapers, strips everything that is
generated or personal, and rebuilds both wallpaper archives.
