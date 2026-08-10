local mainMod = "SUPER"
local noctCall = "qs -c noctalia-shell ipc call "
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + W",           hl.dsp.window.close())
hl.bind(mainMod .. " + G",	     hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
-- Super+H: bar görünür kalan "tam ekran" — maximize + boşlukları kapat
-- (bkz. qs-maximize). Gerçek tam ekran Super+F.
-- Performans modu: duvar kağıdı/blur/gölge/animasyon kapanır, bar kalır
hl.bind(mainMod .. " + SHIFT + P",   hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/qs-mode toggle"))
hl.bind(mainMod .. " + H",           hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/qs-maximize"))
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + L",           hl.dsp.exec_cmd("uwsm app -- hyprlock"))
hl.bind(mainMod .. " + ALT + C",     hl.dsp.exec_cmd("qs -c topbar ipc call launcher system"))

-- Change focus
hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down",  hl.dsp.focus({ direction = "down" }))
-- Alt+Tab: quickshell pencere anahtarlayıcısı.
-- Alt basılı tutulurken Tab seçimi ilerletiyor, Alt bırakılınca seçili
-- pencereye (ve onun workspace'ine) geçiliyor. Bkz. qs-alt-tab.
local altTab = os.getenv("HOME") .. "/.local/bin/qs-alt-tab "
hl.bind("ALT + Tab",           hl.dsp.exec_cmd(altTab .. "next"), { repeating = true })
hl.bind("ALT + SHIFT + Tab",   hl.dsp.exec_cmd(altTab .. "prev"), { repeating = true })
-- Alt'ın kendisinin bırakılması: seçimi onayla (release bind)
hl.bind("ALT + Alt_L",         hl.dsp.exec_cmd(altTab .. "commit"), { release = true })
hl.bind("ALT + Alt_R",         hl.dsp.exec_cmd(altTab .. "commit"), { release = true })

-- Move active window around current workspace
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Down",  hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Right", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",  hl.dsp.window.move({ workspace = "r-1" }))

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

------------------
---- LAUNCHER ----
------------------

hl.bind(mainMod .. " + Q",          hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))
hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(launchPrefix .. EDITOR))
hl.bind(mainMod .. " + SHIFT + C",  hl.dsp.exec_cmd("gnome-calculator"))
hl.bind(mainMod .. " + B",          hl.dsp.exec_cmd(launchPrefix .. BROWSER))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))
hl.bind(mainMod .. " + period",     hl.dsp.exec_cmd(noctCall .. "launcher emoji"))
hl.bind("ALT + Space",              hl.dsp.exec_cmd("qs -c topbar ipc call launcher toggle"))
hl.bind(mainMod .. " + V",          hl.dsp.exec_cmd("qs -c topbar ipc call clipboard toggle"))
hl.bind(mainMod .. " + SHIFT + E",  hl.dsp.exec_cmd("kitty -e yazi"))
-- hyprpicker over the frozen screen, then the control centre opens on the
-- colour page with the hex (also copied to the clipboard). Was gcolor3.
hl.bind(mainMod .. " + ALT + X",    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/qs-color pick"))
hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd("claude-desktop"))
hl.bind(mainMod .. " + M",          hl.dsp.exec_cmd("kitty -e noull-pm"))
---------------------------
---- HARDWARE CONTROLS ----
---------------------------

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctCall .. "volume increase"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctCall .. "volume decrease"),   { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(noctCall .. "volume muteOutput"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(noctCall .. "volume muteInput"),  { locked = true, repeating = true })

-- Media
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(noctCall .. "media playPause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(noctCall .. "media playPause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(noctCall .. "media next"),      { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(noctCall .. "media previous"),  { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noctCall .. "brightness increase"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctCall .. "brightness decrease"), { repeating = true })

-------------------
---- UTILITIES ----
-------------------


-- Hyprshot: saved to ~/Pictures/Screenshots and copied to clipboard
local shot = os.getenv("HOME") .. "/.local/bin/screenshot "
hl.bind(mainMod .. " + ALT + S",                   hl.dsp.exec_cmd(shot .. "region"))  -- select an area

-- Clipboard-only variants (nothing written to disk)
hl.bind(mainMod .. " + SHIFT + S",         hl.dsp.exec_cmd("qs -c topbar ipc call screenshot toggle"))

-- Clipboard
-- (kaldırıldı: noctalia kurulu değil; pano için Super+V yukarıda quickshell'e bağlı)

--------------------
---- WORKSPACES ----
--------------------

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
end

hl.bind(mainMod .. " + CONTROL + Right",       hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + CONTROL + Left",        hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + CONTROL + Down",        hl.dsp.focus({ workspace = "empty" }))
hl.bind(mainMod .. " + CONTROL + ALT + Right", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + CONTROL + ALT + Left",  hl.dsp.window.move({ workspace = "r-1" }))

-- Scroll through existing workspaces
hl.bind(mainMod .. " + mouse_down",            hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",              hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down",  hl.dsp.focus({ workspace = "empty" }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + CONTROL + S",           hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + S",                     hl.dsp.workspace.toggle_special())

-----------------------
---- NOTIFICATIONS ----
-----------------------

hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(noctCall .. "notifications toggleHistory"))

-------------------------
---- KEYBOARD LAYOUT ----
-------------------------

hl.bind(mainMod .. " + K", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/qs-kb-layout"))

-- ============================================================
-- QUICKSHELL MENÜLERİ
-- ============================================================

hl.bind(mainMod .. " + SHIFT + Z",   hl.dsp.exec_cmd("qs -c topbar ipc call wallpaper toggle"))
hl.bind(mainMod .. " + CONTROL + Z", hl.dsp.exec_cmd("qs -c topbar ipc call theme toggle"))
-- Control centre — the same panel the running cat in the bar opens
hl.bind(mainMod .. " + CONTROL + C", hl.dsp.exec_cmd("qs -c topbar ipc call controlCenter toggle"))
-- (takvim zaten bardaki tarihe tıklanınca açılıyor; Super+SHIFT+C hesap makinesinde)
