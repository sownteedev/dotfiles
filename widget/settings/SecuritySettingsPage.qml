import "../.."
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string baselineState: ""
    readonly property var cameraDeviceOptions: buildCameraOptions()
    property bool cameraPopupOpen: false
    property bool cameraPopupOpenAbove: false
    property real cameraPopupRightMargin: 12
    property real cameraPopupY: 0
    property int faceAttemptValue: 3
    property bool faceRetryOnWakeValue: true
    property bool greeterRememberLastSessionValue: false
    readonly property var greeterSessionOptions: {
        var result = [
            {
                "label": qsTr("Automatic"),
                "value": "auto"
            }
        ];
        var sessions = GreeterSettingsService.sessions || [];
        for (var index = 0; index < sessions.length; ++index) {
            result.push({
                "label": String(sessions[index].name || sessions[index].id),
                "value": String(sessions[index].id)
            });
        }
        return result;
    }
    property string greeterSessionValue: "niri"
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? qsTr("Saving…") : qsTr("Apply & save")
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState
    property string lockPrivacyValue: "hidden"
    property bool sessionPopupOpen: false
    property bool sessionPopupOpenAbove: false
    property real sessionPopupRightMargin: 12
    property real sessionPopupY: 0

    function basename(path) {
        var parts = String(path || "").split("/");
        return parts.length > 0 ? parts[parts.length - 1] : "";
    }
    function buildCameraOptions() {
        var cameras = FaceAuthService.cameras || [];
        var labelCounts = {};
        var result = [];
        for (var index = 0; index < cameras.length; ++index) {
            var camera = cameras[index];
            var label = String(camera.label || camera.device || camera.path || qsTr("Camera %1").arg(index + 1));
            var normalizedLabel = label.toLowerCase();
            labelCounts[normalizedLabel] = Number(labelCounts[normalizedLabel] || 0) + 1;
            result.push({
                "device": String(camera.device || ""),
                "label": label,
                "path": String(camera.path || ""),
                "value": String(camera.path || camera.device || "")
            });
        }
        for (var resultIndex = 0; resultIndex < result.length; ++resultIndex) {
            var option = result[resultIndex];
            if (labelCounts[String(option.label).toLowerCase()] > 1)
                option.label += " · " + basename(option.device || option.path);
        }
        return result;
    }
    function cameraLabel() {
        for (var index = 0; index < cameraDeviceOptions.length; ++index) {
            var option = cameraDeviceOptions[index];
            if ([option.path, option.device].indexOf(FaceAuthService.camera) >= 0)
                return option.label;
        }
        return FaceAuthService.camera || qsTr("Automatic camera detection");
    }
    function currentState() {
        return {
            "greeterDefaultSession": greeterSessionValue,
            "greeterRememberLastSession": greeterRememberLastSessionValue,
            "lockFaceMaxAttempts": faceAttemptValue,
            "lockFaceRetryOnWake": faceRetryOnWakeValue,
            "notificationLockscreenPrivacy": lockPrivacyValue,
            "notificationShowOnLock": lockPrivacyValue !== "hidden"
        };
    }
    function greeterSessionLabel() {
        for (var index = 0; index < greeterSessionOptions.length; ++index) {
            if (greeterSessionOptions[index].value === greeterSessionValue)
                return greeterSessionOptions[index].label;
        }
        return greeterSessionValue || qsTr("Automatic");
    }
    function modelDate(timestamp) {
        if (!timestamp || Number(timestamp) <= 0)
            return qsTr("Saved face model");

        return qsTr("Added %1").arg(Qt.formatDateTime(new Date(Number(timestamp) * 1000), "dd MMM yyyy · HH:mm"));
    }
    function openCameraPopup(sourceItem) {
        if (cameraPopupOpen) {
            cameraPopupOpen = false;
            return;
        }
        sessionPopupOpen = false;
        var position = sourceItem.mapToItem(root, 0, 0);
        var popupHeight = Math.min(cameraDeviceOptions.length * 46 + 16, height - 24);
        var belowY = position.y + sourceItem.height + 8;
        cameraPopupOpenAbove = belowY + popupHeight > height;
        cameraPopupY = cameraPopupOpenAbove ? position.y - popupHeight - 8 : belowY;
        cameraPopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        cameraPopupOpen = true;
    }
    function openSessionPopup(sourceItem) {
        if (sessionPopupOpen) {
            sessionPopupOpen = false;
            return;
        }
        cameraPopupOpen = false;
        var position = sourceItem.mapToItem(root, 0, 0);
        var popupHeight = Math.min(greeterSessionOptions.length * 46 + 16, height - 24);
        var belowY = position.y + sourceItem.height + 8;
        sessionPopupOpenAbove = belowY + popupHeight > height;
        sessionPopupY = sessionPopupOpenAbove ? position.y - popupHeight - 8 : belowY;
        sessionPopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        sessionPopupOpen = true;
    }
    function resetPage() {
        cameraPopupOpen = false;
        sessionPopupOpen = false;
        syncFields();
    }
    function selectCamera(item) {
        if (!item || FaceAuthService.busy)
            return;

        cameraPopupOpen = false;
        if ([item.path, item.device].indexOf(FaceAuthService.camera) < 0)
            FaceAuthService.setCamera(String(item.value || ""));
    }
    function selectGreeterSession(item) {
        if (!item)
            return;

        greeterSessionValue = String(item.value || "auto");
        sessionPopupOpen = false;
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        faceAttemptValue = Math.max(1, Math.min(3, Number(settings.lockFaceMaxAttempts ?? Config.lockFaceMaxAttempts)));
        faceRetryOnWakeValue = settings.lockFaceRetryOnWake ?? Config.lockFaceRetryOnWake;
        greeterSessionValue = String(settings.greeterDefaultSession ?? Config.greeterDefaultSession);
        greeterRememberLastSessionValue = settings.greeterRememberLastSession ?? Config.greeterRememberLastSession;
        lockPrivacyValue = String(settings.notificationLockscreenPrivacy ?? Config.notificationLockscreenPrivacyMode).toLowerCase();
        if (["hidden", "icons", "full"].indexOf(lockPrivacyValue) < 0)
            lockPrivacyValue = Config.notificationShowOnLock ? "full" : "hidden";

        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        cameraPopupOpen = false;
        sessionPopupOpen = false;
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: {
        syncFields();
        FaceAuthService.refresh();
        GreeterSettingsService.refreshSessions();
    }

    Connections {
        function onOperationFinished(success, message) {
            if (success && FaceAuthService.activeAction === "add")
                modelLabelField.text = "";
        }

        target: FaceAuthService
    }
    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    SettingsPageContent {
        id: pageContent

        anchors.fill: parent

        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.primary
            compact: true
            iconName: "system-lock-screen-symbolic"
            note: FaceAuthService.installed ? qsTr("Face unlock stays scoped to the SownteeShell lock screen; password fallback is always available") : qsTr("Howdy support is installed by the theme installer")
            title: qsTr("Unlock")

            SettingsToggleRow {
                checked: FaceAuthService.enabled
                enabled: FaceAuthService.installed && FaceAuthService.models.length > 0 && !FaceAuthService.busy
                label: qsTr("Enable face authentication")
                note: FaceAuthService.models.length > 0 ? qsTr("Use Howdy before falling back to the password") : qsTr("Add a face model before enabling")

                onToggled: value => {
                    return FaceAuthService.setEnabled(value);
                }
            }
            SettingsToggleRow {
                checked: root.faceRetryOnWakeValue
                enabled: FaceAuthService.installed
                label: qsTr("Retry after monitor wake")
                note: qsTr("Start a fresh face scan when the display turns back on")

                onToggled: value => {
                    return root.faceRetryOnWakeValue = value;
                }
            }
            SettingsChoiceRow {
                Layout.fillWidth: true
                enabled: FaceAuthService.installed
                label: qsTr("Maximum face attempts")
                note: qsTr("After this many attempts the lock screen switches to password input")
                options: [
                    {
                        "label": qsTr("1 attempt"),
                        "value": "1"
                    },
                    {
                        "label": qsTr("2 attempts"),
                        "value": "2"
                    },
                    {
                        "label": qsTr("3 attempts"),
                        "value": "3"
                    }
                ]
                value: String(root.faceAttemptValue)

                onSelected: value => {
                    root.faceAttemptValue = Number(value);
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            iconName: "camera-web-symbolic"
            note: qsTr("The preview is loaded only while the test screen is open")
            title: qsTr("Camera")

            SettingsSelectRow {
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                enabled: root.cameraDeviceOptions.length > 0 && !FaceAuthService.busy
                label: qsTr("Camera device")
                note: root.cameraDeviceOptions.length > 0 ? qsTr("%1 capture camera(s) detected").arg(root.cameraDeviceOptions.length) : qsTr("Install the updated camera helper, then refresh")
                valueText: root.cameraLabel()

                onClicked: sourceItem => {
                    return root.openCameraPopup(sourceItem);
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface_variant, 0.58)
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: qsTr("Changing the Howdy camera requires administrator authorization")
                    wrapMode: Text.Wrap
                }
                SettingsActionButton {
                    iconName: "camera-photo-symbolic"
                    primary: true
                    text: qsTr("Preview & test")

                    onClicked: {
                        root.cameraPopupOpen = false;
                        root.sessionPopupOpen = false;
                        cameraPreviewLoader.active = true;
                    }
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.tertiary
            compact: true
            iconName: "avatar-default-symbolic"
            note: qsTr("Add models for different lighting or appearance, then test recognition")
            title: qsTr("Face models")

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SettingsTextField {
                    id: modelLabelField

                    Layout.fillWidth: true
                    editable: FaceAuthService.installed && !FaceAuthService.busy
                    inputItem.maximumLength: 24
                    label: qsTr("New model label")
                    placeholder: qsTr("Desk, daylight, glasses…")

                    inputItem.onAccepted: {
                        if (FaceAuthService.installed && !FaceAuthService.busy)
                            FaceAuthService.addModel(modelLabelField.text.trim());
                    }
                }
                SettingsActionButton {
                    Layout.alignment: Qt.AlignBottom
                    enabled: FaceAuthService.installed && !FaceAuthService.busy
                    iconName: "list-add-symbolic"
                    primary: true
                    text: FaceAuthService.activeAction === "add" ? qsTr("Scanning…") : qsTr("Add")

                    onClicked: FaceAuthService.addModel(modelLabelField.text.trim())
                }
                SettingsActionButton {
                    Layout.alignment: Qt.AlignBottom
                    enabled: FaceAuthService.models.length > 0 && !FaceAuthService.busy
                    iconName: "emblem-ok-symbolic"
                    text: FaceAuthService.activeAction === "test" ? qsTr("Testing…") : qsTr("Test")

                    onClicked: FaceAuthService.testModel()
                }
                SettingsActionButton {
                    Layout.alignment: Qt.AlignBottom
                    enabled: !FaceAuthService.busy
                    iconName: "view-refresh-symbolic"
                    iconOnly: true
                    text: qsTr("Refresh face models")

                    onClicked: FaceAuthService.refresh()
                }
            }
            Rectangle {
                Layout.fillWidth: true
                color: Config.alpha(FaceAuthService.statusSuccess ? Config.md3.primary : Config.md3.error, 0.1)
                implicitHeight: statusText.implicitHeight + 22
                radius: 12
                visible: FaceAuthService.statusMessage !== ""

                Text {
                    id: statusText

                    anchors.fill: parent
                    anchors.margins: 11
                    color: FaceAuthService.statusSuccess ? Config.md3.primary : Config.md3.error
                    font.family: Config.fontName
                    font.pixelSize: 13
                    text: FaceAuthService.statusMessage
                    wrapMode: Text.Wrap
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: FaceAuthService.models.length > 0

                Repeater {
                    model: FaceAuthService.models

                    delegate: Rectangle {
                        id: modelRow

                        property bool confirmingRemoval: false
                        required property var modelData

                        Layout.fillWidth: true
                        color: Config.alpha(Config.md3.on_surface, 0.045)
                        implicitHeight: 68
                        radius: 13

                        Timer {
                            id: confirmTimer

                            interval: 2500

                            onTriggered: modelRow.confirmingRemoval = false
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 12

                            Rectangle {
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 40
                                color: Config.alpha(Config.md3.tertiary, 0.15)
                                radius: 12

                                Text {
                                    anchors.centerIn: parent
                                    color: Config.md3.tertiary
                                    font.family: Config.fontName
                                    font.pixelSize: 19
                                    font.weight: Font.Bold
                                    text: "◉"
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: modelRow.modelData.label
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.alpha(Config.md3.on_surface_variant, 0.58)
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    text: qsTr("%1 · ID %2").arg(root.modelDate(modelRow.modelData.time)).arg(modelRow.modelData.id)
                                }
                            }
                            SettingsActionButton {
                                enabled: !FaceAuthService.busy
                                iconName: modelRow.confirmingRemoval ? "dialog-warning-symbolic" : "user-trash-symbolic"
                                text: modelRow.confirmingRemoval ? qsTr("Confirm") : qsTr("Remove")

                                onClicked: {
                                    if (!modelRow.confirmingRemoval) {
                                        modelRow.confirmingRemoval = true;
                                        confirmTimer.restart();
                                    } else {
                                        confirmTimer.stop();
                                        FaceAuthService.removeModel(modelRow.modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface_variant, 0.62)
                font.family: Config.fontName
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                text: FaceAuthService.installed ? qsTr("No face models yet") : qsTr("Howdy support is missing")
                visible: FaceAuthService.models.length === 0
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            iconName: "preferences-desktop-display-symbolic"
            note: qsTr("Boot login remains password-only; these options only choose the desktop session")
            title: qsTr("Greeter")

            SettingsSelectRow {
                accentColor: Config.md3.secondary
                label: qsTr("Default desktop session")
                note: qsTr("Automatic uses the installer fallback when no remembered session is available")
                valueText: root.greeterSessionLabel()

                onClicked: sourceItem => {
                    return root.openSessionPopup(sourceItem);
                }
            }
            SettingsToggleRow {
                checked: root.greeterRememberLastSessionValue
                label: qsTr("Remember last session")
                note: qsTr("Use the session selected on the previous successful login")

                onToggled: value => {
                    return root.greeterRememberLastSessionValue = value;
                }
            }
            Text {
                Layout.fillWidth: true
                color: GreeterSettingsService.errorMessage !== "" ? Config.md3.error : Config.alpha(Config.md3.on_surface_variant, 0.58)
                font.family: Config.fontName
                font.pixelSize: 12
                text: GreeterSettingsService.errorMessage || GreeterSettingsService.statusMessage
                visible: text !== ""
                wrapMode: Text.Wrap
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.primary
            compact: true
            iconName: "preferences-system-notifications-symbolic"
            note: qsTr("Control what appears before the session is authenticated")
            title: qsTr("Lock screen notifications")

            SettingsChoiceRow {
                Layout.fillWidth: true
                label: qsTr("Content visibility")
                note: qsTr("Icons only keeps application context without exposing message text")
                options: [
                    {
                        "label": qsTr("Hidden"),
                        "value": "hidden"
                    },
                    {
                        "label": qsTr("Icons only"),
                        "value": "icons"
                    },
                    {
                        "label": qsTr("Full content"),
                        "value": "full"
                    }
                ]
                value: root.lockPrivacyValue

                onSelected: value => {
                    root.lockPrivacyValue = value;
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.error
            compact: true
            iconName: "dialog-warning-symbolic"
            note: qsTr("RGB face recognition is convenient, not equivalent to a depth or infrared sensor")
            title: qsTr("Security note")

            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface_variant, 0.72)
                font.family: Config.fontName
                font.pixelSize: 13
                text: qsTr("Face unlock may be fooled by a photo or video. Keep your password private and available. Successful and failed camera snapshots remain disabled.")
                wrapMode: Text.Wrap
            }
        }
    }
    SelectPopup {
        accentColor: Config.md3.secondary
        anchors.fill: parent
        itemActive: item => {
            return item && [item.path, item.device].indexOf(FaceAuthService.camera) >= 0;
        }
        model: root.cameraDeviceOptions
        openAbove: root.cameraPopupOpenAbove
        opened: root.cameraPopupOpen
        popupWidth: 320
        popupY: root.cameraPopupY
        rightMargin: root.cameraPopupRightMargin
        z: 40

        onDismissed: root.cameraPopupOpen = false
        onItemSelected: item => {
            return root.selectCamera(item);
        }
    }
    SelectPopup {
        accentColor: Config.md3.secondary
        anchors.fill: parent
        itemActive: item => {
            return item && String(item.value) === root.greeterSessionValue;
        }
        model: root.greeterSessionOptions
        openAbove: root.sessionPopupOpenAbove
        opened: root.sessionPopupOpen
        popupWidth: 260
        popupY: root.sessionPopupY
        rightMargin: root.sessionPopupRightMargin
        z: 40

        onDismissed: root.sessionPopupOpen = false
        onItemSelected: item => {
            return root.selectGreeterSession(item);
        }
    }
    Loader {
        id: cameraPreviewLoader

        active: false
        anchors.fill: parent
        asynchronous: true
        source: Qt.resolvedUrl("FaceCameraPreview.qml")
        z: 100
    }
    Connections {
        function onCloseRequested() {
            cameraPreviewLoader.active = false;
        }

        target: cameraPreviewLoader.status === Loader.Ready ? cameraPreviewLoader.item : null
    }
}
