import "../../"
import "../../service"
import ".."
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var outputs: DisplayService.outputs
    readonly property var targetOutputNames: {
        var result = [];
        for (var i = 0; i < root.outputs.length; ++i) {
            var name = String(root.outputs[i] && root.outputs[i].name || "");
            if (name !== "" && name !== DisplayService.mirrorSourceName)
                result.push(name);
        }
        return result;
    }

    signal scalingActivated(var sourceItem)
    signal sourceActivated(var sourceItem)

    function outputLabel(name) {
        for (var i = 0; i < root.outputs.length; ++i) {
            var output = root.outputs[i];
            if (!output || String(output.name || "") !== name)
                continue;
            var model = String(output.model || output.make || "").trim();
            var mode = "";
            if (output.current_mode >= 0 && output.current_mode < (output.modes || []).length) {
                var current = output.modes[output.current_mode];
                mode = current ? " • " + current.width + "×" + current.height : "";
            }
            return name + (model !== "" ? " — " + model : "") + mode;
        }
        return name;
    }

    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        SettingsSelectField {
            Layout.fillWidth: true
            label: qsTr("Source")
            valueText: root.outputLabel(DisplayService.mirrorSourceName)

            onClicked: sourceItem => root.sourceActivated(sourceItem)
        }
        SettingsSelectField {
            Layout.preferredWidth: 150
            label: qsTr("Scaling")
            valueText: DisplayService.mirrorScaling === "cover" ? qsTr("Fill") : qsTr("Fit")

            onClicked: sourceItem => root.scalingActivated(sourceItem)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.alignment: Qt.AlignVCenter
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
            font.pixelSize: Md3.typeScale.labelLarge.size
            font.weight: Font.DemiBold
            text: qsTr("Mirror to")
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.alpha(Config.md3.outline, 0.18)
        }
        Rectangle {
            Layout.preferredHeight: 32
            Layout.preferredWidth: selectAllLabel.implicitWidth + 24
            color: selectAllMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.14) : "transparent"
            radius: Md3.shape.full

            Behavior on color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short3)
                }
            }

            Text {
                id: selectAllLabel

                anchors.centerIn: parent
                color: Config.md3.primary
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                font.pixelSize: Md3.typeScale.labelLarge.size
                font.weight: Font.DemiBold
                text: qsTr("All")
            }
            MouseArea {
                id: selectAllMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: {
                    for (var i = 0; i < root.targetOutputNames.length; ++i)
                        DisplayService.setMirrorTarget(root.targetOutputNames[i], true);
                }
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: root.targetOutputNames

            delegate: Rectangle {
                id: targetPill

                property string outputName: String(modelData || "")
                readonly property bool selected: DisplayService.mirrorTargetNames.indexOf(outputName) >= 0

                border.color: selected ? Config.md3.secondary : Config.alpha(Config.md3.outline, 0.26)
                border.width: 1
                color: selected ? Config.alpha(Config.md3.secondary_container, 0.92) : Config.alpha(Config.md3.surface_container_high, 0.92)
                height: 40
                implicitWidth: targetLabel.implicitWidth + 34
                radius: Md3.shape.full

                Behavior on border.color {
                    ColorAnimation {
                        duration: Config.animationDuration(Md3.motion.short3)
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(Md3.motion.short3)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 7

                    Md3Icon {
                        Layout.alignment: Qt.AlignVCenter
                        color: selected ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                        name: selected ? "check" : "add"
                        size: 18
                    }
                    Text {
                        id: targetLabel

                        Layout.maximumWidth: 260
                        color: selected ? Config.md3.on_secondary_container : Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                        font.pixelSize: Md3.typeScale.labelLarge.size
                        font.weight: Font.Medium
                        text: root.outputLabel(outputName)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: DisplayService.setMirrorTarget(outputName, !targetPill.selected)
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        color: Config.md3.on_surface_variant
        elide: Text.ElideRight
        font.family: Config.fontName
        font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
        font.pixelSize: Md3.typeScale.bodySmall.size
        font.weight: Md3.typeScale.bodySmall.weight
        text: qsTr("Fit keeps the aspect ratio; Fill crops the edges to use the full screen.")
    }
}
