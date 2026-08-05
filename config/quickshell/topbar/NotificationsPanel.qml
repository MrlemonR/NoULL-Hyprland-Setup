import QtQuick
import Quickshell

// Bildirim merkezinin görsel gövdesi. PopupWindow'dan ayrı tutuldu ki
// hem panelde hem de tek başına test edilebilsin.
Item {
    id: root

    readonly property int maxListHeight: 460

    // Panel açılırken okunmamış olanları not ediyoruz: rozet hemen sıfırlansa da
    // listede hangilerinin yeni olduğu görünmeye devam etsin.
    property int unreadMarkId: 0

    implicitWidth: 400
    implicitHeight: header.height + subHeader.height + listArea.height + 2

    function handleOpen() {
        root.unreadMarkId = NotificationService.lastSeenId;
        NotificationService.refresh();
        NotificationService.markAllRead();
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.base
        border.color: Theme.surface0
        border.width: 1

        // ---------------- Başlık: zil + rahatsız etme anahtarı ----------------
        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 46

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NotificationService.dnd ? "󰂛" : "󰂚"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: NotificationService.dnd ? Theme.overlay0 : Theme.mauve
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.text
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            // Rahatsız etme anahtarı
            Row {
                id: dndToggle

                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Do not disturb"
                    color: NotificationService.dnd ? Theme.mauve : Theme.subtext0
                    font.pixelSize: 12
                }

                Rectangle {
                    id: dndTrack

                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 18
                    radius: 0
                    color: NotificationService.dnd ? Theme.mauve : Theme.surface1
                    border.width: 1
                    border.color: NotificationService.dnd ? Theme.mauve : Theme.surface2

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 0
                        y: 3
                        x: NotificationService.dnd ? dndTrack.width - width - 3 : 3
                        color: NotificationService.dnd ? Theme.base : Theme.text

                        Behavior on x {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: dndToggle
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.toggleDnd()
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.surface0
            }
        }

        // ---------------- Sayaç + hepsini temizle ----------------
        Item {
            id: subHeader

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            anchors.topMargin: 0
            height: 32

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: NotificationService.notifications.length + (NotificationService.notifications.length === 1 ? " notification" : " notifications")
                color: Theme.overlay0
                font.pixelSize: 11
            }

            Rectangle {
                id: clearButton

                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: clearText.implicitWidth + 14
                height: 20
                radius: 0
                color: clearArea.containsMouse ? Theme.surface0 : "transparent"
                visible: NotificationService.notifications.length > 0

                Text {
                    id: clearText

                    anchors.centerIn: parent
                    text: "Clear all"
                    color: clearArea.containsMouse ? Theme.red : Theme.subtext0
                    font.pixelSize: 11
                }

                MouseArea {
                    id: clearArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationService.clearAll()
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.surface0
            }
        }

        // ---------------- Liste ----------------
        Item {
            id: listArea

            anchors.top: subHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            anchors.topMargin: 0
            height: NotificationService.notifications.length === 0 ? 90 : Math.min(root.maxListHeight, list.contentHeight)

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: NotificationService.notifications

                delegate: Rectangle {
                    id: item

                    required property var modelData

                    readonly property bool unread: item.modelData.id > root.unreadMarkId

                    width: list.width
                    height: Math.max(58, textColumn.implicitHeight + 22)
                    color: itemArea.containsMouse ? Theme.hover : "transparent"

                    // Sol kenarda aciliyet şeridi
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: 2
                        color: NotificationService.urgencyColor(item.modelData.urgency)
                        opacity: item.unread ? 1 : 0.35
                    }

                    MouseArea {
                        id: itemArea

                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Image {
                        id: itemIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 11
                        width: 32
                        height: 32
                        sourceSize.width: 64
                        sourceSize.height: 64
                        source: NotificationService.iconSource(item.modelData.icon)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: itemIcon
                        visible: !itemIcon.visible
                        text: "󰂚"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: Theme.surface2
                    }

                    Column {
                        id: textColumn

                        anchors.left: itemIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        spacing: 3

                        Item {
                            width: parent.width
                            height: summaryText.implicitHeight

                            Text {
                                id: summaryText

                                width: parent.width - 46
                                text: item.modelData.summary || "(no title)"
                                color: Theme.text
                                font.pixelSize: 13
                                font.bold: true
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                            }

                            Text {
                                anchors.right: closeButton.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: summaryText.verticalCenter
                                text: NotificationService.relativeTime(item.modelData.timestamp)
                                color: Theme.surface2
                                font.pixelSize: 10
                            }

                            // Okunmamış noktası
                            Rectangle {
                                id: unreadDot

                                anchors.right: parent.right
                                anchors.verticalCenter: summaryText.verticalCenter
                                width: 6
                                height: 6
                                radius: 0
                                color: Theme.mauve
                                visible: item.unread && !itemArea.containsMouse
                            }

                            // Tek bildirimi kapat
                            Rectangle {
                                id: closeButton

                                anchors.right: parent.right
                                anchors.rightMargin: -2
                                anchors.verticalCenter: summaryText.verticalCenter
                                width: 16
                                height: 16
                                radius: 0
                                color: closeArea.containsMouse ? Theme.red : "transparent"
                                visible: itemArea.containsMouse

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 10
                                    color: closeArea.containsMouse ? Theme.base : Theme.subtext0
                                }

                                MouseArea {
                                    id: closeArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NotificationService.dismiss(item.modelData.id)
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: item.modelData.body
                            color: Theme.subtext0
                            font.pixelSize: 12
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }

                        Text {
                            width: parent.width
                            text: item.modelData.appname
                            color: Theme.surface2
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            // Bildirimler dunst-proxy üzerinden geçtiği için uygulama adı
                            // her zaman "DunstProxy" oluyor; o durumda göstermiyoruz.
                            visible: text.length > 0 && text !== "DunstProxy"
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.divider
                    }
                }
            }

            // İnce kaydırma göstergesi
            Rectangle {
                anchors.right: parent.right
                width: 3
                radius: 0
                color: Theme.surface1
                visible: list.contentHeight > list.height
                height: list.height * (list.height / Math.max(1, list.contentHeight))
                y: list.contentHeight > 0 ? (list.contentY / list.contentHeight) * list.height : 0
            }

            // Boş durum
            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: NotificationService.notifications.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰂜"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 24
                    color: Theme.surface1
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No notifications"
                    color: Theme.surface2
                    font.pixelSize: 12
                }
            }
        }
    }
}
