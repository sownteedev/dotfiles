import ".."
import "../../"
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color accentColor: Config.md3.primary
    property int currentValue: 0
    readonly property string customPlaceholder: maximumSeconds <= 60 ? qsTr("For example 8s") : qsTr("90s, 15m or 2h")
    property real maxPopupHeight: Math.max(0, height - 24)
    property int maximumSeconds: 86400
    property bool openAbove: false
    property bool opened: false
    readonly property int parsedCustomValue: parseDuration(customField.text)
    property real popupWidth: 330
    property real popupY: 0
    readonly property real preferredHeight: 162 + Math.ceil(presets.length / 2) * 50
    property var presets: []
    readonly property string rangeText: maximumSeconds <= 60 ? qsTr("Up to %1 seconds").arg(maximumSeconds) : qsTr("Up to 24 hours")
    property real rightMargin: 12

    signal dismissed
    signal selected(int seconds)

    function applyCustomDuration() {
        if (parsedCustomValue <= 0)
            return;

        selected(parsedCustomValue);
    }
    function parseDuration(value) {
        var match = /^\s*(\d+(?:\.\d+)?)\s*([smh]?)\s*$/i.exec(String(value || ""));
        if (!match)
            return -1;

        var amount = Number(match[1]);
        var unit = String(match[2] || "m").toLowerCase();
        var multiplier = unit === "h" ? 3600 : unit === "s" ? 1 : 60;
        var seconds = Math.round(amount * multiplier);
        return seconds >= 1 && seconds <= maximumSeconds ? seconds : -1;
    }

    focus: opened
    opacity: opened ? 1 : 0
    visible: opened || opacity > 0

    Behavior on opacity {
        OpacityAnimator {
            duration: Config.animationDuration(150)
        }
    }

    Keys.onEscapePressed: event => {
        root.dismissed();
        event.accepted = true;
    }
    onOpenedChanged: {
        if (opened) {
            customField.text = "";
            forceActiveFocus();
        }
    }

    MouseArea {
        anchors.fill: parent

        onPressed: root.dismissed()
    }
    Item {
        anchors.fill: parent

        transform: Scale {
            origin.x: popupCard.x + popupCard.width - 30
            origin.y: root.openAbove ? popupCard.y + popupCard.height : popupCard.y
            xScale: root.opened ? 1 : 0.92
            yScale: root.opened ? 1 : 0.92

            Behavior on xScale {
                NumberAnimation {
                    duration: Config.animationDuration(170)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on yScale {
                NumberAnimation {
                    duration: Config.animationDuration(170)
                    easing.type: Easing.OutCubic
                }
            }
        }

        ShellShadow {
            active: root.opened
            cornerRadius: popupCard.radius
            target: popupCard
        }
        Rectangle {
            id: popupCard

            border.color: Config.alpha(Config.md3.outline, 0.18)
            border.width: 1
            color: Config.md3.surface_container
            height: Math.min(root.preferredHeight, root.maxPopupHeight)
            radius: 16
            width: Math.min(root.popupWidth, root.width - root.rightMargin - 12)
            x: Math.max(12, root.width - width - root.rightMargin)
            y: Math.max(12, Math.min(root.popupY, root.height - height - 12))

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        text: qsTr("Choose duration")
                    }
                    Text {
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 12
                        text: root.rangeText
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columnSpacing: 8
                    columns: 2
                    rowSpacing: 8
                    uniformCellWidths: true

                    Repeater {
                        model: root.presets

                        delegate: Rectangle {
                            id: presetButton

                            readonly property bool active: Number(modelData.value) === root.currentValue
                            required property var modelData

                            Accessible.checked: active
                            Accessible.name: String(presetButton.modelData.label)
                            Accessible.role: Accessible.RadioButton
                            Layout.fillWidth: true
                            border.color: Config.alpha(active ? root.accentColor : Config.md3.outline, active ? 0.42 : 0.12)
                            border.width: 1
                            color: active ? Config.alpha(root.accentColor, 0.16) : (presetMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.035))
                            implicitHeight: 42
                            radius: 11

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Config.animationDuration(120)
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(120)
                                }
                            }

                            Accessible.onPressAction: root.selected(Number(presetButton.modelData.value))

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                color: presetButton.active ? root.accentColor : Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: presetButton.active ? Font.DemiBold : Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                text: presetButton.modelData.label
                                verticalAlignment: Text.AlignVCenter
                            }
                            MouseArea {
                                id: presetMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: root.selected(Number(presetButton.modelData.value))
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.outline, 0.16)
                    implicitHeight: 1
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    FormTextField {
                        id: customField

                        Layout.fillWidth: true
                        fieldHeight: 44
                        inputFontPixelSize: 14
                        inputMethodHints: Qt.ImhNone
                        label: qsTr("Custom")
                        labelFontPixelSize: 13
                        placeholder: root.customPlaceholder

                        onAccepted: root.applyCustomDuration()
                    }
                    SettingsActionButton {
                        Layout.alignment: Qt.AlignBottom
                        enabled: root.parsedCustomValue > 0
                        iconName: "emblem-ok-symbolic"
                        primary: true
                        text: qsTr("Apply")

                        onClicked: root.applyCustomDuration()
                    }
                }
            }
        }
    }
}
