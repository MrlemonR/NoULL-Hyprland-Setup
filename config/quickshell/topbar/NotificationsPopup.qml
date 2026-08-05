import QtQuick
import Quickshell

// Bildirim merkezi — zil ikonuna sol tıklayınca ekranın sağında açılır.
// Catppuccin Mocha, köşeler keskin (radius: 0).
PopupWindow {
    id: root

    // Dışarı tıklayınca kapansın
    grabFocus: true

    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    onVisibleChanged: {
        if (visible)
            panel.handleOpen();
    }

    // Panel açıkken gelen bildirimler de okundu sayılsın
    Connections {
        target: NotificationService

        function onNotificationsChanged() {
            if (root.visible)
                NotificationService.markAllRead();
        }
    }

    NotificationsPanel {
        id: panel

        anchors.fill: parent
    }
}
