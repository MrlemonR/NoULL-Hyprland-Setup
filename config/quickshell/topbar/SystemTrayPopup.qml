import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

PopupWindow {
    id: root

    // The window under the panel must not paint: a PopupWindow defaults to an
    // opaque background, so a rounded Rectangle inside it sits on a square
    // fill and the corners read as sharp. Every PanelWindow here already
    // does this; the three popups were the ones that never needed it while
    // every corner was square anyway.
    color: "transparent"

    // Dışarı tıklayınca popup otomatik kapansın
    grabFocus: true

    implicitWidth: Math.max(trayRow.implicitWidth + 16, 40)
    implicitHeight: trayRow.implicitHeight + 16

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPanel

        // Aero sheen. Inert on the standard themes — Theme.gloss is 0 — and
        // declared first so it sits under the content rather than over it.
        GlossOverlay {
            anchors.fill: parent
            radius: parent.radius
            midline: 0.3
        }
        color: Theme.panelColor

        Row {
            id: trayRow
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    id: trayItem
                    required property var modelData

                    width: 16
                    height: 16

                    Image {
                        anchors.fill: parent
                        source: trayItem.modelData.icon
                        smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                // Sol tık: programı aç / öne getir
                                trayItem.modelData.activate()
                            } else if (mouse.button === Qt.RightButton) {
                                // Sağ tık: uygulamanın kendi native menüsünü tıklanan
                                // noktada göster (Göster/Gizle, Çıkış vb.)
                                if (trayItem.modelData.hasMenu)
                                    trayItem.modelData.display(root, mouse.x, mouse.y)
                                else
                                    trayItem.modelData.secondaryActivate()
                            }
                        }
                    }
                }
            }
        }
    }
}
