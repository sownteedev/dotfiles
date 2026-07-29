import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

PanelWindow {
    id: root

    property bool active: false
    property string body: ""
    property int notificationId: -1
    property var notificationObject: null
    property var pendingNotification: null
    readonly property bool screenshotReady: CaptureService.screenshotPath !== ""
    property string summary: ""

    function closeToast() {
        autoCloseTimer.stop();
        pendingShowTimer.stop();
        pendingNotification = null;
        active = false;
        removeTimer.restart();
    }
    function finishAction(callback) {
        if (!screenshotReady)
            return;

        var id = notificationId;
        callback();
        closeToast();
        if (id >= 0)
            NotificationHistory.dismiss(id);
    }
    function isScreenshotNotification(notification) {
        return String(notification.summary || "").toLowerCase().indexOf("screenshot captured") !== -1;
    }
    function revealToast() {
        pendingShowTimer.stop();
        pendingNotification = null;
        active = false;
        visible = true;
        autoCloseTimer.restart();
        Qt.callLater(function () {
            root.active = true;
        });
    }
    function showNotification(notification) {
        removeTimer.stop();
        toast.swipeOffset = 0;
        notificationId = notification.id;
        notificationObject = notification;
        summary = notification.summary || "Screenshot captured";
        body = notification.body || "The screenshot is ready.";

        if (screenshotReady)
            revealToast();
        else {
            pendingNotification = notification;
            pendingShowTimer.restart();
        }

        notification.closed.connect(function () {
            if (root.notificationObject === notification)
                root.closeToast();
        });
    }

    aboveWindows: true
    anchors.bottom: true
    anchors.right: true
    color: "transparent"
    exclusiveZone: 0
    focusable: false
    implicitHeight: 480
    implicitWidth: 480
    visible: false

    Connections {
        function onNotification(notification) {
            if (QuickSettingsService.dndActive || !root.isScreenshotNotification(notification))
                return;

            root.showNotification(notification);
        }

        target: globalNotificationManager
    }
    Connections {
        function onDndActiveChanged() {
            if (QuickSettingsService.dndActive)
                root.closeToast();
        }

        target: QuickSettingsService
    }
    Connections {
        function onScreenshotCapturedAtChanged() {
            if (root.pendingNotification && root.screenshotReady)
                root.revealToast();
        }

        target: CaptureService
    }
    Timer {
        id: autoCloseTimer

        interval: 7000
        repeat: false

        onTriggered: root.closeToast()
    }
    Timer {
        id: pendingShowTimer

        interval: 4000
        repeat: false

        // Never flash an empty preview if the capture watcher could not
        // resolve the saved image.
        onTriggered: root.closeToast()
    }
    Timer {
        id: removeTimer

        interval: 220
        repeat: false

        onTriggered: {
            if (!root.active) {
                root.visible = false;
                if (root.notificationObject && (!root.notificationObject.actions || root.notificationObject.actions.length === 0)) {
                    try {
                        root.notificationObject.dismiss();
                    } catch (error) {
                        console.log("[ScreenshotToast] Notification already dismissed:", error);
                    }
                }
                root.notificationObject = null;
                root.notificationId = -1;
            }
        }
    }
    ClippingRectangle {
        id: toast

        property real slideOffset: root.active ? 0 : 42
        property real swipeOffset: 0

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        border.color: Config.alpha(Config.md3.outline_variant, 0.28)
        border.width: 1
        color: Config.md3.surface
        height: mainColumn.implicitHeight + 32
        opacity: (root.active ? 1 : 0) * Math.max(0, 1 - swipeOffset / (width * 0.78))
        radius: 24
        width: 440

        Behavior on opacity {
            enabled: !swipeDrag.active

            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on slideOffset {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        Behavior on swipeOffset {
            enabled: !swipeDrag.active

            NumberAnimation {
                duration: 210
                easing.type: Easing.OutCubic
            }
        }
        transform: Translate {
            x: toast.slideOffset + toast.swipeOffset
        }

        HoverHandler {
            id: toastHover

            onHoveredChanged: {
                if (hovered)
                    autoCloseTimer.stop();
                else if (root.active)
                    autoCloseTimer.restart();
            }
        }
        DragHandler {
            id: swipeDrag

            target: null
            xAxis.enabled: true
            xAxis.minimum: 0
            yAxis.enabled: false

            onActiveChanged: {
                if (active) {
                    autoCloseTimer.stop();
                    return;
                }

                if (toast.swipeOffset >= toast.width * 0.26) {
                    toast.swipeOffset = toast.width + 48;
                    swipeDismissTimer.restart();
                } else {
                    toast.swipeOffset = 0;
                    if (root.active && !toastHover.hovered)
                        autoCloseTimer.restart();
                }
            }
            onTranslationChanged: toast.swipeOffset = Math.max(0, translation.x)
        }
        Timer {
            id: swipeDismissTimer

            interval: 170
            repeat: false

            onTriggered: root.closeToast()
        }
        ColumnLayout {
            id: mainColumn

            anchors.left: parent.left
            anchors.margins: 14
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 14

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 9 / 16

                ClippingRectangle {
                    id: imageFrame

                    anchors.fill: parent
                    border.color: previewArea.containsMouse ? Config.alpha(Config.md3.primary, 0.72) : Config.alpha(Config.md3.outline_variant, 0.3)
                    border.width: 1
                    color: Config.md3.surface_container_lowest
                    radius: 12
                    scale: previewArea.pressed ? 0.985 : 1

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }

                    CachingImage {
                        anchors.fill: parent
                        cacheKey: String(CaptureService.screenshotCapturedAt)
                        fillMode: Image.PreserveAspectFit
                        horizontalAlignment: Image.AlignHCenter
                        path: CaptureService.screenshotPath
                        verticalAlignment: Image.AlignVCenter
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: previewArea.containsMouse ? Config.alpha(Config.md3.primary, 0.06) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }
                    }
                    MouseArea {
                        id: previewArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.finishAction(function () {
                            CaptureService.openScreenshot();
                        })
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(62, infoContent.implicitHeight + 20)
                border.color: Config.alpha(Config.md3.outline_variant, 0.16)
                border.width: 1
                color: Config.md3.surface_container
                radius: 14

                RowLayout {
                    id: infoContent

                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: 40
                        color: Config.md3.primary_container
                        radius: 13

                        IconImage {
                            anchors.centerIn: parent
                            height: 20
                            layer.enabled: true
                            source: Quickshell.iconPath("camera-photo-symbolic")
                            width: 20

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_primary_container
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: root.summary
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 13
                            maximumLineCount: 2
                            text: root.body
                            wrapMode: Text.Wrap
                        }
                    }
                    RowLayout {
                        spacing: 8

                        ToastIconAction {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 40
                            accentColor: Config.md3.primary
                            enabled: root.screenshotReady
                            iconName: "document-edit-symbolic"

                            onTriggered: root.finishAction(function () {
                                CaptureService.openScreenshotEditor(root.screen ? root.screen.name : "");
                            })
                        }
                        ToastIconAction {
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: 40
                            accentColor: Config.md3.error
                            enabled: root.screenshotReady
                            iconName: "user-trash-symbolic"

                            onTriggered: root.finishAction(function () {
                                CaptureService.trashScreenshot();
                            })
                        }
                    }
                }
            }
        }
    }

    component ToastIconAction: Rectangle {
        id: actionRoot

        property color accentColor: Config.md3.primary
        property string iconName: ""

        signal triggered

        border.color: actionArea.containsMouse ? Config.alpha(accentColor, 0.52) : Config.alpha(Config.md3.outline_variant, 0.18)
        border.width: 1
        color: actionArea.pressed ? Config.alpha(accentColor, 0.3) : actionArea.containsMouse ? Config.alpha(accentColor, 0.2) : Config.md3.surface_container_high
        opacity: enabled ? 1 : 0.4
        radius: width / 2
        scale: actionArea.pressed ? 0.96 : 1

        Behavior on border.color {
            ColorAnimation {
                duration: 130
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 130
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        IconImage {
            anchors.centerIn: parent
            height: 20
            layer.enabled: true
            source: Quickshell.iconPath(actionRoot.iconName)
            width: 20

            layer.effect: ColorOverlay {
                color: actionRoot.accentColor
            }
        }
        MouseArea {
            id: actionArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: actionRoot.triggered()
        }
    }
}
