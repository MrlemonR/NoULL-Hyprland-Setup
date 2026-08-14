import QtQuick

// One spectrum strip. Two of these sit either side of the workspaces, the
// right-hand one mirrored so the pair reads outward from the centre.
Item {
    id: root

    property bool mirrored: false

    readonly property int barWidth: 3
    readonly property int gap: 2

    visible: BarSettings.enabled("cava") && CavaService.available

    implicitWidth: root.visible
        ? CavaService.barCount * root.barWidth + (CavaService.barCount - 1) * root.gap
        : 0
    implicitHeight: 16

    Row {
        anchors.fill: parent
        spacing: root.gap
        layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight

        Repeater {
            model: CavaService.barCount

            delegate: Item {
                id: column

                required property int index

                width: root.barWidth
                height: root.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: Theme.radiusUpTo(root.barWidth)

                    // 2px floor so the strip stays a strip in silence instead
                    // of vanishing and shifting the workspaces sideways.
                    height: Math.max(2, (CavaService.levels[column.index] || 0) / 100 * root.height)

                    color: Theme.mauve
                    opacity: 0.55 + (CavaService.levels[column.index] || 0) / 100 * 0.45

                    // cava already smooths; this only takes the edge off the
                    // step between frames at 30fps.
                    Behavior on height {
                        NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }
}
