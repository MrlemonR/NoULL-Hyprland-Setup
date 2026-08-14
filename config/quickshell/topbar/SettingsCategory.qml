import QtQuick

// A row on the settings home page. Pressing it turns the panel into that page
// rather than opening a window, so it reads as a door, not a button.
Rectangle {
    id: root

    property string glyph: ""
    property string title: ""
    property string caption: ""

    // Keyboard navigation: the window walks its rows by these.
    readonly property bool selectable: true
    readonly property string kind: "category"
    property int rowIndex: -1
    property string pageId: ""

    property bool selected: false

    signal clicked()

    height: 56
    radius: Theme.radius
    color: root.selected ? Theme.selected : (area.containsMouse ? Theme.surface0 : Theme.hover)

    GlossOverlay {
        anchors.fill: parent
        radius: root.radius
        strength: area.containsMouse ? Theme.gloss : 0
        bounce: false

        Behavior on strength {
            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
        }
    }

    Text {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyph
        color: Theme.mauve
        font.family: Theme.fontMono
        font.pixelSize: 20
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: root.title
            color: Theme.text
            font.pixelSize: 14
            font.bold: true
        }

        Text {
            text: root.caption
            color: Theme.overlay0
            font.pixelSize: 11
            visible: root.caption.length > 0
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        color: Theme.overlay0
        font.family: Theme.fontMono
        font.pixelSize: 16
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
