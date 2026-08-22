import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string baselineState: ""
    readonly property bool headerActionEnabled: !SettingsHubService.busy
    readonly property string headerActionIcon: "document-save-symbolic"
    readonly property string headerActionText: SettingsHubService.busy ? "Saving…" : "Apply & save"
    readonly property bool headerActionVisible: true
    readonly property bool headerResetVisible: baselineState !== "" && JSON.stringify(currentState()) !== baselineState

    function currentState() {
        return {
            "launcherFuzzySearch": fuzzyToggle.checked,
            "launcherClipboardAutoPaste": autoPasteToggle.checked,
            "launcherMaxResults": Number(maxResultsField.text),
            "launcherClipboardEnabled": clipboardToggle.checked,
            "launcherFilesEnabled": filesToggle.checked,
            "launcherCalculatorEnabled": calculatorToggle.checked,
            "launcherEmojiEnabled": emojiToggle.checked,
            "launcherClipboardPrefix": clipboardPrefixField.text,
            "launcherFilesPrefix": filesPrefixField.text,
            "launcherCalculatorPrefix": calculatorPrefixField.text,
            "launcherEmojiPrefix": emojiPrefixField.text
        };
    }
    function resetPage() {
        syncFields();
    }
    function syncFields() {
        var settings = SettingsHubService.quickshellSettings || ({});
        fuzzyToggle.checked = settings.launcherFuzzySearch ?? Config.launcherFuzzySearch;
        autoPasteToggle.checked = settings.launcherClipboardAutoPaste ?? Config.launcherClipboardAutoPaste;
        maxResultsField.text = String(settings.launcherMaxResults ?? Config.launcherMaxResults);
        clipboardToggle.checked = settings.launcherClipboardEnabled ?? Config.launcherClipboardEnabled;
        filesToggle.checked = settings.launcherFilesEnabled ?? Config.launcherFilesEnabled;
        calculatorToggle.checked = settings.launcherCalculatorEnabled ?? Config.launcherCalculatorEnabled;
        emojiToggle.checked = settings.launcherEmojiEnabled ?? Config.launcherEmojiEnabled;
        clipboardPrefixField.text = settings.launcherClipboardPrefix || Config.launcherClipboardPrefix;
        filesPrefixField.text = settings.launcherFilesPrefix || Config.launcherFilesPrefix;
        calculatorPrefixField.text = settings.launcherCalculatorPrefix || Config.launcherCalculatorPrefix;
        emojiPrefixField.text = settings.launcherEmojiPrefix || Config.launcherEmojiPrefix;
        baselineState = JSON.stringify(currentState());
    }
    function triggerHeaderAction() {
        SettingsHubService.saveQuickshell(currentState());
    }

    Component.onCompleted: syncFields()

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
            Layout.columnSpan: pageContent.columnCount
            Layout.fillWidth: true
            accentColor: Config.md3.primary
            compact: true
            note: "Search behavior shared by applications and every optional provider"
            title: "Search"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: 1
                rowSpacing: 10
                uniformCellWidths: true

                SettingsTextField {
                    id: maxResultsField

                    Layout.fillWidth: true
                    label: "Maximum results"
                    placeholder: "20"

                    inputItem.validator: IntValidator {
                        bottom: 5
                        top: 50
                    }
                }
                SettingsToggleTile {
                    id: fuzzyToggle

                    label: "Fuzzy matching"
                    note: "Match ordered characters when needed"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: autoPasteToggle

                    label: "Automatic clipboard paste"
                    note: "Paste into the previously focused app"

                    onToggled: value => checked = value
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.secondary
            compact: true
            note: "Applications remain the default provider and cannot be disabled"
            title: "Providers"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                columns: 1
                rowSpacing: 10
                uniformCellWidths: true

                SettingsToggleTile {
                    id: clipboardToggle

                    label: "Clipboard"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: filesToggle

                    label: "Files"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: calculatorToggle

                    label: "Calculator"

                    onToggled: value => checked = value
                }
                SettingsToggleTile {
                    id: emojiToggle

                    label: "Emoji"

                    onToggled: value => checked = value
                }
            }
        }
        SettingsSectionCard {
            Layout.fillWidth: true
            accentColor: Config.md3.tertiary
            compact: true
            note: "Type the prefix followed by a space to activate a provider"
            title: "Prefixes"

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 12
                columns: width >= 980 ? 4 : width >= 500 ? 2 : 1
                rowSpacing: 12
                uniformCellWidths: true

                SettingsTextField {
                    id: clipboardPrefixField

                    Layout.fillWidth: true
                    inputItem.maximumLength: 3
                    label: "Clipboard"
                    placeholder: "c"
                }
                SettingsTextField {
                    id: filesPrefixField

                    Layout.fillWidth: true
                    inputItem.maximumLength: 3
                    label: "Files"
                    placeholder: "f"
                }
                SettingsTextField {
                    id: calculatorPrefixField

                    Layout.fillWidth: true
                    inputItem.maximumLength: 3
                    label: "Calculator"
                    placeholder: "="
                }
                SettingsTextField {
                    id: emojiPrefixField

                    Layout.fillWidth: true
                    inputItem.maximumLength: 3
                    label: "Emoji"
                    placeholder: "e"
                }
            }
        }
    }
}
