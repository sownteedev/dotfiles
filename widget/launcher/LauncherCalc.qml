import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../"

// Standalone calculator card.
// Evaluates math expressions using the configured calculator prefix.
// Pressing Enter (from Launcher) copies the result to clipboard via wl-copy.
Item {
    id: calcRoot

    readonly property bool calculatorMode: Config.launcherCalculatorEnabled && query.toLowerCase().startsWith(calculatorPrefix.toLowerCase())
    readonly property string calculatorPrefix: Config.launcherCalculatorPrefix + " "
    property bool copied: false // brief "copied" feedback state

    readonly property string expression: calculatorMode ? query.substring(calculatorPrefix.length).trim() : ""
    readonly property bool hasResult: result !== ""
    property string query: ""

    // ── Security-safe expression evaluator ───────────────────────────────────
    //
    // Supported:  + - * / % ^ ( )
    //             sin cos tan asin acos atan atan2
    //             sqrt cbrt abs log log2 log10 exp pow
    //             ceil floor round min max hypot
    //             pi  e
    //
    // Process:
    //   1. Validate input: strip known tokens → nothing must remain
    //   2. Transform to JS: sin → Math.sin, pi → Math.PI, ^ → **
    //   3. eval() the safe expression
    // ────────────────────────────────────────────────────────────────────────

    readonly property string result: {
        if (!calculatorMode)
            return "";

        var q = expression;
        if (q === "")
            return "";

        var lower = q.toLowerCase();

        // Security: strip all valid tokens from a copy; reject if anything remains
        var check = lower.replace(/\b(atan2|log10|hypot|asin|acos|atan|sqrt|cbrt|log2|ceil|floor|round|min|max|pow|exp|sin|cos|tan|abs|log|pi|e)\b/g, "");
        check = check.replace(/[\d\.\+\-\*\/\(\)%\^\s,]/g, "");
        if (check.trim() !== "")
            return "";

        // Transform to valid JS
        var expr = lower.replace(/\b(atan2|log10|hypot|asin|acos|atan|sqrt|cbrt|log2|ceil|floor|round|min|max|pow|exp|sin|cos|tan|abs|log|pi|e)\b/g, function (match) {
            if (match === "pi")
                return "Math.PI";
            if (match === "e")
                return "Math.E";
            return "Math." + match;
        });
        expr = expr.replace(/\^/g, "**");

        try {
            var r = eval(expr);
            if (typeof r !== "number" || !isFinite(r))
                return "";
            // Very small numbers → scientific notation
            if (r !== 0 && Math.abs(r) < 1e-7)
                return r.toExponential(4);
            // Integer → no decimals
            if (r === Math.floor(r))
                return String(r);
            // Float → trim trailing zeros
            return parseFloat(r.toFixed(8)).toString();
        } catch (e) {}
        return "";
    }

    signal resultCopied

    function copyResult() {
        if (!hasResult)
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + result + "' | wl-copy"]);
        copied = true;
        copyResetTimer.restart();
        resultCopied();
    }

    clip: true
    implicitHeight: hasResult ? 80 : 0

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Config.animationDuration(150)
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: copyResetTimer

        interval: 1500

        onTriggered: calcRoot.copied = false
    }
    Rectangle {
        color: calcMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.10) : Config.alpha(Config.md3.on_surface, 0.06)
        height: 80
        radius: 28
        width: parent.width

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        // Green left accent
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            color: Config.md3.secondary
            height: 36
            radius: 2
            width: 3
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 18
            spacing: 15

            // "ƒ" math badge
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                color: Config.alpha(Config.md3.secondary, 0.15)
                height: 48
                radius: 13
                width: 48

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.secondary
                    font.family: Config.fontName
                    font.pixelSize: calcRoot.copied ? 20 : 18
                    font.weight: Font.Bold
                    text: calcRoot.copied ? "✓" : "ƒ"

                    Behavior on font.pixelSize {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                    Behavior on text {
                    }
                }
            }

            // Result + expression
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    color: calcRoot.copied ? Config.md3.secondary : Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: calcRoot.copied ? 16 : 22
                    font.weight: Font.Bold
                    text: calcRoot.copied ? "Copied!" : calcRoot.result

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Behavior on font.pixelSize {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.40)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: calcRoot.expression
                }
            }
        }
        MouseArea {
            id: calcMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: calcRoot.copyResult()
        }
    }
}
