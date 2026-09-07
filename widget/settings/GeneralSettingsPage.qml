import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string baselineState: ""
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState
    property QtObject profileImageField: QtObject {
        property string text: ""
    }

    function currentState() {
        return {
            "fontName": fontField.text,
            "profileImagePath": profileImageField.text,
            "shellBlurBarEnabled": barBlurToggle.checked,
            "shellBlurBarOpacityDark": barOpacityDarkField.text === "" ? Config.shellBlurBarOpacityDark : Number(barOpacityDarkField.text),
            "shellBlurBarOpacityLight": barOpacityLightField.text === "" ? Config.shellBlurBarOpacityLight : Number(barOpacityLightField.text),
            "shellBlurControlLeftEnabled": controlLeftBlurToggle.checked,
            "shellBlurControlRightEnabled": controlRightBlurToggle.checked,
            "shellBlurDockEnabled": dockBlurToggle.checked,
            "shellBlurLauncherEnabled": launcherBlurToggle.checked,
            "shellBlurNotificationEnabled": notificationBlurToggle.checked,
            "shellBlurOsdEnabled": osdBlurToggle.checked,
            "shellBlurPanelOpacityDark": panelOpacityDarkField.text === "" ? Config.shellBlurPanelOpacityDark : Number(panelOpacityDarkField.text),
            "shellBlurPanelOpacityLight": panelOpacityLightField.text === "" ? Config.shellBlurPanelOpacityLight : Number(panelOpacityLightField.text),
            "shellBlurSettingsEnabled": settingsBlurToggle.checked,
            "shellComponentShadowBlur": componentShadowBlurField.text === "" ? Config.shellComponentShadowBlur : Number(componentShadowBlurField.text),
            "shellComponentShadowEnabled": componentShadowEnabledToggle.checked,
            "shellComponentShadowOffsetX": componentShadowOffsetXField.text === "" ? Config.shellComponentShadowOffsetX : Number(componentShadowOffsetXField.text),
            "shellComponentShadowOffsetY": componentShadowOffsetYField.text === "" ? Config.shellComponentShadowOffsetY : Number(componentShadowOffsetYField.text),
            "shellComponentShadowOpacity": componentShadowOpacityField.text === "" ? Config.shellComponentShadowOpacity : Number(componentShadowOpacityField.text),
            "shellComponentShadowSpread": componentShadowSpreadField.text === "" ? Config.shellComponentShadowSpread : Number(componentShadowSpreadField.text),
            "shellShadowBlur": Number(shadowBlurField.text),
            "shellShadowEnabled": shadowEnabledToggle.checked,
            "shellShadowOffsetX": Number(shadowOffsetXField.text),
            "shellShadowOffsetY": Number(shadowOffsetYField.text),
            "shellShadowOpacity": Number(shadowOpacityField.text),
            "shellShadowSpread": Number(shadowSpreadField.text),
            "clock24h": clockToggle.checked,
            "temperatureUnit": temperatureUnitChoice.value
        };
    }
    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        fontField.text = settings.fontName || Config.fontName;
        profileImageField.text = settings.profileImagePath || Config.profileImagePath;
        barBlurToggle.checked = settings.shellBlurBarEnabled ?? Config.shellBlurBarEnabled;
        barOpacityDarkField.text = String(settings.shellBlurBarOpacityDark ?? Config.shellBlurBarOpacityDark);
        barOpacityLightField.text = String(settings.shellBlurBarOpacityLight ?? Config.shellBlurBarOpacityLight);
        controlLeftBlurToggle.checked = settings.shellBlurControlLeftEnabled ?? Config.shellBlurControlLeftEnabled;
        controlRightBlurToggle.checked = settings.shellBlurControlRightEnabled ?? Config.shellBlurControlRightEnabled;
        dockBlurToggle.checked = settings.shellBlurDockEnabled ?? Config.shellBlurDockEnabled;
        launcherBlurToggle.checked = settings.shellBlurLauncherEnabled ?? Config.shellBlurLauncherEnabled;
        notificationBlurToggle.checked = settings.shellBlurNotificationEnabled ?? Config.shellBlurNotificationEnabled;
        osdBlurToggle.checked = settings.shellBlurOsdEnabled ?? Config.shellBlurOsdEnabled;
        panelOpacityDarkField.text = String(settings.shellBlurPanelOpacityDark ?? Config.shellBlurPanelOpacityDark);
        panelOpacityLightField.text = String(settings.shellBlurPanelOpacityLight ?? Config.shellBlurPanelOpacityLight);
        settingsBlurToggle.checked = settings.shellBlurSettingsEnabled ?? Config.shellBlurSettingsEnabled;
        componentShadowBlurField.text = String(settings.shellComponentShadowBlur ?? Config.shellComponentShadowBlur);
        componentShadowEnabledToggle.checked = settings.shellComponentShadowEnabled ?? Config.shellComponentShadowEnabled;
        componentShadowOffsetXField.text = String(settings.shellComponentShadowOffsetX ?? Config.shellComponentShadowOffsetX);
        componentShadowOffsetYField.text = String(settings.shellComponentShadowOffsetY ?? Config.shellComponentShadowOffsetY);
        componentShadowOpacityField.text = String(settings.shellComponentShadowOpacity ?? Config.shellComponentShadowOpacity);
        componentShadowSpreadField.text = String(settings.shellComponentShadowSpread ?? Config.shellComponentShadowSpread);
        shadowBlurField.text = String(settings.shellShadowBlur ?? Config.shellShadowBlur);
        shadowEnabledToggle.checked = settings.shellShadowEnabled ?? Config.shellShadowEnabled;
        shadowOffsetXField.text = String(settings.shellShadowOffsetX ?? Config.shellShadowOffsetX);
        shadowOffsetYField.text = String(settings.shellShadowOffsetY ?? Config.shellShadowOffsetY);
        shadowOpacityField.text = String(settings.shellShadowOpacity ?? Config.shellShadowOpacity);
        shadowSpreadField.text = String(settings.shellShadowSpread ?? Config.shellShadowSpread);
        clockToggle.checked = settings.clock24h ?? Config.clock24h;
        temperatureUnitChoice.value = settings.temperatureUnit || Config.temperatureUnit;
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: {
        syncFields();
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
            accentColor: Config.md3.secondary
        }
        ScrollBar.vertical: SlimScrollBar {
            accentColor: Config.md3.secondary
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
                accentColor: Config.md3.secondary
                iconName: "avatar-default-symbolic"
                note: qsTr("Used by authentication prompts and the login screen")
                title: qsTr("Profile image")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    ProfileAvatar {
                        Layout.preferredHeight: 76
                        Layout.preferredWidth: 76
                        sourcePath: root.profileImageField.text
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideMiddle
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: root.profileImageField.text === "" ? qsTr("Default profile icon") : root.profileImageField.text.split("/").pop()
                        }
                        Text {
                            Layout.fillWidth: true
                            color: ProfileImageService.errorMessage !== "" ? Config.md3.error : Config.alpha(Config.md3.on_surface, 0.5)
                            font.family: Config.fontName
                            font.pixelSize: 12
                            text: ProfileImageService.errorMessage || ProfileImageService.statusMessage || qsTr("PNG, JPEG, WebP or AVIF")
                            wrapMode: Text.Wrap
                        }
                    }
                    SettingsActionButton {
                        iconName: "document-open-symbolic"
                        iconOnly: true
                        text: qsTr("Choose image")

                        onClicked: SettingsHubService.filePickerDialog.open(root.profileImageField, "file://" + Config.expandHomePath("~"), false, [qsTr("Images | *.png *.jpg *.jpeg *.webp *.avif")])
                    }
                    SettingsActionButton {
                        enabled: root.profileImageField.text !== ""
                        iconName: "user-trash-symbolic"
                        iconOnly: true
                        text: qsTr("Remove profile image")

                        onClicked: root.profileImageField.text = ""
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                iconName: "preferences-desktop-font-symbolic"
                note: "Shell typography"
                title: "Typography"

                SettingsFontPicker {
                    id: fontField

                    Layout.fillWidth: true
                    label: "Font family"
                    placeholder: Config.fontName
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.secondary
                iconName: "weather-fog-symbolic"
                note: "Higher values make surfaces more opaque"
                title: "Surface blur"

                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: width >= 620 ? 2 : 1
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: panelOpacityLightField

                        Layout.fillWidth: true
                        label: "Panels · Light mode"
                        placeholder: "0.88"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: panelOpacityDarkField

                        Layout.fillWidth: true
                        label: "Panels · Dark mode"
                        placeholder: "0.76"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: barOpacityLightField

                        Layout.fillWidth: true
                        label: "Bar · Light mode"
                        placeholder: "0.86"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: barOpacityDarkField

                        Layout.fillWidth: true
                        label: "Bar · Dark mode"
                        placeholder: "0.24"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: width >= 620 ? 2 : 1
                    rowSpacing: 4
                    uniformCellWidths: true

                    SettingsToggleTile {
                        id: barBlurToggle

                        label: "Bar"

                        onToggled: value => {
                            return checked = value;
                        }
                    }
                    SettingsToggleTile {
                        id: launcherBlurToggle

                        label: "Launcher"

                        onToggled: value => {
                            return checked = value;
                        }
                    }
                    SettingsToggleTile {
                        id: osdBlurToggle

                        label: "OSD"

                        onToggled: value => {
                            return checked = value;
                        }
                    }
                    SettingsToggleTile {
                        id: notificationBlurToggle

                        label: "Notifications"

                        onToggled: value => {
                            return checked = value;
                        }
                    }
                    SettingsToggleTile {
                        id: settingsBlurToggle

                        label: "Settings"

                        onToggled: value => {
                            return checked = value;
                        }
                    }
                    SettingsToggleTile {
                        id: controlLeftBlurToggle

                        label: "Control Left"

                        onToggled: value => {
                            return checked = value;
                        }
                    }
                    SettingsToggleTile {
                        id: controlRightBlurToggle

                        label: "Control Right"

                        onToggled: value => {
                            return checked = value;
                        }
                    }
                    SettingsToggleTile {
                        id: dockBlurToggle

                        label: "Dock"

                        onToggled: value => {
                            return checked = value;
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                iconName: "preferences-desktop-effects-symbolic"
                note: "Shadow used by large panels, dialogs and popups"
                title: "Panel shadows"

                SettingsToggleTile {
                    id: shadowEnabledToggle

                    label: "Enable panel shadows"
                    note: "Uses the current Material You shadow color"

                    onToggled: value => {
                        return checked = value;
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: width >= 620 ? 3 : 2
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: shadowBlurField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Blur (0–64)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "18"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 64
                        }
                    }
                    SettingsTextField {
                        id: shadowOpacityField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Opacity (0–1)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0.28"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: shadowSpreadField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Spread (-32–32)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "1"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsTextField {
                        id: shadowOffsetXField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Horizontal offset"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsTextField {
                        id: shadowOffsetYField

                        Layout.fillWidth: true
                        editable: shadowEnabledToggle.checked
                        label: "Vertical offset"
                        opacity: editable ? 1 : 0.45
                        placeholder: "3"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                iconName: "color-select-symbolic"
                note: "Lighter shadow for buttons, tabs and compact controls"
                title: "Component shadows"

                SettingsToggleTile {
                    id: componentShadowEnabledToggle

                    label: "Enable component shadows"
                    note: "Independent from panel shadow settings"

                    onToggled: value => {
                        return checked = value;
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 10
                    columns: width >= 620 ? 3 : 2
                    rowSpacing: 10
                    uniformCellWidths: true

                    SettingsTextField {
                        id: componentShadowBlurField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Blur (0–64)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "10"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 64
                        }
                    }
                    SettingsTextField {
                        id: componentShadowOpacityField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Opacity (0–1)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0.18"

                        inputItem.validator: DoubleValidator {
                            bottom: 0
                            decimals: 2
                            notation: DoubleValidator.StandardNotation
                            top: 1
                        }
                    }
                    SettingsTextField {
                        id: componentShadowSpreadField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Spread (-32–32)"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsTextField {
                        id: componentShadowOffsetXField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Horizontal offset"
                        opacity: editable ? 1 : 0.45
                        placeholder: "0"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsTextField {
                        id: componentShadowOffsetYField

                        Layout.fillWidth: true
                        editable: componentShadowEnabledToggle.checked
                        label: "Vertical offset"
                        opacity: editable ? 1 : 0.45
                        placeholder: "2"

                        inputItem.validator: DoubleValidator {
                            bottom: -32
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                }
            }
            SettingsSectionCard {
                Layout.columnSpan: content.columns
                Layout.fillWidth: true
                accentColor: Config.md3.primary
                compact: true
                iconName: "preferences-system-time-symbolic"
                note: qsTr("Regional date, time and temperature presentation")
                title: "Date & time"

                SettingsToggleTile {
                    id: clockToggle

                    label: "Use 24-hour time format"
                    note: "Turn off to use 12-hour AM/PM format"

                    onToggled: value => {
                        return checked = value;
                    }
                }
                SettingsChoiceRow {
                    id: temperatureUnitChoice

                    Layout.fillWidth: true
                    label: qsTr("Temperature unit")
                    note: qsTr("Used by weather on the bar, lock screen and Control Left")
                    options: [
                        {
                            "label": qsTr("Celsius (°C)"),
                            "value": "celsius"
                        },
                        {
                            "label": qsTr("Fahrenheit (°F)"),
                            "value": "fahrenheit"
                        }
                    ]
                }
            }
        }
    }
}
