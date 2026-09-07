import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

ScrollView {
    id: root

    readonly property bool compactLayout: width < Responsive.settingsCompactContentWidth
    readonly property bool headerActionEnabled: false
    readonly property string headerActionIcon: ""
    readonly property string headerActionText: ""
    readonly property bool headerActionVisible: false
    readonly property bool headerResetVisible: false
    property bool initialLayoutReady: false
    readonly property bool inputSnapshotReady: Boolean(SettingsHubService.inputSettings && SettingsHubService.inputSettings.Keyboard !== undefined)

    function inputAccent(section) {
        const colors = {
            "Keyboard": Config.md3.primary,
            "Touchpad": Config.md3.error,
            "Mouse": Config.md3.secondary,
            "Trackpoint": Config.md3.tertiary,
            "Trackball": Config.md3.primary,
            "Tablet": Config.md3.error,
            "Touch": Config.md3.secondary
        };
        return colors[section] || Config.md3.primary;
    }
    function inputSectionsForColumn(column) {
        return column === 0 ? ["Keyboard", "Mouse", "Trackball", "Touch"] : ["Touchpad", "Trackpoint", "Tablet"];
    }
    function prepareInitialLayout() {
        if (!initialLayoutReady && inputSnapshotReady)
            initialLayoutTimer.restart();
    }

    clip: true
    contentHeight: initialLayoutReady ? inputContent.implicitHeight + 32 : 0
    contentWidth: availableWidth

    ScrollBar.horizontal: SlimScrollBar {
        policy: ScrollBar.AlwaysOff
    }
    ScrollBar.vertical: SlimScrollBar {
    }

    Component.onCompleted: prepareInitialLayout()
    onInputSnapshotReadyChanged: prepareInitialLayout()

    Timer {
        id: initialLayoutTimer

        interval: 0
        repeat: false

        onTriggered: root.initialLayoutReady = true
    }
    GridLayout {
        id: inputContent

        columnSpacing: 16
        columns: root.compactLayout ? 1 : 2
        rowSpacing: 16
        uniformCellWidths: true
        visible: root.initialLayoutReady
        width: root.contentWidth
        y: 8

        Repeater {
            model: 2

            delegate: ColumnLayout {
                readonly property int columnIndex: index
                required property int index

                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 16

                Repeater {
                    model: root.inputSectionsForColumn(parent.columnIndex)

                    delegate: SettingsExpandableCard {
                        id: inputCard

                        readonly property bool canDisable: sectionName !== "Keyboard"
                        required property string modelData
                        property bool sectionEnabled: !canDisable || SettingsHubService.inputEnabled[sectionName] !== false
                        property string sectionName: modelData

                        Layout.fillWidth: true
                        accentColor: root.inputAccent(sectionName)
                        checked: sectionEnabled
                        heightAnimationEnabled: root.initialLayoutReady
                        iconName: sectionName === "Keyboard" ? "input-keyboard-symbolic" : sectionName === "Touchpad" ? "input-touchpad-symbolic" : "input-mouse-symbolic"
                        note: canDisable ? "Disable the whole " + sectionName.toLowerCase() + " section" : "Always available in the active Niri input block"
                        title: sectionName
                        toggleVisible: canDisable

                        onToggled: checked => {
                            inputCard.sectionEnabled = checked;
                            SettingsHubService.saveInputEnabled(inputCard.sectionName, checked);
                        }

                        Connections {
                            function onInputEnabledChanged() {
                                inputCard.sectionEnabled = !inputCard.canDisable || SettingsHubService.inputEnabled[inputCard.sectionName] !== false;
                            }

                            target: SettingsHubService
                        }
                        Repeater {
                            model: SettingsHubService.inputSettings[inputCard.sectionName] || []

                            delegate: Rectangle {
                                required property var modelData
                                property bool optionEnabled: modelData.enabled !== false

                                Layout.fillWidth: true
                                color: inputValue.activeFocus ? Config.alpha(inputCard.accentColor, 0.12) : Config.alpha(Config.md3.on_surface, 0.035)
                                implicitHeight: 44
                                opacity: optionEnabled ? 1 : 0.68
                                radius: 11

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 130
                                    }
                                }

                                TextInput {
                                    id: inputValue

                                    activeFocusOnTab: true
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.right: optionToggle.left
                                    anchors.rightMargin: 12
                                    anchors.top: parent.top
                                    clip: true
                                    color: activeFocus ? inputCard.accentColor : Config.alpha(Config.md3.on_surface, 0.76)
                                    font.family: Config.fontName
                                    font.pixelSize: 14
                                    selectByMouse: true
                                    text: modelData.text
                                    verticalAlignment: TextInput.AlignVCenter

                                    onEditingFinished: {
                                        if (text !== modelData.text)
                                            SettingsHubService.saveInput(inputCard.sectionName, modelData.index, text);
                                    }
                                }
                                ToggleSwitch {
                                    id: optionToggle

                                    accessibleName: inputValue.text
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: parent.optionEnabled
                                    checkedColor: inputCard.accentColor
                                    enabled: !SettingsHubService.busy

                                    onToggled: checked => {
                                        parent.optionEnabled = checked;
                                        SettingsHubService.saveInputEntryEnabled(inputCard.sectionName, modelData.index, checked);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
