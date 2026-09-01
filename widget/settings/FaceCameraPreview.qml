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

        return text;
    }
    function runFaceAction(action) {
        if (!selectedOption || FaceAuthService.busy)
            return;

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
        closeRequested();
        event.accepted = true;
    }
    onCameraOptionsChanged: ensureSelection()

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
            anchors.fill: parent

            onClicked: root.closeRequested()
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
            anchors.fill: parent
        }
        Flickable {
            id: contentScroll

            anchors.fill: parent
            anchors.margins: 24
            boundsBehavior: Flickable.StopAtBounds
            clip: contentHeight > height
            contentHeight: content.implicitHeight
            contentWidth: width

            ColumnLayout {
                id: content

                spacing: 16
                width: contentScroll.width

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 44
                        color: Config.alpha(Config.md3.primary, 0.16)
                        radius: 14

                        Text {
                            anchors.centerIn: parent
                            color: Config.md3.primary
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 22
                            text: "󰄀"
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            text: qsTr("Camera preview")
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface_variant, 0.72)
                            font.family: Config.fontName
                            font.pixelSize: 13
                            text: qsTr("Check framing, select the camera used by Howdy, then test recognition")
                            wrapMode: Text.Wrap
                        }
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
                    Layout.preferredHeight: Math.min(390, Math.max(230, (card.width - 48) * 0.5625))
                    clip: true
                    color: Config.md3.surface_container_lowest
                    radius: 20

                    VideoOutput {
                        id: cameraOutput

                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.cameraOptions.length === 0 || !root.selectedOption || root.selectedOption.mediaIndex < 0 || previewCamera.error !== Camera.NoError

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Config.alpha(Config.md3.on_surface_variant, 0.72)
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 38
                            text: "󰄀"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            text: previewCamera.errorString || (root.cameraOptions.length === 0 ? qsTr("No camera detected") : qsTr("Preview is unavailable for this device"))
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        color: Config.alpha(Config.md3.scrim, 0.62)
                        height: 34
                        radius: 11
                        visible: root.selectedOption !== null
                        width: Math.min(parent.width - 28, cameraName.implicitWidth + 24)

                        Text {
                            id: cameraName

                            anchors.centerIn: parent
                            color: "white"
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            text: root.selectedOption ? root.selectedOption.label : ""
                            width: Math.min(implicitWidth, cameraOutput.width - 48)
                        }
                    }
                }
                SettingsChoiceRow {
                    Layout.fillWidth: true
                    enabled: root.cameraOptions.length > 0 && !FaceAuthService.busy
                    label: qsTr("Camera device")
                    note: qsTr("The live preview is released automatically while Howdy uses the camera")
                    options: root.cameraOptions
                    value: root.selectedOption ? root.selectedOption.value : ""

                    onSelected: value => {
                        return root.selectOption(value);
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        color: FaceAuthService.statusSuccess ? Config.alpha(Config.md3.on_surface_variant, 0.72) : Config.md3.error
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 13
                        text: FaceAuthService.busy ? FaceAuthService.statusMessage : FaceAuthService.statusMessage
                    }
                    SettingsActionButton {
                        enabled: FaceAuthService.installed && FaceAuthService.models.length > 0 && !FaceAuthService.busy
                        iconName: "emblem-ok-symbolic"
                        text: FaceAuthService.activeAction === "test" ? qsTr("Testing…") : qsTr("Test recognition")

                        onClicked: root.runFaceAction("test")
                    }
                    SettingsActionButton {
                        enabled: FaceAuthService.installed && root.selectedOption && (root.selectedOption.path !== "" || root.selectedOption.device !== "") && !root.currentCameraSelected && !FaceAuthService.busy
                        iconName: "camera-photo-symbolic"
                        primary: true
                        text: root.currentCameraSelected ? qsTr("Current camera") : FaceAuthService.activeAction === "set-camera" ? qsTr("Applying…") : qsTr("Use camera")

                        onClicked: root.runFaceAction("set-camera")
                    }
                }
            }
        }
    }
}
