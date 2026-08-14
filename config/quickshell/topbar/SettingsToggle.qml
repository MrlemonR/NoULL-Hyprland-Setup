import QtQuick

// One on/off row. The switch moves on click and lets the file confirm it —
// qs-settings shells out to hyprctl and a switch that lags behind the click
// reads as broken (the same reason SettingsService writes optimistically).
Rectangle {
    id: root

    property string label: ""
    property string caption: ""
    property bool checked: false

    // Keyboard navigation: the window walks its rows by these.
    readonly property bool selectable: true
    readonly property string kind: "toggle"
    property int rowIndex: -1

    property bool selected: false

    signal toggled()

    height: 44
    radius: Theme.radius
    color: root.selected ? Theme.selected : (area.containsMouse ? Theme.hover : "transparent")

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            text: root.label
            color: Theme.text
            font.pixelSize: 13
        }

        Text {
            text: root.caption
            color: Theme.overlay0
            font.pixelSize: 10
            visible: root.caption.length > 0
        }
    }

    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 18
        // A switch is a pill or it is a box — there is no useful middle. Any
        // theme that rounds anything gets the full pill here rather than the
        // shared radius, which at 6 on an 18px track just looked unfinished.
        radius: Theme.radius > 0 ? height / 2 : 0
        color: root.checked ? Theme.mauve : Theme.surface1

        Behavior on color {
            ColorAnimation { duration: 140 }
        }

        Rectangle {
            width: 12
            height: 12
            radius: Theme.radius > 0 ? height / 2 : 0
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            // Reads against the track whichever way the palette runs.
            color: root.checked ? Theme.textOn(Theme.mauve) : Theme.subtext0

            Behavior on x {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
