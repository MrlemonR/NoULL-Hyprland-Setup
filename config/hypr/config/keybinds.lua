local mainMod = "SUPER"
local home = os.getenv("HOME")
local bin = home .. "/.local/bin/"

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

hl.bind(mainMod .. " + W",         hl.dsp.window.close())
hl.bind(mainMod .. " + G",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("uwsm app -- hyprlock"))
hl.bind(mainMod .. " + H",         hl.dsp.exec_cmd(bin .. "qs-maximize"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(bin .. "qs-mode toggle"))

-- Directional Focus
local focusDirections = { Left = "left", Right = "right", Up = "up", Down = "down" }
for key, dir in pairs(focusDirections) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
end

-- Move Active Window
local moveDirections = { Left = "l", Right = "r", Up = "u", Down = "d" }
for key, dir in pairs(moveDirections) do
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

hl.bind(mainMod .. " + CONTROL + SHIFT + Right", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",  hl.dsp.window.move({ workspace = "r-1" }))

-- Mouse Binds
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Alt+Tab Switcher
local altTab = bin .. "qs-alt-tab "
hl.bind("ALT + Tab",         hl.dsp.exec_cmd(altTab .. "next"),   { repeating = true })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(altTab .. "prev"),   { repeating = true })

-- Workspace overview. Drops out of the bar and shows every workspace side by
-- side; drag a card to move a window, or press the X on one to close it.
hl.bind("ALT + CONTROL + Tab", hl.dsp.exec_cmd("qs -c topbar ipc call overview toggle"))
hl.bind("ALT + Alt_L",       hl.dsp.exec_cmd(altTab .. "commit"), { release = true })
hl.bind("ALT + Alt_R",       hl.dsp.exec_cmd(altTab .. "commit"), { release = true })

-------------------
---- LAUNCHERS ----
-------------------

local appLaunchers = {
    { key = mainMod .. " + Q",          cmd = "kitty"},
    { key = mainMod .. " + E",          cmd = "dolphin"},
    { key = mainMod .. " + T",          cmd = "gnome-text-editor --new-window" },
    { key = mainMod .. " + B",          cmd = "zen-browser"},
    { key = mainMod .. " + C",          cmd = "claude-desktop" },
    { key = mainMod .. " + SHIFT + C",  cmd = "gnome-calculator" },
    { key = mainMod .. " + SHIFT + E",  cmd = "kitty -e yazi" },
    { key = mainMod .. " + M",          cmd = "kitty -e " .. bin .. "noull-pm" },
    { key = "CONTROL + SHIFT + Escape", cmd = "kitty -e btop" },
}
for _, app in ipairs(appLaunchers) do
    hl.bind(app.key, hl.dsp.exec_cmd(app.cmd))
end

------------------------------------
---- QUICKSHELL & IPC COMMANDS ----
------------------------------------

local qsIPCBinds = {
    { key = "ALT + Space",               call = "launcher toggle" },
    { key = mainMod .. " + V",           call = "clipboard toggle" },
    { key = mainMod .. " + SHIFT + S",   call = "screenshot toggle" },
    { key = mainMod .. " + ALT + C",     call = "launcher system" },
    { key = mainMod .. " + SHIFT + Z",   call = "wallpaper toggle" },
    { key = mainMod .. " + Z",           call = "settings toggle" },
    { key = mainMod .. " + CONTROL + Z", call = "theme toggle" },
    { key = mainMod .. " + CONTROL + C", call = "controlCenter toggle" },
}
for _, qs in ipairs(qsIPCBinds) do
    hl.bind(qs.key, hl.dsp.exec_cmd("qs -c topbar ipc call " .. qs.call))
end

---------------------------------
---- UTILITIES & MISC BINDS ----
---------------------------------

hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd(bin .. "screenshot region"))
hl.bind(mainMod .. " + ALT + X", hl.dsp.exec_cmd(bin .. "qs-color pick"))
hl.bind(mainMod .. " + K",       hl.dsp.exec_cmd(bin .. "qs-kb-layout"))

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

-- Workspace Scrolling & Special Workspace
hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "empty" }))
hl.bind(mainMod .. " + CONTROL + S",          hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + S",                    hl.dsp.workspace.toggle_special())
