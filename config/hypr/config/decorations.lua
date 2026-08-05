-- Pencere kenarlık renkleri temadan geliyor.
-- config/theme.lua dosyasını qs-theme-hypr üretiyor (qs-theme <tema> çalışınca)
-- ve aynı renkleri hyprctl eval ile canlı olarak da uyguluyor.
-- Dosya yoksa aşağıdaki varsayılanlara düşülüyor.
local ok, theme = pcall(require, "config.theme")
if not ok or type(theme) ~= "table" then
    theme = {}
end

local active_border     = theme.active_border     or MOCHALBLUE
local inactive_border   = theme.inactive_border   or MOCHADBLUE
local group_active      = theme.group_active      or CACHYLGREEN
local group_inactive    = theme.group_inactive    or CACHYGRAY
local groupbar_active   = theme.groupbar_active   or CACHYLGREEN
local groupbar_inactive = theme.groupbar_inactive or CACHYGRAY

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = active_border,
            inactive_border = inactive_border,
        },
    },
    group = {
        col = {
            border_active = group_active,
            border_inactive = group_inactive,
            border_locked_active = CACHYDBLUE,
            border_locked_inactive = group_inactive,
        },
        groupbar = {
            col = {
                active = groupbar_active,
                inactive = groupbar_inactive,
                locked_active = CACHYDBLUE,
                locked_inactive = groupbar_inactive,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        active_opacity = 0.95,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1,
        blur = {
            size = 5,
            passes = 4,
            special = true,
        },
    },
})
