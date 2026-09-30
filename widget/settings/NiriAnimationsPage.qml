import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root

    property string baselineState: ""
    readonly property bool compactLayout: width < Responsive.settingsCompactContentWidth
    readonly property bool headerActionEnabled: !SettingsHubService.busy && slowdownValid
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Applying…" : "Apply animations"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState
    readonly property bool slowdownValid: isFinite(Number(slowdownField.text)) && Number(slowdownField.text) >= 0.05 && Number(slowdownField.text) <= 10

    function currentState() {
        return {
            "enabled": animationToggle.checked,
            "slowdown": Number(slowdownField.text)
        };
    }
    function resetPage() {
        syncGlobal();
    }
    function syncGlobal() {
        var settings = SettingsHubService.animationSettings || {};
        animationToggle.checked = settings.enabled !== false;
        slowdownField.text = String(settings.slowdown === undefined ? 1 : settings.slowdown);
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveAnimationGlobal(animationToggle.checked, Number(slowdownField.text));
    }

    clip: true
    contentHeight: content.implicitHeight
    contentWidth: availableWidth

    ScrollBar.horizontal: SlimScrollBar {
        accentColor: Config.md3.secondary
        policy: ScrollBar.AlwaysOff
    }
    ScrollBar.vertical: SlimScrollBar {
        accentColor: Config.md3.secondary
    }

    Component.onCompleted: syncGlobal()

    Connections {
        function onAnimationSettingsChanged() {
            root.syncGlobal();
        }

        target: SettingsHubService
    }
    ColumnLayout {
        id: content

        spacing: Md3.spacing.md
        width: root.contentWidth

        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            headerOutside: true
            iconName: "media-playback-start-symbolic"
            title: qsTr("Animation engine")

            SettingsToggleRow {
                id: animationToggle

                enabled: !SettingsHubService.busy
                label: qsTr("Enable Niri animations")
                note: qsTr("A global switch for every compositor animation")

                onToggled: checked => animationToggle.checked = checked
            }
            SettingsTextField {
                id: slowdownField

                Layout.fillWidth: true
                label: qsTr("Speed multiplier")
                placeholder: "1.0"
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                color: root.slowdownValid ? Config.md3.on_surface_variant : Config.md3.error
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                font.pixelSize: Md3.typeScale.bodyMedium.size
                font.weight: Md3.typeScale.bodyMedium.weight
                lineHeight: Md3.typeScale.bodyMedium.lineHeight
                lineHeightMode: Text.FixedHeight
                text: root.slowdownValid ? qsTr("1.0 is normal. Larger values make animations slower.") : qsTr("Enter a value from 0.05 to 10.")
                wrapMode: Text.Wrap
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columnSpacing: 12
            columns: root.compactLayout ? 1 : 2
            rowSpacing: 12
            uniformCellWidths: true

            Repeater {
                model: (SettingsHubService.animationSettings || {
                        "entries": []
                    }).entries || []

                delegate: Rectangle {
                    id: animationCard

                    property bool enabledState: modelData.enabled === true
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    color: Config.md3.surface_container_low
                    implicitHeight: Math.max(80, animationLabel.implicitHeight + 2 * Md3.spacing.md)
                    radius: Md3.shape.large

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: Md3.spacing.md

                        SettingsLabelBlock {
                            id: animationLabel

                            Layout.fillWidth: true
                            headline: String(animationCard.modelData.name).replace(/-/g, " ")
                            supportingText: animationCard.modelData.spec || qsTr("Uses Niri defaults")
                        }
                        ToggleSwitch {
                            accessibleName: "Toggle " + animationCard.modelData.name
                            checked: animationCard.enabledState
                            enabled: !SettingsHubService.busy

                            onToggled: checked => {
                                animationCard.enabledState = checked;
                                SettingsHubService.saveAnimationEntry(animationCard.modelData.name, checked);
                            }
                        }
                    }
                }
            }
        }
        Item {
            Layout.preferredHeight: 4
        }
    }
}
