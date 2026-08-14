import QtQuick

// A heading inside a settings page. Not `selectable`, so the keyboard cursor
// steps straight over it — Down should never land somewhere Enter does nothing.
Item {
    id: root

    property string label: ""

    height: 30

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: root.label
        color: Theme.overlay0
        font.pixelSize: 10
        font.bold: true
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        height: 1
        color: Theme.divider
        opacity: 0.6
    }
}
