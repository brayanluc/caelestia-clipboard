pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
    id: root

    required property ScreenState screenState
    required property real maxHeight

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge
    readonly property int panelWidth: 600
    readonly property var currentEntry: list.currentItem?.modelData ?? null
    readonly property bool showPreview: currentEntry?.isImage === true

    property bool limitExpanded: false
    property int draftLimit: 100
    property int pendingIndex: -1

    readonly property bool isUnlimited: service.maxHistory === 0
    readonly property int activeSliderValue: sliderDrag.pressed ? draftLimit : (isUnlimited ? service.lastFiniteLimit : service.maxHistory)
    readonly property real sliderRatio: Math.max(0, Math.min(1, (activeSliderValue - 25) / 225))

    implicitWidth: panelWidth + padding * 2
    implicitHeight: previewCard.implicitHeight + (showPreview ? padding : 0) + listArea.implicitHeight + (limitBar.implicitHeight > 0 ? limitBar.implicitHeight + Tokens.spacing.small : 0) + searchRow.height + padding * 3

    Keys.forwardTo: [search]
    Keys.onEscapePressed: {
        if (root.limitExpanded)
            root.limitExpanded = false;
        else
            root.screenState.clipboard = false;
    }

    ClipboardService {
        id: service
        onItemDeleting: id => {
            const currentIdx = list.currentIndex;
            const currentId = root.currentEntry?.id ?? "";
            if (currentIdx < 0)
                return;
            if (id === currentId) {
                root.pendingIndex = currentIdx;
            } else {
                const vals = listModel.values;
                let deletedIdx = -1;
                for (let i = 0; i < vals.length; i++) {
                    if (vals[i].id === id) {
                        deletedIdx = i;
                        break;
                    }
                }
                root.pendingIndex = (deletedIdx !== -1 && deletedIdx < currentIdx) ? currentIdx - 1 : currentIdx;
            }
        }
        onMaxHistoryChanged: {
            if (maxHistory > 0)
                root.draftLimit = maxHistory;
        }
        onLastFiniteLimitChanged: {
            if (!sliderDrag.pressed)
                root.draftLimit = lastFiniteLimit;
        }
    }

    StyledClippingRect {
        id: previewCard

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding

        implicitHeight: root.showPreview ? 210 : 0
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
        visible: implicitHeight > 1
        clip: true

        Behavior on implicitHeight {
            Anim {}
        }

        Image {
            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 580
            sourceSize.height: 200
            source: root.showPreview ? `file://${root.currentEntry.thumbPath}?v=${service.thumbRevision}` : ""
        }

        StyledRect {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.medium
            implicitWidth: badgeText.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: badgeText.implicitHeight + Tokens.padding.small * 2
            radius: height / 2
            color: Colours.tPalette.m3surfaceContainerHighest
            visible: root.showPreview

            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: root.showPreview ? `${root.currentEntry.dimensions} • ${root.currentEntry.size}` : ""
                font: Tokens.font.body.small
            }
        }
    }

    Item {
        id: listArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: limitBar.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: limitBar.implicitHeight > 0 ? Tokens.spacing.small : root.padding

        readonly property int maxVisible: Math.min(7, Math.max(1, list.count))
        implicitHeight: list.count > 0 ? (Tokens.sizes.launcher.itemHeight + list.spacing) * maxVisible - list.spacing : 96

        Behavior on implicitHeight {
            Anim {}
        }

        Behavior on anchors.bottomMargin {
            Anim {}
        }

        StyledListView {
            id: list

            anchors.fill: parent
            spacing: Tokens.spacing.small
            orientation: Qt.Vertical
            clip: true

            preferredHighlightBegin: 0
            preferredHighlightEnd: height
            highlightRangeMode: ListView.ApplyRange
            highlightFollowsCurrentItem: false

            highlight: StyledRect {
                radius: Tokens.rounding.large
                color: Colours.palette.m3onSurface
                opacity: 0.08
                y: list.currentItem?.y ?? 0
                implicitWidth: list.width
                implicitHeight: list.currentItem?.implicitHeight ?? 0

                Behavior on y {
                    Anim {}
                }
            }

            model: ScriptModel {
                id: listModel
                values: service.filter(search.text)
                onValuesChanged: {
                    if (values.length === 0)
                        list.currentIndex = -1;
                    else if (root.pendingIndex >= 0)
                        list.currentIndex = Math.max(0, Math.min(root.pendingIndex, values.length - 1));
                    else
                        list.currentIndex = 0;
                    root.pendingIndex = -1;
                }
            }

            remove: Transition {
                ParallelAnimation {
                    ScriptAction {
                        script: ViewTransition.item.z = -1
                    }
                    Anim {
                        property: "opacity"
                        to: 0
                        type: Anim.DefaultEffects
                    }
                    Anim {
                        property: "scale"
                        to: 0.94
                        type: Anim.DefaultEffects
                    }
                }
            }

            displaced: Transition {
                Anim {
                    properties: "x,y"
                }
            }

            delegate: ClipboardItem {
                required property int index
                screenState: root.screenState
                service: service
                isCurrent: list.currentIndex === index
            }

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small
            visible: list.count === 0

            MaterialIcon {
                text: "content_paste_off"
                color: Colours.palette.m3outline
            }

            StyledText {
                text: search.text ? "No matching entries" : "Clipboard is empty"
                color: Colours.palette.m3outline
            }
        }
    }

    StyledRect {
        id: limitBar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: searchRow.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: implicitHeight > 0 ? Tokens.spacing.small : 0

        implicitHeight: root.limitExpanded ? 46 : 0
        radius: height / 2
        color: Colours.tPalette.m3surfaceContainer
        opacity: root.limitExpanded ? 1 : 0
        visible: implicitHeight > 1
        clip: true

        Behavior on implicitHeight {
            Anim {}
        }

        Behavior on anchors.bottomMargin {
            Anim {}
        }

        Behavior on opacity {
            Anim { type: Anim.DefaultEffects }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            RowLayout {
                id: limitLabelRow
                Layout.preferredWidth: implicitWidth
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: "tune"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.builders.medium.scale(0.95).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: "History limit"
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                id: sliderTrackArea

                Layout.fillWidth: true
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                opacity: root.isUnlimited && !sliderDrag.pressed ? 0.45 : 1.0

                Behavior on opacity {
                    Anim { type: Anim.DefaultEffects }
                }

                StyledRect {
                    id: trackBg
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Colours.tPalette.m3surfaceContainerHighest
                }

                StyledRect {
                    anchors.left: trackBg.left
                    anchors.verticalCenter: trackBg.verticalCenter
                    width: Math.max(6, trackBg.width * root.sliderRatio)
                    height: 6
                    radius: 3
                    color: Colours.palette.m3primary

                    Behavior on width {
                        enabled: !sliderDrag.pressed
                        Anim { type: Anim.DefaultEffects }
                    }
                }

                StyledRect {
                    id: sliderThumb
                    anchors.verticalCenter: trackBg.verticalCenter
                    x: Math.max(0, Math.min(trackBg.width - width, trackBg.width * root.sliderRatio - width / 2))
                    width: sliderDrag.pressed ? 20 : (sliderDrag.containsMouse ? 17 : 14)
                    height: width
                    radius: width / 2
                    color: Colours.palette.m3primary
                    border.width: 2
                    border.color: Colours.tPalette.m3surfaceContainer

                    Behavior on x {
                        enabled: !sliderDrag.pressed
                        Anim { type: Anim.DefaultEffects }
                    }

                    Behavior on width {
                        Anim { type: Anim.DefaultEffects }
                    }
                }

                MouseArea {
                    id: sliderDrag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function valueFromX(mx: real): int {
                        const ratio = Math.max(0, Math.min(1, mx / Math.max(1, width)));
                        const raw = 25 + ratio * 225;
                        return Math.max(25, Math.min(250, Math.round(raw / 5) * 5));
                    }

                    onPressed: mouse => {
                        root.draftLimit = valueFromX(mouse.x);
                    }
                    onPositionChanged: mouse => {
                        if (pressed)
                            root.draftLimit = valueFromX(mouse.x);
                    }
                    onReleased: {
                        service.setMaxHistory(root.draftLimit);
                        search.forceActiveFocus();
                    }
                    onWheel: wheel => {
                        const delta = wheel.angleDelta.y > 0 ? 5 : -5;
                        service.setMaxHistory(root.activeSliderValue + delta);
                    }
                }
            }

            StyledRect {
                id: limitValueBadge

                Layout.preferredWidth: 46
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: root.isUnlimited && !sliderDrag.pressed ? Colours.tPalette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                Behavior on color {
                    CAnim {}
                }

                StyledText {
                    anchors.centerIn: parent
                    text: root.isUnlimited && !sliderDrag.pressed ? "∞" : `${root.activeSliderValue}`
                    font: Tokens.font.body.small
                    color: root.isUnlimited && !sliderDrag.pressed ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                }
            }

            Item {
                id: infCheckboxRow

                Layout.preferredWidth: infContent.implicitWidth + Tokens.padding.medium * 2
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter

                StateLayer {
                    id: infHover
                    radius: parent.height / 2
                    shapeMorph: true
                    onClicked: {
                        service.toggleUnlimited();
                        search.forceActiveFocus();
                    }
                }

                Row {
                    id: infContent
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.smaller

                    StyledRect {
                        id: infBox

                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: root.isUnlimited ? 6 : 5
                        color: root.isUnlimited ? Colours.palette.m3primary : "transparent"
                        border.width: 2
                        border.color: root.isUnlimited ? Colours.palette.m3primary : Colours.palette.m3outline
                        scale: infHover.pressed ? 0.88 : 1.0

                        Behavior on color {
                            CAnim {}
                        }
                        Behavior on border.color {
                            CAnim {}
                        }
                        Behavior on scale {
                            Anim { type: Anim.DefaultEffects }
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "check"
                            color: Colours.palette.m3onPrimary
                            fontStyle: Tokens.font.icon.builders.small.scale(0.85).build()
                            scale: root.isUnlimited ? 1 : 0
                            opacity: root.isUnlimited ? 1 : 0

                            Behavior on scale {
                                Anim { type: Anim.DefaultEffects }
                            }
                            Behavior on opacity {
                                Anim { type: Anim.DefaultEffects }
                            }
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "∞"
                        font: Tokens.font.body.medium
                        color: root.isUnlimited ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }
            }
        }
    }

    Item {
        id: searchRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        anchors.bottomMargin: CUtils.clamp(root.padding - Config.border.thickness, 0, root.padding)
        height: search.implicitHeight

        SearchBar {
            id: search

            anchors.left: parent.left
            anchors.right: controlsRow.left
            anchors.rightMargin: Tokens.spacing.medium
            anchors.verticalCenter: parent.verticalCenter

            topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
            bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
            placeholderText: {
                if (autoPasteHover.containsMouse)
                    return `Auto-paste on select: ${service.autoPaste ? "Enabled" : "Disabled"}`;
                if (limitHover.containsMouse)
                    return `History limit: ${service.maxHistory > 0 ? service.maxHistory + " entries" : "Unlimited"}`;
                if (wipeHover.containsMouse)
                    return "Clear entire clipboard history";
                return "Search clipboard...";
            }

            onAccepted: {
                if (root.currentEntry) {
                    service.copyItem(root.currentEntry);
                    root.screenState.clipboard = false;
                }
            }

            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onEscapePressed: {
                if (root.limitExpanded)
                    root.limitExpanded = false;
                else
                    root.screenState.clipboard = false;
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Delete || ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D)) {
                    if (root.currentEntry) {
                        service.deleteItem(root.currentEntry);
                        event.accepted = true;
                    }
                } else if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                        list.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                        list.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Tab) {
                    list.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.decrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()
        }

        Row {
            id: controlsRow

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small

            StyledRect {
                id: autoPasteBtn

                width: search.implicitHeight
                height: search.implicitHeight
                radius: autoPasteHover.pressed ? 10 : (service.autoPaste ? 14 : height / 2)
                color: service.autoPaste ? Colours.tPalette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
                scale: autoPasteHover.pressed ? 0.92 : (autoPasteHover.containsMouse ? 1.04 : 1.0)

                Behavior on color {
                    CAnim {}
                }
                Behavior on radius {
                    Anim { type: Anim.DefaultEffects }
                }
                Behavior on scale {
                    Anim { type: Anim.DefaultEffects }
                }

                StateLayer {
                    id: autoPasteHover
                    radius: parent.radius
                    shapeMorph: true
                    onClicked: {
                        service.toggleAutoPaste();
                        search.forceActiveFocus();
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "content_paste_go"
                    color: service.autoPaste ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.medium.scale(1.0).build()
                    scale: service.autoPaste ? 1.08 : 1.0

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on scale {
                        Anim { type: Anim.DefaultEffects }
                    }
                }
            }

            StyledRect {
                id: limitBtn

                width: limitRow.implicitWidth + Tokens.padding.large * 2
                height: search.implicitHeight
                radius: limitHover.pressed ? 10 : (root.limitExpanded ? 14 : height / 2)
                color: root.limitExpanded ? Colours.tPalette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
                scale: limitHover.pressed ? 0.94 : (limitHover.containsMouse ? 1.03 : 1.0)

                Behavior on width {
                    Anim { type: Anim.DefaultEffects }
                }
                Behavior on color {
                    CAnim {}
                }
                Behavior on radius {
                    Anim { type: Anim.DefaultEffects }
                }
                Behavior on scale {
                    Anim { type: Anim.DefaultEffects }
                }

                StateLayer {
                    id: limitHover
                    radius: parent.radius
                    shapeMorph: true
                    onClicked: {
                        root.limitExpanded = !root.limitExpanded;
                        search.forceActiveFocus();
                    }
                }

                Row {
                    id: limitRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.smaller

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "history"
                        color: root.limitExpanded ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.builders.medium.scale(0.95).build()
                        rotation: root.limitExpanded ? -35 : 0

                        Behavior on color {
                            CAnim {}
                        }
                        Behavior on rotation {
                            Anim { type: Anim.DefaultEffects }
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isUnlimited ? "∞" : `${root.activeSliderValue}`
                        font: Tokens.font.body.small
                        color: root.limitExpanded ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }
            }

            StyledRect {
                id: wipeBtn

                width: search.implicitHeight
                height: search.implicitHeight
                radius: wipeHover.pressed ? 10 : height / 2
                color: wipeHover.containsMouse && service.entries.length > 0 ? Colours.tPalette.m3errorContainer : Colours.tPalette.m3surfaceContainer
                opacity: service.entries.length > 0 ? 1 : 0.45
                scale: wipeHover.pressed ? 0.92 : (wipeHover.containsMouse && service.entries.length > 0 ? 1.04 : 1.0)

                Behavior on color {
                    CAnim {}
                }
                Behavior on radius {
                    Anim { type: Anim.DefaultEffects }
                }
                Behavior on scale {
                    Anim { type: Anim.DefaultEffects }
                }
                Behavior on opacity {
                    Anim { type: Anim.DefaultEffects }
                }

                StateLayer {
                    id: wipeHover
                    disabled: service.entries.length === 0
                    radius: parent.radius
                    shapeMorph: true
                    onClicked: {
                        service.wipeAll();
                        search.forceActiveFocus();
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    color: wipeHover.containsMouse && service.entries.length > 0 ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.medium.scale(1.15).build()

                    Behavior on color {
                        CAnim {}
                    }
                }
            }
        }
    }

    Connections {
        function onClipboardChanged(): void {
            if (root.screenState.clipboard) {
                service.reload();
                search.forceActiveFocus();
            } else {
                search.text = "";
                root.limitExpanded = false;
            }
        }

        target: root.screenState
    }
}
