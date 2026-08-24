import QtQuick
import QtQuick.Layouts
import "../../"
import "../../components" as Components

Item {
    id: root

    property color chartBackgroundColor: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.60 : 0.30)
    property color chartBorderColor: Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.11 : 0.08)
    property int chartHeight: 130
    property var displayedHistory: []
    property var displayedHistory2: []
    property bool expandable: false
    property bool expanded: false
    property real expansionProgress: expanded ? 1 : 0
    property var historyData: []
    property var historyData2: []
    property color lineColor: Config.md3.primary
    property color lineColor2: "transparent"
    property real maxValue: 100
    property int modelFontSize: 15
    property string modelText: ""
    property var processList: null
    property bool processManagerEnabled: false
    property int processPanelHeight: processManagerEnabled ? Math.ceil(processContent.implicitHeight + 10) : 178
    property int processRevision: 0
    property string processTitle: "Top Processes"
    property string processValueSuffix: "%"
    property var slideHistory: []
    property var slideHistory2: []
    property int terminatingPid: -1
    property string terminationError: ""
    property string title: ""
    property int titleFontSize: 15
    property string valueText: ""

    signal clicked
    signal terminateRequested(int pid, string name)

    function requestPaint() {
        if (!root.visible || root.width <= 0 || root.height <= 0)
            return;

        var nextHistory = root.historyData ? root.historyData.slice() : [];
        var nextHistory2 = root.historyData2 ? root.historyData2.slice() : [];
        var firstFrame = displayedHistory.length !== nextHistory.length;

        // Draw the previous 60 samples plus the newest sample. At x = 0 this
        // exactly matches the end of the previous frame; moving left by one
        // point then reveals the new value without a reset flash.
        var primaryBase = firstFrame ? nextHistory : displayedHistory;
        slideHistory = primaryBase.slice();
        if (nextHistory.length > 0)
            slideHistory.push(nextHistory[nextHistory.length - 1]);

        if (nextHistory2.length > 0) {
            var secondaryBase = displayedHistory2.length === nextHistory2.length ? displayedHistory2 : nextHistory2;
            slideHistory2 = secondaryBase.slice();
            slideHistory2.push(nextHistory2[nextHistory2.length - 1]);
        } else {
            slideHistory2 = [];
        }

        displayedHistory = nextHistory;
        displayedHistory2 = nextHistory2;
        dataCanvas.prepareFrame(!firstFrame);
    }

    implicitHeight: 28 + chartHeight + processPanelHeight * expansionProgress

    Behavior on expansionProgress {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: Qt.callLater(root.requestPaint)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.bottomMargin: 8
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 8

            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: root.titleFontSize
                font.weight: Font.Bold
                text: root.title
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                Layout.maximumWidth: root.width * 0.56
                color: root.lineColor
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: root.modelFontSize
                font.weight: Font.Bold
                text: root.modelText
                textFormat: Text.RichText
            }
            Text {
                color: Config.alpha(root.lineColor, 0.8)
                font.family: Config.fontName
                font.pixelSize: 10
                font.weight: Font.Bold
                text: root.expanded ? "▲" : "▼"
                visible: root.expandable

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.chartHeight
            border.color: root.expanded ? Config.alpha(root.lineColor, 0.28) : root.chartBorderColor
            border.width: 1
            color: root.chartBackgroundColor
            radius: 8

            Behavior on border.color {
                ColorAnimation {
                    duration: 180
                }
            }

            Item {
                id: chartContainer

                anchors.fill: parent
                anchors.margins: 1
                clip: true

                Canvas {
                    anchors.fill: parent
                    antialiasing: false
                    renderStrategy: Canvas.Threaded

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = Config.alpha(Config.md3.on_surface, 0.05);
                        ctx.lineWidth = 1;

                        for (var i = 1; i < 4; ++i) {
                            var y = (height / 4) * i;
                            ctx.beginPath();
                            ctx.moveTo(0, y);
                            ctx.lineTo(width, y);
                            ctx.stroke();
                        }

                        for (var j = 1; j < 12; ++j) {
                            var x = (width / 12) * j;
                            ctx.beginPath();
                            ctx.moveTo(x, 0);
                            ctx.lineTo(x, height);
                            ctx.stroke();
                        }
                    }
                }
                Canvas {
                    id: dataCanvas

                    property real stepX: chartContainer.width / (root.displayedHistory.length > 1 ? root.displayedHistory.length - 1 : 1)

                    function prepareFrame(animate) {
                        slideAnimation.stop();
                        x = 0;
                        requestPaint();
                        if (animate)
                            slideAnimation.start();
                    }

                    antialiasing: true
                    height: chartContainer.height
                    // Immediate keeps the texture update synchronized with the
                    // x reset. Threaded painting could expose the old texture for
                    // one frame, which looked like a flash every second.
                    renderStrategy: Canvas.Immediate
                    width: chartContainer.width + stepX

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();

                        function drawDataLine(data, color, fillOpacity) {
                            if (!data || data.length < 2)
                                return;

                            var step = width / (data.length - 1);
                            var maxV = root.maxValue > 0 ? root.maxValue : 100;
                            ctx.beginPath();
                            ctx.lineWidth = 2.2;
                            ctx.strokeStyle = color;
                            for (var i = 0; i < data.length; ++i) {
                                var x = i * step;
                                var y = height - (data[i] / maxV) * (height - 6) - 3;
                                if (i === 0)
                                    ctx.moveTo(x, y);
                                else
                                    ctx.lineTo(x, y);
                            }
                            ctx.stroke();

                            ctx.beginPath();
                            ctx.moveTo(0, height);
                            for (var j = 0; j < data.length; ++j)
                                ctx.lineTo(j * step, height - (data[j] / maxV) * (height - 6) - 3);
                            ctx.lineTo((data.length - 1) * step, height);
                            ctx.closePath();

                            var gradient = ctx.createLinearGradient(0, 0, 0, height);
                            gradient.addColorStop(0, Config.alpha(color, fillOpacity));
                            gradient.addColorStop(1, Config.alpha(color, 0));
                            ctx.fillStyle = gradient;
                            ctx.fill();
                        }

                        drawDataLine(root.slideHistory2, root.lineColor2, 0.12);
                        drawDataLine(root.slideHistory, root.lineColor, 0.18);
                    }

                    NumberAnimation {
                        id: slideAnimation

                        duration: 1000
                        easing.type: Easing.Linear
                        from: 0
                        property: "x"
                        target: dataCanvas
                        to: -dataCanvas.stepX
                    }
                }
            }
            Rectangle {
                anchors.margins: 8
                anchors.right: parent.right
                anchors.top: parent.top
                border.color: Config.alpha(root.lineColor, 0.25)
                border.width: 1
                color: Config.alpha(Config.md3.background, Config.lightTheme ? 0.64 : 0.36)
                height: 22
                radius: 6
                visible: root.valueText !== ""
                width: overlayText.implicitWidth + 16

                Text {
                    id: overlayText

                    anchors.centerIn: parent
                    color: root.lineColor
                    font.family: Config.fontName
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    text: root.valueText
                    textFormat: Text.RichText
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.expandable

                onClicked: root.clicked()
            }
        }
        Item {
            id: processReveal

            Layout.fillWidth: true
            Layout.preferredHeight: root.processPanelHeight * root.expansionProgress
            clip: true
            opacity: root.expansionProgress

            ColumnLayout {
                id: processContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: 7

                transform: Translate {
                    y: -8 * (1 - root.expansionProgress)
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        color: root.lineColor
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        text: root.processTitle
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        color: Config.md3.outline
                        font.family: Config.fontName
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        text: "updates every " + (root.title.startsWith("GPU") ? "3s" : "2s")
                    }
                }
                Components.ProcessManager {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    lineColor: root.lineColor
                    processList: root.processList
                    processRevision: root.processRevision
                    terminatingPid: root.terminatingPid
                    terminationError: root.terminationError
                    valueSuffix: root.processValueSuffix
                    visible: root.processManagerEnabled

                    onTerminateRequested: (pid, name) => root.terminateRequested(pid, name)
                }
            }
        }
    }
}
