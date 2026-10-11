import "../.."
import ".."
import "../../service"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    readonly property var controlGroups: [
        {
            "key": "lighting",
            "label": qsTr("Lighting"),
            "names": ["brightness", "backlight_compensation", "auto_exposure", "exposure_time_absolute", "exposure_dynamic_framerate"]
        },
        {
            "key": "color",
            "label": qsTr("Color"),
            "names": ["contrast", "saturation", "hue", "gamma", "gain", "white_balance_automatic", "white_balance_temperature"]
        },
        {
            "key": "sharpness",
            "label": qsTr("Sharpness"),
            "names": ["sharpness", "focus_auto", "focus_absolute"]
        },
        {
            "key": "flicker",
            "label": qsTr("Flicker reduction"),
            "names": ["power_line_frequency"]
        },
        {
            "key": "advanced",
            "label": qsTr("Advanced"),
            "names": []
        }
    ]
    readonly property var controls: CameraControlService.controls || []
    property string device: ""

    function controlForName(name) {
        for (var index = 0; index < controls.length; ++index) {
            if (String(controls[index].name) === name)
                return controls[index];
        }
        return {};
    }
    function controlLabel(name) {
        var labels = {
            "brightness": qsTr("Brightness"),
            "contrast": qsTr("Contrast"),
            "saturation": qsTr("Saturation"),
            "hue": qsTr("Hue"),
            "white_balance_automatic": qsTr("Automatic white balance"),
            "white_balance_temperature": qsTr("White balance temperature"),
            "gamma": qsTr("Gamma"),
            "gain": qsTr("Gain"),
            "power_line_frequency": qsTr("Power-line frequency"),
            "sharpness": qsTr("Sharpness"),
            "backlight_compensation": qsTr("Backlight compensation"),
            "auto_exposure": qsTr("Exposure mode"),
            "exposure_time_absolute": qsTr("Exposure time"),
            "exposure_dynamic_framerate": qsTr("Dynamic framerate")
        };
        return labels[name] || String(name).replaceAll("_", " ");
    }
    function controlNote(control) {
        if (control.inactive)
            return qsTr("Inactive while another automatic control is enabled");
        if (control.disabled)
            return qsTr("Disabled by the camera driver");
        return control.kind === "menu" || control.kind === "bool" ? qsTr("Applied immediately to the camera") : qsTr("Release the slider to apply to the camera");
    }
    function controlsForGroup(group) {
        var names = group.names || [];
        if (group.key === "advanced") {
            names = [];
            for (var groupIndex = 0; groupIndex < controlGroups.length; ++groupIndex) {
                if (controlGroups[groupIndex].key !== "advanced")
                    names = names.concat(controlGroups[groupIndex].names);
            }
        }
        var result = [];
        var controlNames = CameraControlService.controlNames;
        for (var index = 0; index < controlNames.length; ++index) {
            var name = controlNames[index];
            if (group.key !== "advanced" && names.indexOf(name) < 0)
                continue;
            if (group.key === "advanced" && names.indexOf(name) >= 0)
                continue;
            result.push(name);
        }
        return result;
    }
    function optionsFor(control) {
        if (control.kind === "bool")
            return [
                {
                    "label": qsTr("Off"),
                    "value": "0"
                },
                {
                    "label": qsTr("On"),
                    "value": "1"
                }
            ];
        var result = [];
        var options = control.options || [];
        for (var index = 0; index < options.length; ++index)
            result.push({
                "label": String(options[index].label),
                "value": String(options[index].value)
            });
        return result;
    }
    function setControl(name, value) {
        CameraControlService.setControl(name, value);
    }

    spacing: Md3.spacing.sm
    visible: root.device !== ""

    onDeviceChanged: CameraControlService.load(root.device)

    SettingsSectionCard {
        Layout.fillWidth: true
        accentColor: Config.md3.secondary
        compact: true
        headerOutside: true
        iconName: "preferences-system-symbolic"
        note: qsTr("Sliders apply on release; choices apply immediately. Hold the compare button to preview driver defaults.")
        title: qsTr("Camera controls")

        Repeater {
            model: root.controlGroups

            delegate: SettingsSectionCard {
                id: controlGroup

                required property var modelData

                Layout.fillWidth: true
                accentColor: Config.md3.tertiary
                compact: true
                contentSpacing: Md3.spacing.xs
                headerOutside: true
                iconName: "camera-photo-symbolic"
                title: modelData.label
                visible: root.controlsForGroup(modelData).length > 0

                Repeater {
                    model: root.controlsForGroup(controlGroup.modelData)

                    delegate: Loader {
                        id: controlLoader

                        readonly property var control: root.controlForName(String(modelData))
                        required property var modelData

                        Layout.fillWidth: true
                        sourceComponent: control.kind === "menu" || control.kind === "bool" ? menuControl : sliderControl

                        Component {
                            id: sliderControl

                            SettingsSliderRow {
                                id: cameraSlider

                                readonly property var control: controlLoader.control

                                accentColor: Config.md3.tertiary
                                applyOnRelease: true
                                dimWhenDisabled: control.inactive === true || control.disabled === true
                                enabled: !control.inactive && !control.disabled && !CameraControlService.busy
                                from: Number(control.min)
                                label: root.controlLabel(control.name)
                                note: root.controlNote(control)
                                stepSize: Math.max(1, Number(control.step || 1))
                                to: Number(control.max)
                                value: Number(control.value)
                                valueText: String(Math.round(cameraSlider.currentValue))

                                onEdited: value => root.setControl(control.name, value)
                            }
                        }
                        Component {
                            id: menuControl

                            SettingsChoiceRow {
                                id: cameraChoice

                                readonly property var control: controlLoader.control

                                dimWhenDisabled: control.inactive === true || control.disabled === true
                                enabled: !control.inactive && !control.disabled && !CameraControlService.busy
                                label: root.controlLabel(control.name)
                                note: root.controlNote(control)
                                options: root.optionsFor(control)

                                onSelected: value => root.setControl(control.name, value)

                                Binding {
                                    property: "value"
                                    target: cameraChoice
                                    value: String(cameraChoice.control.value)
                                }
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            color: Config.alpha(CameraControlService.statusSuccess ? Config.md3.primary : Config.md3.error, 0.1)
            implicitHeight: statusText.implicitHeight + 22
            radius: Md3.shape.medium
            visible: CameraControlService.statusMessage !== ""

            Text {
                id: statusText

                anchors.fill: parent
                anchors.margins: 11
                color: CameraControlService.statusSuccess ? Config.md3.primary : Config.md3.error
                font.family: Config.fontName
                font.pixelSize: Md3.typeScale.bodyMedium.size
                text: CameraControlService.statusMessage
                wrapMode: Text.Wrap
            }
        }
    }
}
