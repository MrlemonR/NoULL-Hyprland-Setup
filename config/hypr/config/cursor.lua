-- Fare imleci.
--
-- Bu blok olmadan her şey Hyprland'in varsayılanlarına kalıyordu ve
-- varsayılanlar makineye/sürücüye göre değiştiği için temiz kurulumda imleç
-- hareketsiz kalınca kayboluyordu. Üç şeyi açıkça sabitliyoruz:
--
--   * inactive_timeout = 0  -> imleç hiçbir zaman kendiliğinden gizlenmesin.
--   * no_hardware_cursors   -> NVIDIA'da (bu makinede RTX 5060) donanım
--     imleç düzlemi Wayland'de sık sık boş kalıyor; imleç yazılımla çizilince
--     sorun tamamen gidiyor. Maliyeti ihmal edilebilir.
--   * enable_hyprcursor = false -> environment.lua breeze_cursors diyor ama
--     breeze YALNIZCA XCursor formatında geliyor, hyprcursor sürümü yok.
--     Açık bırakılırsa Hyprland önce olmayan hyprcursor temasını arıyor.
--
-- no_warps BİLEREK burada değil (yani false / Hyprland varsayılanı): Super+ok
-- ile yön bazlı odak değiştirince farenin de yeni pencereye gitmesi isteniyor
-- — bu, no_warps kapalıyken Hyprland'in zaten yaptığı şey. Alt+Tab'de ise
-- fare yerinde kalmalı; o TEK yol için genel ayarı değiştirmek yerine
-- WindowSwitcherWindow.qml odaklanmadan önceki imleç konumunu kaydedip
-- sonra geri koyuyor (bkz. qs-focus-keep-cursor).
--
-- İmleç teması ve boyutu environment.lua'da (XCURSOR_THEME / XCURSOR_SIZE).

hl.config({
    cursor = {
        inactive_timeout = 0,
        no_hardware_cursors = true,
        enable_hyprcursor = false,
        hide_on_key_press = false,
        hide_on_touch = false,
    },
})
