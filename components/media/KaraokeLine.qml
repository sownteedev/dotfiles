pragma ComponentBehavior: Bound
import "../../"
import QtQuick

Item {
    id: root

    property real fontSize: 18
    property bool highlighted: true
    readonly property real horizontalInset: Math.min(18, root.width * 0.04)
    required property real position
    required property var words

    clip: true

    Flow {
        id: wordRow

        height: Math.max(1, implicitHeight)
        spacing: 0
        width: Math.max(1, root.width - 2 * root.horizontalInset)
        x: root.horizontalInset + Math.max(0, (root.width - 2 * root.horizontalInset - childrenRect.width) / 2)
        y: Math.max(0, (root.height - height) / 2)

        Repeater {
            model: root.words

            Item {
                id: wordItem

                required property var modelData
                readonly property real progress: !root.highlighted ? 0 : modelData.end <= modelData.start ? (root.position >= modelData.start ? 1 : 0) : Math.max(0, Math.min(1, (root.position - modelData.start) / (modelData.end - modelData.start)))

                height: baseText.implicitHeight
                width: baseText.implicitWidth

                Text {
                    id: baseText

                    color: Config.alpha(Config.md3.on_surface, root.highlighted ? 0.5 : 1)
                    font.family: Config.fontName
                    font.pixelSize: root.fontSize
                    font.weight: Font.Bold
                    text: wordItem.modelData.text
                    textFormat: Text.PlainText
                }
                Item {
                    clip: true
                    height: wordItem.height
                    width: wordItem.width * wordItem.progress

                    Text {
                        color: Config.md3.primary
                        font: baseText.font
                        text: baseText.text
                        textFormat: Text.PlainText
                    }
                }
            }
        }
    }
}
