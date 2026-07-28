import "../../"
import QtQuick

Rectangle {
    id: root

    property bool capturing: false
    property string displayKey: ""
    property bool interactive: true
    property string oldHeader: ""
    property string pendingDisplay: ""
    property string pendingRaw: ""

    signal committed(string oldHeader, string newKey)

    function displayFromRaw(raw) {
        var parts = raw.split("+");
        var output = [];
        for (var i = 0; i < parts.length; i++) output.push(parts[i] === "Mod" ? "Super" : parts[i])
        return output.join(" + ");
    }

    function finishCapture() {
        if (!capturing)
            return ;

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

    Accessible.name: capturing ? "Press a new keyboard shortcut" : displayKey
    Accessible.role: Accessible.Button
    activeFocusOnTab: interactive
    border.color: activeFocus ? Config.md3.primary : "transparent"
    border.width: 1
    color: capturing ? Config.alpha(Config.md3.primary, 0.27) : Config.alpha(Config.md3.primary, 0.15)
    implicitHeight: 32
    implicitWidth: keyText.implicitWidth + 24
    opacity: interactive ? 1 : 0.5
    radius: 15
    Keys.onPressed: (event) => {
        if (!capturing)
            return ;

        if (event.key === Qt.Key_Escape) {
            capturing = false;
            pendingRaw = "";
            pendingDisplay = "";
            event.accepted = true;
            return ;
        }
        var raw = rawFromEvent(event);
        if (raw === "") {
            event.accepted = true;
            return ;
        }
        pendingRaw = raw;
        pendingDisplay = displayFromRaw(raw);
        event.accepted = true;
    }
    onActiveFocusChanged: {
        if (!activeFocus)
            finishCapture();

    }

    Text {
        id: keyText

        anchors.centerIn: parent
        color: Config.md3.primary
        font.family: Config.fontName
        font.pixelSize: 13
        font.weight: Font.DemiBold
        text: root.capturing ? (root.pendingDisplay === "" ? "Press shortcut…" : root.pendingDisplay) : root.displayKey
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.interactive
        onClicked: {
            root.pendingRaw = "";
            root.pendingDisplay = "";
            root.capturing = true;
            root.forceActiveFocus(Qt.MouseFocusReason);
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: 130
        }

    }

}
