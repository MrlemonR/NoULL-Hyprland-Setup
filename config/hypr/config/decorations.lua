-- Pencere kenarlıklarının GRUP renkleri ve fare davranışı.
--
-- DİKKAT: blur, opaklık, gölge, boşluk, köşe yuvarlaması ve ana kenarlık
-- ARTIK BURADA DEĞİL — hepsi config/effects.lua'da, tek yerde birleştirilip
-- bir kez uygulanıyor. Dört ayrı dosyanın aynı anahtarları yazması ve
-- kazananı require sırasının belirlemesi çorbanın kaynağıydı.
local ok, theme = pcall(require, "config.theme")
if not ok or type(theme) ~= "table" then
    theme = {}
end

local group_active      = theme.group_active      or CACHYLGREEN
local group_inactive    = theme.group_inactive    or CACHYGRAY
local groupbar_active   = theme.groupbar_active   or CACHYLGREEN
local groupbar_inactive = theme.groupbar_inactive or CACHYGRAY

hl.config({
    general = {
        extend_border_grab_area = 10,
        resize_on_border = true,
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
})
