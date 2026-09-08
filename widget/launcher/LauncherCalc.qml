import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import "LauncherCalculatorEngine.js" as CalculatorEngine

Item {
    id: calcRoot

    readonly property var calculatorFunctions: [
        {
            name: "abs",
            sig: "abs(x)",
            desc: qsTr("Absolute value")
        },
        {
            name: "acos",
            sig: "acos(x)",
            desc: qsTr("Arccosine")
        },
        {
            name: "asin",
            sig: "asin(x)",
            desc: qsTr("Arcsine")
        },
        {
            name: "atan",
            sig: "atan(x)",
            desc: qsTr("Arctangent")
        },
        {
            name: "atan2",
            sig: "atan2(y, x)",
            desc: qsTr("Two-arg arctangent")
        },
        {
            name: "cbrt",
            sig: "cbrt(x)",
            desc: qsTr("Cube root")
        },
        {
            name: "ceil",
            sig: "ceil(x)",
            desc: qsTr("Round up")
        },
        {
            name: "cos",
            sig: "cos(x)",
            desc: qsTr("Cosine")
        },
        {
            name: "exp",
            sig: "exp(x)",
            desc: qsTr("e^x")
        },
        {
            name: "floor",
            sig: "floor(x)",
            desc: qsTr("Round down")
        },
        {
            name: "hypot",
            sig: "hypot(a, b)",
            desc: qsTr("Hypotenuse")
        },
        {
            name: "log",
            sig: "log(x)",
            desc: qsTr("Natural log (ln)")
        },
        {
            name: "log10",
            sig: "log10(x)",
            desc: qsTr("Log base 10")
        },
        {
            name: "log2",
            sig: "log2(x)",
            desc: qsTr("Log base 2")
        },
        {
            name: "max",
            sig: "max(a, b)",
            desc: qsTr("Maximum")
        },
        {
            name: "min",
            sig: "min(a, b)",
            desc: qsTr("Minimum")
        },
        {
            name: "pow",
            sig: "pow(x, y)",
            desc: qsTr("Power x^y")
        },
        {
            name: "round",
            sig: "round(x)",
            desc: qsTr("Round to nearest")
        },
        {
            name: "sin",
            sig: "sin(x)",
            desc: qsTr("Sine")
        },
        {
            name: "sqrt",
            sig: "sqrt(x)",
            desc: qsTr("Square root")
        },
        {
            name: "tan",
            sig: "tan(x)",
            desc: qsTr("Tangent")
        }
    ]
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
    readonly property var suggestions: {
        var token = trailingToken;
        if (token === "")
            return calculatorFunctions.filter(fn => ["sin", "cos", "tan", "sqrt", "floor", "ceil", "log", "abs"].indexOf(fn.name) !== -1);
        return calculatorFunctions.filter(fn => fn.name.indexOf(token) === 0);
    }
    property int tabCycleIndex: 0
    readonly property string trailingToken: {
        var match = String(expression || "").match(/[a-zA-Z0-9_]+$/);
        return match ? match[0].toLowerCase() : "";
    }

    signal insertRequested(string textToInsert, int replaceLength)
    signal resultCopied

    function applySuggestion(funcName) {
        var insertion = (funcName === "pi" || funcName === "e") ? funcName : (funcName + "(");
        insertRequested(insertion, trailingToken.length);
    }
    function completeCurrentToken() {
        var list = suggestions;
        if (list.length === 0)
            return false;

        var pick = list[tabCycleIndex % list.length];
        tabCycleIndex = (tabCycleIndex + 1) % list.length;
        applySuggestion(pick.name);
        return true;
    }
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

    implicitHeight: 148

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
    onTrailingTokenChanged: tabCycleIndex = 0
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
            anchors.margins: 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 12

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
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface_variant, 0.68)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    text: calcRoot.hasResult ? qsTr("↑↓ History  ·  Enter Copy") : calcRoot.delayedErrorVisible ? qsTr("Check the expression") : qsTr("Tab for autocomplete  ·  Functions:")
                    visible: calcRoot.hasResult || calcRoot.suggestions.length === 0
                }
                ListView {
                    id: suggestionView

                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    model: calcRoot.suggestions
                    orientation: ListView.Horizontal
                    spacing: 8
                    visible: !calcRoot.hasResult && calcRoot.suggestions.length > 0

                    delegate: Rectangle {
                        id: chip

                        required property var modelData

                        border.color: Config.alpha(Config.md3.tertiary, chipMouse.containsMouse ? 0.45 : 0.22)
                        border.width: 1
                        color: chipMouse.pressed ? Config.alpha(Config.md3.tertiary, 0.24) : chipMouse.containsMouse ? Config.alpha(Config.md3.tertiary, 0.16) : Config.alpha(Config.md3.tertiary, 0.09)
                        height: 30
                        radius: 8
                        width: chipText.implicitWidth + 20

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            id: chipText

                            anchors.centerIn: parent
                            color: Config.md3.tertiary
                            font.family: Config.fontName
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            text: chip.modelData.sig
                        }
                        MouseArea {
                            id: chipMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: calcRoot.applySuggestion(chip.modelData.name)
                        }
                    }
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
                    visible: calcRoot.hasResult

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
