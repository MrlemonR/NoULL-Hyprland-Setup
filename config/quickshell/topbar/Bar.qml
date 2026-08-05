import Quickshell
import QtQuick

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 30
    color: Theme.base

    Item {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        LeftSection {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        CenterSection {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            screenName: bar.screen ? bar.screen.name : ""
        }

        RightSection {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
