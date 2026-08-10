
-- Picture-in-Picture
hl.window_rule({
    match             = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float             = true,
    keep_aspect_ratio = true,
    move              = "73% 72%",
    size              = "25% 25%",
    pin               = true,
})

-- Gaming

hl.window_rule({ match = { class = "steam", title = "Friends List"}, float = true, center = true })
hl.window_rule({ match = { class = "steam", title = "Steam Settings"}, float = true, center = true })
-- Apps
local primaryWorkspace = 1

hl.window_rule({ match = { class = "^(.*\\.exe)$", float = true }, primaryWorkspace, center = true, fullscreen_state = 0 })
hl.window_rule({ match = { class = "^(vesktop|discord)$" }, primaryWorkspace })
hl.window_rule({ match = { class = "^(.*[Cc]alculator.*)$" }, float = true, size = "380 616" })
hl.window_rule({ match = { class = "^(org.kde.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org.kde.ark)$" }, size = "(monitor_w*0.40) (monitor_h*0.40)" })
hl.window_rule({ match = { class = "com.saivert.pwvucontrol"}, float = true, size = "743 390", move = "1172 33"})
hl.window_rule({ match = { class = "com.sidevesh.Luminance"}, float = true, move = "1517 32"})
hl.window_rule({ match = { class = "FloatBtop"}, float = true, center = true, size = "1337 854"})
-- Control centre -> Encrypted DNS: a terminal only because the script needs a
-- sudo prompt. It prints a short report, so it does not need to be large.
hl.window_rule({ match = { class = "FloatDns"}, float = true, center = true, size = "760 460"})
hl.window_rule({ match = { class = "nl.hjdskes.gcolor3"}, float = true, center = true, size = "928 535"})
hl.window_rule({ match = { class = "zen", title = "Oturum açın.*"}, float = true, center = true})
hl.window_rule({ match = { class = "org.kde.gwenview"}, float = true, center = true, size = "1259 788"})
hl.window_rule({ match = { class = "^([Bb]lender)$", title = "^(Blender File View)$"}, float = true, center = true, size = "1084 825"})
hl.window_rule({
    match = {
        class = "^(org.kde.dolphin)$",
        title = "negative:^(Moving.*|Create New.*|Extract.*|Compress.*|Copying.*|Progress.*|Configure.*|Properties.*|Choose\\sApplication.*|.*Folder Already Exists.*)$",
    },
    float = true,
    center = true,
    size = "1300 800",
})

-- Opacity Overrides
local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)$"

hl.window_rule({ match = { class = "^(firefox|zen)$" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" }) -- override opacity in favor of terminal settings for opacity
hl.window_rule({ match = { class = "^(mpv|org.kde.haruna|.*plex.*|org\\.kde\\.gwenview|.*vlc.*)$" }, opacity = "1.0 override" })

-- Float Utility Windows
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
}
for _, m in ipairs(floatApps) do hl.window_rule({ match = m, float = true }) end

hl.window_rule({ match = { float = true }, move = "50% 50%" })

-- Float Common Modals
local modalMatches = {
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress|File Already Exists)$" },
    { initial_title = "^(Open File)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$"},
}
for _, m in ipairs(modalMatches) do hl.window_rule({ match = m, float = true }) end
hl.window_rule({match = { title = "File Already Exists.*"}, center = true, size = "881 448"})

-- Ignore maximize requests from all apps. You'll probably like this.
local suppressMaximizeRule = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})
