import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property string activePopupKind: ""
    property var activePopupModel: []
    property string baselineState: ""
    readonly property var cursorSizeOptions: [16, 20, 24, 28, 32, 36, 40, 48, 56, 64]
    property int cursorSizeValue: 24
    property string cursorThemeValue: "Dark_Cursor"
    readonly property var defaultQtDialogOptions: [
        {
            "label": "Default",
            "value": "default"
        },
        {
            "label": "GTK3",
            "value": "gtk3"
        },
        {
            "label": "XDG Desktop Portal",
            "value": "xdgdesktopportal"
        }
    ]
    readonly property bool gtkFontSizeValid: {
        var size = Number(gtkFontSizeField.text);
        return gtkFontSizeField.text !== "" && !isNaN(size) && size >= 6 && size <= 32;
    }
    property string gtkThemeValue: "adw-gtk3-dark"
    readonly property bool headerActionEnabled: !SettingsHubService.busy && gtkFontSizeValid
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(pageState()) !== baselineState
    property string iconThemeValue: "WhiteSur"
    property QtObject profileImageField: QtObject {
        property string text: ""
    }
    property string qtColorSchemeValue: "matugen"
    readonly property var qtDialogOptions: (SettingsHubService.gtkSettings && SettingsHubService.gtkSettings.qtDialogOptions && SettingsHubService.gtkSettings.qtDialogOptions.length > 0) ? SettingsHubService.gtkSettings.qtDialogOptions : defaultQtDialogOptions
    property string qtDialogsValue: "gtk3"
    property string qtStyleValue: "kvantum"
    property bool selectorPopupOpen: false
    property bool selectorPopupOpenAbove: false
    property real selectorPopupRightMargin: 12
    property real selectorPopupY: 0

    function currentPopupValue() {
        switch (activePopupKind) {
        case "gtk":
            return gtkThemeValue;
        case "icons":
            return iconThemeValue;
        case "cursor":
            return cursorThemeValue;
        case "cursorSize":
            return String(cursorSizeValue);
        case "qtStyle":
            return qtStyleValue;
        case "qtColorScheme":
            return qtColorSchemeValue;
        case "qtDialogs":
            return qtDialogsValue;
        default:
            return "";
        }
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
    function gtkState() {
        return {
            "gtkTheme": gtkThemeValue,
            "iconTheme": iconThemeValue,
            "cursorTheme": cursorThemeValue,
            "cursorSize": cursorSizeValue,
            "fontName": gtkFontFamilyField.text.trim() + " " + normalizedGtkFontSize(),
            "qtStyle": qtStyleValue,
            "qtColorScheme": qtColorSchemeValue,
            "qtDialogs": qtDialogsValue
        };
    }
    function normalizedGtkFontSize() {
        var size = Number(gtkFontSizeField.text);
        return !isNaN(size) && size >= 6 && size <= 32 ? String(size) : "10.5";
    }
    function openSelector(sourceItem, kind, values) {
        selectorPopupOpen = false;
        activePopupKind = kind;
        activePopupModel = optionModel(values, currentPopupValue());

        var position = sourceItem.mapToItem(root, 0, 0);
        var popupHeight = Math.min(activePopupModel.length * 46 + 16, height - 24);
        var belowY = position.y + sourceItem.height + 8;
        selectorPopupOpenAbove = belowY + popupHeight > height - 12 && position.y >= popupHeight + 20;
        selectorPopupY = selectorPopupOpenAbove ? position.y - popupHeight - 8 : belowY;
        selectorPopupRightMargin = Math.max(12, width - position.x - sourceItem.width);
        selectorPopupOpen = activePopupModel.length > 0;
    }
    function optionModel(values, currentValue) {
        var result = [];
        var seen = {};
        var source = values || [];
        for (var index = 0; index < source.length; ++index) {
            var item = source[index];
            var val = typeof item === "object" && item !== null && item.value !== undefined ? String(item.value) : String(item);
            var lbl = typeof item === "object" && item !== null && item.label !== undefined ? String(item.label) : (activePopupKind === "cursorSize" ? qsTr("%1 px").arg(val) : val);
            if (val === "" || seen[val])
                continue;
            seen[val] = true;
            result.push({
                "label": lbl,
                "value": val
            });
        }
        var current = String(currentValue || "");
        if (current !== "" && !seen[current]) {
            result.unshift({
                "label": activePopupKind === "cursorSize" ? qsTr("%1 px").arg(current) : current,
                "value": current
            });
        }
        return result;
    }
    function pageState() {
        return {
            "quickshell": currentState(),
            "gtk": gtkState()
        };
    }
    function parseGtkFontName(value) {
        var text = String(value || "").trim();
        var match = text.match(/^(.+?)\s+([0-9]+(?:\.[0-9]+)?)$/);
        return match ? {
            "family": match[1],
            "size": match[2]
        } : {
            "family": text || "SF Pro Text",
            "size": "10.5"
        };
    }
    function qtColorSchemeLabel() {
        var schemes = (SettingsHubService.gtkSettings && SettingsHubService.gtkSettings.qtColorSchemes) || [];
        for (var i = 0; i < schemes.length; ++i) {
            var item = schemes[i];
            if (item && item.value === qtColorSchemeValue)
                return item.label;
        }
        if (qtColorSchemeValue === "system")
            return qsTr("Default");
        if (qtColorSchemeValue === "style")
            return qsTr("Style's colors");
        return qtColorSchemeValue || "matugen";
    }
    function qtDialogsLabel() {
        var options = root.qtDialogOptions || [];
        for (var i = 0; i < options.length; ++i) {
            if (options[i].value === qtDialogsValue)
                return options[i].label;
        }
        return qtDialogsValue || "GTK3";
    }
    function resetPage() {
        syncFields();
    }
    function selectPopupItem(item) {
        if (!item)
            return;

        var value = String(item.value || "");
        if (activePopupKind === "gtk")
            gtkThemeValue = value;
        else if (activePopupKind === "icons")
            iconThemeValue = value;
        else if (activePopupKind === "cursor")
            cursorThemeValue = value;
        else if (activePopupKind === "cursorSize")
            cursorSizeValue = Number(value) || 24;
        else if (activePopupKind === "qtStyle")
            qtStyleValue = value;
        else if (activePopupKind === "qtColorScheme")
            qtColorSchemeValue = value;
        else if (activePopupKind === "qtDialogs")
            qtDialogsValue = value;
        selectorPopupOpen = false;
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
        var gtkSettings = SettingsHubService.gtkSettings || ({});
        gtkThemeValue = String(gtkSettings.gtkTheme || "adw-gtk3-dark");
        iconThemeValue = String(gtkSettings.iconTheme || "WhiteSur");
        cursorThemeValue = String(gtkSettings.cursorTheme || "Dark_Cursor");
        cursorSizeValue = Number(gtkSettings.cursorSize) || 24;
        qtStyleValue = String(gtkSettings.qtStyle || "kvantum");
        qtColorSchemeValue = String(gtkSettings.qtColorScheme || "matugen");
        qtDialogsValue = String(gtkSettings.qtDialogs || "gtk3");
        var gtkFont = parseGtkFontName(gtkSettings.fontName || "SF Pro Text 10.5");
        gtkFontFamilyField.text = gtkFont.family;
        gtkFontSizeField.text = gtkFont.size;
        baselineState = JSON.stringify(pageState());
    }
    function triggerHeaderAction() {
        if (gtkFontSizeValid)
            SettingsHubService.saveGeneral(currentState(), gtkState());
    }

    Component.onCompleted: {
        syncFields();
    }

    Connections {
        function onGtkSettingsChanged() {
            root.syncFields();
        }
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
                accentColor: Config.md3.tertiary
                iconName: "applications-graphics-symbolic"
                note: qsTr("Theme, icons and interface fonts synchronized across GTK and Qt5 / Qt6")
                title: qsTr("Desktop applications (GTK & Qt)")

                SettingsSelectRow {
                    accentColor: Config.md3.tertiary
                    label: qsTr("Application theme (GTK)")
                    note: qsTr("GTK style; Qt applications use Kvantum with Matugen palette")
                    valueText: root.gtkThemeValue

                    onClicked: sourceItem => root.openSelector(sourceItem, "gtk", SettingsHubService.gtkSettings.gtkThemes)
                }
                SettingsSelectRow {
                    accentColor: Config.md3.secondary
                    label: qsTr("Icon theme")
                    note: qsTr("Synchronized across GTK, Qt5 and Qt6 applications")
                    valueText: root.iconThemeValue

                    onClicked: sourceItem => root.openSelector(sourceItem, "icons", SettingsHubService.gtkSettings.iconThemes)
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 12
                    columns: width >= 620 ? 2 : 1
                    rowSpacing: 12
                    uniformCellWidths: true

                    SettingsSelectField {
                        id: cursorThemeField

                        Layout.fillWidth: true
                        accentColor: Config.md3.primary
                        label: qsTr("Cursor theme")
                        placeholder: qsTr("Select cursor theme")
                        valueText: root.cursorThemeValue

                        onClicked: sourceItem => root.openSelector(sourceItem, "cursor", SettingsHubService.gtkSettings.cursorThemes)
                    }
                    SettingsSelectField {
                        id: cursorSizeField

                        Layout.fillWidth: true
                        accentColor: Config.md3.primary
                        label: qsTr("Cursor size")
                        placeholder: qsTr("Select cursor size")
                        valueText: qsTr("%1 px").arg(root.cursorSizeValue)

                        onClicked: sourceItem => root.openSelector(sourceItem, "cursorSize", root.cursorSizeOptions)
                    }
                    SettingsFontPicker {
                        id: gtkFontFamilyField

                        Layout.fillWidth: true
                        label: qsTr("Interface font (GTK & Qt)")
                        placeholder: qsTr("Select an installed font")
                    }
                    SettingsTextField {
                        id: gtkFontSizeField

                        Layout.fillWidth: true
                        label: qsTr("Font size")
                        placeholder: "10.5"

                        inputItem.validator: DoubleValidator {
                            bottom: 6
                            decimals: 1
                            notation: DoubleValidator.StandardNotation
                            top: 32
                        }
                    }
                    SettingsSelectField {
                        id: qtStyleField

                        Layout.fillWidth: true
                        accentColor: Config.md3.tertiary
                        label: qsTr("Qt widget style")
                        placeholder: "kvantum"
                        valueText: root.qtStyleValue

                        onClicked: sourceItem => root.openSelector(sourceItem, "qtStyle", SettingsHubService.gtkSettings.qtStyles)
                    }
                    SettingsSelectField {
                        id: qtColorSchemeField

                        Layout.fillWidth: true
                        accentColor: Config.md3.tertiary
                        label: qsTr("Qt color scheme")
                        placeholder: "matugen"
                        valueText: root.qtColorSchemeLabel()

                        onClicked: sourceItem => root.openSelector(sourceItem, "qtColorScheme", SettingsHubService.gtkSettings.qtColorSchemes)
                    }
                }
                SettingsSelectRow {
                    accentColor: Config.md3.tertiary
                    label: qsTr("Qt standard dialogs")
                    note: qsTr("File chooser and message dialog provider for Qt applications")
                    valueText: root.qtDialogsLabel()

                    onClicked: sourceItem => root.openSelector(sourceItem, "qtDialogs", root.qtDialogOptions)
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
    SelectPopup {
        accentColor: activePopupKind === "cursorSize" || activePopupKind === "cursor" ? Config.md3.primary : activePopupKind === "icons" ? Config.md3.secondary : Config.md3.tertiary
        anchors.fill: parent
        itemActive: item => item && String(item.value) === root.currentPopupValue()
        model: root.activePopupModel
        openAbove: root.selectorPopupOpenAbove
        opened: root.selectorPopupOpen
        popupWidth: activePopupKind === "cursorSize" ? 200 : activePopupKind === "qtColorScheme" ? 340 : activePopupKind === "cursor" || activePopupKind === "qtStyle" || activePopupKind === "qtDialogs" ? 260 : 320
        popupY: root.selectorPopupY
        rightMargin: root.selectorPopupRightMargin
        shadowOpacity: 0.5
        z: 40

        onDismissed: root.selectorPopupOpen = false
        onItemSelected: item => root.selectPopupItem(item)
    }
}
