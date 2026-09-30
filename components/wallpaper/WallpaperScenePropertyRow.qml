import ".."
import "../.."
import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts

Item {
    id: root

    required property var propertyData
    property var value
    readonly property string valueType: String(propertyData.type || "text").toLowerCase()

    signal valueEdited(var value)

    function colorChannels(rawValue) {
        var text = String(rawValue || "0 0 0").trim();
        if (/^#[0-9a-fA-F]{6}$/.test(text)) {
            return [parseInt(text.substring(1, 3), 16) / 255, parseInt(text.substring(3, 5), 16) / 255, parseInt(text.substring(5, 7), 16) / 255];
        }
        var parts = text.split(/\s+/);
        return [0, 1, 2].map(index => Math.max(0, Math.min(1, Number(parts[index] || 0))));
    }
    function editColor(channel, nextValue) {
        var channels = colorChannels(value);
        channels[channel] = Math.max(0, Math.min(1, Number(nextValue)));
        valueEdited(channels.map(component => component.toFixed(5)).join(" "));
    }
    function numericValue(fallback) {
        var number = Number(value);
        return isFinite(number) ? number : fallback;
    }

    implicitHeight: editorLoader.status === Loader.Ready && editorLoader.item ? editorLoader.item.implicitHeight : 58

    Loader {
        id: editorLoader

        anchors.fill: parent
        sourceComponent: root.valueType === "bool" || root.valueType === "boolean" ? booleanEditor : root.valueType === "slider" ? sliderEditor : root.valueType === "color" ? colorEditor : root.valueType === "combo" || root.valueType === "combolist" ? comboEditor : textEditor
    }
    Component {
        id: booleanEditor

        RowLayout {
            implicitHeight: 58
            spacing: 16

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                text: root.propertyData.label
            }
            ToggleSwitch {
                accessibleName: root.propertyData.label
                checked: root.value === true || root.value === 1 || String(root.value) === "1" || String(root.value).toLowerCase() === "true"

                onToggled: checked => root.valueEdited(checked)
            }
        }
    }
    Component {
        id: sliderEditor

        ColumnLayout {
            implicitHeight: 92
            spacing: 7

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: root.propertyData.label
                }
                Text {
                    color: Config.md3.primary
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    text: root.numericValue(Number(root.propertyData.minimum || 0)).toLocaleString(Qt.locale(), "f", Number(root.propertyData.step || 1) < 1 ? 2 : 0)
                }
            }
            Controls.Slider {
                Layout.fillWidth: true
                from: Number(root.propertyData.minimum || 0)
                live: true
                stepSize: Math.max(0.0001, Number(root.propertyData.step || 0.01))
                to: Number(root.propertyData.maximum === undefined ? 1 : root.propertyData.maximum)
                value: root.numericValue(from)

                onMoved: root.valueEdited(value)
            }
        }
    }
    Component {
        id: colorEditor

        ColumnLayout {
            implicitHeight: 150
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: root.propertyData.label
                }
                Rectangle {
                    readonly property var channels: root.colorChannels(root.value)

                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 42
                    border.color: Config.alpha(Config.md3.on_surface, 0.3)
                    border.width: 1
                    color: Qt.rgba(channels[0], channels[1], channels[2], 1)
                    radius: 9
                }
            }
            Repeater {
                model: [qsTr("R"), qsTr("G"), qsTr("B")]

                delegate: RowLayout {
                    id: colorChannelRow

                    required property int index
                    required property string modelData

                    Layout.fillWidth: true
                    spacing: 9

                    Text {
                        Layout.preferredWidth: 14
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        text: modelData
                    }
                    Controls.Slider {
                        Layout.fillWidth: true
                        from: 0
                        live: true
                        stepSize: 0.01
                        to: 1
                        value: root.colorChannels(root.value)[colorChannelRow.index]

                        onMoved: root.editColor(colorChannelRow.index, value)
                    }
                }
            }
        }
    }
    Component {
        id: comboEditor

        RowLayout {
            implicitHeight: 64
            spacing: 14

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                text: root.propertyData.label
            }
            Controls.ComboBox {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 180
                activeFocusOnTab: false
                currentIndex: {
                    var options = root.propertyData.options || [];
                    for (var index = 0; index < options.length; ++index) {
                        if (String(options[index].value) === String(root.value))
                            return index;
                    }
                    return 0;
                }
                model: root.propertyData.options || []
                textRole: "label"

                onActivated: index => {
                    var option = root.propertyData.options[index];
                    if (option)
                        root.valueEdited(option.value);
                }
            }
        }
    }
    Component {
        id: textEditor

        ColumnLayout {
            implicitHeight: 82
            spacing: 6

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                text: root.propertyData.label
            }
            FormTextField {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                fieldHeight: 42
                text: String(root.value === undefined || root.value === null ? "" : root.value)

                onTextChanged: root.valueEdited(text)
            }
        }
    }
}
