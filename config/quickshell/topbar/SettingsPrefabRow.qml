import QtQuick

// One theme in the prefab list.
//
// Every theme is listed, but only the ACTIVE one can be pressed: the values a
// prefab stores are the live ones, so saving them under another theme's name
// would record a look that theme never had. The others are shown anyway —
// greyed, with whether they already hold a prefab — because the point of the
// page is seeing which themes are set up and which are not.
Item {
    id: root

    property string themeName: ""
    property string label: ""
    property bool isActive: false
    property bool hasPrefab: false
    property bool expanded: false
    property bool selected: false

    // Keyboard navigation, same contract as the other rows.
    readonly property bool selectable: true
    readonly property string kind: "toggle"
    property int rowIndex: -1

    signal toggled()
    signal saveRequested()
    signal clearRequested()

    width: parent ? parent.width : 0
    height: 44 + (root.expanded ? actions.height + 8 : 0)

    Behavior on height {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    ButtonSurface {
        id: surface

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44
        hovered: area.containsMouse && root.isActive
        selected: root.selected
        restingColor: "transparent"
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 8
        text: root.label
        color: root.isActive ? Theme.text : Theme.overlay0
        font.pixelSize: 13
        font.bold: root.isActive
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 25
        text: {
            if (root.isActive)
                return root.hasPrefab ? "active — saved" : "active — not saved yet"
            return root.hasPrefab ? "saved" : "not saved"
        }
        color: Theme.overlay0
        font.pixelSize: 10
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 14
        text: root.isActive ? (root.expanded ? "⌄" : "›") : "󰌾"
        color: root.isActive ? Theme.mauve : Theme.surface2
        font.family: Theme.fontMono
        font.pixelSize: 14
    }

    MouseArea {
        id: area

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44
        hoverEnabled: true
        enabled: root.isActive
        cursorShape: root.isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled()
    }

    // Save / Reset, revealed under the row rather than in a dialog: the two
    // choices belong to the row that opened them.
    Row {
        id: actions

        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 48
        spacing: 8
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        ButtonSurface {
            width: saveLabel.implicitWidth + 24
            height: 26
            hovered: saveArea.containsMouse
            restingColor: Theme.surface0
            accentColor: Theme.green

            Text {
                id: saveLabel

                anchors.centerIn: parent
                text: "Save settings"
                color: saveArea.containsMouse ? Theme.textOn(Theme.surface0) : Theme.text
                font.pixelSize: 11
            }

            MouseArea {
                id: saveArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.saveRequested()
            }
        }

        ButtonSurface {
            width: clearLabel.implicitWidth + 24
            height: 26
            hovered: clearArea.containsMouse
            restingColor: Theme.surface0
            accentColor: Theme.red

            Text {
                id: clearLabel

                anchors.centerIn: parent
                text: "Reset"
                color: clearArea.containsMouse ? Theme.red : Theme.subtext0
                font.pixelSize: 11
            }

            MouseArea {
                id: clearArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearRequested()
            }
        }
    }
}
