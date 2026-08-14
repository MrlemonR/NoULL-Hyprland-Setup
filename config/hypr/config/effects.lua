-- Efektlerin TEK uygulayıcısı: blur, opaklık, gölge, animasyon, boşluklar,
-- köşe yuvarlaması ve pencere kenarlığı.
--
-- NEDEN TEK DOSYA
--
-- Eskiden dört dosya aynı anahtarları yazıyordu — decorations.lua, glass.lua,
-- toggles.lua, perfmode.lua — ve hangisinin kazandığını yalnızca
-- hyprland.lua'daki require sırası belirliyordu. Sonuç: cam blur'ü açıyor,
-- arkasından çalışan toggles.lua "blur kapalı" görüp geri kapatıyordu. Çözüm
-- diye toggles.lua'ya "cam açıkken karışma" istisnası eklenmişti; beşinci bir
-- yazıcı gelse bir istisna daha gerekecekti.
--
-- Artık her katman yalnızca NE İSTEDİĞİNİ söylüyor, uygulamayı bu dosya
-- yapıyor — bir kez, açık bir öncelik sırasıyla:
--
--     temel (decorations.lua'nın değerleri + kullanıcı slider'ları)
--       -> cam        (aeroGlass açıksa: blur/opaklık/kenarlığı devralır)
--       -> anahtarlar (kullanıcının kapattıkları)
--       -> perfmode   (her şeyi kapatır, en üstte)
--
-- Sonrakiler öncekileri eziyor, tek istisnası SAHİPLİK: cam açıkken blur ve
-- saydamlık ona ait, kullanıcı anahtarları o iki alanda söz sahibi değil.
-- Sebebi kurallı: ayarlar ekranı camı açarken o iki anahtarı zaten kapatıyor
-- (üç anahtar aynı yüzey için yarışmasın diye), yani depodaki "kapalı" bir
-- kullanıcı niyeti değil, camın kendi izi. Onu niyet sanmak camı açar açmaz
-- geri kapatıyordu.
--
-- DİKKAT: bu Hyprland sürümünde bulunmayan tek bir anahtar `hl.config`
-- çağrısının TAMAMINI hata verdiriyor, üstelik hatayı yalnızca stderr'e
-- yazıyor (gotcha #33). Aşağıdaki her anahtar 0.56'da denenmiştir.

local settings = require("config.settings")

local flag = (os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/qs-mode.performance"
local function perfmode()
    local f = io.open(flag, "r")
    if not f then return false end
    f:close()
    return true
end

-- Pencere kenarlık renkleri temadan; qs-theme-hypr üretiyor.
local ok, theme = pcall(require, "config.theme")
if not ok or type(theme) ~= "table" then
    theme = {}
end

-- ── 1. Temel ───────────────────────────────────────────────────────────
-- "Açık" ne demek: decorations.lua'nın sabitleri, kullanıcının slider'ları.

local gaps = settings.number("gapsAmount", 8, 0, 40)
local opacity = settings.number("transparencyAmount", 0.95, 0.5, 1)

local state = {
    animations = true,
    blur = true,
    blur_size = settings.number("blurAmount", 5, 1, 20),
    blur_passes = 4,
    blur_vibrancy = nil,
    blur_brightness = nil,
    blur_contrast = nil,
    blur_noise = nil,
    shadow = true,
    active_opacity = opacity,
    inactive_opacity = math.max(0.4, opacity - 0.1),
    fullscreen_opacity = 1,
    gaps_in = math.max(0, math.floor(gaps * 3 / 8 + 0.5)),
    gaps_out = gaps,
    rounding = theme.rounding or 0,
    border_size = 2,
    active_border = theme.active_border,
    inactive_border = theme.inactive_border,
}

-- ── 2. Aero Glass ──────────────────────────────────────────────────────
-- Cam üçüncü bir efekt değil: blur ve saydamlığın birlikte ayarlanmış hâli
-- artı kalın yarı saydam bir çerçeve. O yüzden ikisini de DEVRALIYOR.

local glass = settings.explicit("aeroGlass")

if glass then
    state.blur = true
    -- Buzlu cam, bulamaç değil. Çok saydam bir pencerede geniş yarıçap
    -- arkadaki her şeyi tek bir renk alanına ortalıyor; dar yarıçap detayı
    -- siliyor ama şekilleri bırakıyor — cam hissini veren o.
    state.blur_size = 3
    state.blur_passes = 2
    state.blur_vibrancy = 0.45
    state.blur_brightness = 1.08
    state.blur_contrast = 1.12
    -- Gerçek buzlu cam pürüzlü; düz bir bulanıklık plastik gibi duruyor.
    state.blur_noise = 0.045
    state.active_opacity = 0.72
    state.inactive_opacity = 0.62
    -- Win7'nin cam çerçevesi: derleyici başlık çubuğu ekleyemez ama bulanık
    -- zemin üstünde kalın yarı saydam bir kenarlık aynı siluet.
    state.border_size = 5
    state.active_border = "rgba(ffffff66)"
    state.inactive_border = "rgba(ffffff33)"
end

-- ── 3. Kullanıcının kapattıkları ───────────────────────────────────────
-- Yalnızca KAPATIYOR — ve camın sahiplendiği iki alana dokunmuyor.

if settings.disabled("animations") then state.animations = false end
if settings.disabled("shadows") then state.shadow = false end

if settings.disabled("blur") and not glass then state.blur = false end

if settings.disabled("transparency") and not glass then
    state.active_opacity = 1
    state.inactive_opacity = 1
    state.fullscreen_opacity = 1
end

if settings.disabled("gaps") then
    state.gaps_in = 0
    state.gaps_out = 0
end

-- ── 4. Performans modu ─────────────────────────────────────────────────
-- Her şeyin üstünde. Bu dosya hyprland.lua'nın sonunda require edildiği için
-- `hyprctl reload` sonrasında da kendini yeniden uyguluyor — eskiden reload
-- modu sessizce iptal ediyordu.

if perfmode() then
    state.animations = false
    state.blur = false
    state.shadow = false
    state.rounding = 0
    state.active_opacity = 1
    state.inactive_opacity = 1
    state.fullscreen_opacity = 1
end

-- ── Uygula ─────────────────────────────────────────────────────────────

local blur = { enabled = state.blur }
if state.blur then
    blur.size = state.blur_size
    blur.passes = state.blur_passes
    blur.special = true
    if state.blur_vibrancy then blur.vibrancy = state.blur_vibrancy end
    if state.blur_brightness then blur.brightness = state.blur_brightness end
    if state.blur_contrast then blur.contrast = state.blur_contrast end
    if state.blur_noise then blur.noise = state.blur_noise end
    if glass then blur.popups = true end
end

local general = {
    gaps_in = state.gaps_in,
    gaps_out = state.gaps_out,
    border_size = state.border_size,
}
if state.active_border then
    general.col = {
        active_border = state.active_border,
        inactive_border = state.inactive_border,
    }
end

hl.config({
    animations = { enabled = state.animations },
    general = general,
    decoration = {
        rounding = state.rounding,
        active_opacity = state.active_opacity,
        inactive_opacity = state.inactive_opacity,
        fullscreen_opacity = state.fullscreen_opacity,
        dim_special = perfmode() and 0 or 0.3,
        blur = blur,
        shadow = { enabled = state.shadow },
    },
})

-- Camın kabuk yüzeyleri. Bir layer surface ne kadar saydam olursa olsun
-- KENDİLİĞİNDEN bulanıklaşmıyor; kural olmadan paneller masaüstünü net
-- gösteriyor, bu da cam değil kırık pencere gibi duruyor.
--
-- `match.namespace` bir REGEX, Lua pattern değil — tireyi `%-` diye kaçırmak
-- kuralı sessizce hiçbir şeyle eşleştirmiyor (gotcha #51).
--
-- `ignore_alpha` bu pencerelerin çizdiği iki saydam şeyin ARASINA düşmek
-- zorunda: tam ekran perde (cam açıkken 0.16) ve panelin kendisi (0.55).
if glass then
    local namespaces = {
        "quickshell-settings", "quickshell-theme", "quickshell-launcher",
        "quickshell-clipboard", "quickshell-calendar", "quickshell-wallpaper",
        "quickshell-switcher", "quickshell-notepreview", "quickshell-controlcenter",
        "quickshell",
    }
    for _, ns in ipairs(namespaces) do
        hl.layer_rule({
            name = "qs-glass-" .. ns,
            match = { namespace = "^" .. ns .. "$" },
            blur = true,
            ignore_alpha = 0.35,
        })
    end
end
