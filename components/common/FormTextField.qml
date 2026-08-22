import QtQuick
import QtQuick.Layouts
import "../../"

ColumnLayout {
    id: root

    property color backgroundColor: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.6 : 0.24)
    property int echoMode: TextInput.Normal
    readonly property bool editing: inputItem ? inputItem.activeFocus : false
    property int fieldHeight: multiline ? 100 : 50
    property real fieldRadius: 12
    property color focusedBorderColor: Config.alpha(Config.md3.primary, 0.55)
    property int horizontalAlignment: Text.AlignLeft
    property string inputFontFamily: Config.fontName
    property int inputFontPixelSize: 15
    property int inputFontWeight: Font.DemiBold
    readonly property var inputItem: editorLoader.item
    property int inputMethodHints: Qt.ImhNone
    property string label: ""
    property color labelColor: Config.md3.on_surface
    property string labelFontFamily: Config.fontName
    property int labelFontPixelSize: 16
    property int labelFontWeight: Font.Bold
    property int maximumLength: -1
    property bool multiline: false
    property color normalBorderColor: Config.alpha(Config.md3.on_surface, 0.06)
    property string placeholder: ""
    property color placeholderColor: Config.md3.outline
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

    opacity: enabled ? 1 : 0.5
    spacing: 6

    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }

    onMultilineChanged: Qt.callLater(syncEditorText)
    onTextChanged: syncEditorText()

    Text {
        color: root.labelColor
        font.family: root.labelFontFamily
        font.pixelSize: root.labelFontPixelSize
        font.weight: root.labelFontWeight
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
                duration: 150
            }
        }

        Loader {
            id: editorLoader

            anchors.bottomMargin: root.multiline ? 15 : 10
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: root.multiline ? 15 : 10
            sourceComponent: root.multiline ? multilineEditor : singleLineEditor

            onLoaded: root.syncEditorText()
        }
        Text {
            anchors.fill: editorLoader
            color: root.placeholderColor
            font.family: root.placeholderFontFamily
            font.pixelSize: root.placeholderFontPixelSize
            font.weight: root.placeholderFontWeight
            horizontalAlignment: root.horizontalAlignment
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
            clip: true
            color: root.textColor
            echoMode: root.echoMode
            font.family: root.inputFontFamily
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
            color: root.textColor
            font.family: root.inputFontFamily
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
