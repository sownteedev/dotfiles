import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string baselineState: ""
    property bool capturePopupOpen: false
    property bool capturePopupOpenAbove: false
    property real capturePopupRightMargin: 12
    property string capturePopupTarget: ""
    property real capturePopupY: 0
    property string editorDefaultTool: "pen"
    readonly property var editorToolOptions: [
        {
            "label": qsTr("Select and move"),
            "value": "select"
        },
        {
            "label": qsTr("Pen"),
            "value": "pen"
        },
        {
            "label": qsTr("Highlighter"),
            "value": "highlight"
        },
        {
            "label": qsTr("Line"),
            "value": "line"
        },
        {
            "label": qsTr("Arrow"),
            "value": "arrow"
        },
        {
            "label": qsTr("Rectangle"),
            "value": "rectangle"
        },
        {
            "label": qsTr("Ellipse"),
            "value": "ellipse"
        },
        {
            "label": qsTr("Blur"),
            "value": "blur"
        },
        {
            "label": qsTr("Pixelate"),
            "value": "pixelate"
        },
        {
            "label": qsTr("Text"),
            "value": "text"
        },
        {
            "label": qsTr("Number marker"),
            "value": "number"
        },
        {
            "label": qsTr("Zoom callout"),
            "value": "callout"
        },
        {
            "label": qsTr("Magnifier"),
            "value": "loupe"
        },
        {
            "label": qsTr("Crop"),
            "value": "crop"
        },
        {
            "label": qsTr("OCR"),
            "value": "ocr"
        },
        {
            "label": qsTr("Eraser"),
            "value": "eraser"
        }
    ]
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState
    readonly property var recordingMicrophoneOptions: {
        var options = (CaptureService.recordingMicrophoneOptions || []).slice();
        var current = String(recordingMicrophoneSource || "default_input");
        var present = false;
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === current) {
                present = true;
                break;
            }
        }
        if (!present)
            options.push({
                "label": qsTr("Unavailable device"),
                "value": current
            });

        return options;
    }
    property string recordingMicrophoneSource: "default_input"

    function capturePopupOptions() {
        return capturePopupTarget === "editor-tool" ? editorToolOptions : recordingMicrophoneOptions;
    }
    function capturePopupValue() {
        return capturePopupTarget === "editor-tool" ? editorDefaultTool : recordingMicrophoneSource;
    }
    function closeCapturePopup() {
        capturePopupOpen = false;
    }
    function currentState() {
        return {
            "captureScreenshotDirPath": screenshotDirField.text,
            "captureRecordingDirPath": recordingDirField.text,
            "captureAutoCopyScreenshot": copyScreenshotToggle.checked,
            "captureAutoCopyRecording": copyRecordingToggle.checked,
            "captureRecordingFps": Number(recordingFpsField.text),
            "captureRecordingCodec": recordingCodecChoice.value,
            "captureRecordingCountdown": Number(recordingCountdownChoice.value),
            "captureRecordingCursor": recordingCursorToggle.checked,
            "captureRecordingQuality": recordingQualityChoice.value,
            "captureRecordingMicrophone": recordingMicrophoneToggle.checked,
            "captureRecordingMicrophoneSource": recordingMicrophoneSource,
            "captureRecordingMode": recordingModeChoice.value,
            "captureScreenshotAction": screenshotActionChoice.value,
            "captureScreenshotFilenameTemplate": screenshotFilenameField.text,
            "captureScreenshotFormat": screenshotFormatChoice.value,
            "captureScreenshotQuality": Number(screenshotQualityField.text),
            "captureEditorTool": editorDefaultTool
        };
    }
    function openCapturePopup(sourceItem, target) {
        if (!sourceItem)
            return;

        if (capturePopupOpen && capturePopupTarget === target) {
            closeCapturePopup();
            return;
        }
        if (target === "microphone")
            CaptureService.refreshRecordingMicrophones();

        capturePopupTarget = target;
        var position = sourceItem.mapToItem(root, 0, 0);
        var popupHeight = Math.min(height - 24, capturePopupOptions().length * 44 + 16);
        var belowY = position.y + sourceItem.height + 8;
        capturePopupOpenAbove = belowY + popupHeight > height;
        capturePopupY = capturePopupOpenAbove ? position.y - popupHeight - 8 : belowY;
        capturePopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        capturePopupOpen = true;
    }
    function optionLabel(options, value, fallback) {
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === String(value))
                return String(options[i].label);
        }
        return fallback;
    }
    function resetPage() {
        syncFields();
    }
    function selectCapturePopupItem(item) {
        if (!item)
            return;

        if (capturePopupTarget === "editor-tool")
            editorDefaultTool = String(item.value);
        else
            recordingMicrophoneSource = String(item.value);
        closeCapturePopup();
    }
    function syncFields() {
        closeCapturePopup();
        var settings = SettingsHubService.quickshellSettings || ({});
        screenshotDirField.text = settings.captureScreenshotDirPath || Config.captureScreenshotDirPath;
        recordingDirField.text = settings.captureRecordingDirPath || Config.captureRecordingDirPath;
        copyScreenshotToggle.checked = settings.captureAutoCopyScreenshot ?? Config.captureAutoCopyScreenshot;
        copyRecordingToggle.checked = settings.captureAutoCopyRecording ?? Config.captureAutoCopyRecording;
        recordingFpsField.text = String(settings.captureRecordingFps ?? Config.captureRecordingFps);
        recordingCodecChoice.value = settings.captureRecordingCodec || Config.captureRecordingCodec;
        recordingCountdownChoice.value = String(settings.captureRecordingCountdown ?? Config.captureRecordingCountdown);
        recordingCursorToggle.checked = settings.captureRecordingCursor ?? Config.captureRecordingCursor;
        recordingQualityChoice.value = settings.captureRecordingQuality || Config.captureRecordingQuality;
        recordingMicrophoneToggle.checked = settings.captureRecordingMicrophone ?? Config.captureRecordingMicrophone;
        recordingMicrophoneSource = settings.captureRecordingMicrophoneSource || Config.captureRecordingMicrophoneSource;
        recordingModeChoice.value = settings.captureRecordingMode || Config.captureRecordingMode;
        screenshotActionChoice.value = settings.captureScreenshotAction || Config.captureScreenshotAction;
        screenshotFilenameField.text = settings.captureScreenshotFilenameTemplate || Config.captureScreenshotFilenameTemplate;
        screenshotFormatChoice.value = settings.captureScreenshotFormat || Config.captureScreenshotFormat;
        screenshotQualityField.text = String(settings.captureScreenshotQuality ?? Config.captureScreenshotQuality);
        editorDefaultTool = settings.captureEditorTool || Config.captureEditorTool;
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: {
        syncFields();
        CaptureService.refreshRecordingMicrophones();
    }

    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    ScrollView {
        id: scroll

        anchors.fill: parent
        contentHeight: content.implicitHeight
        contentWidth: availableWidth

        ScrollBar.horizontal: SlimScrollBar {
            accentColor: Config.md3.primary
        }
        ScrollBar.vertical: SlimScrollBar {
            accentColor: Config.md3.primary
        }

        GridLayout {
            id: content

            columnSpacing: 12
            columns: 1
            rowSpacing: 12
            uniformCellWidths: true
            width: scroll.availableWidth
            x: (scroll.availableWidth - width) / 2

            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                iconName: "folder-symbolic"
                note: "The screenshot path is also written to Niri so the watcher stays in sync"
                title: "Storage"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    SettingsTextField {
                        id: screenshotDirField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: "Screenshot folder"
                        placeholder: "~/Pictures/Screenshots"

                        onActionClicked: {
                            SettingsHubService.filePickerDialog.open(screenshotDirField, "file://" + Config.expandHomePath("~"), true);
                        }
                    }
                    SettingsTextField {
                        id: recordingDirField

                        Layout.fillWidth: true
                        actionIcon: "folder-open-symbolic"
                        label: "Recording folder"
                        placeholder: "~/Videos"

                        onActionClicked: {
                            SettingsHubService.filePickerDialog.open(recordingDirField, "file://" + Config.expandHomePath("~"), true);
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                iconName: "camera-photo-symbolic"
                note: qsTr("Choose what happens after capture and how images are exported")
                title: qsTr("Screenshot")

                SettingsSelectRow {
                    label: qsTr("Default editor tool")
                    note: qsTr("Selected automatically whenever Screenshot Editor opens")
                    valueText: root.optionLabel(root.editorToolOptions, root.editorDefaultTool, qsTr("Pen"))

                    onClicked: sourceItem => {
                        return root.openCapturePopup(sourceItem, "editor-tool");
                    }
                }
                SettingsChoiceRow {
                    id: screenshotActionChoice

                    Layout.fillWidth: true
                    label: qsTr("After capture")
                    options: [
                        {
                            "label": qsTr("Notification"),
                            "value": "notification"
                        },
                        {
                            "label": qsTr("Open editor"),
                            "value": "editor"
                        },
                        {
                            "label": qsTr("Copy directly"),
                            "value": "copy"
                        },
                        {
                            "label": qsTr("Save only"),
                            "value": "save"
                        }
                    ]
                }
                SettingsChoiceRow {
                    id: screenshotFormatChoice

                    Layout.fillWidth: true
                    label: qsTr("Image format")
                    note: qsTr("JPEG and WebP use the quality value below")
                    options: [
                        {
                            "label": "PNG",
                            "value": "png"
                        },
                        {
                            "label": "JPEG",
                            "value": "jpeg"
                        },
                        {
                            "label": "WebP",
                            "value": "webp"
                        }
                    ]
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: screenshotQualityField.visible && width >= 620 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: screenshotFilenameField

                        Layout.fillWidth: true
                        label: qsTr("Edited filename · {date} and {time}")
                        placeholder: "{date}_{time}-edited"
                    }
                    SettingsTextField {
                        id: screenshotQualityField

                        Layout.fillWidth: true
                        label: qsTr("Image quality (1–100)")
                        placeholder: "90"
                        visible: screenshotFormatChoice.value !== "png"

                        inputItem.validator: IntValidator {
                            bottom: 1
                            top: 100
                        }
                    }
                }
                SettingsToggleRow {
                    id: copyScreenshotToggle

                    label: qsTr("Copy edited screenshot")
                    note: qsTr("Places the final exported image on the clipboard")

                    onToggled: value => {
                        return checked = value;
                    }
                }
            }
            SettingsSectionCard {
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                compact: true
                iconName: "media-record-symbolic"
                note: qsTr("Capture area, encoding and recording behavior")
                title: qsTr("Recording")

                GridLayout {
                    id: recordingGroupGrid

                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 900 ? 3 : width >= 620 ? 2 : 1
                    rowSpacing: 12
                    uniformCellWidths: true

                    Rectangle {
                        id: recordingCapturePanel

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        border.color: Config.alpha(Config.md3.on_surface, 0.065)
                        border.width: 1
                        color: Config.alpha(Config.md3.on_surface, 0.035)
                        implicitHeight: recordingCaptureContent.implicitHeight + 28
                        radius: 14

                        ColumnLayout {
                            id: recordingCaptureContent

                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.preferredHeight: 30
                                    Layout.preferredWidth: 4
                                    color: Config.md3.primary
                                    radius: 2
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        text: qsTr("Capture")
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.alpha(Config.md3.on_surface, 0.46)
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 11
                                        text: qsTr("Area and start delay")
                                    }
                                }
                            }
                            SettingsChoiceRow {
                                id: recordingModeChoice

                                Layout.fillWidth: true
                                label: qsTr("Capture area")
                                options: [
                                    {
                                        "label": qsTr("Region"),
                                        "value": "region"
                                    },
                                    {
                                        "label": qsTr("Full screen"),
                                        "value": "screen"
                                    }
                                ]
                            }
                            SettingsChoiceRow {
                                id: recordingCountdownChoice

                                Layout.fillWidth: true
                                label: qsTr("Start delay")
                                options: [
                                    {
                                        "label": qsTr("Off"),
                                        "value": "0"
                                    },
                                    {
                                        "label": qsTr("3 s"),
                                        "value": "3"
                                    },
                                    {
                                        "label": qsTr("5 s"),
                                        "value": "5"
                                    },
                                    {
                                        "label": qsTr("10 s"),
                                        "value": "10"
                                    }
                                ]
                            }
                        }
                    }
                    Rectangle {
                        id: recordingEncodingPanel

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        border.color: Config.alpha(Config.md3.on_surface, 0.065)
                        border.width: 1
                        color: Config.alpha(Config.md3.on_surface, 0.035)
                        implicitHeight: recordingEncodingContent.implicitHeight + 28
                        radius: 14

                        ColumnLayout {
                            id: recordingEncodingContent

                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.preferredHeight: 30
                                    Layout.preferredWidth: 4
                                    color: Config.md3.secondary
                                    radius: 2
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        text: qsTr("Encoding")
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.alpha(Config.md3.on_surface, 0.46)
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 11
                                        text: qsTr("Frame rate, codec and quality")
                                    }
                                }
                            }
                            SettingsTextField {
                                id: recordingFpsField

                                Layout.fillWidth: true
                                label: qsTr("Frame rate (FPS)")
                                placeholder: "60"

                                inputItem.validator: IntValidator {
                                    bottom: 5
                                    top: 165
                                }
                            }
                            SettingsChoiceRow {
                                id: recordingCodecChoice

                                Layout.fillWidth: true
                                label: qsTr("Codec")
                                options: [
                                    {
                                        "label": "H.264",
                                        "value": "h264"
                                    },
                                    {
                                        "label": "HEVC",
                                        "value": "hevc"
                                    }
                                ]
                            }
                            SettingsChoiceRow {
                                id: recordingQualityChoice

                                Layout.fillWidth: true
                                label: qsTr("Quality")
                                options: [
                                    {
                                        "label": qsTr("Medium"),
                                        "value": "medium"
                                    },
                                    {
                                        "label": qsTr("High"),
                                        "value": "high"
                                    },
                                    {
                                        "label": qsTr("Very high"),
                                        "value": "very_high"
                                    }
                                ]
                            }
                        }
                    }
                    Rectangle {
                        id: recordingBehaviorPanel

                        Layout.columnSpan: recordingGroupGrid.columns === 2 ? 2 : 1
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        border.color: Config.alpha(Config.md3.on_surface, 0.065)
                        border.width: 1
                        color: Config.alpha(Config.md3.on_surface, 0.035)
                        implicitHeight: recordingBehaviorContent.implicitHeight + 28
                        radius: 14

                        ColumnLayout {
                            id: recordingBehaviorContent

                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    Layout.preferredHeight: 30
                                    Layout.preferredWidth: 4
                                    color: Config.md3.tertiary
                                    radius: 2
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.md3.on_surface
                                        font.family: Config.fontName
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        text: qsTr("Behavior")
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        color: Config.alpha(Config.md3.on_surface, 0.46)
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 11
                                        text: qsTr("Cursor, microphone and clipboard")
                                    }
                                }
                            }
                            GridLayout {
                                id: recordingBehaviorGrid

                                Layout.fillWidth: true
                                columnSpacing: 12
                                columns: recordingBehaviorPanel.width >= 760 ? 3 : recordingBehaviorPanel.width >= 500 ? 2 : 1
                                rowSpacing: 4
                                uniformCellWidths: true

                                SettingsToggleRow {
                                    id: recordingCursorToggle

                                    label: qsTr("Capture cursor")
                                    note: qsTr("Show the pointer in the video")

                                    onToggled: value => {
                                        return checked = value;
                                    }
                                }
                                SettingsToggleRow {
                                    id: recordingMicrophoneToggle

                                    label: qsTr("Record microphone")
                                    note: qsTr("Mix voice with system audio")

                                    onToggled: value => {
                                        return checked = value;
                                    }
                                }
                                SettingsToggleRow {
                                    id: copyRecordingToggle

                                    label: qsTr("Copy after stop")
                                    note: qsTr("Copy the recording as a file")

                                    onToggled: value => {
                                        return checked = value;
                                    }
                                }
                                SettingsSelectRow {
                                    Layout.columnSpan: recordingBehaviorGrid.columns
                                    enabled: recordingMicrophoneToggle.checked
                                    label: qsTr("Microphone source")
                                    note: CaptureService.recordingMicrophoneQueryBusy ? qsTr("Refreshing available devices…") : qsTr("Select the input device used for your voice")
                                    valueText: root.optionLabel(root.recordingMicrophoneOptions, root.recordingMicrophoneSource, qsTr("Default microphone"))
                                    visible: recordingMicrophoneToggle.checked

                                    onClicked: sourceItem => {
                                        return root.openCapturePopup(sourceItem, "microphone");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    SelectPopup {
        accentColor: Config.md3.primary
        anchors.fill: parent
        itemActive: item => {
            return item && String(item.value) === root.capturePopupValue();
        }
        model: root.capturePopupOptions()
        openAbove: root.capturePopupOpenAbove
        opened: root.capturePopupOpen
        popupWidth: root.capturePopupTarget === "microphone" ? 360 : 260
        popupY: root.capturePopupY
        rightMargin: root.capturePopupRightMargin
        rowHeight: 44
        z: 30

        onDismissed: root.closeCapturePopup()
        onItemSelected: item => {
            return root.selectCapturePopupItem(item);
        }
    }
    Connections {
        function onMovementStarted() {
            root.closeCapturePopup();
        }

        target: scroll.contentItem
    }
}
