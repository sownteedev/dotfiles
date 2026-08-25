import QtQuick

Item {
    id: root

    property color accentColor: GreeterTheme.surfaceVariantText
    readonly property int boundedPercentage: Math.max(0, Math.min(100, percentage))
    property bool charging: false
    property int percentage: 0
    property real scaleFactor: 1

    function roundedRect(context, x, y, width, height, radius) {
        var boundedRadius = Math.min(radius, width / 2, height / 2);
        context.beginPath();
        context.moveTo(x + boundedRadius, y);
        context.lineTo(x + width - boundedRadius, y);
        context.quadraticCurveTo(x + width, y, x + width, y + boundedRadius);
        context.lineTo(x + width, y + height - boundedRadius);
        context.quadraticCurveTo(x + width, y + height, x + width - boundedRadius, y + height);
        context.lineTo(x + boundedRadius, y + height);
        context.quadraticCurveTo(x, y + height, x, y + height - boundedRadius);
        context.lineTo(x, y + boundedRadius);
        context.quadraticCurveTo(x, y, x + boundedRadius, y);
        context.closePath();
    }

    Accessible.name: charging ? qsTr("Battery at %1%, charging").arg(boundedPercentage) : qsTr("Battery at %1%").arg(boundedPercentage)
    Accessible.role: Accessible.StaticText
    implicitHeight: 32 * root.scaleFactor
    implicitWidth: 36 * root.scaleFactor

    onAccentColorChanged: batteryCanvas.requestPaint()
    onBoundedPercentageChanged: batteryCanvas.requestPaint()
    onChargingChanged: batteryCanvas.requestPaint()
    onScaleFactorChanged: batteryCanvas.requestPaint()

    Canvas {
        id: batteryCanvas

        anchors.centerIn: parent
        antialiasing: true
        height: 22 * root.scaleFactor
        width: 34 * root.scaleFactor

        onHeightChanged: requestPaint()
        onPaint: {
            var context = getContext("2d");
            var scale = root.scaleFactor;
            var bodyX = 1.5 * scale;
            var bodyY = 3.5 * scale;
            var bodyWidth = 26 * scale;
            var bodyHeight = 15 * scale;
            var innerX = bodyX + 3 * scale;
            var innerY = bodyY + 3 * scale;
            var innerWidth = bodyWidth - 6 * scale;
            var innerHeight = bodyHeight - 6 * scale;
            var fillWidth = innerWidth * root.boundedPercentage / 100;

            context.clearRect(0, 0, width, height);

            root.roundedRect(context, bodyX, bodyY, bodyWidth, bodyHeight, 4 * scale);
            context.fillStyle = root.accentColor;
            context.globalAlpha = 0.14;
            context.fill();
            context.globalAlpha = 0.94;
            context.lineWidth = 1.8 * scale;
            context.strokeStyle = root.accentColor;
            context.stroke();

            root.roundedRect(context, bodyX + bodyWidth + 1.5 * scale, bodyY + 4 * scale, 3.5 * scale, 7 * scale, 1.5 * scale);
            context.globalAlpha = 0.72;
            context.fillStyle = root.accentColor;
            context.fill();

            context.save();
            root.roundedRect(context, innerX, innerY, innerWidth, innerHeight, 1.8 * scale);
            context.clip();
            context.globalAlpha = root.charging ? 0.96 : 0.82;
            context.fillStyle = root.accentColor;
            context.fillRect(innerX, innerY, fillWidth, innerHeight);
            context.restore();

            if (root.charging) {
                var centerX = bodyX + bodyWidth / 2;
                var top = bodyY + 1.7 * scale;
                context.beginPath();
                context.moveTo(centerX + 1.2 * scale, top);
                context.lineTo(centerX - 4.2 * scale, top + 7 * scale);
                context.lineTo(centerX - 0.7 * scale, top + 7 * scale);
                context.lineTo(centerX - 2 * scale, top + 12.2 * scale);
                context.lineTo(centerX + 4.2 * scale, top + 5.2 * scale);
                context.lineTo(centerX + 0.7 * scale, top + 5.2 * scale);
                context.closePath();
                context.globalAlpha = 1;
                context.fillStyle = root.accentColor;
                context.lineJoin = "round";
                context.lineWidth = 2.2 * scale;
                context.strokeStyle = GreeterTheme.background;
                context.stroke();
                context.fill();
            }

            context.globalAlpha = 1;
        }
        onWidthChanged: requestPaint()
    }
}
