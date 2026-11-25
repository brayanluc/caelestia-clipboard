pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property var modelData
    required property ScreenState screenState
    required property var service
    required property bool isCurrent

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    HoverHandler {
        id: rowHover
    }

    StateLayer {
        id: stateLayer

        radius: Tokens.rounding.large
        onClicked: {
            root.service.copyItem(root.modelData);
            root.screenState.clipboard = false;
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.small
        anchors.margins: Tokens.padding.small

        Item {
            id: leading

            implicitWidth: parent.height * 1.15
            implicitHeight: parent.height * 0.8
            anchors.verticalCenter: parent.verticalCenter

            StyledClippingRect {
                anchors.fill: parent
                radius: Tokens.rounding.small
                visible: root.modelData.isImage
                color: Colours.tPalette.m3surfaceContainerHigh

                Image {
                    anchors.fill: parent
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 140
                    sourceSize.height: 90
                    source: root.modelData.isImage ? `file://${root.modelData.thumbPath}?v=${root.service.thumbRevision}` : ""
                }
            }

            StyledRect {
                anchors.centerIn: parent
                implicitWidth: 24
                implicitHeight: 24
                radius: Tokens.rounding.full
                visible: root.modelData.isHexColor
                color: root.modelData.isHexColor ? root.modelData.displayText.trim() : "transparent"
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !root.modelData.isImage && !root.modelData.isHexColor
                text: root.modelData.isUrl ? "link" : "notes"
                color: root.isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }
        }

        Item {
            anchors.left: leading.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: delBtn.left
            anchors.rightMargin: Tokens.spacing.small
            anchors.verticalCenter: parent.verticalCenter

            implicitHeight: titleText.implicitHeight + subText.implicitHeight

            StyledText {
                id: titleText

                width: parent.width
                text: root.modelData.displayText.replace(/\s+/g, " ").trim()
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                id: subText

                anchors.top: titleText.bottom
                width: parent.width
                text: root.modelData.isImage ? `#${root.modelData.id} • ${root.modelData.ext.toUpperCase()} • ${root.modelData.size}` : `#${root.modelData.id} • ${root.modelData.displayText.length} chars`
                font: Tokens.font.body.small
                color: Colours.palette.m3outline
                elide: Text.ElideRight
            }
        }

        IconButton {
            id: delBtn

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "delete"
            type: IconButton.Text
            radius: Tokens.rounding.full
            opacity: root.isCurrent || rowHover.hovered ? 0.85 : 0
            visible: opacity > 0
            onClicked: root.service.deleteItem(root.modelData)

            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }
        }
    }
}
