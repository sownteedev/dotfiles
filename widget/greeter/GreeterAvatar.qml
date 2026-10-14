import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    readonly property string framePath: {
        var points = [];
        var diameter = Math.min(avatarFrame.width, avatarFrame.height);
        var samples = 80;
        var previous = shapeProfiles[previousShapeIndex];
        var currentShape = shapeProfiles[shapeIndex];
        for (var index = 0; index < samples; ++index) {
            var angle = index * Math.PI * 2 / samples - Math.PI / 2;
            var previousRadius = shapeRadius(previous, angle);
            var currentRadius = shapeRadius(currentShape, angle);
            var radius = diameter * (previousRadius + (currentRadius - previousRadius) * shapeProgress);
            points.push(Qt.point(avatarFrame.width / 2 + Math.cos(angle) * radius, avatarFrame.height / 2 + Math.sin(angle) * radius));
        }
        var first = points[0];
        var last = points[points.length - 1];
        var path = "M " + (last.x + first.x) / 2 + " " + (last.y + first.y) / 2;
        for (var pointIndex = 0; pointIndex < points.length; ++pointIndex) {
            var current = points[pointIndex];
            var next = points[(pointIndex + 1) % points.length];
            path += " Q " + current.x + " " + current.y + " " + (current.x + next.x) / 2 + " " + (current.y + next.y) / 2;
        }
        return path + " Z";
    }
    property int previousShapeIndex: 0
    property int shapeIndex: 0
    readonly property var shapeProfiles: [
        {
            "power": 2,
            "lobes": 10,
            "depth": 0.025
        },
        {
            "power": 4,
            "lobes": 0,
            "depth": 0
        },
        {
            "power": 2,
            "lobes": 4,
            "depth": 0.06
        },
        {
            "power": 1.5,
            "lobes": 0,
            "depth": 0
        },
        {
            "power": 2,
            "lobes": 6,
            "depth": 0.035
        },
        {
            "power": 2,
            "lobes": 8,
            "depth": 0.025
        }
    ]
    property real shapeProgress: 1
    property string sourcePath: GreeterProfile.sourcePath

    function pulse() {
        root.previousShapeIndex = root.shapeIndex;
        root.shapeIndex = (root.shapeIndex + 1) % root.shapeProfiles.length;
        root.shapeProgress = 0;
        shapeMorph.restart();
        pulseAnimation.restart();
    }
    function shapeRadius(profile, angle) {
        var contour = Math.pow(Math.pow(Math.abs(Math.cos(angle)), profile.power) + Math.pow(Math.abs(Math.sin(angle)), profile.power), 1 / profile.power);
        var phase = profile.lobes === 4 ? Math.PI : 0;
        return (0.49 - profile.depth + profile.depth * Math.cos(profile.lobes * angle + phase)) / contour;
    }

    Accessible.ignored: true
    implicitHeight: 112
    implicitWidth: 112

    NumberAnimation {
        id: shapeMorph

        duration: 75
        easing.type: Easing.OutCubic
        from: 0
        property: "shapeProgress"
        target: root
        to: 1
    }
    Item {
        id: ornamentLayer

        anchors.fill: parent
        z: -1

        NumberAnimation on rotation {
            duration: 4200
            easing.type: Easing.InOutSine
            from: -3
            loops: Animation.Infinite
            to: 3
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: GreeterTheme.withAlpha(GreeterTheme.primary, 0.62)
                strokeWidth: 1.2

                PathSvg {
                    path: "M 24 10 C 13 1, 2 3, 2 15 C 10 15, 18 13, 24 10 M 2 15 C 9 10, 15 9, 24 10"
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: GreeterTheme.withAlpha(GreeterTheme.primary, 0.5)
                strokeWidth: 1.1

                PathSvg {
                    path: "M 88 102 C 99 110, 109 105, 108 94 C 100 96, 93 99, 88 102 M 108 94 C 101 98, 95 100, 88 102"
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.8)
                strokeWidth: 1

                PathSvg {
                    path: "M 88 8 C 103 15, 110 31, 105 46 M 6 65 C -1 78, 4 91, 16 98"
                }
            }
        }
        Rectangle {
            color: GreeterTheme.primary
            height: 3
            opacity: 0.7
            radius: 1.5
            width: 3
            x: 108
            y: 54
        }
        Rectangle {
            color: GreeterTheme.primary
            height: 2
            opacity: 0.55
            radius: 1
            width: 2
            x: 2
            y: 48
        }
    }
    SequentialAnimation {
        id: pulseAnimation

        loops: 1

        NumberAnimation {
            duration: 110
            easing.type: Easing.InOutSine
            from: 1
            property: "scale"
            target: root
            to: 1.08
        }
        NumberAnimation {
            duration: 150
            easing.type: Easing.InOutSine
            property: "scale"
            target: root
            to: 1
        }
    }
    Item {
        id: avatarFrame

        anchors.centerIn: parent
        height: Math.max(1, parent.height - 12)
        width: Math.max(1, parent.width - 12)

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: GreeterTheme.primaryContainer
                strokeWidth: -1

                PathSvg {
                    path: root.framePath
                }
            }
        }
        Text {
            anchors.centerIn: parent
            color: GreeterTheme.primaryContainerText
            font.family: "Symbols Nerd Font"
            font.pixelSize: Math.round(Math.min(avatarFrame.width, avatarFrame.height) * 0.42)
            text: "󰀄"
            visible: avatar.status !== Image.Ready
        }
        Image {
            id: avatar

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            layer.enabled: status === Image.Ready
            smooth: true
            source: GreeterProfile.fileUrl(root.sourcePath)
            sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
            visible: status === Image.Ready

            layer.effect: OpacityMask {
                maskSource: Shape {
                    height: avatarFrame.height
                    preferredRendererType: Shape.CurveRenderer
                    width: avatarFrame.width

                    ShapePath {
                        fillColor: "white"
                        strokeWidth: -1

                        PathSvg {
                            path: root.framePath
                        }
                    }
                }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: GreeterTheme.primary
                strokeWidth: 2

                PathSvg {
                    path: root.framePath
                }
            }
        }
    }
}
