import QtQuick
import QtQuick.Controls
import "../../"

Popup {
    id: root

    // ─── Internal state ────────────────────────────────────────────────────────
    property int _hour: 0
    property int _minute: 0
    property bool _selectingMinute: false

    signal confirmed(string h, string m)

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
        open();
    }

    closePolicy: Popup.CloseOnEscape
    focus: true
    height: parent ? Responsive.fitWithMargins(400, parent.height, 8, 260) : 400
    modal: true
    parent: Overlay.overlay

    // ─── Geometry & style ──────────────────────────────────────────────────────
    width: parent ? Responsive.fitWithMargins(300, parent.width, 8, 220) : 300

    background: Rectangle {
        border.color: Config.alpha(Config.md3.on_surface, 0.12)
        border.width: 1
        color: Config.md3.surface
        radius: Math.min(16, root.width / 2, root.height / 2)
    }

    // ─── Root item ─────────────────────────────────────────────────────────────
    Flickable {
        id: contentViewport

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: contentWidth > width || contentHeight > height
        contentHeight: Math.max(height, 400)
        contentWidth: Math.max(width, 300)
        flickableDirection: Flickable.AutoFlickDirection
        interactive: contentWidth > width || contentHeight > height

        Item {
            id: contentCanvas

            height: 368
            width: 268
            x: (contentViewport.contentWidth - width) / 2
            y: (contentViewport.contentHeight - height) / 2

        // ── Time display (top) ─────────────────────────────────────────────
        Row {
            id: timeDisplay

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            spacing: 0

            // Hour chip
            Rectangle {
                color: !root._selectingMinute ? Config.alpha(Config.md3.primary, 0.25) : Config.alpha(Config.md3.on_surface, 0.07)
                height: 50
                radius: 10
                width: 60

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: !root._selectingMinute ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.7)
                    font.family: Config.fontName
                    font.pixelSize: 27
                    font.weight: Font.ExtraBold
                    text: String(root._hour).padStart(2, '0')

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: root._selectingMinute = false
                }
            }

            // Separator
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 27
                font.weight: Font.ExtraBold
                leftPadding: 4
                rightPadding: 4
                text: ":"
            }

            // Minute chip
            Rectangle {
                color: root._selectingMinute ? Config.alpha(Config.md3.primary, 0.25) : Config.alpha(Config.md3.on_surface, 0.07)
                height: 50
                radius: 10
                width: 60

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: root._selectingMinute ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.7)
                    font.family: Config.fontName
                    font.pixelSize: 27
                    font.weight: Font.ExtraBold
                    text: String(root._minute).padStart(2, '0')

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
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

        // ── Analog clock face ──────────────────────────────────────────────
        Item {
            id: clockFace

            readonly property int cx: 115
            readonly property int cy: 115

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: timeDisplay.bottom
            anchors.topMargin: 14
            height: 230
            width: 230

            // Background circle
            Rectangle {
                anchors.fill: parent
                color: Config.md3.surface_container
                radius: width / 2
            }

            // ── Number labels ──────────────────────────────────────────────
            Repeater {
                model: root._selectingMinute ? 12 : 24

                delegate: Item {
                    property real angleDeg: {
                        if (root._selectingMinute)
                            return index * 30 - 90;
                        return (index % 12) * 30 - 90;
                    }
                    // For hours:   outer ring = 1-12, inner ring = 13-23 + 00
                    // For minutes: 12 tick labels every 5 minutes
                    property int displayVal: {
                        if (root._selectingMinute) {
                            return index * 5;
                        } else if (index < 12) {
                            return (index === 0) ? 12 : index;
                        } else {
                            return (index === 12) ? 0 : index;
                        }
                    }
                    property bool isInner: !root._selectingMinute && index >= 12
                    property bool isSelected: {
                        if (root._selectingMinute) {
                            return root._minute === displayVal;
                        }
                        return root._hour === displayVal;
                    }
                    property real ringRadius: isInner ? 65 : 95

                    height: 30
                    width: 30
                    x: clockFace.cx + ringRadius * Math.cos(angleDeg * Math.PI / 180) - 15
                    y: clockFace.cy + ringRadius * Math.sin(angleDeg * Math.PI / 180) - 15

                    // Selection highlight
                    Rectangle {
                        anchors.centerIn: parent
                        color: isSelected ? Config.md3.primary : "transparent"
                        height: 28
                        radius: 14
                        width: 28

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        color: isSelected ? Config.md3.background : (isInner ? Config.alpha(Config.md3.on_surface, 0.55) : Config.md3.on_surface)
                        font.family: Config.fontName
                        font.pixelSize: isInner ? 12 : 14
                        font.weight: isSelected ? Font.ExtraBold : (isInner ? Font.DemiBold : Font.Bold)
                        text: displayVal === 0 ? "00" : String(displayVal)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                }
            }

            // ── Clock hand ─────────────────────────────────────────────────
            Item {
                property real handAngle: {
                    if (root._selectingMinute)
                        return root._minute * 6 - 90;
                    return (root._hour % 12) * 30 - 90;
                }
                property real handLen: {
                    if (root._selectingMinute)
                        return 95;
                    // Inner ring contains 00 and 13–23; 12 belongs to the outer ring.
                    return (root._hour === 0 || root._hour > 12) ? 65 : 95;
                }

                anchors.fill: parent

                // Stem
                Rectangle {
                    color: Config.md3.primary
                    height: 2
                    opacity: 0.8
                    rotation: parent.handAngle
                    transformOrigin: Item.Left
                    width: parent.handLen
                    x: clockFace.cx
                    y: clockFace.cy - 1

                    Behavior on rotation {
                        RotationAnimation {
                            direction: RotationAnimation.Shortest
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Center dot
                Rectangle {
                    anchors.centerIn: parent
                    color: Config.md3.primary
                    height: 10
                    radius: 5
                    width: 10
                }
            }

            // ── Mouse / touch interaction ──────────────────────────────────
            MouseArea {
                function pick(mx, my) {
                    var dx = mx - clockFace.cx;
                    var dy = my - clockFace.cy;
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    // atan2 → [−180, 180]; shift so 12 o'clock = 0°
                    var angle = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + 360) % 360;

                    if (root._selectingMinute) {
                        root._minute = Math.round(angle / 6) % 60;
                    } else {
                        var slot = Math.round(angle / 30) % 12;
                        if (dist < 82) {                            // inner ring
                            root._hour = (slot === 0) ? 0 : slot + 12;
                        } else {                                    // outer ring
                            root._hour = (slot === 0) ? 12 : slot;
                        }
                    }
                }

                anchors.fill: parent

                onPositionChanged: e => {
                    pick(e.x, e.y);
                }
                onPressed: e => {
                    pick(e.x, e.y);
                }
                onReleased: {
                    // After selecting hour, automatically switch to minute mode
                    if (!root._selectingMinute)
                        root._selectingMinute = true;
                }
            }
        }

        // ── Cancel / OK buttons (bottom-right) ────────────────────────────
        Row {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            spacing: 8

            // Cancel
            Rectangle {
                color: cancelArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent"
                height: 34
                radius: 8
                width: 72

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.outline
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: "Cancel"
                }
                MouseArea {
                    id: cancelArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.close()
                }
            }

            // OK
            Rectangle {
                color: okArea.pressed ? Qt.darker(Config.md3.primary, 1.15) : Config.md3.primary
                height: 34
                radius: 8
                width: 60

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.background
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    text: "OK"
                }
                MouseArea {
                    id: okArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.confirmed(String(root._hour).padStart(2, '0'), String(root._minute).padStart(2, '0'));
                        root.close();
                    }
                }
            }
        }
        }
    }
}
