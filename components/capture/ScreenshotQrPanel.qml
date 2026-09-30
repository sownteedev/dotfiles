import "../../"
import ".."
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Rectangle {
    id: root

    readonly property var activeCode: activeIndex >= 0 ? codes[activeIndex] : ({})
    readonly property int activeIndex: codes.length === 0 ? -1 : Math.max(0, Math.min(codeList.currentIndex, codes.length - 1))
    property var codes: []
    property int copiedIndex: -1
    property bool copyBusy: false
    property bool copyFailed: false

    signal backRequested
    signal copyRequested(int index)
    signal openRequested(int index)

    function preview(code) {
        var text = String(code.text || "");
        if (/^WIFI:/i.test(text))
            return qsTr("Wi-Fi details · Copy to view");
        if (/^otpauth:/i.test(text))
            return qsTr("Authenticator setup · Copy to view");
        return text.replace(/[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]/g, " ");
    }

    color: Config.md3.surface_container_low
    implicitHeight: 232
    radius: 12

    onCodesChanged: {
        copiedIndex = -1;
        copyBusy = false;
        copyFailed = false;
        codeList.currentIndex = codes.length > 0 ? 0 : -1;
        codeList.positionViewAtBeginning();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 4

            Md3IconButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                iconName: "go-previous-symbolic"
                iconSize: 20
                tooltipText: qsTr("Back to screenshot")

                onClicked: root.backRequested()
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                color: root.copyFailed ? Config.md3.error : Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                font.pixelSize: Md3.typeScale.bodyMedium.size
                font.weight: Font.Medium
                text: root.copyFailed ? qsTr("Could not copy. Try again.") : root.activeCode.host || qsTr("Text")
                textFormat: Text.PlainText
            }
            Md3IconButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                enabled: root.activeIndex >= 0 && !root.copyBusy
                iconName: root.copiedIndex === root.activeIndex ? "checkmark-symbolic" : "edit-copy-symbolic"
                iconSize: 20
                tooltipText: root.copiedIndex === root.activeIndex ? qsTr("Copied") : qsTr("Copy QR content")

                onClicked: root.copyRequested(root.activeIndex)
            }
            Md3IconButton {
                Layout.preferredHeight: 40
                Layout.preferredWidth: 40
                containerStyle: "tonal"
                iconName: "external-link-symbolic"
                iconSize: 20
                tooltipText: qsTr("Open %1").arg(String(root.activeCode.host || ""))
                visible: String(root.activeCode.url || "") !== ""

                onClicked: root.openRequested(root.activeIndex)
            }
        }
        ListView {
            id: codeList

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumHeight: 0
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentHeight > height
            model: root.codes
            spacing: 12

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: ColumnLayout {
                id: codeRow

                required property int index
                required property var modelData

                height: implicitHeight
                spacing: 8
                width: ListView.view.width - (codeList.interactive ? 10 : 0)

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: Md3.typeScale.bodyMedium.size
                    text: root.preview(codeRow.modelData)
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                }
                Rectangle {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.outline_variant, 0.35)
                    implicitHeight: 1
                    visible: codeRow.index < root.codes.length - 1
                }
            }

            onMovementEnded: {
                var visibleIndex = indexAt(1, contentY + 1);
                if (visibleIndex >= 0)
                    currentIndex = visibleIndex;
            }
        }
    }
}
