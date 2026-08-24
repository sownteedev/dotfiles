import ".."
import "../../"
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: root

    readonly property var filteredFonts: {
        var query = searchInput.text.trim().toLowerCase();
        if (query === "")
            return fontFamilies;

        var matches = [];
        for (var i = 0; i < fontFamilies.length; ++i) {
            var family = String(fontFamilies[i]);
            if (family.toLowerCase().indexOf(query) >= 0)
                matches.push(family);
        }
        return matches;
    }
    property var fontFamilies: []
    property string label: ""
    property string placeholder: ""
    property string text: ""

    function openPicker() {
        if (!enabled)
            return;

        searchInput.text = "";
        pickerPopup.open();
    }
    function positionSelectedFont() {
        Qt.callLater(function () {
            var selectedIndex = root.filteredFonts.indexOf(root.text);
            fontList.currentIndex = selectedIndex >= 0 ? selectedIndex : (root.filteredFonts.length > 0 ? 0 : -1);
            if (selectedIndex >= 0)
                fontList.positionViewAtIndex(selectedIndex, ListView.Center);
            else
                fontList.positionViewAtBeginning();
        });
    }
    function selectFont(family) {
        if (!family)
            return;

        text = String(family);
        pickerPopup.close();
    }

    spacing: 8

    Component.onCompleted: {
        var families = Qt.fontFamilies().slice();
        families.sort(function (left, right) {
            return String(left).localeCompare(String(right));
        });
        fontFamilies = families;
    }

    Text {
        color: Config.alpha(Config.md3.on_surface, 0.85)
        font.family: Config.fontName
        font.pixelSize: 14
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
        text: root.label
        visible: text !== ""
    }
    Rectangle {
        id: fieldFrame

        Accessible.name: root.label + ": " + root.text
        Accessible.role: Accessible.ComboBox
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        activeFocusOnTab: root.enabled
        border.color: activeFocus || pickerPopup.visible ? Config.alpha(Config.md3.primary, 0.7) : "transparent"
        border.width: 1
        color: fieldMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : Config.alpha(Config.md3.on_surface, 0.05)
        radius: 12

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Accessible.onPressAction: root.openPicker()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                root.openPicker();
                event.accepted = true;
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: caretIcon.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: root.text === "" ? Config.alpha(Config.md3.on_surface, 0.38) : Config.md3.on_surface
            elide: Text.ElideRight
            font.family: root.text === "" ? Config.fontName : root.text
            font.pixelSize: 14
            font.weight: Font.Medium
            renderType: Text.NativeRendering
            text: root.text === "" ? root.placeholder : root.text
        }
        IconImage {
            id: caretIcon

            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            height: 16
            layer.enabled: true
            source: Quickshell.iconPath("pan-down-symbolic")
            width: 16

            layer.effect: ColorOverlay {
                color: Config.alpha(Config.md3.on_surface, 0.58)
            }
        }
        MouseArea {
            id: fieldMouse

            anchors.fill: parent
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.enabled
            hoverEnabled: true

            onClicked: {
                fieldFrame.forceActiveFocus();
                root.openPicker();
            }
        }
    }
    Popup {
        id: pickerPopup

        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        focus: true
        height: 400
        padding: 8
        width: Math.min(520, root.width)
        x: 0
        y: root.height + 6

        background: Item {
            ShellShadow {
                cornerRadius: pickerSurface.radius
                target: pickerSurface
            }
            Rectangle {
                id: pickerSurface

                anchors.fill: parent
                border.color: Config.alpha(Config.md3.outline, 0.28)
                border.width: 1
                color: Config.md3.surface_container_high
                radius: 14
            }
        }
        contentItem: ColumnLayout {
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                border.color: searchInput.activeFocus ? Config.alpha(Config.md3.primary, 0.64) : Config.alpha(Config.md3.outline, 0.22)
                border.width: 1
                color: Config.alpha(Config.md3.on_surface, 0.055)
                radius: 10

                IconImage {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath("system-search-symbolic")
                    width: 16

                    layer.effect: ColorOverlay {
                        color: Config.alpha(Config.md3.on_surface, 0.55)
                    }
                }
                TextInput {
                    id: searchInput

                    anchors.bottom: parent.bottom
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter

                    Keys.onPressed: event => {
                        var count = root.filteredFonts.length;
                        if (event.key === Qt.Key_Escape) {
                            pickerPopup.close();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down && count > 0) {
                            fontList.currentIndex = Math.min(count - 1, fontList.currentIndex + 1);
                            fontList.positionViewAtIndex(fontList.currentIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up && count > 0) {
                            fontList.currentIndex = Math.max(0, fontList.currentIndex - 1);
                            fontList.positionViewAtIndex(fontList.currentIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Home && count > 0) {
                            fontList.currentIndex = 0;
                            fontList.positionViewAtBeginning();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_End && count > 0) {
                            fontList.currentIndex = count - 1;
                            fontList.positionViewAtEnd();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown && count > 0) {
                            fontList.currentIndex = Math.min(count - 1, fontList.currentIndex + 7);
                            fontList.positionViewAtIndex(fontList.currentIndex, ListView.Contain);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageUp && count > 0) {
                            fontList.currentIndex = Math.max(0, fontList.currentIndex - 7);
                            fontList.positionViewAtIndex(fontList.currentIndex, ListView.Contain);
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && fontList.currentIndex >= 0) {
                            root.selectFont(root.filteredFonts[fontList.currentIndex]);
                            event.accepted = true;
                        }
                    }
                    onTextChanged: {
                        fontList.currentIndex = root.filteredFonts.length > 0 ? 0 : -1;
                        fontList.positionViewAtBeginning();
                    }

                    Text {
                        anchors.fill: parent
                        color: Config.alpha(Config.md3.on_surface, 0.38)
                        font: searchInput.font
                        text: qsTr("Search fonts")
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text === ""
                    }
                }
            }
            ListView {
                id: fontList

                Layout.fillHeight: true
                Layout.fillWidth: true
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                currentIndex: -1
                model: root.filteredFonts
                reuseItems: true
                spacing: 2

                delegate: Rectangle {
                    id: fontRow

                    required property int index
                    required property string modelData
                    readonly property bool selected: modelData === root.text

                    color: selected ? Config.alpha(Config.md3.primary, 0.15) : index === fontList.currentIndex || rowMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : "transparent"
                    height: 50
                    radius: 10
                    width: ListView.view.width

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: checkmark.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: fontRow.selected ? Config.md3.primary : Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: fontRow.modelData
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                        text: fontRow.modelData
                    }
                    Text {
                        id: checkmark

                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.primary
                        font.family: Config.fontName
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        text: "✓"
                        visible: fontRow.selected
                    }
                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.selectFont(fontRow.modelData)
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                color: Config.alpha(Config.md3.on_surface, 0.48)
                font.family: Config.fontName
                font.pixelSize: 13
                text: qsTr("No matching fonts")
                visible: root.filteredFonts.length === 0
            }
        }
        enter: Transition {
            NumberAnimation {
                duration: Config.shellReducedMotion ? 0 : 160
                easing.type: Easing.OutCubic
                from: 0
                property: "opacity"
                to: 1
            }
        }
        exit: Transition {
            NumberAnimation {
                duration: Config.shellReducedMotion ? 0 : 110
                easing.type: Easing.InCubic
                from: 1
                property: "opacity"
                to: 0
            }
        }

        onClosed: fieldFrame.forceActiveFocus()
        onOpened: {
            searchInput.forceActiveFocus();
            root.positionSelectedFont();
        }
    }
}
