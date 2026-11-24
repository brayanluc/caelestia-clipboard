pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.clipboard

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            screenState.launcher = false;
            screenState.session = false;
            implicitHeight = Qt.binding(() => content.implicitHeight);
        } else {
            implicitHeight = implicitHeight;
        }
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 632
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Connections {
        target: root.screenState

        function onLauncherChanged(): void {
            if (root.screenState.launcher)
                root.screenState.clipboard = false;
        }

        function onSessionChanged(): void {
            if (root.screenState.session)
                root.screenState.clipboard = false;
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
            maxHeight: root.maxHeight
        }
    }
}
