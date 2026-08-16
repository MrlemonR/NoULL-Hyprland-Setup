//@ pragma UseQApplication

import Quickshell
import QtQuick

ShellRoot {
    Bar {}

    // Başlatıcı iskeleti — "quickshell ipc call launcher toggle" ile açılıyor
    LauncherWindow {}

    // Hatırlatma bildirimindeki "Önizle" bunu açıyor
    NotePreviewWindow {}

    // Pano geçmişi (Super+V)
    ClipboardWindow {}

    // Duvar kağıdı seçici (Super+Shift+Z)
    WallpaperWindow {}

    // Duvar kağıdı değişim animasyonu
    WallpaperTransition {}

    // Tema seçici (Super+Ctrl+Z)
    ThemeWindow {}


    SettingsWindow {}
    // Ekran görüntüsü arayüzü (Super+Shift+S)
    ScreenshotWindow {}

    // Alt+Tab pencere anahtarlayıcısı
    WindowSwitcherWindow {}
    WorkspaceOverview {}
}




