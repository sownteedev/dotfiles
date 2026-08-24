import QtQuick
import QtQuick.Controls
import ".."
import "../../"

Popup {
    id: root

    property bool _dragging: false
    property int _hour: 0
    property int _minute: 0
    property real _pointerAngle: -90
    property bool _selectingMinute: false
    property Item placementParent: null

    signal confirmed(string h, string m)

    function confirmSelection() {
        root.confirmed(String(root._hour).padStart(2, "0"), String(root._minute).padStart(2, "0"));
        root.close();
    }
    function openWith(timeStr) {
        var parts = timeStr.split(":");
        if (parts.length === 2) {
            _hour = parseInt(parts[0], 10);
            _minute = parseInt(parts[1], 10);
        } else {
            _hour = 0;
            _minute = 0;
        }
        _selectingMinute = false;
        updatePlacement();
        open();
    }
    function updatePlacement() {
        if (!placementParent || !parent)
            return;
        var origin = placementParent.mapToItem(parent, 0, 0);
        x = Math.max(8, Math.min(origin.x + (placementParent.width - width) / 2, parent.width - width - 8));
        y = Math.max(8, Math.min(origin.y + (placementParent.height - height) / 2, parent.height - height - 8));
    }

    closePolicy: Popup.CloseOnEscape
    focus: true
    height: placementParent ? Responsive.fitWithMargins(436, placementParent.height, 8, 340) : parent ? Responsive.fitWithMargins(436, parent.height, 8, 340) : 436
    modal: true
    padding: 0
    parent: Overlay.overlay
    width: placementParent ? Responsive.fitWithMargins(368, placementParent.width, 8, 310) : parent ? Responsive.fitWithMargins(368, parent.width, 8, 310) : 368

    Overlay.modal: Rectangle {
        color: Config.alpha(Config.md3.scrim, Config.lightTheme ? 0.22 : 0.38)
    }
    background: Item {
        ShellShadow {
            cornerRadius: pickerSurface.radius
            target: pickerSurface
        }
        Rectangle {
            id: pickerSurface

            anchors.fill: parent
            border.color: Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.14 : 0.1)
            border.width: 1
            color: Config.alpha(Config.md3.surface, Config.lightTheme ? 0.97 : 0.92)
            radius: Math.min(24, root.width / 2, root.height / 2)
        }
    }
    enter: Transition {
        NumberAnimation {
            duration: Config.animationDuration(170)
            easing.type: Easing.OutCubic
            from: 0
            property: "opacity"
            to: 1
        }
    }
    exit: Transition {
        NumberAnimation {
            duration: Config.animationDuration(120)
            easing.type: Easing.InCubic
            from: 1
            property: "opacity"
            to: 0
        }
    }

    onAboutToShow: updatePlacement()

    Flickable {
        id: contentViewport

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: contentWidth > width || contentHeight > height
        contentHeight: Math.max(height, 436)
        contentWidth: Math.max(width, 368)
        flickableDirection: Flickable.AutoFlickDirection
        interactive: contentWidth > width || contentHeight > height

        Item {
            id: contentCanvas

            height: 404
            width: 336
            x: (contentViewport.contentWidth - width) / 2
            y: (contentViewport.contentHeight - height) / 2

            Row {
                id: timeDisplay

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 8

                Rectangle {
                    border.color: !root._selectingMinute ? Config.alpha(Config.md3.primary, 0.45) : Config.alpha(Config.md3.on_surface, 0.08)
                    border.width: 1
                    color: !root._selectingMinute ? Config.md3.primary_container : Config.alpha(Config.md3.on_surface, 0.055)
                    height: 58
                    radius: 17
                    width: 74

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(140)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: !root._selectingMinute ? Config.md3.on_primary_container : Config.alpha(Config.md3.on_surface, 0.66)
                        font.family: Config.fontName
                        font.pixelSize: 28
                        font.weight: Font.ExtraBold
                        text: String(root._hour).padStart(2, "0")

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(140)
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root._selectingMinute = false
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Config.alpha(Config.md3.on_surface, 0.62)
                    font.family: Config.fontName
                    font.pixelSize: 26
                    font.weight: Font.ExtraBold
                    text: ":"
                }
                Rectangle {
                    border.color: root._selectingMinute ? Config.alpha(Config.md3.primary, 0.45) : Config.alpha(Config.md3.on_surface, 0.08)
                    border.width: 1
                    color: root._selectingMinute ? Config.md3.primary_container : Config.alpha(Config.md3.on_surface, 0.055)
                    height: 58
                    radius: 17
                    width: 74

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(140)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: root._selectingMinute ? Config.md3.on_primary_container : Config.alpha(Config.md3.on_surface, 0.66)
                        font.family: Config.fontName
                        font.pixelSize: 28
                        font.weight: Font.ExtraBold
                        text: String(root._minute).padStart(2, "0")

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(140)
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root._selectingMinute = true
                    }
                }
            }
            Item {
                id: clockFace

                readonly property int cx: 136
                readonly property int cy: 136

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: timeDisplay.bottom
                anchors.topMargin: 14
                height: 272
                width: 272

                Rectangle {
                    anchors.fill: parent
                    border.color: Config.alpha(Config.md3.on_surface, 0.075)
                    border.width: 1
                    color: Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.045 : 0.065)
                    radius: width / 2
                }
                Item {
                    id: clockHand

                    property real handAngle: {
                        if (root._dragging)
                            return root._pointerAngle;
                        if (root._selectingMinute)
                            return root._minute * 6 - 90;
                        return (root._hour % 12) * 30 - 90;
                    }
                    property real handLen: {
                        if (root._selectingMinute)
                            return 114;
                        return root._hour === 0 || root._hour > 12 ? 80 : 114;
                    }

                    anchors.fill: parent

                    Rectangle {
                        color: Config.md3.primary
                        height: 3
                        opacity: 0.82
                        radius: 2
                        rotation: clockHand.handAngle
                        transformOrigin: Item.Left
                        width: clockHand.handLen
                        x: clockFace.cx
                        y: clockFace.cy - height / 2

                        Behavior on rotation {
                            enabled: !root._dragging

                            RotationAnimation {
                                direction: RotationAnimation.Shortest
                                duration: Config.animationDuration(150)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Rectangle {
                        color: Config.md3.primary
                        height: 12
                        radius: 6
                        width: 12
                        x: clockFace.cx + clockHand.handLen * Math.cos(clockHand.handAngle * Math.PI / 180) - width / 2
                        y: clockFace.cy + clockHand.handLen * Math.sin(clockHand.handAngle * Math.PI / 180) - height / 2
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        border.color: Config.md3.primary
                        border.width: 3
                        color: Config.md3.surface
                        height: 12
                        radius: 6
                        width: 12
                    }
                }
                Repeater {
                    model: root._selectingMinute ? 12 : 24

                    delegate: Item {
                        property real angleDeg: root._selectingMinute ? index * 30 - 90 : (index % 12) * 30 - 90
                        property int displayVal: {
                            if (root._selectingMinute)
                                return index * 5;
                            if (index < 12)
                                return index === 0 ? 12 : index;
                            return index === 12 ? 0 : index;
                        }
                        property bool isInner: !root._selectingMinute && index >= 12
                        property bool isSelected: root._selectingMinute ? root._minute === displayVal : root._hour === displayVal
                        property real ringRadius: isInner ? 80 : 114

                        height: 32
                        width: 32
                        x: clockFace.cx + ringRadius * Math.cos(angleDeg * Math.PI / 180) - width / 2
                        y: clockFace.cy + ringRadius * Math.sin(angleDeg * Math.PI / 180) - height / 2

                        Rectangle {
                            anchors.centerIn: parent
                            color: isSelected ? Config.md3.primary : "transparent"
                            height: 32
                            radius: 16
                            width: 32

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(120)
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            color: isSelected ? Config.md3.on_primary : (isInner ? Config.alpha(Config.md3.on_surface, 0.46) : Config.alpha(Config.md3.on_surface, 0.86))
                            font.family: Config.fontName
                            font.pixelSize: isInner ? 12 : 14
                            font.weight: isSelected ? Font.ExtraBold : Font.DemiBold
                            text: displayVal === 0 ? "00" : String(displayVal)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(120)
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    id: clockArea

                    function pick(mx, my) {
                        var dx = mx - clockFace.cx;
                        var dy = my - clockFace.cy;
                        var dist = Math.sqrt(dx * dx + dy * dy);
                        var angle = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + 360) % 360;
                        var pointerAngle = angle - 90;
                        while (pointerAngle - root._pointerAngle > 180)
                            pointerAngle -= 360;
                        while (pointerAngle - root._pointerAngle < -180)
                            pointerAngle += 360;
                        root._pointerAngle = pointerAngle;

                        if (root._selectingMinute) {
                            root._minute = Math.round(angle / 6) % 60;
                        } else {
                            var slot = Math.round(angle / 30) % 12;
                            if (dist < 97)
                                root._hour = slot === 0 ? 0 : slot + 12;
                            else
                                root._hour = slot === 0 ? 12 : slot;
                        }
                    }

                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    preventStealing: true

                    onCanceled: root._dragging = false
                    onPositionChanged: event => pick(event.x, event.y)
                    onPressed: event => {
                        root._pointerAngle = root._selectingMinute ? root._minute * 6 - 90 : (root._hour % 12) * 30 - 90;
                        root._dragging = true;
                        pick(event.x, event.y);
                    }
                    onReleased: {
                        if (!root._selectingMinute)
                            root._selectingMinute = true;
                        root._dragging = false;
                    }
                }
            }
            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    border.color: Config.alpha(Config.md3.on_surface, 0.1)
                    border.width: 1
                    color: cancelArea.pressed ? Config.alpha(Config.md3.on_surface, 0.12) : cancelArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : Config.alpha(Config.md3.on_surface, 0.035)
                    height: 40
                    radius: 20
                    width: 96

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(100)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: Config.alpha(Config.md3.on_surface, 0.72)
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        text: qsTr("Cancel")
                    }
                    MouseArea {
                        id: cancelArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.close()
                    }
                }
                Rectangle {
                    color: doneArea.pressed ? Qt.darker(Config.md3.primary, 1.12) : doneArea.containsMouse ? Qt.lighter(Config.md3.primary, 1.08) : Config.md3.primary
                    height: 40
                    radius: 20
                    width: 104

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(100)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: Config.md3.on_primary
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        text: qsTr("Done")
                    }
                    MouseArea {
                        id: doneArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: root.confirmSelection()
                    }
                }
            }
        }
    }
}
