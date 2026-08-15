import "../.."
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    readonly property var blurShapes: shapes.filter(function (shape) {
        return shape.tool === "blur";
    })
    readonly property bool cropActive: cropRect.width > 2 && cropRect.height > 2
    property rect cropDraftRect: Qt.rect(0, 0, 0, 0)
    property bool cropDragging: false
    property rect cropRect: Qt.rect(0, 0, 0, 0)
    property bool cropWasLastAction: false
    property var currentShape: null
    readonly property rect displayedCropRect: cropDragging ? cropDraftRect : cropRect
    readonly property rect displayedOcrRect: ocrDragging ? ocrDraftRect : ocrRect
    property bool imageLoadEnabled: true
    property var lastMoveUndo: null
    property rect liveDirtyRect: Qt.rect(0, 0, 0, 0)
    property int livePaintFrameId: -1
    property int movingShapeIndex: -1
    property var movingShapeOriginal: null
    property int nextMarkerNumber: 1
    property rect ocrDraftRect: Qt.rect(0, 0, 0, 0)
    property bool ocrDragging: false
    property bool ocrPreparing: false
    property rect ocrRect: Qt.rect(0, 0, 0, 0)
    property int ocrSessionToken: 0
    readonly property var pixelateShapes: shapes.filter(function (shape) {
        return shape.tool === "pixelate";
    })
    property string saveError: ""
    property bool saving: false
    property color selectedColor: Config.captureEditorColor
    property string selectedTool: Config.captureEditorTool
    property real selectedWidth: Config.captureEditorWidth
    property var shapes: []

    function addNumberMarker(x, y) {
        lastMoveUndo = null;
        var size = markerSize();
        var radius = size / 2;
        var centerX = Math.max(radius, Math.min(captureSurface.width - radius, x));
        var centerY = Math.max(radius, Math.min(captureSurface.height - radius, y));
        var nextShapes = shapes.slice();
        nextShapes.push({
            "tool": "number",
            "color": String(selectedColor),
            "textColor": contrastingTextColor(selectedColor),
            "width": selectedWidth,
            "markerSize": size,
            "markerNumber": nextMarkerNumber,
            "startX": centerX - radius,
            "startY": centerY - radius,
            "endX": centerX + radius,
            "endY": centerY + radius,
            "points": []
        });
        shapes = nextShapes;
        nextMarkerNumber++;
        cropWasLastAction = false;
        committedCanvas.requestPaint();
    }
    function beginText(x, y) {
        if (inlineTextEditor.visible)
            commitText();

        inlineTextEditor.x = Math.max(0, Math.min(captureSurface.width - 80, x));
        inlineTextEditor.y = Math.max(0, Math.min(captureSurface.height - inlineTextEditor.height, y));
        inlineTextEditor.text = "";
        inlineTextEditor.visible = true;
        inlineTextEditor.forceActiveFocus();
    }
    function cancelEditor() {
        cancelOcrSession();
        CaptureService.closeScreenshotEditor();
    }
    function cancelOcrSession() {
        ocrSessionToken += 1;
        ocrPreparing = false;
        OcrService.reset();
    }
    function cancelShapeMove() {
        if (movingShapeIndex >= 0 && movingShapeOriginal) {
            var nextShapes = shapes.slice();
            var restoreIndex = Math.max(0, Math.min(movingShapeIndex, nextShapes.length));
            nextShapes.splice(restoreIndex, 0, copyShape(movingShapeOriginal));
            shapes = nextShapes;
            recomputeMarkerNumber();
        }

        movingShapeIndex = -1;
        movingShapeOriginal = null;
        liveCanvasTranslate.x = 0;
        liveCanvasTranslate.y = 0;
        currentShape = null;
        prepareLiveCanvas();
        committedCanvas.requestPaint();
        scheduleLivePaint();
    }
    function cancelText() {
        inlineTextEditor.text = "";
        inlineTextEditor.visible = false;
        keyScope.forceActiveFocus();
    }
    function clearAll() {
        cancelOcrSession();
        shapes = [];
        currentShape = null;
        lastMoveUndo = null;
        movingShapeIndex = -1;
        movingShapeOriginal = null;
        cropRect = Qt.rect(0, 0, 0, 0);
        cropDraftRect = Qt.rect(0, 0, 0, 0);
        cropDragging = false;
        cropWasLastAction = false;
        nextMarkerNumber = 1;
        ocrRect = Qt.rect(0, 0, 0, 0);
        ocrDraftRect = Qt.rect(0, 0, 0, 0);
        ocrDragging = false;
        inlineTextEditor.visible = false;
        inlineTextEditor.text = "";
        prepareLiveCanvas();
        committedCanvas.requestPaint();
    }
    function commitText() {
        var value = inlineTextEditor.text.trim();
        if (value !== "") {
            lastMoveUndo = null;
            var fontSize = textFontSize();
            var nextShapes = shapes.slice();
            nextShapes.push({
                "tool": "text",
                "color": String(selectedColor),
                "width": selectedWidth,
                "fontSize": fontSize,
                "text": value,
                "startX": inlineTextEditor.x,
                "startY": inlineTextEditor.y,
                "endX": inlineTextEditor.x + Math.max(1, inlineTextEditor.contentWidth),
                "endY": inlineTextEditor.y + fontSize,
                "points": []
            });
            shapes = nextShapes;
            cropWasLastAction = false;
            committedCanvas.requestPaint();
        }
        inlineTextEditor.text = "";
        inlineTextEditor.visible = false;
        keyScope.forceActiveFocus();
    }
    function contrastingTextColor(colorValue) {
        var luminance = colorValue.r * 0.299 + colorValue.g * 0.587 + colorValue.b * 0.114;
        return luminance > 0.58 ? "#151515" : "#ffffff";
    }
    function copyShape(shape) {
        var copiedPoints = [];
        if (shape.points) {
            for (var i = 0; i < shape.points.length; ++i) {
                copiedPoints.push({
                    "x": shape.points[i].x,
                    "y": shape.points[i].y
                });
            }
        }
        return {
            "tool": shape.tool,
            "color": shape.color,
            "width": shape.width,
            "startX": shape.startX,
            "startY": shape.startY,
            "endX": shape.endX,
            "endY": shape.endY,
            "text": shape.text || "",
            "fontSize": shape.fontSize || 0,
            "markerNumber": shape.markerNumber || 0,
            "markerSize": shape.markerSize || 0,
            "textColor": shape.textColor || "",
            "points": copiedPoints
        };
    }
    function distanceSquaredToSegment(px, py, x1, y1, x2, y2) {
        var segmentX = x2 - x1;
        var segmentY = y2 - y1;
        var lengthSquared = segmentX * segmentX + segmentY * segmentY;
        if (lengthSquared <= 0.0001) {
            var pointDx = px - x1;
            var pointDy = py - y1;
            return pointDx * pointDx + pointDy * pointDy;
        }

        var t = ((px - x1) * segmentX + (py - y1) * segmentY) / lengthSquared;
        t = Math.max(0, Math.min(1, t));
        var nearestX = x1 + t * segmentX;
        var nearestY = y1 + t * segmentY;
        var dx = px - nearestX;
        var dy = py - nearestY;
        return dx * dx + dy * dy;
    }
    function drawEllipse(ctx, shape) {
        var left = Math.min(shape.startX, shape.endX);
        var top = Math.min(shape.startY, shape.endY);
        var width = Math.abs(shape.endX - shape.startX);
        var height = Math.abs(shape.endY - shape.startY);
        var rx = width / 2;
        var ry = height / 2;
        var cx = left + rx;
        var cy = top + ry;
        var kappa = 0.552285;
        ctx.beginPath();
        ctx.moveTo(cx + rx, cy);
        ctx.bezierCurveTo(cx + rx, cy + ry * kappa, cx + rx * kappa, cy + ry, cx, cy + ry);
        ctx.bezierCurveTo(cx - rx * kappa, cy + ry, cx - rx, cy + ry * kappa, cx - rx, cy);
        ctx.bezierCurveTo(cx - rx, cy - ry * kappa, cx - rx * kappa, cy - ry, cx, cy - ry);
        ctx.bezierCurveTo(cx + rx * kappa, cy - ry, cx + rx, cy - ry * kappa, cx + rx, cy);
        ctx.stroke();
    }
    function drawIncrementalPen(ctx, shape) {
        var points = shape && shape.points ? shape.points : [];
        if (points.length === 0)
            return;

        // Once a midpoint segment has two neighbours its curve can no longer
        // change, so bake only those new segments into the live canvas.
        ctx.save();
        ctx.strokeStyle = shape.color;
        ctx.fillStyle = shape.color;
        ctx.lineWidth = shape.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        if (!liveCanvas.penStartPainted) {
            ctx.beginPath();
            ctx.arc(points[0].x, points[0].y, shape.width / 2, 0, Math.PI * 2);
            ctx.fill();
            liveCanvas.penStartPainted = true;
        }

        var lastStableControl = points.length - 2;
        var firstControl = liveCanvas.nextPenControlPoint;
        if (lastStableControl >= firstControl) {
            ctx.beginPath();
            if (firstControl === 1) {
                ctx.moveTo(points[0].x, points[0].y);
            } else {
                var previousPoint = points[firstControl - 1];
                var controlPoint = points[firstControl];
                ctx.moveTo((previousPoint.x + controlPoint.x) / 2, (previousPoint.y + controlPoint.y) / 2);
            }

            for (var i = firstControl; i <= lastStableControl; ++i) {
                var endX = (points[i].x + points[i + 1].x) / 2;
                var endY = (points[i].y + points[i + 1].y) / 2;
                ctx.quadraticCurveTo(points[i].x, points[i].y, endX, endY);
            }
            ctx.stroke();
            liveCanvas.nextPenControlPoint = lastStableControl + 1;
        }
        ctx.restore();
    }
    function drawShape(ctx, shape) {
        if (!shape || shape.tool === "blur" || shape.tool === "pixelate")
            return;

        ctx.save();
        ctx.strokeStyle = shape.color;
        ctx.fillStyle = shape.color;
        ctx.lineWidth = shape.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        if (shape.tool === "highlight") {
            ctx.globalAlpha = 0.34;
            ctx.lineWidth = shape.width * 3;
        }
        if (shape.tool === "number") {
            var markerRadius = shape.markerSize / 2;
            var markerX = shape.startX + markerRadius;
            var markerY = shape.startY + markerRadius;
            ctx.beginPath();
            ctx.arc(markerX, markerY, markerRadius, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = shape.textColor;
            ctx.font = "700 " + Math.round(shape.markerSize * 0.52) + "px '" + Config.fontName + "'";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.fillText(String(shape.markerNumber), markerX, markerY + 0.5);
        } else if (shape.tool === "text") {
            ctx.font = "600 " + shape.fontSize + "px '" + Config.fontName + "'";
            ctx.textBaseline = "top";
            ctx.fillText(shape.text, shape.startX, shape.startY);
        } else if (shape.tool === "pen" || shape.tool === "highlight") {
            var points = shape.points || [];
            if (points.length === 1) {
                ctx.beginPath();
                ctx.arc(points[0].x, points[0].y, shape.width / 2, 0, Math.PI * 2);
                ctx.fill();
            } else if (points.length > 1) {
                ctx.beginPath();
                ctx.moveTo(points[0].x, points[0].y);
                for (var i = 1; i < points.length - 1; ++i) {
                    var xc = (points[i].x + points[i + 1].x) / 2.0;
                    var yc = (points[i].y + points[i + 1].y) / 2.0;
                    ctx.quadraticCurveTo(points[i].x, points[i].y, xc, yc);
                }
                ctx.lineTo(points[points.length - 1].x, points[points.length - 1].y);
                ctx.stroke();
            }
        } else if (shape.tool === "rectangle") {
            ctx.strokeRect(shape.startX, shape.startY, shape.endX - shape.startX, shape.endY - shape.startY);
        } else if (shape.tool === "ellipse") {
            drawEllipse(ctx, shape);
        } else {
            ctx.beginPath();
            ctx.moveTo(shape.startX, shape.startY);
            ctx.lineTo(shape.endX, shape.endY);
            ctx.stroke();
            if (shape.tool === "arrow") {
                var angle = Math.atan2(shape.endY - shape.startY, shape.endX - shape.startX);
                var head = 12 + shape.width * 1.4;
                ctx.beginPath();
                ctx.moveTo(shape.endX, shape.endY);
                ctx.lineTo(shape.endX - head * Math.cos(angle - Math.PI / 6), shape.endY - head * Math.sin(angle - Math.PI / 6));
                ctx.moveTo(shape.endX, shape.endY);
                ctx.lineTo(shape.endX - head * Math.cos(angle + Math.PI / 6), shape.endY - head * Math.sin(angle + Math.PI / 6));
                ctx.stroke();
            }
        }
        ctx.restore();
    }
    function eraseAt(x, y) {
        var radius = 14 + selectedWidth;
        var nextShapes = shapes.slice();
        for (var i = nextShapes.length - 1; i >= 0; --i) {
            var bounds = shapeBounds(nextShapes[i]);
            if (x >= bounds.minX - radius && x <= bounds.maxX + radius && y >= bounds.minY - radius && y <= bounds.maxY + radius) {
                lastMoveUndo = null;
                nextShapes.splice(i, 1);
                shapes = nextShapes;
                recomputeMarkerNumber();
                committedCanvas.requestPaint();
                return;
            }
        }
    }
    function hitTestShape(shape, x, y) {
        var threshold = 15;
        if (!shape || shape.tool === "crop" || shape.tool === "ocr")
            return false;

        if (shape.tool === "blur" || shape.tool === "pixelate") {
            var bMinX = Math.min(shape.startX, shape.endX);
            var bMaxX = Math.max(shape.startX, shape.endX);
            var bMinY = Math.min(shape.startY, shape.endY);
            var bMaxY = Math.max(shape.startY, shape.endY);
            return x >= bMinX && x <= bMaxX && y >= bMinY && y <= bMaxY;
        }

        if (shape.tool === "number") {
            var cx = shape.startX + shape.markerSize / 2;
            var cy = shape.startY + shape.markerSize / 2;
            var dist = Math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
            return dist <= (shape.markerSize / 2) + threshold;
        }
        if (shape.tool === "text") {
            var estW = (shape.text || "").length * shape.fontSize * 0.6;
            return x >= shape.startX - threshold && x <= shape.startX + estW + threshold && y >= shape.startY - threshold && y <= shape.startY + shape.fontSize + threshold;
        }

        if (shape.tool === "line" || shape.tool === "arrow") {
            var lineRadius = shape.width / 2 + 10;
            var lineRadiusSquared = lineRadius * lineRadius;
            if (distanceSquaredToSegment(x, y, shape.startX, shape.startY, shape.endX, shape.endY) <= lineRadiusSquared)
                return true;

            if (shape.tool === "arrow") {
                var angle = Math.atan2(shape.endY - shape.startY, shape.endX - shape.startX);
                var head = 12 + shape.width * 1.4;
                var headX1 = shape.endX - head * Math.cos(angle - Math.PI / 6);
                var headY1 = shape.endY - head * Math.sin(angle - Math.PI / 6);
                var headX2 = shape.endX - head * Math.cos(angle + Math.PI / 6);
                var headY2 = shape.endY - head * Math.sin(angle + Math.PI / 6);
                return distanceSquaredToSegment(x, y, shape.endX, shape.endY, headX1, headY1) <= lineRadiusSquared || distanceSquaredToSegment(x, y, shape.endX, shape.endY, headX2, headY2) <= lineRadiusSquared;
            }
            return false;
        }

        if (shape.tool === "pen" || shape.tool === "highlight") {
            var pts = shape.points;
            if (!pts || pts.length === 0)
                pts = [
                    {
                        "x": shape.startX,
                        "y": shape.startY
                    },
                    {
                        "x": shape.endX,
                        "y": shape.endY
                    }
                ];
            var strokeRadius = shape.tool === "highlight" ? shape.width * 1.5 + 8 : shape.width / 2 + 10;
            var strokeRadiusSquared = strokeRadius * strokeRadius;
            if (pts.length === 1)
                return distanceSquaredToSegment(x, y, pts[0].x, pts[0].y, pts[0].x, pts[0].y) <= strokeRadiusSquared;

            for (var i = 1; i < pts.length; ++i) {
                if (distanceSquaredToSegment(x, y, pts[i - 1].x, pts[i - 1].y, pts[i].x, pts[i].y) <= strokeRadiusSquared)
                    return true;
            }
            return false;
        }

        var minX = Math.min(shape.startX, shape.endX);
        var maxX = Math.max(shape.startX, shape.endX);
        var minY = Math.min(shape.startY, shape.endY);
        var maxY = Math.max(shape.startY, shape.endY);
        return x >= minX - threshold && x <= maxX + threshold && y >= minY - threshold && y <= maxY + threshold;
    }
    function markerSize() {
        return Math.round(24 + selectedWidth);
    }
    function normalizeCropRect(startX, startY, endX, endY) {
        var left = Math.max(0, Math.min(captureSurface.width, Math.min(startX, endX)));
        var top = Math.max(0, Math.min(captureSurface.height, Math.min(startY, endY)));
        var right = Math.max(0, Math.min(captureSurface.width, Math.max(startX, endX)));
        var bottom = Math.max(0, Math.min(captureSurface.height, Math.max(startY, endY)));
        return Qt.rect(left, top, Math.max(0, right - left), Math.max(0, bottom - top));
    }
    function prepareLiveCanvas() {
        if (livePaintFrameId >= 0) {
            liveCanvas.cancelRequestAnimationFrame(livePaintFrameId);
            livePaintFrameId = -1;
        }
        liveCanvas.clearBeforePaint = true;
        liveCanvas.nextPenControlPoint = 1;
        liveCanvas.penStartPainted = false;
        liveDirtyRect = Qt.rect(0, 0, 0, 0);
    }
    function recognizeRegion(region) {
        if (OcrService.busy || region.width < 8 || region.height < 8)
            return;

        ocrRect = region;
        ocrPreparing = true;
        OcrService.clearStatus();
        var editorSession = ocrSessionToken;
        Qt.callLater(function () {
            if (editorSession !== root.ocrSessionToken || !CaptureService.screenshotEditorVisible)
                return;
            var scaleX = sourceImage.sourceSize.width / Math.max(1, captureSurface.width);
            var scaleY = sourceImage.sourceSize.height / Math.max(1, captureSurface.height);
            var targetWidth = Math.max(1, Math.round(region.width * scaleX));
            var targetHeight = Math.max(1, Math.round(region.height * scaleY));
            var started = ocrExportSurface.grabToImage(function (result) {
                if (editorSession !== root.ocrSessionToken || !CaptureService.screenshotEditorVisible)
                    return;
                var path = "/tmp/quickshell-ocr-" + Date.now() + ".png";
                var saved = result.saveToFile(path);
                root.ocrPreparing = false;
                if (saved && editorSession === root.ocrSessionToken && CaptureService.screenshotEditorVisible)
                    OcrService.recognize(path);
                else if (saved)
                    OcrService.discardFile(path);
                else
                    OcrService.reportCaptureError();
            }, Qt.size(targetWidth, targetHeight));
            if (!started) {
                root.ocrPreparing = false;
                OcrService.reportCaptureError();
            }
        });
    }
    function recomputeMarkerNumber() {
        var highest = 0;
        for (var i = 0; i < shapes.length; ++i) {
            if (shapes[i].tool === "number")
                highest = Math.max(highest, shapes[i].markerNumber || 0);
        }
        nextMarkerNumber = highest + 1;
    }
    function resetEditorDefaults() {
        selectedTool = Config.captureEditorTool || "pen";
        selectedColor = Config.captureEditorColor || "#ff3b30";
        selectedWidth = Math.max(1, Number(Config.captureEditorWidth) || 6);
        clearAll();
    }
    function retrySourceImage() {
        if (!CaptureService.screenshotPath)
            return;

        imageLoadEnabled = false;
        Qt.callLater(function () {
            if (CaptureService.screenshotEditorVisible)
                root.imageLoadEnabled = true;
        });
    }
    function saveEditedImage() {
        if (inlineTextEditor.visible)
            commitText();

        if (saving || sourceImage.status !== Image.Ready)
            return;

        cancelOcrSession();
        saving = true;
        saveError = "";
        committedCanvas.requestPaint();
        liveCanvas.requestPaint();
        Qt.callLater(function () {
            var outputPath = CaptureService.editedScreenshotPath();
            var scaleX = sourceImage.sourceSize.width / Math.max(1, captureSurface.width);
            var scaleY = sourceImage.sourceSize.height / Math.max(1, captureSurface.height);
            var exportItem = root.cropActive ? cropExportSurface : captureSurface;
            var targetWidth = root.cropActive ? Math.max(1, Math.round(root.cropRect.width * scaleX)) : Math.max(1, sourceImage.sourceSize.width);
            var targetHeight = root.cropActive ? Math.max(1, Math.round(root.cropRect.height * scaleY)) : Math.max(1, sourceImage.sourceSize.height);
            var started = exportItem.grabToImage(function (result) {
                var saved = result.saveToFile(outputPath);
                root.saving = false;
                if (saved)
                    CaptureService.finishScreenshotEditing(outputPath);
                else
                    root.saveError = "Could not save the edited screenshot";
            }, Qt.size(targetWidth, targetHeight));
            if (!started) {
                root.saving = false;
                root.saveError = "Could not render the edited screenshot";
            }
        });
    }
    function scheduleLivePaint(dirtyRect) {
        if (dirtyRect && dirtyRect.width > 0 && dirtyRect.height > 0) {
            var dirtyLeft = Math.max(0, dirtyRect.x);
            var dirtyTop = Math.max(0, dirtyRect.y);
            var dirtyRight = Math.min(liveCanvas.width, dirtyRect.x + dirtyRect.width);
            var dirtyBottom = Math.min(liveCanvas.height, dirtyRect.y + dirtyRect.height);
            dirtyRect = Qt.rect(dirtyLeft, dirtyTop, Math.max(0, dirtyRight - dirtyLeft), Math.max(0, dirtyBottom - dirtyTop));
            if (dirtyRect.width > 0 && dirtyRect.height > 0) {
                if (liveDirtyRect.width <= 0 || liveDirtyRect.height <= 0) {
                    liveDirtyRect = dirtyRect;
                } else {
                    var left = Math.min(liveDirtyRect.x, dirtyRect.x);
                    var top = Math.min(liveDirtyRect.y, dirtyRect.y);
                    var right = Math.max(liveDirtyRect.x + liveDirtyRect.width, dirtyRect.x + dirtyRect.width);
                    var bottom = Math.max(liveDirtyRect.y + liveDirtyRect.height, dirtyRect.y + dirtyRect.height);
                    liveDirtyRect = Qt.rect(left, top, right - left, bottom - top);
                }
            }
        }
        if (livePaintFrameId >= 0)
            return;

        // Pointer events can arrive much faster than the display refresh rate.
        // Coalesce them and upload only the pen area touched during this frame.
        livePaintFrameId = liveCanvas.requestAnimationFrame(function () {
            root.livePaintFrameId = -1;
            var pendingDirtyRect = root.liveDirtyRect;
            root.liveDirtyRect = Qt.rect(0, 0, 0, 0);
            if (liveCanvas.clearBeforePaint || !root.currentShape || root.currentShape.tool !== "pen" || pendingDirtyRect.width <= 0 || pendingDirtyRect.height <= 0)
                liveCanvas.requestPaint();
            else
                liveCanvas.markDirty(pendingDirtyRect);
        });
    }
    function shapeBounds(shape) {
        var minX = Math.min(shape.startX, shape.endX);
        var maxX = Math.max(shape.startX, shape.endX);
        var minY = Math.min(shape.startY, shape.endY);
        var maxY = Math.max(shape.startY, shape.endY);
        if (shape.tool === "text") {
            minX = shape.startX;
            minY = shape.startY;
            maxX = shape.endX;
            maxY = shape.endY;
        }
        if ((shape.tool === "pen" || shape.tool === "highlight") && shape.points && shape.points.length > 0) {
            minX = maxX = shape.points[0].x;
            minY = maxY = shape.points[0].y;
            for (var i = 1; i < shape.points.length; ++i) {
                minX = Math.min(minX, shape.points[i].x);
                maxX = Math.max(maxX, shape.points[i].x);
                minY = Math.min(minY, shape.points[i].y);
                maxY = Math.max(maxY, shape.points[i].y);
            }
        }
        return {
            "minX": minX,
            "maxX": maxX,
            "minY": minY,
            "maxY": maxY
        };
    }
    function textFontSize() {
        return Math.round(selectedWidth * 3);
    }
    function undo() {
        if (cropActive && cropWasLastAction) {
            cropRect = Qt.rect(0, 0, 0, 0);
            cropWasLastAction = false;
            return;
        }
        if (lastMoveUndo) {
            var restoredShapes = shapes.slice();
            var restoreIndex = Math.max(0, Math.min(lastMoveUndo.index, restoredShapes.length - 1));
            if (restoredShapes.length > 0)
                restoredShapes.splice(restoreIndex, 1, copyShape(lastMoveUndo.shape));
            else
                restoredShapes.push(copyShape(lastMoveUndo.shape));
            shapes = restoredShapes;
            lastMoveUndo = null;
            cropWasLastAction = false;
            recomputeMarkerNumber();
            committedCanvas.requestPaint();
            return;
        }
        if (shapes.length === 0)
            return;

        var nextShapes = shapes.slice();
        nextShapes.pop();
        shapes = nextShapes;
        cropWasLastAction = false;
        recomputeMarkerNumber();
        committedCanvas.requestPaint();
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "screenshot-editor"
    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: Config.alpha(Config.md3.background, 0.95)
    exclusiveZone: 0
    focusable: true

    Component.onCompleted: {
        resetEditorDefaults();
    }
    Component.onDestruction: cancelOcrSession()

    Connections {
        function onScreenshotEditorSessionChanged() {
            root.resetEditorDefaults();
            root.retrySourceImage();
        }

        target: CaptureService
    }
    Item {
        id: keyScope

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.cancelEditor()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.saveEditedImage();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace) {
                root.clearAll();
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                root.undo();
                event.accepted = true;
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Responsive.clamp(root.width * 0.012, 12, 24)
        spacing: root.height < 720 ? 10 : 16

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30

            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.Bold
                text: "Edit screenshot"
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                color: Config.md3.error
                font.family: Config.fontName
                font.pixelSize: 13
                font.weight: Font.Medium
                text: root.saveError
                visible: text !== ""
            }
            Text {
                Layout.maximumWidth: root.width * 0.62
                color: OcrService.statusIsError ? Config.md3.error : OcrService.statusText !== "" ? Config.md3.primary : Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                maximumLineCount: 1
                text: OcrService.statusText !== "" ? OcrService.statusText : root.selectedTool === "ocr" ? "Drag over text to copy it" : "Enter to save · Backspace to clear · Ctrl+Z to undo · Esc to cancel"
            }
        }
        Item {
            id: editorArea

            Layout.fillHeight: true
            Layout.fillWidth: true

            Rectangle {
                id: imageFrame

                anchors.centerIn: parent
                border.color: Config.alpha(Config.md3.on_surface, 0.18)
                border.width: 1
                color: Config.md3.surface_container
                height: captureSurface.height + 2
                width: captureSurface.width + 2

                Item {
                    id: captureSurface

                    anchors.centerIn: parent
                    clip: true
                    height: {
                        var sourceWidth = Math.max(1, sourceImage.sourceSize.width);
                        var sourceHeight = Math.max(1, sourceImage.sourceSize.height);
                        return width * sourceHeight / sourceWidth;
                    }
                    width: {
                        var sourceWidth = Math.max(1, sourceImage.sourceSize.width);
                        var sourceHeight = Math.max(1, sourceImage.sourceSize.height);
                        var aspect = sourceWidth / sourceHeight;
                        return Math.min(editorArea.width - 8, (editorArea.height - 8) * aspect);
                    }

                    Image {
                        id: sourceImage

                        anchors.fill: parent
                        asynchronous: true
                        cache: false
                        fillMode: Image.Stretch
                        source: root.imageLoadEnabled && CaptureService.screenshotPath ? "file://" + CaptureService.screenshotPath : ""
                    }
                    Repeater {
                        model: root.blurShapes

                        delegate: BlurRegion {
                            required property var modelData

                            shapeData: modelData
                            sourceItem: sourceImage
                            surfaceHeight: captureSurface.height
                            surfaceWidth: captureSurface.width
                        }
                    }
                    Repeater {
                        model: root.pixelateShapes

                        delegate: PixelateRegion {
                            required property var modelData

                            shapeData: modelData
                            sourceItem: sourceImage
                            surfaceHeight: captureSurface.height
                            surfaceWidth: captureSurface.width
                        }
                    }
                    BlurRegion {
                        shapeData: root.currentShape || {
                            "startX": 0,
                            "startY": 0,
                            "endX": 0,
                            "endY": 0,
                            "width": root.selectedWidth
                        }
                        showOutline: true
                        sourceItem: sourceImage
                        surfaceHeight: captureSurface.height
                        surfaceWidth: captureSurface.width
                        visible: root.currentShape !== null && root.currentShape.tool === "blur"
                    }
                    PixelateRegion {
                        shapeData: root.currentShape || {
                            "startX": 0,
                            "startY": 0,
                            "endX": 0,
                            "endY": 0,
                            "width": root.selectedWidth
                        }
                        showOutline: true
                        sourceItem: sourceImage
                        surfaceHeight: captureSurface.height
                        surfaceWidth: captureSurface.width
                        visible: root.currentShape !== null && root.currentShape.tool === "pixelate"
                    }
                    Canvas {
                        id: committedCanvas

                        anchors.fill: parent
                        antialiasing: true
                        renderStrategy: Canvas.Immediate

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            for (var i = 0; i < root.shapes.length; ++i)
                                root.drawShape(ctx, root.shapes[i]);
                        }
                        onPainted: {
                            if (root.currentShape && root.currentShape.__hideLiveCanvas) {
                                liveCanvas.opacity = 0;
                                liveCanvasTranslate.x = 0;
                                liveCanvasTranslate.y = 0;
                                root.currentShape = null;
                                root.prepareLiveCanvas();
                                root.scheduleLivePaint();
                            }
                            if (root.currentShape && root.currentShape.__waitingForCommit) {
                                root.currentShape.__waitingForCommit = false;
                            }
                        }
                    }
                    Canvas {
                        id: liveCanvas

                        property bool clearBeforePaint: true
                        property int nextPenControlPoint: 1
                        property bool penStartPainted: false

                        anchors.fill: parent
                        antialiasing: true
                        renderStrategy: Canvas.Immediate
                        visible: true

                        transform: Translate {
                            id: liveCanvasTranslate
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            var shape = root.currentShape;
                            if (clearBeforePaint || !shape || shape.tool !== "pen") {
                                ctx.clearRect(0, 0, width, height);
                                clearBeforePaint = false;
                            }
                            if (shape && shape.tool === "pen")
                                root.drawIncrementalPen(ctx, shape);
                            else
                                root.drawShape(ctx, shape);

                            liveCanvas.opacity = 1;
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.selectedTool === "select" ? Qt.ArrowCursor : (root.selectedTool === "eraser" || root.selectedTool === "text" || root.selectedTool === "number" ? Qt.PointingHandCursor : Qt.CrossCursor)

                        onCanceled: {
                            root.cropDragging = false;
                            root.cropDraftRect = Qt.rect(0, 0, 0, 0);
                            root.ocrDragging = false;
                            root.ocrDraftRect = Qt.rect(0, 0, 0, 0);
                            if (root.selectedTool === "select") {
                                root.cancelShapeMove();
                            } else {
                                root.currentShape = null;
                                root.prepareLiveCanvas();
                            }
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;

                            if (root.selectedTool === "select") {
                                if (root.currentShape && root.currentShape.__dragStartX !== undefined) {
                                    if (root.currentShape.__waitingForCommit)
                                        return;

                                    var dx = mouse.x - root.currentShape.__dragStartX;
                                    var dy = mouse.y - root.currentShape.__dragStartY;

                                    if (root.currentShape.tool === "blur" || root.currentShape.tool === "pixelate") {
                                        var s = root.copyShape(root.currentShape);
                                        s.__dragStartX = mouse.x;
                                        s.__dragStartY = mouse.y;

                                        if (s.startX !== undefined)
                                            s.startX += dx;
                                        if (s.startY !== undefined)
                                            s.startY += dy;
                                        if (s.endX !== undefined)
                                            s.endX += dx;
                                        if (s.endY !== undefined)
                                            s.endY += dy;
                                        root.currentShape = s;
                                    } else {
                                        liveCanvasTranslate.x = mouse.x - root.currentShape.__dragStartX;
                                        liveCanvasTranslate.y = mouse.y - root.currentShape.__dragStartY;
                                    }
                                }
                                return;
                            }

                            if (root.selectedTool === "eraser") {
                                root.eraseAt(mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "crop" && root.cropDragging && root.currentShape) {
                                root.cropDraftRect = root.normalizeCropRect(root.currentShape.startX, root.currentShape.startY, mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "ocr" && root.ocrDragging && root.currentShape) {
                                root.ocrDraftRect = root.normalizeCropRect(root.currentShape.startX, root.currentShape.startY, mouse.x, mouse.y);
                                return;
                            }
                            if (!root.currentShape)
                                return;

                            var tmpShape = root.currentShape;
                            tmpShape.endX = mouse.x;
                            tmpShape.endY = mouse.y;

                            if (tmpShape.tool === "blur" || tmpShape.tool === "pixelate") {
                                root.currentShape = root.copyShape(tmpShape);
                            } else {
                                root.currentShapeChanged();
                                if (tmpShape.tool === "pen" || tmpShape.tool === "highlight") {
                                    var points = root.currentShape.points;
                                    var lastPoint = points[points.length - 1];
                                    var dx = mouse.x - lastPoint.x;
                                    var dy = mouse.y - lastPoint.y;
                                    var minimumPointDistance = Math.max(1.5, Math.min(4, tmpShape.width * 0.25));
                                    if (dx * dx + dy * dy >= minimumPointDistance * minimumPointDistance) {
                                        var previousPoint = points.length > 1 ? points[points.length - 2] : lastPoint;
                                        points.push({
                                            "x": mouse.x,
                                            "y": mouse.y
                                        });
                                        var padding = root.selectedWidth + 3;
                                        var dirtyLeft = Math.min(previousPoint.x, lastPoint.x, mouse.x) - padding;
                                        var dirtyTop = Math.min(previousPoint.y, lastPoint.y, mouse.y) - padding;
                                        var dirtyRight = Math.max(previousPoint.x, lastPoint.x, mouse.x) + padding;
                                        var dirtyBottom = Math.max(previousPoint.y, lastPoint.y, mouse.y) + padding;
                                        root.scheduleLivePaint(Qt.rect(dirtyLeft, dirtyTop, dirtyRight - dirtyLeft, dirtyBottom - dirtyTop));
                                    }
                                    return;
                                }
                            }
                            if (tmpShape.tool !== "blur" && tmpShape.tool !== "pixelate")
                                root.scheduleLivePaint();
                        }
                        onPressed: mouse => {
                            if (root.selectedTool === "select") {
                                for (var i = root.shapes.length - 1; i >= 0; i--) {
                                    if (root.hitTestShape(root.shapes[i], mouse.x, mouse.y)) {
                                        root.movingShapeIndex = i;
                                        root.movingShapeOriginal = root.copyShape(root.shapes[i]);
                                        var selectedShape = root.copyShape(root.shapes[i]);
                                        selectedShape.__dragStartX = mouse.x;
                                        selectedShape.__dragStartY = mouse.y;

                                        var nextShapes = root.shapes.slice();
                                        nextShapes.splice(i, 1);
                                        root.shapes = nextShapes;

                                        liveCanvasTranslate.x = 0;
                                        liveCanvasTranslate.y = 0;
                                        root.currentShape = selectedShape;

                                        if (selectedShape.tool !== "blur" && selectedShape.tool !== "pixelate") {
                                            root.currentShape.__waitingForCommit = true;
                                            root.prepareLiveCanvas();
                                            root.scheduleLivePaint();
                                        }
                                        committedCanvas.requestPaint();
                                        return;
                                    }
                                }
                                root.movingShapeIndex = -1;
                                root.movingShapeOriginal = null;
                                root.currentShape = null;
                                return;
                            }
                            if (root.selectedTool === "text") {
                                root.beginText(mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "number") {
                                root.addNumberMarker(mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "eraser") {
                                root.eraseAt(mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "crop") {
                                root.cropDragging = true;
                                root.cropDraftRect = Qt.rect(mouse.x, mouse.y, 0, 0);
                                root.currentShape = {
                                    "startX": mouse.x,
                                    "startY": mouse.y
                                };
                                return;
                            }
                            if (root.selectedTool === "ocr") {
                                if (OcrService.busy || root.ocrPreparing)
                                    return;

                                OcrService.clearStatus();
                                root.ocrDragging = true;
                                root.ocrDraftRect = Qt.rect(mouse.x, mouse.y, 0, 0);
                                root.currentShape = {
                                    "startX": mouse.x,
                                    "startY": mouse.y
                                };
                                return;
                            }
                            root.prepareLiveCanvas();
                            root.currentShape = {
                                "tool": root.selectedTool,
                                "color": String(root.selectedColor),
                                "width": root.selectedWidth,
                                "startX": mouse.x,
                                "startY": mouse.y,
                                "endX": mouse.x,
                                "endY": mouse.y,
                                "points": [
                                    {
                                        "x": mouse.x,
                                        "y": mouse.y
                                    }
                                ]
                            };
                            var padding = root.selectedWidth + 3;
                            root.scheduleLivePaint(Qt.rect(mouse.x - padding, mouse.y - padding, padding * 2, padding * 2));
                        }
                        onReleased: mouse => {
                            if (root.selectedTool === "select") {
                                if (root.currentShape && root.currentShape.__dragStartX !== undefined) {
                                    var finalShape = root.copyShape(root.currentShape);
                                    var moveDx = finalShape.startX - root.movingShapeOriginal.startX;
                                    var moveDy = finalShape.startY - root.movingShapeOriginal.startY;

                                    if (finalShape.tool !== "blur" && finalShape.tool !== "pixelate") {
                                        var dx = liveCanvasTranslate.x;
                                        var dy = liveCanvasTranslate.y;
                                        moveDx = dx;
                                        moveDy = dy;
                                        if (finalShape.startX !== undefined)
                                            finalShape.startX += dx;
                                        if (finalShape.startY !== undefined)
                                            finalShape.startY += dy;
                                        if (finalShape.endX !== undefined)
                                            finalShape.endX += dx;
                                        if (finalShape.endY !== undefined)
                                            finalShape.endY += dy;
                                        if (finalShape.points) {
                                            for (var j = 0; j < finalShape.points.length; j++) {
                                                if (finalShape.points[j].x !== undefined)
                                                    finalShape.points[j].x += dx;
                                                if (finalShape.points[j].y !== undefined)
                                                    finalShape.points[j].y += dy;
                                            }
                                        }
                                    }

                                    delete finalShape.__dragStartX;
                                    delete finalShape.__dragStartY;
                                    delete finalShape.__waitingForCommit;
                                    delete finalShape.__hideLiveCanvas;

                                    var nextShapesList = root.shapes.slice();
                                    var insertionIndex = Math.max(0, Math.min(root.movingShapeIndex, nextShapesList.length));
                                    nextShapesList.splice(insertionIndex, 0, finalShape);
                                    root.shapes = nextShapesList;
                                    if (Math.abs(moveDx) > 0.01 || Math.abs(moveDy) > 0.01) {
                                        root.lastMoveUndo = {
                                            "index": insertionIndex,
                                            "shape": root.copyShape(root.movingShapeOriginal)
                                        };
                                        root.cropWasLastAction = false;
                                    }
                                    root.movingShapeIndex = -1;
                                    root.movingShapeOriginal = null;

                                    if (finalShape.tool !== "blur" && finalShape.tool !== "pixelate") {
                                        root.currentShape.__hideLiveCanvas = true;
                                        committedCanvas.requestPaint();
                                    } else {
                                        liveCanvasTranslate.x = 0;
                                        liveCanvasTranslate.y = 0;
                                        root.currentShape = null;
                                        root.prepareLiveCanvas();
                                        committedCanvas.requestPaint();
                                        root.scheduleLivePaint();
                                    }
                                }
                                return;
                            }
                            if (root.selectedTool === "crop" && root.cropDragging && root.currentShape) {
                                var nextCrop = root.normalizeCropRect(root.currentShape.startX, root.currentShape.startY, mouse.x, mouse.y);
                                root.cropDragging = false;
                                root.currentShape = null;
                                if (nextCrop.width >= 8 && nextCrop.height >= 8) {
                                    root.lastMoveUndo = null;
                                    root.cropRect = nextCrop;
                                    root.cropWasLastAction = true;
                                }
                                root.cropDraftRect = Qt.rect(0, 0, 0, 0);
                                return;
                            }
                            if (root.selectedTool === "ocr" && root.ocrDragging && root.currentShape) {
                                var nextOcr = root.normalizeCropRect(root.currentShape.startX, root.currentShape.startY, mouse.x, mouse.y);
                                root.ocrDragging = false;
                                root.currentShape = null;
                                root.ocrDraftRect = Qt.rect(0, 0, 0, 0);
                                root.recognizeRegion(nextOcr);
                                return;
                            }
                            if (!root.currentShape || root.selectedTool === "eraser")
                                return;

                            root.currentShape.endX = mouse.x;
                            root.currentShape.endY = mouse.y;
                            root.lastMoveUndo = null;
                            var nextShapes = root.shapes.slice();
                            nextShapes.push(root.copyShape(root.currentShape));
                            root.shapes = nextShapes;
                            root.cropWasLastAction = false;

                            if (root.currentShape.tool !== "blur" && root.currentShape.tool !== "pixelate") {
                                root.currentShape.__hideLiveCanvas = true;
                                committedCanvas.requestPaint();
                            } else {
                                root.currentShape = null;
                                root.prepareLiveCanvas();
                                committedCanvas.requestPaint();
                                root.scheduleLivePaint();
                            }
                        }
                    }
                    Item {
                        id: cropOverlay

                        anchors.fill: parent
                        visible: root.displayedCropRect.width >= 2 && root.displayedCropRect.height >= 2 && !root.saving

                        Rectangle {
                            color: "#88000000"
                            height: Math.max(0, root.displayedCropRect.y)
                            width: parent.width
                            x: 0
                            y: 0
                        }
                        Rectangle {
                            color: "#88000000"
                            height: Math.max(0, parent.height - y)
                            width: parent.width
                            x: 0
                            y: root.displayedCropRect.y + root.displayedCropRect.height
                        }
                        Rectangle {
                            color: "#88000000"
                            height: root.displayedCropRect.height
                            width: Math.max(0, root.displayedCropRect.x)
                            x: 0
                            y: root.displayedCropRect.y
                        }
                        Rectangle {
                            color: "#88000000"
                            height: root.displayedCropRect.height
                            width: Math.max(0, parent.width - x)
                            x: root.displayedCropRect.x + root.displayedCropRect.width
                            y: root.displayedCropRect.y
                        }
                        Rectangle {
                            border.color: Config.md3.tertiary
                            border.width: 2
                            color: "transparent"
                            height: root.displayedCropRect.height
                            width: root.displayedCropRect.width
                            x: root.displayedCropRect.x
                            y: root.displayedCropRect.y
                        }
                    }
                    Rectangle {
                        border.color: Config.md3.primary
                        border.width: 2
                        color: Config.alpha(Config.md3.primary, 0.1)
                        height: root.displayedOcrRect.height
                        visible: width >= 2 && height >= 2 && !root.saving
                        width: root.displayedOcrRect.width
                        x: root.displayedOcrRect.x
                        y: root.displayedOcrRect.y
                    }
                    Rectangle {
                        border.color: Config.md3.tertiary
                        border.width: 1
                        color: Config.alpha(Config.md3.background, 0.88)
                        height: inlineTextEditor.height + 6
                        radius: 6
                        visible: inlineTextEditor.visible
                        width: inlineTextEditor.width + 12
                        x: inlineTextEditor.x - 6
                        y: inlineTextEditor.y - 3
                    }
                    TextInput {
                        id: inlineTextEditor

                        clip: true
                        color: root.selectedColor
                        font.family: Config.fontName
                        font.pixelSize: root.textFontSize()
                        font.weight: Font.DemiBold
                        height: Math.max(30, font.pixelSize * 1.35)
                        selectedTextColor: Config.md3.background
                        selectionColor: Config.md3.tertiary
                        visible: false
                        width: Math.min(captureSurface.width - x - 8, Math.max(140, contentWidth + 12))

                        Keys.onEnterPressed: event => {
                            root.commitText();
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: event => {
                            root.cancelText();
                            event.accepted = true;
                        }
                        onAccepted: root.commitText()
                    }
                }
                Item {
                    id: cropExportSurface

                    clip: true
                    height: root.cropRect.height
                    visible: root.saving && root.cropActive
                    width: root.cropRect.width
                    x: captureSurface.x + root.cropRect.x
                    y: captureSurface.y + root.cropRect.y

                    ShaderEffectSource {
                        anchors.fill: parent
                        live: false
                        smooth: true
                        sourceItem: captureSurface
                        sourceRect: root.cropRect
                    }
                }
                Item {
                    id: ocrExportSurface

                    clip: true
                    height: root.ocrRect.height
                    visible: root.ocrPreparing
                    width: root.ocrRect.width
                    x: captureSurface.x + root.ocrRect.x
                    y: captureSurface.y + root.ocrRect.y

                    ShaderEffectSource {
                        anchors.fill: parent
                        live: false
                        smooth: true
                        sourceItem: sourceImage
                        sourceRect: root.ocrRect
                    }
                }
            }
            LoadingIndicator {
                anchors.centerIn: parent
                animated: sourceImage.status === Image.Loading
                color: Config.md3.primary
                height: 48
                visible: sourceImage.status === Image.Loading
                width: 48
            }
            Rectangle {
                anchors.centerIn: parent
                color: Config.alpha(Config.md3.surface_container_high, 0.96)
                implicitHeight: sourceErrorContent.implicitHeight + 32
                radius: 18
                visible: sourceImage.status === Image.Error
                width: Math.min(360, editorArea.width - 32)

                ColumnLayout {
                    id: sourceErrorContent

                    anchors.centerIn: parent
                    spacing: 12
                    width: parent.width - 32

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: Config.md3.error
                        font.family: Config.fontName
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        text: qsTr("Could not load the screenshot")
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("The image may still be writing or is no longer available.")
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        Rectangle {
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: retryLabel.implicitWidth + 28
                            color: retryArea.pressed ? Config.md3.primary_container : Config.alpha(Config.md3.primary, retryArea.containsMouse ? 0.22 : 0.14)
                            radius: 12

                            Text {
                                id: retryLabel

                                anchors.centerIn: parent
                                color: Config.md3.primary
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                text: qsTr("Retry")
                            }
                            MouseArea {
                                id: retryArea

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: root.retrySourceImage()
                            }
                        }
                        Rectangle {
                            Layout.preferredHeight: 38
                            Layout.preferredWidth: closeLabel.implicitWidth + 28
                            color: closeArea.pressed ? Config.md3.surface_container_highest : Config.alpha(Config.md3.on_surface, closeArea.containsMouse ? 0.12 : 0.07)
                            radius: 12

                            Text {
                                id: closeLabel

                                anchors.centerIn: parent
                                color: Config.md3.on_surface
                                font.family: Config.fontName
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                text: qsTr("Close")
                            }
                            MouseArea {
                                id: closeArea

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: root.cancelEditor()
                            }
                        }
                    }
                }
            }
        }
        Item {
            id: toolbarViewport

            Layout.fillWidth: true
            Layout.preferredHeight: toolbar.implicitHeight

            Flickable {
                anchors.fill: parent
                boundsBehavior: Flickable.StopAtBounds
                clip: contentWidth > width
                contentHeight: height
                contentWidth: Math.max(width, toolbar.implicitWidth)
                flickableDirection: Flickable.HorizontalFlick
                interactive: contentWidth > width

                ScreenshotEditorToolbar {
                    id: toolbar

                    anchors.verticalCenter: parent.verticalCenter
                    selectedColor: root.selectedColor
                    selectedTool: root.selectedTool
                    selectedWidth: root.selectedWidth
                    x: toolbar.implicitWidth <= toolbarViewport.width ? (toolbarViewport.width - toolbar.implicitWidth) / 2 : 0

                    onColorSelected: colorValue => {
                        return root.selectedColor = colorValue;
                    }
                    onToolSelected: tool => {
                        if (inlineTextEditor.visible)
                            root.commitText();

                        root.selectedTool = tool;
                    }
                    onWidthSelected: widthValue => {
                        return root.selectedWidth = widthValue;
                    }
                }
            }
        }
    }
}
