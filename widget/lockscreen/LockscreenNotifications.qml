pragma ComponentBehavior: Bound

import "../.."
import "../../components"
import "../../service"
import QtQuick

Item {
    id: root

    readonly property real cardHeight: 40 * scaleFactor
    readonly property real cardSpacing: 4 * scaleFactor
    readonly property real scaleFactor: width > 0 ? width / 220 : 1
    readonly property real stackHeight: {
        var count = LockscreenNotificationService.notifications.count;
        return count > 0 ? count * cardHeight + (count - 1) * cardSpacing : 0;
    }

    height: stackHeight
    implicitHeight: stackHeight
    visible: Config.notificationShowOnLock && StateManager.sessionLocked && LockscreenNotificationService.notifications.count > 0

    ListView {
        id: notificationList

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        model: LockscreenNotificationService.notifications
        spacing: root.cardSpacing

        add: Transition {
            ParallelAnimation {
                OpacityAnimator {
                    duration: Config.animationDuration(150)
                    easing.type: Easing.OutCubic
                    from: 0
                    to: 1
                }
                XAnimator {
                    duration: Config.animationDuration(210)
                    easing.type: Easing.OutCubic
                    from: 18 * root.scaleFactor
                    to: 0
                }
            }
        }
        delegate: Item {
            id: notificationDelegate

            required property string appIcon
            required property string appName
            required property string body
            readonly property string descriptionText: body !== "" ? body : (summary !== "" ? appName : "")
            property bool dismissing: false
            required property string image
            required property bool isCritical
            required property int nid
            required property string summary
            property real swipeOffset: 0
            readonly property string titleText: summary !== "" ? summary : appName

            function settleSwipe(targetOffset, shouldDismiss) {
                dismissing = shouldDismiss;
                swipeAnimation.stop();
                swipeAnimation.from = swipeOffset;
                swipeAnimation.to = targetOffset;
                swipeAnimation.restart();
            }

            height: root.cardHeight
            width: ListView.view.width

            NumberAnimation {
                id: swipeAnimation

                alwaysRunToEnd: notificationDelegate.dismissing
                duration: Config.animationDuration(notificationDelegate.dismissing ? 180 : 220)
                easing.type: notificationDelegate.dismissing ? Easing.InCubic : Easing.OutQuint
                property: "swipeOffset"
                target: notificationDelegate

                onFinished: {
                    if (notificationDelegate.dismissing)
                        LockscreenNotificationService.dismiss(notificationDelegate.nid, true);
                }
            }
            Rectangle {
                id: notificationCard

                color: Config.alpha(Config.md3.surface_container_high, 0.88)
                height: parent.height
                opacity: 1 - Math.min(0.78, Math.abs(notificationDelegate.swipeOffset) / Math.max(1, width) * 0.82)
                radius: 10 * root.scaleFactor
                width: parent.width

                transform: Translate {
                    x: notificationDelegate.swipeOffset
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.scaleFactor
                    anchors.right: parent.right
                    anchors.rightMargin: 9 * root.scaleFactor
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7 * root.scaleFactor

                    NotificationIcon {
                        id: compactIcon

                        anchors.verticalCenter: parent.verticalCenter
                        asynchronous: true
                        backgroundColor: Config.alpha(notificationDelegate.isCritical ? Config.md3.error_container : Config.md3.primary_container, 0.68)
                        height: 26 * root.scaleFactor
                        iconSize: hasProvidedIcon ? 19 * root.scaleFactor : 15 * root.scaleFactor
                        notificationData: notificationDelegate
                        radius: 8 * root.scaleFactor
                        width: height

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: -1 * root.scaleFactor
                            anchors.top: parent.top
                            anchors.topMargin: -1 * root.scaleFactor
                            color: Config.md3.error
                            height: 5 * root.scaleFactor
                            radius: width / 2
                            visible: notificationDelegate.isCritical
                            width: height
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        width: parent.width - parent.spacing - compactIcon.width

                        Text {
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 9.5 * root.scaleFactor
                            font.weight: Font.DemiBold
                            text: notificationDelegate.titleText
                            textFormat: Text.PlainText
                            width: parent.width
                        }
                        Text {
                            color: Config.alpha(Config.md3.on_surface_variant, 0.8)
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 8 * root.scaleFactor
                            text: notificationDelegate.descriptionText
                            textFormat: Text.PlainText
                            visible: text !== ""
                            width: parent.width
                        }
                    }
                }
            }
            DragHandler {
                id: swipeDrag

                enabled: !notificationDelegate.dismissing
                target: null
                xAxis.enabled: true
                xAxis.maximum: notificationDelegate.width * 1.2
                xAxis.minimum: -notificationDelegate.width * 1.2
                yAxis.enabled: false

                onActiveChanged: {
                    if (active) {
                        swipeAnimation.stop();
                        return;
                    }
                    if (notificationDelegate.dismissing)
                        return;
                    if (Math.abs(notificationDelegate.swipeOffset) >= notificationDelegate.width * 0.28) {
                        notificationDelegate.settleSwipe((notificationDelegate.swipeOffset < 0 ? -1 : 1) * (notificationDelegate.width + 18 * root.scaleFactor), true);
                    } else {
                        notificationDelegate.settleSwipe(0, false);
                    }
                }
                onTranslationChanged: {
                    if (!notificationDelegate.dismissing)
                        notificationDelegate.swipeOffset = translation.x;
                }
            }
        }
        displaced: Transition {
            YAnimator {
                duration: Config.animationDuration(190)
                easing.type: Easing.OutCubic
            }
        }
        remove: Transition {
            OpacityAnimator {
                duration: Config.animationDuration(90)
                easing.type: Easing.InCubic
                to: 0
            }
        }
    }
}
