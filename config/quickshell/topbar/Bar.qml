import Quickshell
import QtQuick

// The bar. Two shapes, chosen by BarSettings:
//
//   stuck     a 30px strip flush against the top edge, square, opaque — what
//             this bar has always been, and still the default
//   floating  the same strip inset by a gap on three sides, with the active
//             theme's corner radius
//
// The **window** is always full width and always claims the whole height
// including the gap, so the exclusive zone keeps windows out from under it
// either way. Only the visible Rectangle moves; nothing here touches
// `exclusiveZone` by hand (gotcha #19).
PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }

    readonly property bool floating: BarSettings.floating
    readonly property int gap: bar.floating ? BarSettings.floatGap : 0
    readonly property int sideGap: bar.floating ? BarSettings.floatSideGap : 0

    implicitHeight: BarSettings.barHeight + bar.gap
    // The window must not paint: when floating, the gap has to show the
    // wallpaper through it, and an opaque window would fill it instead.
    color: "transparent"

    Rectangle {
        id: strip

        anchors.fill: parent
        anchors.topMargin: bar.gap
        anchors.leftMargin: bar.sideGap
        anchors.rightMargin: bar.sideGap

        color: BarSettings.surface
        // Square while stuck to the edge whatever the theme says — a rounded
        // corner against the screen edge reads as a rendering fault, not a
        // choice. Floating is where the radius earns its place.
        radius: bar.floating ? Theme.radiusPanel : 0

        Behavior on anchors.topMargin {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Behavior on color {
            ColorAnimation { duration: 160 }
        }

        // Aero sheen. `bounce` off and a tight midline: at 30px a full-height
        // highlight has nowhere to fall off and just lifts the whole strip.
        // Inert on the standard themes.
        GlossOverlay {
            anchors.fill: parent
            radius: strip.radius
            midline: 0.55
            bounce: false
        }

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
}
