import QtQuick
import Quickshell

// Bildirim merkezi — zil ikonuna sol tıklayınca ekranın sağında açılır.
// Colours and corner radius both come from Theme; the standard themes resolve
// the radius to 0, a custom theme rounds it.
PopupWindow {
    id: root

    // The window under the panel must not paint: a PopupWindow defaults to an
    // opaque background, so a rounded Rectangle inside it sits on a square
    // fill and the corners read as sharp. Every PanelWindow here already
    // does this; the three popups were the ones that never needed it while
    // every corner was square anyway.
    color: "transparent"

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
