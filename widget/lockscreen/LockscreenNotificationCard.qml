import "../.."
import "../../components"
import "../../service"
import QtQuick

Item {
    id: root

    required property string appIcon
    required property string appName
    required property string body
    readonly property string descriptionText: body !== "" ? body : (summary !== "" ? appName : "")
    property bool dismissing: false
    property int groupCount: 1
    required property string image
    required property bool isCritical
    required property int nid
    property real revealOffsetX: 0
    property real revealOpacity: 1
    property real scaleFactor: 1
    property bool showGroupCount: false
    required property string summary
    property bool swipeEnabled: true
    property real swipeOffset: 0
    property bool tapEnabled: false
    readonly property string titleText: summary !== "" ? summary : appName

    signal tapped

    function revealFromRight() {
        dismissing = false;
        swipeAnimation.stop();
        swipeOffset = 0;
        revealOpacity = 0.48;
        revealOffsetX = width + 18 * scaleFactor;
        revealAnimation.restart();
    }
    function settleSwipe(targetOffset, shouldDismiss) {
        dismissing = shouldDismiss;
        swipeAnimation.stop();
        swipeAnimation.from = swipeOffset;
        swipeAnimation.to = targetOffset;
        swipeAnimation.restart();
    }

    ParallelAnimation {
        id: revealAnimation

        NumberAnimation {
            duration: Config.animationDuration(300)
            easing.type: Easing.OutQuint
            property: "revealOffsetX"
            target: root
            to: 0
        }
        NumberAnimation {
            duration: Config.animationDuration(180)
            easing.type: Easing.OutCubic
            property: "revealOpacity"
            target: root
            to: 1
        }
    }
    NumberAnimation {
        id: swipeAnimation

        alwaysRunToEnd: root.dismissing
        duration: Config.animationDuration(root.dismissing ? 230 : 260)
        easing.type: root.dismissing ? Easing.OutQuart : Easing.OutQuint
        property: "swipeOffset"
        target: root

        onFinished: {
            if (root.dismissing)
                LockscreenNotificationService.dismiss(root.nid, true);
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Config.alpha(Config.md3.surface_container_high, 0.88)
        opacity: root.revealOpacity * (1 - Math.min(0.78, Math.abs(root.swipeOffset) / Math.max(1, width) * 0.82))
        radius: 10 * root.scaleFactor

        transform: Translate {
            x: root.swipeOffset + root.revealOffsetX
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8 * root.scaleFactor
            anchors.right: parent.right
            anchors.rightMargin: 9 * root.scaleFactor
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7 * root.scaleFactor

            Item {
                id: iconContainer

                anchors.verticalCenter: parent.verticalCenter
                height: 26 * root.scaleFactor
                width: height

                NotificationIcon {
                    id: compactIcon

                    anchors.fill: parent
                    asynchronous: true
                    backgroundColor: Config.alpha(root.isCritical ? Config.md3.error_container : Config.md3.primary_container, 0.68)
                    iconSize: hasProvidedIcon ? 19 * root.scaleFactor : 15 * root.scaleFactor
                    notificationData: root
                    radius: 8 * root.scaleFactor
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -1 * root.scaleFactor
                    anchors.right: parent.right
                    anchors.rightMargin: -1 * root.scaleFactor
                    color: Config.md3.error
                    height: 5 * root.scaleFactor
                    radius: width / 2
                    visible: root.isCritical
                    width: height
                    z: 2
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: -4 * root.scaleFactor
                    anchors.top: parent.top
                    anchors.topMargin: -4 * root.scaleFactor
                    color: Config.md3.primary
                    height: 13 * root.scaleFactor
                    opacity: root.showGroupCount && root.groupCount > 1 ? 1 : 0
                    radius: height / 2
                    visible: opacity > 0.01
                    width: Math.max(height, groupCountText.implicitWidth + 6 * root.scaleFactor)
                    z: 3

                    Behavior on opacity {
                        OpacityAnimator {
                            duration: Config.animationDuration(140)
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: groupCountText

                        anchors.centerIn: parent
                        color: Config.md3.on_primary
                        font.family: Config.fontName
                        font.pixelSize: 7.5 * root.scaleFactor
                        font.weight: Font.Bold
                        text: root.groupCount > 99 ? "99+" : String(root.groupCount)
                    }
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
                    text: root.titleText
                    textFormat: Text.PlainText
                    width: parent.width
                }
                Text {
                    color: Config.alpha(Config.md3.on_surface_variant, 0.8)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 8 * root.scaleFactor
                    text: root.descriptionText
                    textFormat: Text.PlainText
                    visible: text !== ""
                    width: parent.width
                }
            }
        }
    }
    TapHandler {
        enabled: root.tapEnabled && !root.dismissing

        onTapped: root.tapped()
    }
    DragHandler {
        enabled: root.swipeEnabled && !root.dismissing
        target: null
        xAxis.enabled: true
        xAxis.maximum: root.width * 1.2
        xAxis.minimum: -root.width * 1.2
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                swipeAnimation.stop();
                return;
            }
            if (root.dismissing)
                return;
            if (Math.abs(root.swipeOffset) >= root.width * 0.28) {
                root.settleSwipe((root.swipeOffset < 0 ? -1 : 1) * (root.width + 18 * root.scaleFactor), true);
            } else {
                root.settleSwipe(0, false);
            }
        }
        onTranslationChanged: {
            if (!root.dismissing)
                root.swipeOffset = translation.x;
        }
    }
}
