import QtQuick
import QtQuick.Layouts
import "../../"

ColumnLayout {
    id: root

    property color backgroundColor: Config.md3.surface_container_low
    property int echoMode: TextInput.Normal
    readonly property bool editing: inputItem ? inputItem.activeFocus : false
    property int fieldHeight: multiline ? 112 : 56
    property real fieldRadius: Md3.shape.medium
    property color focusedBorderColor: Config.alpha(Config.md3.primary, 0.52)
    property int horizontalAlignment: Text.AlignLeft
    property string inputFontFamily: Config.fontName
    property int inputFontPixelSize: 15
    property int inputFontWeight: Font.Medium
    readonly property var inputItem: editorLoader.item
    property int inputMethodHints: Qt.ImhNone
    property string label: ""
    property color labelColor: Config.md3.on_surface
    property string labelFontFamily: Config.fontName
    property int labelFontPixelSize: 14
    property int labelFontWeight: Font.DemiBold
    property int maximumLength: -1
    property bool multiline: false
    property color normalBorderColor: Config.alpha(Config.md3.outline, 0.22)
    property string placeholder: ""
    property color placeholderColor: Config.alpha(Config.md3.on_surface_variant, 0.45)
    property string placeholderFontFamily: inputFontFamily
    property int placeholderFontPixelSize: inputFontPixelSize
    property int placeholderFontWeight: inputFontWeight
    property bool readOnly: false
    property string text: ""
    property color textColor: Config.md3.on_surface
    property int verticalAlignment: multiline ? Text.AlignTop : Text.AlignVCenter
    property int wrapMode: multiline ? TextEdit.Wrap : TextEdit.NoWrap

    signal accepted
    signal clicked

    function forceActiveFocus() {
        if (inputItem)
            inputItem.forceActiveFocus();
    }
    function syncEditorText() {
        if (inputItem && inputItem.text !== text)
            inputItem.text = text;
    }

    Layout.minimumWidth: 0
    opacity: enabled ? 1 : Md3.state.disabledContent
    spacing: Md3.spacing.xs

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animationDuration(Md3.motion.short2)
        }
    }

    onMultilineChanged: Qt.callLater(syncEditorText)
    onTextChanged: syncEditorText()

    Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        color: root.labelColor
        elide: Text.ElideRight
        font.family: root.labelFontFamily
        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
        font.pixelSize: root.labelFontPixelSize
        font.weight: root.labelFontWeight
        renderType: Text.NativeRendering
        text: root.label
        visible: text !== ""
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.multiline && root.inputItem ? Math.max(root.fieldHeight, root.inputItem.contentHeight + 30) : root.fieldHeight
        border.color: root.editing ? root.focusedBorderColor : root.normalBorderColor
        border.width: 1
        color: root.backgroundColor
        radius: root.fieldRadius

        Behavior on border.color {
            ColorAnimation {
                duration: Config.animationDuration(Md3.motion.short3)
            }
        }

        Loader {
            id: editorLoader

            anchors.bottomMargin: root.multiline ? 15 : 10
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: root.multiline ? 15 : 10
            sourceComponent: root.multiline ? multilineEditor : singleLineEditor

            onLoaded: root.syncEditorText()
        }
        Text {
            anchors.fill: editorLoader
            color: root.placeholderColor
            elide: root.multiline ? Text.ElideNone : Text.ElideRight
            font.family: root.placeholderFontFamily
            font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
            font.pixelSize: root.placeholderFontPixelSize
            font.weight: root.placeholderFontWeight
            horizontalAlignment: root.horizontalAlignment
            renderType: Text.NativeRendering
            text: root.placeholder
            verticalAlignment: root.verticalAlignment
            visible: root.text === ""
            wrapMode: root.wrapMode
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: root.readOnly

            onClicked: root.clicked()
        }
    }
    Component {
        id: singleLineEditor

        TextInput {
            Accessible.description: root.placeholder
            Accessible.name: root.label !== "" ? root.label : root.placeholder
            Accessible.role: Accessible.EditableText
            activeFocusOnTab: !root.readOnly
            clip: true
            color: root.textColor
            echoMode: root.echoMode
            font.family: root.inputFontFamily
            font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
            font.pixelSize: root.inputFontPixelSize
            font.weight: root.inputFontWeight
            horizontalAlignment: root.horizontalAlignment
            inputMethodHints: root.inputMethodHints
            maximumLength: root.maximumLength > 0 ? root.maximumLength : 32767
            readOnly: root.readOnly
            selectedTextColor: Config.md3.background
            selectionColor: Config.md3.primary
            verticalAlignment: TextInput.AlignVCenter

            onAccepted: root.accepted()
            onTextChanged: {
                if (root.text !== text)
                    root.text = text;
            }
        }
    }
    Component {
        id: multilineEditor

        TextEdit {
            Accessible.description: root.placeholder
            Accessible.name: root.label !== "" ? root.label : root.placeholder
            Accessible.role: Accessible.EditableText
            activeFocusOnTab: !root.readOnly
            color: root.textColor
            font.family: root.inputFontFamily
            font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
            font.pixelSize: root.inputFontPixelSize
            font.weight: root.inputFontWeight
            horizontalAlignment: root.horizontalAlignment
            inputMethodHints: root.inputMethodHints
            readOnly: root.readOnly
            selectedTextColor: Config.md3.background
            selectionColor: Config.md3.primary
            textFormat: TextEdit.PlainText
            verticalAlignment: TextEdit.AlignTop
            wrapMode: root.wrapMode

            onTextChanged: {
                if (root.text !== text)
                    root.text = text;
            }
        }
    }
}
