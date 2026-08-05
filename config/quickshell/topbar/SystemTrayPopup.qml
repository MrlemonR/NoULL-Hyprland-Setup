import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

PopupWindow {
    id: root

    // Dışarı tıklayınca popup otomatik kapansın
    grabFocus: true

    implicitWidth: Math.max(trayRow.implicitWidth + 16, 40)
    implicitHeight: trayRow.implicitHeight + 16

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.base

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
