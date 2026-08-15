import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: true

    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        heightField.text = String(settings.barHeight ?? Config.barHeight);
        densityChoice.value = settings.barDensity || Config.barDensity;
        activeClientToggle.checked = settings.barShowActiveClient ?? Config.barShowActiveClient;
        mediaToggle.checked = settings.barShowMedia ?? Config.barShowMedia;
        workspacesToggle.checked = settings.barShowWorkspaces ?? Config.barShowWorkspaces;
        recordingToggle.checked = settings.barShowRecording ?? Config.barShowRecording;
        trayToggle.checked = settings.barShowSysTray ?? Config.barShowSysTray;
        microphoneToggle.checked = settings.barShowMicrophone ?? Config.barShowMicrophone;
        networkToggle.checked = settings.barShowNetwork ?? Config.barShowNetwork;
        bluetoothToggle.checked = settings.barShowBluetooth ?? Config.barShowBluetooth;
        batteryToggle.checked = settings.barShowBattery ?? Config.barShowBattery;
        notificationsToggle.checked = settings.barShowNotifications ?? Config.barShowNotifications;
        clockToggle.checked = settings.barShowClock ?? Config.barShowClock;
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell({
            "barHeight": Number(heightField.text),
            "barDensity": densityChoice.value,
            "barShowActiveClient": activeClientToggle.checked,
            "barShowMedia": mediaToggle.checked,
            "barShowWorkspaces": workspacesToggle.checked,
            "barShowRecording": recordingToggle.checked,
            "barShowSysTray": trayToggle.checked,
            "barShowMicrophone": microphoneToggle.checked,
            "barShowNetwork": networkToggle.checked,
            "barShowBluetooth": bluetoothToggle.checked,
            "barShowBattery": batteryToggle.checked,
            "barShowNotifications": notificationsToggle.checked,
            "barShowClock": clockToggle.checked
        });
    }

    Component.onCompleted: syncFields()

    Connections {
        function onQuickshellSettingsChanged() {
            root.syncFields();
        }

        target: SettingsHubService
    }
    SettingsPageContent {
        anchors.fill: parent

        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            note: "Global bar geometry. Responsive compression still applies on narrow outputs."
            title: "Layout"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: width >= 720 ? 2 : 1
                rowSpacing: 12
                uniformCellWidths: true

                SettingsTextField {
                    id: heightField

                    Layout.fillWidth: true
                    label: "Bar height (px)"
                    placeholder: "50"

                    inputItem.validator: IntValidator {
                        bottom: 40
                        top: 72
                    }
                }
                SettingsChoiceRow {
                    id: densityChoice

                    Layout.fillWidth: true
                    label: "Density"
                    options: [
                        {
                            "label": "Compact",
                            "value": "compact"
                        },
                        {
                            "label": "Comfortable",
                            "value": "comfortable"
                        },
                        {
                            "label": "Spacious",
                            "value": "spacious"
                        }
                    ]

                    onSelected: value => densityChoice.value = value
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.primary
            compact: true
            note: "Primary navigation and current workspace context"
            title: "Left and center"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: width >= 820 ? 3 : width >= 500 ? 2 : 1
                rowSpacing: 10
                uniformCellWidths: true

                SettingsToggleTile {
                    id: activeClientToggle

                    label: "Active application"
                    note: "Focused application name and title"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: mediaToggle

                    label: "Media"
                    note: "Playback metadata and spectrum"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: workspacesToggle

                    label: "Workspaces"
                    note: "Workspace strip in the center zone"

                    onToggled: value => checked = value
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.tertiary
            compact: true
            note: "Status modules are hidden without stopping their underlying services"
            title: "Status area"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: width >= 980 ? 4 : width >= 500 ? 2 : 1
                rowSpacing: 10
                uniformCellWidths: true

                SettingsToggleTile {
                    id: recordingToggle

                    label: "Recording indicator"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: trayToggle

                    label: "System tray"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: microphoneToggle

                    label: "Microphone privacy"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: networkToggle

                    label: "Wi-Fi"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: bluetoothToggle

                    label: "Bluetooth"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: batteryToggle

                    label: "Battery"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: notificationsToggle

                    label: "Notifications"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: clockToggle

                    label: "Clock and date"

                    onToggled: value => checked = value
                }
            }
        }
    }
}
