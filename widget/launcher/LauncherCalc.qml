import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import "LauncherCalculatorEngine.js" as CalculatorEngine

Item {
    id: calcRoot

    readonly property bool calculatorMode: Config.launcherCalculatorEnabled && query.toLowerCase().startsWith(calculatorPrefix.toLowerCase())
    readonly property string calculatorPrefix: Config.launcherCalculatorPrefix + " "
    property bool copied: false
    property string copiedResult: ""
    property bool delayedErrorVisible: false
    readonly property var evaluation: CalculatorEngine.evaluate(expression, Config.launcherCalculatorAngleMode, StateManager.launcherCalculatorLastAnswer)
    readonly property string expression: calculatorMode ? query.substring(calculatorPrefix.length).trim() : ""
    readonly property bool hasResult: copied ? copiedResult !== "" : evaluation.status === "result"
    property string query: ""
    readonly property string result: copied && copiedResult !== "" ? copiedResult : hasResult ? evaluation.display : ""

    signal resultCopied

    function copyResult() {
        if (!hasResult || copied)
            return;

        var display = result;
        var value = evaluation.value;
        copiedResult = display;
        copied = true;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "calculator_copy", display]);
        StateManager.commitLauncherCalculation(expression, value, display);
        copyFeedbackTimer.restart();
    }
    function errorMessage(code, token) {
        switch (code) {
        case "division_by_zero":
            return qsTr("Division by zero");
        case "invalid_factorial":
            return qsTr("Factorial needs an integer from 0 to 170");
        case "invalid_arguments":
            return qsTr("Check the function arguments");
        case "missing_answer":
            return qsTr("No previous answer yet");
        case "unknown_unit":
            return qsTr("Unknown unit: %1").arg(token);
        case "incompatible_units":
            return qsTr("Those units cannot be converted");
        case "domain_error":
            return qsTr("Result is outside the valid range");
        default:
            return qsTr("Check the expression");
        }
    }
    function toggleAngleMode() {
        Config.launcherCalculatorAngleMode = Config.launcherCalculatorAngleMode === "deg" ? "rad" : "deg";
    }

    implicitHeight: 132

    onEvaluationChanged: {
        delayedErrorVisible = false;
        errorDelayTimer.stop();
        if (evaluation.status === "error")
            errorDelayTimer.restart();
    }
    onExpressionChanged: {
        copied = false;
        copiedResult = "";
    }
    onVisibleChanged: {
        if (!visible) {
            copied = false;
            copiedResult = "";
            errorDelayTimer.stop();
        }
    }

    Timer {
        id: copyFeedbackTimer

        interval: Math.max(180, Config.animationDuration(220))

        onTriggered: calcRoot.resultCopied()
    }
    Timer {
        id: errorDelayTimer

        interval: 220

        onTriggered: calcRoot.delayedErrorVisible = calcRoot.evaluation.status === "error"
    }
    Rectangle {
        anchors.fill: parent
        border.color: Config.alpha(Config.md3.outline_variant, 0.26)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.78 : 0.66)
        radius: 24

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 9

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 30
                    color: Config.alpha(Config.md3.tertiary, 0.16)
                    radius: 10

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.tertiary
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        text: "ƒx"
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: calcRoot.copied ? Config.md3.primary : Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    text: calcRoot.copied ? qsTr("Copied to clipboard") : calcRoot.hasResult ? (calcRoot.evaluation.conversion ? qsTr("Conversion") : qsTr("Result")) : calcRoot.evaluation.status === "empty" ? qsTr("Calculator") : calcRoot.delayedErrorVisible ? qsTr("Unable to calculate") : qsTr("Live result")

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }
                Rectangle {
                    id: angleModeButton

                    Accessible.name: qsTr("Toggle angle mode")
                    Accessible.role: Accessible.Button
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 58
                    activeFocusOnTab: true
                    border.color: Config.alpha(Config.md3.tertiary, activeFocus ? 0.68 : 0.30)
                    border.width: 1
                    color: angleModeMouse.containsMouse ? Config.alpha(Config.md3.tertiary, 0.18) : Config.alpha(Config.md3.tertiary, 0.10)
                    radius: 10

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Accessible.onPressAction: calcRoot.toggleAngleMode()
                    Keys.onReturnPressed: event => {
                        calcRoot.toggleAngleMode();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: event => {
                        calcRoot.toggleAngleMode();
                        event.accepted = true;
                    }

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.tertiary
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        text: Config.launcherCalculatorAngleMode.toUpperCase()
                    }
                    MouseArea {
                        id: angleModeMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            angleModeButton.forceActiveFocus();
                            calcRoot.toggleAngleMode();
                        }
                    }
                }
            }
            Text {
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: calcRoot.delayedErrorVisible ? Config.md3.error : Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: calcRoot.hasResult ? 27 : 19
                font.weight: calcRoot.hasResult ? Font.Bold : Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                text: calcRoot.hasResult ? calcRoot.result : calcRoot.evaluation.status === "empty" ? qsTr("Type an expression") : calcRoot.evaluation.status === "incomplete" || !calcRoot.delayedErrorVisible ? qsTr("Keep typing…") : calcRoot.errorMessage(calcRoot.evaluation.code, calcRoot.evaluation.token)
                verticalAlignment: Text.AlignVCenter

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface_variant, 0.68)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    text: calcRoot.hasResult ? qsTr("↑↓ History  ·  Enter Copy") : calcRoot.evaluation.status === "empty" ? qsTr("2pi  ·  25% of 800  ·  10 km to mi") : calcRoot.evaluation.status === "incomplete" || !calcRoot.delayedErrorVisible ? qsTr("Complete the expression") : qsTr("Functions, units and ans are supported")
                }
                Rectangle {
                    id: copyButton

                    Accessible.name: qsTr("Copy result")
                    Accessible.role: Accessible.Button
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 38
                    activeFocusOnTab: calcRoot.hasResult
                    border.color: Config.alpha(Config.md3.primary, activeFocus ? 0.72 : 0.26)
                    border.width: 1
                    color: calcRoot.copied ? Config.md3.primary : copyMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.19) : Config.alpha(Config.md3.primary, 0.11)
                    enabled: calcRoot.hasResult
                    opacity: enabled ? 1 : 0
                    radius: 10
                    scale: calcRoot.copied ? 1.05 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutBack
                        }
                    }

                    Accessible.onPressAction: calcRoot.copyResult()
                    Keys.onReturnPressed: event => {
                        calcRoot.copyResult();
                        event.accepted = true;
                    }
                    Keys.onSpacePressed: event => {
                        calcRoot.copyResult();
                        event.accepted = true;
                    }

                    IconImage {
                        anchors.centerIn: parent
                        height: 17
                        layer.enabled: true
                        source: Quickshell.iconPath(calcRoot.copied ? "emblem-ok-symbolic" : "edit-copy-symbolic")
                        width: 17

                        layer.effect: ColorOverlay {
                            color: calcRoot.copied ? Config.md3.on_primary : Config.md3.primary
                        }
                    }
                    MouseArea {
                        id: copyMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: calcRoot.hasResult
                        hoverEnabled: true

                        onClicked: {
                            copyButton.forceActiveFocus();
                            calcRoot.copyResult();
                        }
                    }
                }
            }
        }
    }
}
