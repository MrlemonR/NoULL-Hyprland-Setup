import QtQuick
import Quickshell

// Bildirim merkezinin görsel gövdesi. PopupWindow'dan ayrı tutuldu ki
// hem panelde hem de tek başına test edilebilsin.
//
// İki sayfası var ve aralarında geçiş yapıyor (takvimdeki ay ızgarası ↔ not
// düzenleyici gibi): liste ve inceleme. Listede bir bildirime tıklayınca
// inceleme sayfası açılıyor — başlık ve gövde orada kırpılmadan, uzunsa
// kaydırılarak okunabiliyor.
Item {
    id: root

    readonly property int maxListHeight: 460

    // Panel açılırken okunmamış olanları not ediyoruz: rozet hemen sıfırlansa da
    // listede hangilerinin yeni olduğu görünmeye devam etsin.
    property int unreadMarkId: 0

    // İncelenen bildirimin KOPYASI; null ise liste sayfası açık.
    // Kopya tutuyoruz çünkü dunst geçmişi 2 saniyede bir yeniden okunuyor;
    // kimliğe bakıp her seferinde listeden arasaydık, kayıt geçmişten
    // düştüğü anda okunan mesaj gözden kaybolurdu.
    property var detail: null

    // "Copy" düğmesinin kısa geri bildirimi
    property bool copied: false

    implicitWidth: 400
    implicitHeight: header.height + root.bodyHeight + 2

    readonly property int bodyHeight: root.detail ? detailPage.pageHeight : listPage.pageHeight

    Behavior on implicitHeight {
        NumberAnimation { duration: 170; easing.type: Easing.OutQuad }
    }

    function handleOpen() {
        root.showList();
        root.unreadMarkId = NotificationService.lastSeenId;
        NotificationService.refresh();
        NotificationService.markAllRead();
    }

    function showDetail(entry) {
        root.copied = false;
        root.detail = entry;
    }

    function showList() {
        root.copied = false;
        root.detail = null;
    }

    function dismissDetail() {
        if (root.detail)
            NotificationService.dismiss(root.detail.id);
        root.showList();
    }

    // Başlık + gövdeyi panoya al. Bildirimlerde tıklanacak bir eylem
    // olmadığı için "tam mesajı görmek" genelde onu bir yere yapıştırmak
    // demek oluyor.
    function copyDetail() {
        if (!root.detail)
            return;

        const parts = [];
        if (root.detail.summary)
            parts.push(root.detail.summary);
        if (root.detail.body)
            parts.push(root.detail.body);

        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", parts.join("\n\n")]);
        root.copied = true;
        copiedTimer.restart();
    }

    // dunst monotonik saat kullanıyor; elimizde göreli zamandan başkası yok
    function detailAge() {
        if (!root.detail)
            return "";
        const t = NotificationService.relativeTime(root.detail.timestamp);
        return t === "now" ? "just now" : t + " ago";
    }

    Timer {
        id: copiedTimer

        interval: 1400
        repeat: false
        onTriggered: root.copied = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.base
        border.color: Theme.surface0
        border.width: 1

        // ---------------- Başlık ----------------
        // İki sayfanın başlığı aynı şeridi paylaşıyor, birbirine soluyor.
        Item {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 46

            // --- Liste başlığı: zil + rahatsız etme anahtarı ---
            Item {
                id: listHeader

                anchors.fill: parent
                opacity: root.detail ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                }

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
            }

            // --- İnceleme başlığı: geri + kopyala + kapat ---
            Item {
                id: detailHeader

                anchors.fill: parent
                opacity: root.detail ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                }

                Rectangle {
                    id: backButton

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: backRow.implicitWidth + 18
                    height: 26
                    radius: 0
                    color: backArea.containsMouse ? Theme.surface0 : "transparent"

                    Row {
                        id: backRow

                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "‹"
                            color: backArea.containsMouse ? Theme.mauve : Theme.text
                            font.pixelSize: 17
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Back"
                            color: backArea.containsMouse ? Theme.mauve : Theme.text
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: backArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showList()
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: copyText.implicitWidth + 16
                        height: 22
                        radius: 0
                        color: copyArea.containsMouse ? Theme.surface0 : "transparent"

                        Text {
                            id: copyText

                            anchors.centerIn: parent
                            text: root.copied ? "Copied" : "Copy"
                            color: root.copied ? Theme.green : (copyArea.containsMouse ? Theme.text : Theme.subtext0)
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: copyArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyDetail()
                        }
                    }

                    Rectangle {
                        width: dismissText.implicitWidth + 16
                        height: 22
                        radius: 0
                        color: dismissArea.containsMouse ? Theme.surface0 : "transparent"

                        Text {
                            id: dismissText

                            anchors.centerIn: parent
                            text: "Dismiss"
                            color: dismissArea.containsMouse ? Theme.red : Theme.subtext0
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: dismissArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismissDetail()
                        }
                    }
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

        // ---------------- Liste sayfası ----------------
        Item {
            id: listPage

            readonly property int pageHeight: subHeader.height + listArea.height

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: listPage.pageHeight

            opacity: root.detail ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
            }

            // ---------------- Sayaç + hepsini temizle ----------------
            Item {
                id: subHeader

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
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

                        // Satıra tıklamak inceleme sayfasını açıyor. Kapat düğmesi
                        // bunun üstünde duruyor (sonra tanımlı), tıklaması ona gidiyor.
                        MouseArea {
                            id: itemArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showDetail(item.modelData)
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

        // ---------------- İnceleme sayfası ----------------
        Item {
            id: detailPage

            // Kısa mesajda panel gereksiz büyümesin, uzun mesajda da taşmasın:
            // aradaki her şeyi içerik belirliyor, sonra kaydırma devralıyor.
            readonly property int pageHeight: Math.max(120,
                Math.min(root.maxListHeight + 32, detailColumn.implicitHeight + 28))

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: detailPage.pageHeight

            opacity: root.detail ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
            }

            Flickable {
                id: detailFlick

                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                clip: true
                contentHeight: detailColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: detailColumn

                    width: detailFlick.width
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 12

                        Item {
                            id: detailIconBox

                            width: 36
                            height: 36

                            Image {
                                id: detailIcon

                                anchors.fill: parent
                                sourceSize.width: 72
                                sourceSize.height: 72
                                source: root.detail ? NotificationService.iconSource(root.detail.icon) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                mipmap: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !detailIcon.visible
                                text: "󰂚"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 20
                                color: Theme.surface2
                            }
                        }

                        Column {
                            width: parent.width - detailIconBox.width - 12
                            spacing: 4

                            // Listede kırpılan başlık burada tam hâliyle sarılıyor
                            Text {
                                width: parent.width
                                text: root.detail ? (root.detail.summary || "(no title)") : ""
                                color: Theme.text
                                font.pixelSize: 14
                                font.bold: true
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                width: parent.width
                                text: {
                                    const app = root.detail ? root.detail.appname : "";
                                    // Proxy yüzünden uygulama adı hep "DunstProxy" geliyor
                                    if (app && app.length > 0 && app !== "DunstProxy")
                                        return app + "  ·  " + root.detailAge();
                                    return root.detailAge();
                                }
                                color: Theme.overlay0
                                font.pixelSize: 11
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.divider
                        visible: detailBody.visible
                    }

                    // Asıl mesaj: satır sınırı yok, uzunsa Flickable kaydırıyor
                    Text {
                        id: detailBody

                        width: parent.width
                        text: root.detail ? root.detail.body : ""
                        color: Theme.subtext1
                        font.pixelSize: 13
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        visible: text.length > 0
                    }

                    Text {
                        width: parent.width
                        visible: !detailBody.visible
                        text: "This notification has no message body."
                        color: Theme.surface2
                        font.pixelSize: 12
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // İnce kaydırma göstergesi — listedekiyle aynı
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 3
                width: 3
                radius: 0
                color: Theme.surface1
                visible: detailFlick.contentHeight > detailFlick.height
                height: detailFlick.height * (detailFlick.height / Math.max(1, detailFlick.contentHeight))
                y: detailFlick.contentHeight > 0
                    ? detailFlick.y + (detailFlick.contentY / detailFlick.contentHeight) * detailFlick.height
                    : 0
            }
        }
    }
}
