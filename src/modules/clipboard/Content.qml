pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
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

    implicitWidth: panelWidth + padding * 2
    implicitHeight: previewCard.implicitHeight + (showPreview ? padding : 0) + listArea.implicitHeight + searchRow.height + padding * 3

    ClipboardService {
        id: service
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
            radius: Tokens.rounding.full
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
        anchors.bottom: searchRow.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: root.padding

        readonly property int maxVisible: Math.min(7, Math.max(1, list.count))
        implicitHeight: list.count > 0 ? (Tokens.sizes.launcher.itemHeight + list.spacing) * maxVisible - list.spacing : 96

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
                values: service.filter(search.text)
                onValuesChanged: list.currentIndex = 0
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
                text: search.text ? Tr.tr("Nenhum item encontrado") : Tr.tr("Clipboard vazio")
                color: Colours.palette.m3outline
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
            anchors.right: wipeBtn.left
            anchors.rightMargin: Tokens.spacing.small
            anchors.verticalCenter: parent.verticalCenter

            topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
            bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
            placeholderText: Tr.tr("Pesquisar no clipboard...")

            onAccepted: {
                if (root.currentEntry) {
                    service.copyItem(root.currentEntry);
                    root.screenState.clipboard = false;
                }
            }

            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onEscapePressed: root.screenState.clipboard = false

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

        IconButton {
            id: wipeBtn

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "delete_sweep"
            type: IconButton.Text
            radius: Tokens.rounding.full
            enabled: service.entries.length > 0
            onClicked: service.wipeAll()
        }
    }

    Connections {
        function onClipboardChanged(): void {
            if (root.screenState.clipboard) {
                service.reload();
                search.forceActiveFocus();
            } else {
                search.text = "";
            }
        }

        target: root.screenState
    }
}
