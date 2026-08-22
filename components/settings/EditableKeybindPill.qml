import "../../"
import QtQuick

Rectangle {
    id: root

    property bool capturing: false
    property string displayKey: ""
    readonly property var displayParts: splitDisplay(visibleDisplay)
    property bool interactive: true
    property string oldHeader: ""
    property string pendingDisplay: ""
    property string pendingRaw: ""
    readonly property string visibleDisplay: capturing ? (pendingDisplay === "" ? "Press shortcut…" : pendingDisplay) : displayKey

    signal committed(string oldHeader, string newKey)

    function beginCapture() {
        if (!interactive)
            return;

        pendingRaw = "";
        pendingDisplay = "";
        capturing = true;
        forceActiveFocus(Qt.MouseFocusReason);
    }
    function displayFromRaw(raw) {
        var parts = raw.split("+");
        var output = [];
        for (var i = 0; i < parts.length; i++)
            output.push(parts[i] === "Mod" ? "Super" : parts[i]);
        return output.join(" + ");
    }
    function finishCapture() {
        if (!capturing)
            return;

        capturing = false;
        if (pendingRaw !== "")
            committed(oldHeader, pendingRaw);

        pendingRaw = "";
        pendingDisplay = "";
    }
    function keyName(event) {
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            return String.fromCharCode(event.key);

        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
            return String.fromCharCode(event.key);

        if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F35)
            return "F" + String(event.key - Qt.Key_F1 + 1);

        switch (event.key) {
        case Qt.Key_Return:
            return "Return";
        case Qt.Key_Enter:
            return "Return";
        case Qt.Key_Tab:
            return "Tab";
        case Qt.Key_Backspace:
            return "BackSpace";
        case Qt.Key_Space:
            return "Space";
        case Qt.Key_Left:
            return "Left";
        case Qt.Key_Right:
            return "Right";
        case Qt.Key_Up:
            return "Up";
        case Qt.Key_Down:
            return "Down";
        case Qt.Key_Home:
            return "Home";
        case Qt.Key_End:
            return "End";
        case Qt.Key_PageUp:
            return "PageUp";
        case Qt.Key_PageDown:
            return "PageDown";
        case Qt.Key_Insert:
            return "Insert";
        case Qt.Key_Delete:
            return "Delete";
        case Qt.Key_Minus:
            return "Minus";
        case Qt.Key_Equal:
            return "Equal";
        case Qt.Key_BracketLeft:
            return "BracketLeft";
        case Qt.Key_BracketRight:
            return "BracketRight";
        case Qt.Key_Comma:
            return "Comma";
        case Qt.Key_Period:
            return "Period";
        case Qt.Key_Slash:
            return "Slash";
        case Qt.Key_Backslash:
            return "Backslash";
        case Qt.Key_Semicolon:
            return "Semicolon";
        case Qt.Key_Apostrophe:
            return "Apostrophe";
        case Qt.Key_QuoteLeft:
            return "Grave";
        default:
            return "";
        }
    }
    function keycapLabel(key) {
        switch (String(key).trim()) {
        case "Mod":
        case "Super":
            return "⊞";
        case "+":
            return "＋";
        case "-":
        case "Minus":
        case "−":
            return "−";
        case "Equal":
            return "=";
        case "Left":
            return "←";
        case "Right":
            return "→";
        case "Up":
            return "↑";
        case "Down":
            return "↓";
        case "PageUp":
            return "PgUp";
        case "PageDown":
            return "PgDn";
        case "BackSpace":
            return "Backspace";
        case "WheelScrollUp":
            return "Wheel ↑";
        case "WheelScrollDown":
            return "Wheel ↓";
        default:
            return String(key).trim();
        }
    }
    function rawFromEvent(event) {
        var key = keyName(event);
        if (key === "")
            return "";

        var parts = [];
        if (event.modifiers & Qt.MetaModifier)
            parts.push("Mod");

        if (event.modifiers & Qt.ControlModifier)
            parts.push("Ctrl");

        if (event.modifiers & Qt.AltModifier)
            parts.push("Alt");

        if (event.modifiers & Qt.ShiftModifier)
            parts.push("Shift");

        parts.push(key);
        return parts.join("+");
    }
    function splitDisplay(value) {
        var text = String(value || "").trim();
        if (text === "")
            return [];

        var trailingKey = "";
        if (text.endsWith(" +")) {
            trailingKey = "+";
            text = text.slice(0, -2).trim();
        } else if (text.endsWith(" -") || text.endsWith(" −")) {
            trailingKey = "−";
            text = text.slice(0, -2).trim();
        }

        var rawParts = text === "" ? [] : text.split(/\s*\+\s*/);
        var parts = [];
        for (var i = 0; i < rawParts.length; i++) {
            var part = String(rawParts[i]).trim();
            if (part !== "")
                parts.push(part);
        }
        if (trailingKey !== "")
            parts.push(trailingKey);
        return parts;
    }

    Accessible.name: capturing ? "Press a new keyboard shortcut" : displayKey
    Accessible.role: Accessible.Button
    activeFocusOnTab: interactive
    border.color: activeFocus || capturing ? Config.alpha(Config.md3.primary, 0.7) : "transparent"
    border.width: 1
    color: capturing ? Config.alpha(Config.md3.primary, 0.08) : "transparent"
    implicitHeight: 32
    implicitWidth: keycapRow.implicitWidth + 6
    opacity: interactive ? 1 : 0.5
    radius: 10

    Behavior on color {
        ColorAnimation {
            duration: 130
        }
    }

    Accessible.onPressAction: beginCapture()
    Keys.onPressed: event => {
        if (!capturing) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                beginCapture();
                event.accepted = true;
            }
            return;
        }

        if (event.key === Qt.Key_Escape) {
            capturing = false;
            pendingRaw = "";
            pendingDisplay = "";
            event.accepted = true;
            return;
        }
        var raw = rawFromEvent(event);
        if (raw === "") {
            event.accepted = true;
            return;
        }
        pendingRaw = raw;
        pendingDisplay = displayFromRaw(raw);
        event.accepted = true;
    }
    onActiveFocusChanged: {
        if (!activeFocus)
            finishCapture();
    }

    Row {
        id: keycapRow

        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: root.displayParts

            delegate: Item {
                id: keyPart

                readonly property string label: root.keycapLabel(modelData)
                required property string modelData

                height: 29
                width: Math.max(28, keyLabel.implicitWidth + 16)

                Rectangle {
                    anchors.bottom: parent.bottom
                    color: Config.alpha(root.capturing ? Config.md3.primary : Config.md3.on_surface, root.capturing ? 0.28 : 0.16)
                    height: 27
                    radius: 7
                    width: parent.width
                }
                Rectangle {
                    id: keyFace

                    border.color: Config.alpha(root.capturing ? Config.md3.primary : Config.md3.outline, root.capturing ? 0.5 : 0.28)
                    border.width: 1
                    color: root.capturing ? Config.alpha(Config.md3.primary, 0.18) : Config.alpha(Config.md3.on_surface, 0.09)
                    height: 27
                    radius: 7
                    width: parent.width
                    y: keyPointer.pressed ? 2 : 0

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 130
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: keyLabel

                        anchors.centerIn: parent
                        color: root.capturing ? Config.md3.primary : Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: keyPart.label
                    }
                }
            }
        }
    }
    MouseArea {
        id: keyPointer

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.interactive

        onClicked: root.beginCapture()
    }
}
