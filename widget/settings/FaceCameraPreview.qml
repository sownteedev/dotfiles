import "../.."
import "../../components"
import "../../service"
import QtMultimedia
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

FocusScope {
    id: root

    readonly property var cameraOptions: buildCameraOptions()
    property bool cameraPopupOpen: false
    property real cameraPopupRightMargin: 12
    property real cameraPopupY: 0
    readonly property bool currentCameraSelected: {
        var option = selectedOption;
        return option && FaceAuthService.camera !== "" && [option.path, option.device].indexOf(FaceAuthService.camera) >= 0;
    }
    property string pendingAction: ""
    property bool previewActive: true
    property int selectedIndex: -1
    readonly property var selectedOption: selectedIndex >= 0 && selectedIndex < cameraOptions.length ? cameraOptions[selectedIndex] : null

    signal closeRequested

    function basename(path) {
        var value = normalizeDeviceId(path);
        var parts = value.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : value;
    }
    function buildCameraOptions() {
        var result = [];
        var helpers = FaceAuthService.cameras || [];
        var inputs = mediaDevices.videoInputs || [];
        var matchedHelpers = {};
        for (var inputIndex = 0; inputIndex < inputs.length; ++inputIndex) {
            var input = inputs[inputIndex];
            var inputId = normalizeDeviceId(input.id);
            var description = String(input.description || qsTr("Camera %1").arg(inputIndex + 1));
            var helperIndex = -1;
            for (var index = 0; index < helpers.length; ++index) {
                var helper = helpers[index];
                var sameDevice = inputId !== "" && (inputId === normalizeDeviceId(helper.device) || basename(inputId) === basename(helper.device));
                var sameLabel = description.toLowerCase() === String(helper.label || "").toLowerCase();
                if (sameDevice || sameLabel) {
                    helperIndex = index;
                    break;
                }
            }
            var matched = helperIndex >= 0 ? helpers[helperIndex] : null;
            if (matched)
                matchedHelpers[helperIndex] = true;

            result.push({
                "device": matched ? String(matched.device || inputId) : inputId,
                "label": matched ? String(matched.label || description) : description,
                "mediaIndex": inputIndex,
                "path": matched ? String(matched.path || "") : "",
                "value": "media:" + inputIndex
            });
        }
        for (var helperIndex = 0; helperIndex < helpers.length; ++helperIndex) {
            if (matchedHelpers[helperIndex])
                continue;

            var helper = helpers[helperIndex];
            result.push({
                "device": String(helper.device || ""),
                "label": String(helper.label || helper.device || qsTr("Camera")),
                "mediaIndex": -1,
                "path": String(helper.path || ""),
                "value": "helper:" + helperIndex
            });
        }
        var labelCounts = {};
        for (var resultIndex = 0; resultIndex < result.length; ++resultIndex) {
            var normalizedLabel = String(result[resultIndex].label).toLowerCase();
            labelCounts[normalizedLabel] = Number(labelCounts[normalizedLabel] || 0) + 1;
        }
        for (var labelIndex = 0; labelIndex < result.length; ++labelIndex) {
            var optionLabel = String(result[labelIndex].label);
            if (labelCounts[optionLabel.toLowerCase()] > 1)
                result[labelIndex].label = optionLabel + " · " + basename(result[labelIndex].device || result[labelIndex].path);
        }
        return result;
    }
    function ensureSelection() {
        if (cameraOptions.length === 0) {
            selectedIndex = -1;
            return;
        }
        for (var index = 0; index < cameraOptions.length; ++index) {
            var option = cameraOptions[index];
            if (FaceAuthService.camera !== "" && [option.path, option.device].indexOf(FaceAuthService.camera) >= 0) {
                selectedIndex = index;
                return;
            }
        }
        if (selectedIndex >= 0 && selectedIndex < cameraOptions.length)
            return;

        selectedIndex = 0;
    }
    function normalizeDeviceId(value) {
        var text = String(value || "");
        if (text.indexOf("file://") === 0)
            text = text.substring(7);
        var videoPathIndex = text.indexOf("/dev/video");
        if (videoPathIndex >= 0)
            text = text.substring(videoPathIndex);

        return text;
    }
    function openCameraPopup(sourceItem) {
        if (cameraPopupOpen) {
            cameraPopupOpen = false;
            return;
        }
        var position = sourceItem.mapToItem(root, 0, 0);
        var popupHeight = Math.min(cameraOptions.length * 46 + 16, height - 24);
        cameraPopupY = position.y - popupHeight - 8;
        cameraPopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        cameraPopupOpen = true;
    }
    function runFaceAction(action) {
        if (!selectedOption || FaceAuthService.busy)
            return;

        cameraPopupOpen = false;
        previewActive = false;
        pendingAction = action;
        cameraReleaseTimer.restart();
    }
    function selectOption(value) {
        for (var index = 0; index < cameraOptions.length; ++index) {
            if (String(cameraOptions[index].value) === String(value)) {
                selectedIndex = index;
                break;
            }
        }
    }

    Component.onCompleted: {
        ensureSelection();
        forceActiveFocus();
    }
    Keys.onEscapePressed: event => {
        if (cameraPopupOpen)
            cameraPopupOpen = false;
        else
            closeRequested();
        event.accepted = true;
    }
    onCameraOptionsChanged: ensureSelection()
    onHeightChanged: cameraPopupOpen = false
    onWidthChanged: cameraPopupOpen = false

    Connections {
        function onOperationFinished(success, message) {
            if (root.pendingAction === "")
                return;

            root.pendingAction = "";
            root.previewActive = true;
        }

        target: FaceAuthService
    }
    Timer {
        id: cameraReleaseTimer

        interval: 180

        onTriggered: {
            if (root.pendingAction === "set-camera")
                FaceAuthService.setCamera(root.selectedOption.path || root.selectedOption.device);
            else if (root.pendingAction === "test")
                FaceAuthService.testModel();
        }
    }
    MediaDevices {
        id: mediaDevices
    }
    Camera {
        id: previewCamera

        active: root.previewActive && !FaceAuthService.busy && root.selectedOption && root.selectedOption.mediaIndex >= 0
        cameraDevice: root.selectedOption && root.selectedOption.mediaIndex >= 0 ? mediaDevices.videoInputs[root.selectedOption.mediaIndex] : mediaDevices.defaultVideoInput
    }
    CaptureSession {
        camera: previewCamera
        videoOutput: cameraOutput
    }
    Rectangle {
        anchors.fill: parent
        color: Config.alpha(Config.md3.scrim, 0.48)

        MouseArea {
            acceptedButtons: Qt.AllButtons
            anchors.fill: parent
            hoverEnabled: true
            scrollGestureEnabled: true

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    root.closeRequested();
            }
            onWheel: wheel => wheel.accepted = true
        }
    }
    Rectangle {
        id: card

        anchors.centerIn: parent
        color: Config.md3.surface_container
        height: Math.min(parent.height - 36, 720)
        radius: 26
        width: Math.min(parent.width - 36, 820)

        MouseArea {
            acceptedButtons: Qt.AllButtons
            anchors.fill: parent
            hoverEnabled: true
            scrollGestureEnabled: true

            onWheel: wheel => wheel.accepted = true
        }
        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.preferredHeight: 44
                    Layout.preferredWidth: 44
                    color: Config.alpha(Config.md3.primary, 0.16)
                    radius: 14

                    Md3Icon {
                        anchors.centerIn: parent
                        color: Config.md3.primary
                        name: "videocam"
                        size: 24
                    }
                }
                SettingsLabelBlock {
                    Layout.fillWidth: true
                    emphasized: true
                    headline: qsTr("Camera preview")
                    headlineRole: "titleLarge"
                    supportingText: qsTr("Check framing, select the camera used by Howdy, then test recognition")
                }
                SettingsActionButton {
                    iconName: "window-close-symbolic"
                    iconOnly: true
                    text: qsTr("Close camera preview")

                    onClicked: root.closeRequested()
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(390, content.height * 0.5, (card.width - 48) * 0.5625)
                color: Config.md3.surface_container_lowest
                radius: 20
                z: 1

                VideoOutput {
                    id: cameraOutput

                    anchors.fill: parent
                    clip: true
                    fillMode: VideoOutput.PreserveAspectCrop
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.cameraOptions.length === 0 || !root.selectedOption || root.selectedOption.mediaIndex < 0 || previewCamera.error !== Camera.NoError

                    Md3Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Config.md3.on_surface_variant
                        name: "videocam"
                        size: 40
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                        font.pixelSize: Md3.typeScale.titleMedium.size
                        font.weight: Md3.typeScale.titleMedium.emphasizedWeight
                        text: previewCamera.errorString || (root.cameraOptions.length === 0 ? qsTr("No camera detected") : qsTr("Preview is unavailable for this device"))
                    }
                }
                RowLayout {
                    id: previewToolbar

                    readonly property real actionSize: width < 360 ? 40 : 48
                    readonly property real sourceFieldWidth: Math.max(96, Math.min(260, width - actionSize * 2 - spacing * 3))

                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 14
                    anchors.right: parent.right
                    spacing: 8

                    SettingsActionButton {
                        Layout.preferredHeight: previewToolbar.actionSize
                        Layout.preferredWidth: previewToolbar.actionSize
                        dimWhenDisabled: FaceAuthService.busy || CameraControlService.controls.length === 0
                        enabled: !FaceAuthService.busy && !CameraControlService.busy && CameraControlService.controls.length > 0
                        iconName: "view-restore-symbolic"
                        iconOnly: true
                        text: qsTr("Reset to defaults")
                        tooltipText: qsTr("Set all camera controls to driver defaults")

                        onClicked: CameraControlService.reset()
                    }
                    SettingsActionButton {
                        Layout.preferredHeight: previewToolbar.actionSize
                        Layout.preferredWidth: previewToolbar.actionSize
                        dimWhenDisabled: FaceAuthService.busy || CameraControlService.controls.length === 0
                        enabled: !FaceAuthService.busy && CameraControlService.controls.length > 0 && (!CameraControlService.busy || CameraControlService.defaultCompareActive || CameraControlService.defaultCompareRestorePending)
                        iconName: "edit-undo-history-symbolic"
                        iconOnly: true
                        primary: CameraControlService.defaultCompareActive || CameraControlService.defaultCompareRestorePending
                        text: qsTr("Preview defaults")
                        tooltipText: qsTr("Hold to preview defaults; release to restore current settings")

                        onPressEnded: CameraControlService.endDefaultComparison()
                        onPressStarted: CameraControlService.beginDefaultComparison()
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    SettingsSelectField {
                        Layout.fillWidth: false
                        Layout.maximumWidth: previewToolbar.sourceFieldWidth
                        Layout.minimumWidth: previewToolbar.sourceFieldWidth
                        Layout.preferredWidth: previewToolbar.sourceFieldWidth
                        dimWhenDisabled: FaceAuthService.busy || root.cameraOptions.length === 0
                        enabled: root.cameraOptions.length > 0 && !FaceAuthService.busy && !CameraControlService.busy
                        fieldHeight: previewToolbar.actionSize
                        placeholder: qsTr("Select camera")
                        valueFontPixelSize: previewToolbar.actionSize < 48 ? 12 : 13
                        valueText: root.selectedOption ? root.selectedOption.label : ""

                        onClicked: sourceItem => root.openCameraPopup(sourceItem)
                    }
                }
            }
            Flickable {
                id: contentScroll

                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.minimumHeight: 0
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                contentHeight: controlsContent.implicitHeight
                contentWidth: width
                flickableDirection: Flickable.VerticalFlick

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: controlsContent

                    spacing: 16
                    width: contentScroll.width

                    CameraControlsPanel {
                        Layout.fillWidth: true
                        device: root.selectedOption ? (root.selectedOption.path || root.selectedOption.device) : ""
                        visible: root.selectedOption !== null
                    }
                    RowLayout {
                        id: actionRow

                        readonly property real actionSize: width < 460 ? 40 : 48
                        readonly property bool compact: width < 460

                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            color: FaceAuthService.statusSuccess ? Config.md3.on_surface_variant : Config.md3.error
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                            font.pixelSize: Md3.typeScale.bodyMedium.size
                            lineHeight: Md3.typeScale.bodyMedium.lineHeight
                            lineHeightMode: Text.FixedHeight
                            text: FaceAuthService.busy ? FaceAuthService.statusMessage : FaceAuthService.statusMessage
                            visible: !actionRow.compact
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            visible: actionRow.compact
                        }
                        SettingsActionButton {
                            Layout.preferredHeight: actionRow.compact ? actionRow.actionSize : implicitHeight
                            Layout.preferredWidth: actionRow.compact ? actionRow.actionSize : implicitWidth
                            enabled: FaceAuthService.installed && FaceAuthService.models.length > 0 && !FaceAuthService.busy
                            iconName: "emblem-ok-symbolic"
                            iconOnly: actionRow.compact
                            text: FaceAuthService.activeAction === "test" ? qsTr("Testing…") : qsTr("Test recognition")
                            tooltipText: qsTr("Test recognition")

                            onClicked: root.runFaceAction("test")
                        }
                        SettingsActionButton {
                            Layout.preferredHeight: actionRow.compact ? actionRow.actionSize : implicitHeight
                            Layout.preferredWidth: actionRow.compact ? actionRow.actionSize : implicitWidth
                            enabled: FaceAuthService.installed && root.selectedOption && (root.selectedOption.path !== "" || root.selectedOption.device !== "") && !root.currentCameraSelected && !FaceAuthService.busy
                            iconName: "camera-photo-symbolic"
                            iconOnly: actionRow.compact
                            primary: true
                            text: root.currentCameraSelected ? qsTr("Current camera") : FaceAuthService.activeAction === "set-camera" ? qsTr("Applying…") : qsTr("Use camera")
                            tooltipText: root.currentCameraSelected ? qsTr("Current camera") : qsTr("Use camera")

                            onClicked: root.runFaceAction("set-camera")
                        }
                    }
                }
            }
        }
    }
    SelectPopup {
        accentColor: Config.md3.secondary
        anchors.fill: parent
        itemActive: item => root.selectedOption !== null && String(item.value) === String(root.selectedOption.value)
        model: root.cameraOptions
        openAbove: true
        opened: root.cameraPopupOpen
        popupWidth: 360
        popupY: root.cameraPopupY
        rightMargin: root.cameraPopupRightMargin
        z: 10

        onDismissed: root.cameraPopupOpen = false
        onItemSelected: item => {
            root.cameraPopupOpen = false;
            if (!FaceAuthService.busy && !CameraControlService.busy)
                root.selectOption(item.value);
        }
    }
}
