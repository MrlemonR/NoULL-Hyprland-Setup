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

Every colour lives in one file: `config/quickshell/palettes.json`. Adding a
theme means adding one block there — the bar, GTK 3/4, Qt/Kvantum, KDE apps,
kitty, dunst, btop, Hyprland window borders, Zen Browser and YouTube Music
Desktop all read from it.

```bash
qs-theme nord          # apply a theme
qs-palette list        # list themes
```

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
