-- Performans modu (Super+Shift+P -> qs-mode).
--
-- Bu dosya modun TEK kaynağı. İki yerden çalışıyor:
--   1) hyprland.lua en sonda require ediyor — böylece `hyprctl reload`
--      sonrasında mod kendini yeniden uyguluyor. Eskiden reload,
--      decorations.lua/animations.lua'yı geri yükleyip modu sessizce iptal
--      ediyordu: bayrak dosyası "performance" derken blur/gölge/animasyon
--      geri açılmış oluyordu.
--   2) qs-mode `hyprctl eval "dofile(...)"` ile doğrudan çağırıyor.
--
-- Bayrak dosyası yoksa hiçbir şey yapmıyor, yani normal modda etkisiz.
--
-- DİKKAT: monitör tazeleme hızına BİLEREK dokunulmuyor. 180Hz oyunda
-- performansın kendisi; düşürmek derdi çözmek değil, başka yere taşımak.

local flag = (os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/qs-mode.performance"

local f = io.open(flag, "r")
if not f then
    return
end
f:close()

-- DİKKAT: `misc.vfr` Hyprland 0.56'da yok (debug.vfr'ye taşınmış ve zaten
-- varsayılan olarak açık). Burada bulunmayan bir anahtar olması hl.config
-- çağrısının tamamını hata verdiriyor — modun yıllardır yarım uygulanmasının
-- sebebi buydu.
hl.config({
    animations = {
        enabled = false,
    },
    decoration = {
        rounding = 0,
        active_opacity = 1,
        inactive_opacity = 1,
        fullscreen_opacity = 1,
        dim_inactive = false,
        dim_special = 0,
        blur = {
            enabled = false,
        },
        shadow = {
            enabled = false,
        },
    },
    misc = {
        disable_hyprland_logo = true,
    },
})
