import QtQuick
import Quickshell

// İki sayfalı takvim: ay ızgarası ve not ekranı.
// Bir güne tıklayınca kutu büyüyüp not ekranına dönüşüyor, geri butonu
// aynı animasyonla takvime döndürüyor.
Item {
    id: root

    // Görüntülenen ay
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    // 0 = gün ızgarası, 1 = ay seçici, 2 = yıl seçici
    property int mode: 0

    // Seçili gün ("" ise takvim sayfası açık)
    property string selectedKey: ""

    readonly property bool editing: selectedKey.length > 0

    readonly property int calendarWidth: 322
    readonly property int calendarHeight: 348
    readonly property int editorWidth: 620
    readonly property int editorHeight: 372

    readonly property int maxWidth: Math.max(calendarWidth, editorWidth)
    readonly property int maxHeight: Math.max(calendarHeight, editorHeight)

    readonly property string todayKey: CalendarService.dateKey(new Date())

    // Resim seçici açıkken pencere kapanmasın
    readonly property bool busy: editorPage.busy

    // Sağ tık ile toplu silme onayı: { label, count, scope, arg1, arg2 }
    property var pendingDelete: null

    function askDeleteDate(key) {
        const count = CalendarService.countForDate(key)
        if (count === 0)
            return
        root.pendingDelete = {
            label: Qt.formatDate(CalendarService.keyToDate(key), "d MMMM yyyy"),
            count: count,
            scope: "date",
            arg1: key,
            arg2: 0
        }
    }

    function askDeleteMonth(year, month) {
        const count = CalendarService.countForMonth(year, month)
        if (count === 0)
            return
        root.pendingDelete = {
            label: Qt.formatDate(new Date(year, month, 1), "MMMM yyyy"),
            count: count,
            scope: "month",
            arg1: year,
            arg2: month
        }
    }

    function askDeleteYear(year) {
        const count = CalendarService.countForYear(year)
        if (count === 0)
            return
        root.pendingDelete = {
            label: String(year),
            count: count,
            scope: "year",
            arg1: year,
            arg2: 0
        }
    }

    function confirmDelete() {
        const p = root.pendingDelete
        if (!p)
            return

        if (p.scope === "date")
            CalendarService.removeDate(p.arg1)
        else if (p.scope === "month")
            CalendarService.removeMonth(p.arg1, p.arg2)
        else if (p.scope === "year")
            CalendarService.removeYear(p.arg1)

        root.pendingDelete = null
    }

    implicitWidth: editing ? editorWidth : calendarWidth
    implicitHeight: editing ? editorHeight : calendarHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    function openDay(date) {
        const key = CalendarService.dateKey(date)
        root.viewYear = date.getFullYear()
        root.viewMonth = date.getMonth()

        // Bugüne tıklandıysa şu anki saatten başla
        const now = new Date()
        const isToday = key === root.todayKey
        editorPage.reset(key, isToday ? now.getHours() : 9, isToday ? now.getMinutes() : 0)

        root.selectedKey = key
        editorFocusTimer.restart()
    }

    function closeDay() {
        root.selectedKey = ""
    }

    function startPicker() {
        editorPage.startPicker()
    }

    function shiftMonth(delta) {
        let m = root.viewMonth + delta
        let y = root.viewYear
        while (m < 0) {
            m += 12
            y -= 1
        }
        while (m > 11) {
            m -= 12
            y += 1
        }
        root.viewMonth = m
        root.viewYear = y
    }

    function goToday() {
        const now = new Date()
        root.viewYear = now.getFullYear()
        root.viewMonth = now.getMonth()
        root.mode = 0
    }

    // Sayfa geçiş animasyonu bitmeden odak vermek işe yaramıyor
    Timer {
        id: editorFocusTimer

        interval: 220
        repeat: false
        onTriggered: editorPage.focusText()
    }

    // 6 satır x 7 sütun, pazartesi başlangıçlı
    readonly property var gridCells: {
        const first = new Date(root.viewYear, root.viewMonth, 1)
        const offset = (first.getDay() + 6) % 7
        const daysInMonth = new Date(root.viewYear, root.viewMonth + 1, 0).getDate()
        const daysInPrev = new Date(root.viewYear, root.viewMonth, 0).getDate()

        const cells = []
        for (let i = 0; i < 42; i++) {
            const dayIndex = i - offset + 1
            let date
            if (dayIndex < 1)
                date = new Date(root.viewYear, root.viewMonth - 1, daysInPrev + dayIndex)
            else if (dayIndex > daysInMonth)
                date = new Date(root.viewYear, root.viewMonth + 1, dayIndex - daysInMonth)
            else
                date = new Date(root.viewYear, root.viewMonth, dayIndex)

            cells.push({
                date: date,
                day: date.getDate(),
                key: CalendarService.dateKey(date),
                inMonth: dayIndex >= 1 && dayIndex <= daysInMonth
            })
        }
        return cells
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.panelColor
        border.color: Theme.surface0
        border.width: Theme.borderWidth
        radius: Theme.radiusPanel

        // Aero sheen. Inert on the standard themes — Theme.gloss is 0 — and
        // declared first so it sits under the content rather than over it.
        GlossOverlay {
            anchors.fill: parent
            radius: parent.radius
            midline: 0.3
        }
        clip: true

        // ================= Sayfa 1: ay ızgarası =================
        Item {
            id: calendarPage

            width: root.calendarWidth - 2
            height: root.calendarHeight - 2
            x: 1 + (root.editing ? -40 : 0)
            y: 1

            opacity: root.editing ? 0 : 1
            visible: opacity > 0

            Behavior on x {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            // ---- Başlık ----
            Item {
                id: calHeader

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 40

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 24
                    color: prevArea.containsMouse ? Theme.surface0 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Theme.text
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: prevArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.mode === 0)
                                root.shiftMonth(-1)
                            else if (root.mode === 1)
                                root.viewYear -= 1
                            else
                                root.viewYear -= 12
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: titleText.implicitWidth + 18
                    height: 24
                    color: titleArea.containsMouse ? Theme.surface0 : "transparent"

                    Text {
                        id: titleText

                        anchors.centerIn: parent
                        text: {
                            if (root.mode === 0)
                                return Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                            if (root.mode === 1)
                                return String(root.viewYear)
                            const start = root.viewYear - (root.viewYear % 12)
                            return start + " – " + (start + 11)
                        }
                        color: Theme.text
                        font.pixelSize: 14
                        font.bold: true
                    }

                    MouseArea {
                        id: titleArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                // Gün → ay → yıl seçici arasında dolaş
                                root.mode = (root.mode + 1) % 3
                                return
                            }

                            // Sağ tık: başlığın gösterdiği aralığın notlarını sil
                            if (root.mode === 0)
                                root.askDeleteMonth(root.viewYear, root.viewMonth)
                            else
                                root.askDeleteYear(root.viewYear)
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 24
                    color: nextArea.containsMouse ? Theme.surface0 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: Theme.text
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: nextArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.mode === 0)
                                root.shiftMonth(1)
                            else if (root.mode === 1)
                                root.viewYear += 1
                            else
                                root.viewYear += 12
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

            // ---- Gün ızgarası ----
            Item {
                id: dayGrid

                anchors.top: calHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                height: 268
                visible: root.mode === 0

                Row {
                    id: weekRow

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        delegate: Item {
                            required property string modelData
                            required property int index

                            width: 43
                            height: 22

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: parent.index >= 5 ? Theme.red : Theme.overlay0
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }

                Grid {
                    anchors.top: weekRow.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7
                    spacing: 0

                    Repeater {
                        model: root.gridCells

                        delegate: Rectangle {
                            id: cell

                            required property var modelData

                            readonly property bool isToday: modelData.key === root.todayKey
                            readonly property int noteCount: CalendarService.countForDate(modelData.key)

                            width: 43
                            height: 38
                            radius: Theme.radius
                            color: cellArea.containsMouse ? Theme.surface0 : "transparent"
                            border.width: cell.isToday ? 1 : 0
                            border.color: Theme.blue

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -3
                                text: cell.modelData.day
                                font.pixelSize: 13
                                font.bold: cell.isToday
                                color: {
                                    if (!cell.modelData.inMonth)
                                        return Theme.surface1
                                    if (cell.isToday)
                                        return Theme.blue
                                    return Theme.text
                                }
                            }

                            // Not göstergesi
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                width: 4
                                height: 4
                                radius: Theme.radiusUpTo(4)
                                visible: cell.noteCount > 0
                                color: Theme.yellow
                            }

                            MouseArea {
                                id: cellArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton)
                                        root.openDay(cell.modelData.date)
                                    else
                                        root.askDeleteDate(cell.modelData.key)
                                }
                            }
                        }
                    }
                }
            }

            // ---- Ay seçici ----
            Grid {
                anchors.top: calHeader.bottom
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                spacing: 6
                visible: root.mode === 1

                Repeater {
                    model: 12

                    delegate: Rectangle {
                        id: monthCell

                        required property int index

                        width: 96
                        height: 44
                        color: {
                            if (monthCell.index === root.viewMonth)
                                return Theme.mauve
                            return monthArea.containsMouse ? Theme.surface0 : "transparent"
                        }
                        border.width: Theme.borderWidth
                        border.color: Theme.surface0

                        Text {
                            anchors.centerIn: parent
                            text: Qt.formatDate(new Date(root.viewYear, monthCell.index, 1), "MMM")
                            color: monthCell.index === root.viewMonth ? Theme.base : Theme.text
                            font.pixelSize: 13
                            font.bold: monthCell.index === root.viewMonth
                        }

                        MouseArea {
                            id: monthArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.askDeleteMonth(root.viewYear, monthCell.index)
                                    return
                                }
                                root.viewMonth = monthCell.index
                                root.mode = 0
                            }
                        }
                    }
                }
            }

            // ---- Yıl seçici ----
            Grid {
                anchors.top: calHeader.bottom
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                spacing: 6
                visible: root.mode === 2

                Repeater {
                    model: 12

                    delegate: Rectangle {
                        id: yearCell

                        required property int index

                        readonly property int year: root.viewYear - (root.viewYear % 12) + yearCell.index

                        width: 96
                        height: 44
                        color: {
                            if (yearCell.year === root.viewYear)
                                return Theme.mauve
                            return yearArea.containsMouse ? Theme.surface0 : "transparent"
                        }
                        border.width: Theme.borderWidth
                        border.color: Theme.surface0

                        Text {
                            anchors.centerIn: parent
                            text: yearCell.year
                            color: yearCell.year === root.viewYear ? Theme.base : Theme.text
                            font.pixelSize: 13
                            font.bold: yearCell.year === root.viewYear
                        }

                        MouseArea {
                            id: yearArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.askDeleteYear(yearCell.year)
                                    return
                                }
                                root.viewYear = yearCell.year
                                root.mode = 1
                            }
                        }
                    }
                }
            }

            // ---- Alt satır ----
            Item {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.surface0
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
                    color: Theme.overlay0
                    font.pixelSize: 11
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: todayText.implicitWidth + 14
                    height: 20
                    color: todayArea.containsMouse ? Theme.surface0 : "transparent"

                    Text {
                        id: todayText

                        anchors.centerIn: parent
                        text: "Today"
                        color: todayArea.containsMouse ? Theme.blue : Theme.subtext0
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: todayArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToday()
                    }
                }
            }
        }

        // ================= Toplu silme onayı =================
        Rectangle {
            id: deleteConfirm

            anchors.fill: parent
            color: Theme.base
            opacity: root.pendingDelete !== null ? 0.97 : 0
            visible: opacity > 0
            z: 20

            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            // Alttaki takvime tıklama sızmasın
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰀦"
                    font.family: Theme.fontMono
                    font.weight: Theme.fontWeight
                    font.pixelSize: 26
                    color: Theme.red
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.pendingDelete
                        ? "Delete all notes in " + root.pendingDelete.label + "?"
                        : ""
                    color: Theme.text
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.pendingDelete
                        ? (root.pendingDelete.count === 1
                            ? "1 note will be removed. This cannot be undone."
                            : root.pendingDelete.count + " notes will be removed. This cannot be undone.")
                        : ""
                    color: Theme.overlay0
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: parent.width
                    height: 12
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Rectangle {
                        width: cancelText.implicitWidth + 24
                        height: 28
                        color: cancelArea.containsMouse ? Theme.surface0 : "transparent"
                        border.width: Theme.borderWidth
                        border.color: Theme.surface1

                        Text {
                            id: cancelText

                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.text
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: cancelArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pendingDelete = null
                        }
                    }

                    Rectangle {
                        width: confirmText.implicitWidth + 24
                        height: 28
                        color: confirmArea.containsMouse ? Theme.red : Theme.dangerBg
                        border.width: Theme.borderWidth
                        border.color: Theme.red

                        Text {
                            id: confirmText

                            anchors.centerIn: parent
                            text: "Delete"
                            color: confirmArea.containsMouse ? Theme.base : Theme.red
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            id: confirmArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.confirmDelete()
                        }
                    }
                }
            }
        }

        // ================= Sayfa 2: not ekranı =================
        NoteEditor {
            id: editorPage

            width: root.editorWidth - 2
            height: root.editorHeight - 2
            x: 1 + (root.editing ? 0 : 40)
            y: 1

            opacity: root.editing ? 1 : 0
            visible: opacity > 0

            Behavior on x {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            onBack: root.closeDay()
        }
    }
}
