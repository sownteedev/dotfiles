import "../.."
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root

    property bool annotationResizeFromCenter: false
    property int annotationResizeHorizontalSign: 0
    property real annotationResizeStartPointerX: 0
    property real annotationResizeStartPointerY: 0
    property int annotationResizeVerticalSign: 0
    readonly property bool annotationTransformActive: annotationTransformMode !== ""
    property bool annotationTransformChanged: false
    property int annotationTransformIndex: -1
    property string annotationTransformMode: ""
    property var annotationTransformOriginal: null
    property bool baseImageFitPending: true
    property var baseImageLayer: null
    readonly property string baseImageLayerId: "screenshot-base"
    readonly property bool baseImageReady: baseImageLayer !== null && Math.abs(Number(baseImageLayer.endX || 0) - Number(baseImageLayer.startX || 0)) > 1 && Math.abs(Number(baseImageLayer.endY || 0) - Number(baseImageLayer.startY || 0)) > 1
    readonly property var blurShapes: shapes.filter(function (shape) {
        return shape.tool === "blur";
    })
    readonly property real bottomControlSpacing: height < 720 ? 10 : 16
    readonly property var calloutShapes: shapes.filter(function (shape) {
        return shape.tool === "callout";
    })
    readonly property bool canRedo: redoHistory.length > 0
    readonly property bool canUndo: shapes.length > 0 || (cropActive && cropWasLastAction) || lastMoveUndo !== null || edgeStitchHistory.length > 0
    readonly property real chromeMargin: Responsive.clamp(width * 0.012, 12, 24)
    property color colorPickerColor: selectedColor
    property bool colorPickerCommitPending: false
    property bool colorPickerHeld: false
    property real colorPickerPixelX: 0
    property real colorPickerPixelY: 0
    property Item colorPickerSourceItem: null
    property real colorPickerSourceX: 0
    property real colorPickerSourceY: 0
    readonly property bool compactChrome: width < 900
    readonly property bool cropActive: cropRect.width > 2 && cropRect.height > 2
    property rect cropDraftRect: Qt.rect(0, 0, 0, 0)
    property bool cropDragging: false
    property rect cropRect: Qt.rect(0, 0, 0, 0)
    property string cropTargetLayerId: ""
    property var cropTargetOriginal: null
    property bool cropWasLastAction: false
    property var currentShape: null
    readonly property rect displayedCropRect: cropDragging ? cropDraftRect : cropRect
    readonly property rect displayedOcrRect: ocrDragging ? ocrDraftRect : ocrRect
    property string edgeStitchDropEdge: ""
    property var edgeStitchHistory: []
    property string edgeStitchImagePath: ""
    property string edgeStitchLayerId: ""
    property var edgeStitchPendingSnapshot: null
    property bool edgeStitchPreparing: false
    property int edgeStitchProcessSession: -1
    property int edgeStitchSessionToken: 0
    property string edgeStitchSourcePath: ""
    readonly property bool editorChromeBusy: saving || reverseSearchPreparing || edgeStitchPreparing || (renderExportBusy && renderExportOperation !== "ocr")
    property bool editorPresented: false
    readonly property bool editorReady: sourceImage.status === Image.Error || (sourceImage.status === Image.Ready && logicalSurfaceReady && !baseImageFitPending && baseImageReady)
    readonly property var effectiveImageLayerOrderIds: normalizedImageLayerOrder(imageLayerOrderIds)
    readonly property bool imageCompositeLive: imageResizePreview !== null || (currentShape !== null && currentShape.tool === "image")
    property int imageCompositeRevision: 0
    readonly property bool imageInsertBusy: imageLayerPicker.running || imageProbeProcess.running
    property int imageInsertSessionToken: 0
    property var imageLayerOrderIds: []
    property bool imageLoadEnabled: true
    property int imagePickerSession: -1
    property string imageResizeLayerId: ""
    property var imageResizeOriginal: null
    property var imageResizePreview: null
    property string imageTransformMode: ""
    property real inlineTextBoxWidth: 180
    property var insertedImageRenderIds: []
    property var lastMoveUndo: null
    readonly property var layerPanelItems: {
        var items = [];
        for (var i = 0; i < effectiveImageLayerOrderIds.length; ++i) {
            var layer = imageLayerById(effectiveImageLayerOrderIds[i]);
            if (layer)
                items.push(layer);
        }
        return items;
    }
    readonly property bool layersPanelInline: layersPanel.visible && width >= chromeMargin * 2 + layersPanel.width + bottomControlSpacing + 320
    property rect liveDirtyRect: Qt.rect(0, 0, 0, 0)
    property int livePaintFrameId: -1
    property real logicalSurfaceHeight: 1
    property bool logicalSurfaceReady: false
    property real logicalSurfaceWidth: 1
    property bool loupeHeld: false
    property bool loupePointerInside: false
    property real loupePointerX: 0
    property real loupePointerY: 0
    property real loupeZoom: 2.5
    property bool movingShapeDetached: false
    property int movingShapeIndex: -1
    property var movingShapeOriginal: null
    property int nextImageLayerId: 1
    property int nextMarkerNumber: 1
    property rect ocrDraftRect: Qt.rect(0, 0, 0, 0)
    property bool ocrDragging: false
    property bool ocrNoticeError: false
    property string ocrNoticeText: ""
    property bool ocrNoticeVisible: false
    property bool ocrPreparing: false
    property rect ocrRect: Qt.rect(0, 0, 0, 0)
    property int ocrSessionToken: 0
    property string pendingImagePath: ""
    property int pendingImageSession: -1
    readonly property var pixelateShapes: shapes.filter(function (shape) {
        return shape.tool === "pixelate";
    })
    property var redoHistory: []
    readonly property bool renderExportBusy: renderExportCapturePending || renderExportProcess.running
    property bool renderExportCapturePending: false
    property rect renderExportCropRect: Qt.rect(0, 0, 0, 0)
    property string renderExportInputPath: ""
    property bool renderExportInputTemporary: false
    property string renderExportOperation: ""
    property int renderExportOperationSession: -1
    property string renderExportOutputPath: ""
    property bool renderExportOutputTemporary: false
    property int renderExportRunningSession: -1
    property int renderExportSessionToken: 0
    property int renderExportTargetHeight: 0
    property int renderExportTargetWidth: 0
    readonly property bool renderingOutput: saving || reverseSearchPreparing || edgeStitchPreparing || ocrPreparing
    property bool reverseSearchPreparing: false
    property int reverseSearchSessionToken: 0
    property string saveError: ""
    property bool saving: false
    property int selectedAnnotationIndex: -1
    property var selectedAnnotationShape: null
    property color selectedColor: Config.captureEditorColor
    readonly property real selectedFrameOffsetX: movingShapeOriginal && currentShape && currentShape.tool !== "image" && currentShape.tool !== "blur" && currentShape.tool !== "pixelate" ? liveCanvasTranslate.x : 0
    readonly property real selectedFrameOffsetY: movingShapeOriginal && currentShape && currentShape.tool !== "image" && currentShape.tool !== "blur" && currentShape.tool !== "pixelate" ? liveCanvasTranslate.y : 0
    readonly property rect selectedFrameRect: selectionRectForShape(selectedFrameShape)
    readonly property real selectedFrameRotation: Number(selectedFrameShape && selectedFrameShape.rotation || 0)
    readonly property var selectedFrameShape: selectedTool === "select" ? (movingShapeOriginal && currentShape && currentShape.tool !== "image" ? currentShape : selectedAnnotationShape) : null
    readonly property var selectedImageLayer: imageLayerById(selectedImageLayerId)
    property string selectedImageLayerId: ""
    property real selectedOpacity: 1
    property string selectedTool: "pen"
    property real selectedWidth: Config.captureEditorWidth
    property real selectionPointerX: 0
    property real selectionPointerY: 0
    property int selectionPreviewFrameId: -1
    property real selectionStartX: 0
    property real selectionStartY: 0
    property var shapes: []
    readonly property real toolbarOpacity: selectedTool === "select" ? shapeOpacity(toolbarOpacityAnnotation || toolbarOpacityImageLayer) : selectedOpacity
    readonly property var toolbarOpacityAnnotation: annotationTransformMode === "opacity" && currentShape ? currentShape : selectedAnnotationShape
    readonly property bool toolbarOpacityAvailable: toolSupportsOpacity(selectedTool) || (selectedTool === "select" && (toolbarOpacityAnnotation || toolbarOpacityImageLayer))
    readonly property var toolbarOpacityImageLayer: imageTransformMode === "opacity" && imageResizePreview ? imageResizePreview : selectedImageLayer

    function acceptColorSample(red, green, blue, alpha) {
        if (!colorPickerHeld && !colorPickerCommitPending)
            return;
        if (alpha <= 0) {
            colorPickerCommitPending = false;
            if (!colorPickerHeld)
                colorPickerSourceItem = null;
            return;
        }
        colorPickerColor = Qt.rgba(red / 255, green / 255, blue / 255, 1);
        if (colorPickerCommitPending) {
            selectedColor = colorPickerColor;
            colorPickerCommitPending = false;
            if (!colorPickerHeld)
                colorPickerSourceItem = null;
        }
    }
    function addNumberMarker(x, y) {
        invalidateRedo();
        lastMoveUndo = null;
        var size = markerSize();
        var radius = size / 2;
        var centerX = Math.max(radius, Math.min(captureSurface.width - radius, x));
        var centerY = Math.max(radius, Math.min(captureSurface.height - radius, y));
        var nextShapes = shapes.slice();
        nextShapes.push({
            "tool": "number",
            "color": String(selectedColor),
            "opacity": selectedOpacity,
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
    function annotationSupportsRotation(shape) {
        if (!shape)
            return false;
        return ["pen", "highlight", "line", "arrow", "rectangle", "ellipse", "text", "callout"].indexOf(String(shape.tool || "")) >= 0;
    }
    function applySelectionPreview() {
        if (selectedTool === "crop" && cropDragging)
            cropDraftRect = cropTargetOriginal ? normalizeCropRectForLayer(cropTargetOriginal, selectionStartX, selectionStartY, selectionPointerX, selectionPointerY) : normalizeCropRect(selectionStartX, selectionStartY, selectionPointerX, selectionPointerY);
        else if (selectedTool === "ocr" && ocrDragging)
            ocrDraftRect = normalizeCropRect(selectionStartX, selectionStartY, selectionPointerX, selectionPointerY);
    }
    function beginAnnotationResize(horizontalSign, verticalSign, pointerX, pointerY, modifiers) {
        beginAnnotationTransform("resize");
        if (annotationTransformMode !== "resize")
            return;

        annotationResizeHorizontalSign = horizontalSign < 0 ? -1 : 1;
        annotationResizeVerticalSign = verticalSign < 0 ? -1 : 1;
        annotationResizeFromCenter = (Number(modifiers || 0) & Qt.AltModifier) !== 0;
        annotationResizeStartPointerX = Number(pointerX || 0);
        annotationResizeStartPointerY = Number(pointerY || 0);
    }
    function beginAnnotationTransform(mode) {
        if (annotationTransformActive || selectedTool !== "select" || !selectedAnnotationShape || selectedAnnotationIndex < 0 || selectedAnnotationIndex >= shapes.length)
            return;

        var original = shapes[selectedAnnotationIndex];
        if (!original || original.tool === "image" || (mode === "rotation" && !annotationSupportsRotation(original)))
            return;

        annotationTransformChanged = false;
        annotationTransformIndex = selectedAnnotationIndex;
        annotationTransformMode = mode;
        annotationTransformOriginal = copyShape(original);
        annotationResizeHorizontalSign = 0;
        annotationResizeFromCenter = false;
        annotationResizeVerticalSign = 0;
        annotationResizeStartPointerX = 0;
        annotationResizeStartPointerY = 0;
        movingShapeDetached = false;
        movingShapeIndex = selectedAnnotationIndex;
        movingShapeOriginal = copyShape(original);
        prepareLiveCanvas();
        var preview = copyShape(original);
        preview.__annotationTransform = true;
        preview.__waitingForLiveHandoff = true;
        currentShape = preview;
        scheduleLivePaint();
    }
    function beginImageCrop(layerId) {
        beginImageTransform(layerId, "crop");
    }
    function beginImageResize(layerId) {
        beginImageTransform(layerId, "resize");
    }
    function beginImageRotation(layerId) {
        beginImageTransform(layerId, "rotation");
    }
    function beginImageTransform(layerId, mode) {
        var layer = imageLayerById(layerId);
        if (!layer)
            return;

        selectedAnnotationShape = null;
        imageResizeLayerId = layerId;
        imageResizeOriginal = copyShape(layer);
        imageResizePreview = copyShape(layer);
        imageTransformMode = mode;
        selectedImageLayerId = layerId;
        lastMoveUndo = null;
    }
    function beginOpacityChange() {
        if (selectedTool !== "select")
            return;
        if (selectedAnnotationShape) {
            beginAnnotationTransform("opacity");
            return;
        }
        if (!selectedImageLayer || imageTransformMode !== "")
            return;
        beginImageTransform(selectedImageLayer.layerId, "opacity");
    }
    function beginText(x, y) {
        if (inlineTextEditor.visible)
            commitText();

        inlineTextEditor.x = Math.max(8, Math.min(captureSurface.width - 188, x));
        inlineTextEditor.y = Math.max(8, Math.min(captureSurface.height - inlineTextEditor.height - 8, y));
        inlineTextBoxWidth = 180;
        inlineTextEditor.text = "";
        inlineTextEditor.visible = true;
        inlineTextEditor.forceActiveFocus();
    }
    function calloutZoomForWidth() {
        return Math.max(1.5, Math.min(4, 1.5 + (Math.max(2, Math.min(24, selectedWidth)) - 2) / 22 * 2.5));
    }
    function canUseOriginalForRenderExport() {
        if (!baseImageLayer || shapes.length !== 0 || currentShape !== null || imageResizePreview !== null || !CaptureService.screenshotPath)
            return false;
        if (String(baseImageLayer.source || "") !== String(CaptureService.screenshotPath))
            return false;
        if (Boolean(baseImageLayer.hidden) || Math.abs(Number(baseImageLayer.rotation || 0)) > 0.01 || Math.abs(shapeOpacity(baseImageLayer) - 1) > 0.001)
            return false;
        if (Math.abs(Number(baseImageLayer.cropX || 0)) > 0.0001 || Math.abs(Number(baseImageLayer.cropY || 0)) > 0.0001)
            return false;
        if (Math.abs(Number(baseImageLayer.cropWidth === undefined ? 1 : baseImageLayer.cropWidth) - 1) > 0.0001 || Math.abs(Number(baseImageLayer.cropHeight === undefined ? 1 : baseImageLayer.cropHeight) - 1) > 0.0001)
            return false;

        return Math.abs(Number(baseImageLayer.startX || 0)) < 0.5 && Math.abs(Number(baseImageLayer.startY || 0)) < 0.5 && Math.abs(Number(baseImageLayer.endX || 0) - captureSurface.width) < 0.5 && Math.abs(Number(baseImageLayer.endY || 0) - captureSurface.height) < 0.5;
    }
    function cancelAnnotationTransform() {
        if (!annotationTransformActive)
            return;
        cancelShapeMove();
    }
    function cancelEdgeStitch() {
        edgeStitchSessionToken += 1;
        if (edgeStitchProcess.running)
            edgeStitchProcess.running = false;
        edgeStitchPendingSnapshot = null;
        clearEdgeStitchState();
    }
    function cancelEditor() {
        if (annotationTransformActive) {
            cancelAnnotationTransform();
            return;
        }
        stopSelectionPreview();
        cancelRenderExport();
        cancelEdgeStitch();
        imageInsertSessionToken += 1;
        cancelOcrSession();
        reverseSearchSessionToken += 1;
        reverseSearchPreparing = false;
        CaptureService.closeScreenshotEditor();
    }
    function cancelImageCrop(layerId) {
        cancelImageTransform(layerId, "crop");
    }
    function cancelImageResize(layerId) {
        cancelImageTransform(layerId, "resize");
    }
    function cancelImageRotation(layerId) {
        cancelImageTransform(layerId, "rotation");
    }
    function cancelImageTransform(layerId, mode) {
        if (imageResizeLayerId !== layerId || imageTransformMode !== mode)
            return;

        imageResizeLayerId = "";
        imageResizeOriginal = null;
        imageResizePreview = null;
        imageTransformMode = "";
    }
    function cancelOcrSession() {
        ocrSessionToken += 1;
        ocrPreparing = false;
        if (renderExportOperation === "ocr")
            cancelRenderExport();
        OcrService.reset();
    }
    function cancelRenderExport() {
        if (renderExportOperation === "" && !renderExportCapturePending && !renderExportProcess.running)
            return;

        var operation = renderExportOperation;
        renderExportSessionToken += 1;
        if (renderExportProcess.running)
            renderExportProcess.running = false;

        clearRenderExportState(true);
        if (operation === "ocr") {
            ocrPreparing = false;
            ocrRect = Qt.rect(0, 0, 0, 0);
        } else if (operation === "reverse")
            reverseSearchPreparing = false;
        else if (operation === "save")
            saving = false;
    }
    function cancelShapeMove() {
        var canceledIndex = movingShapeIndex;
        var canceledAnnotation = movingShapeOriginal && movingShapeOriginal.tool !== "image" ? copyShape(movingShapeOriginal) : null;
        if (movingShapeOriginal) {
            var nextShapes = shapes.slice();
            if (movingShapeOriginal.layerId === baseImageLayerId) {
                baseImageLayer = copyShape(movingShapeOriginal);
            } else if (movingShapeOriginal.tool === "image") {
                var imageIndex = imageLayerIndexById(movingShapeOriginal.layerId);
                if (imageIndex >= 0)
                    nextShapes[imageIndex] = copyShape(movingShapeOriginal);
            } else if (movingShapeDetached) {
                var restoreIndex = Math.max(0, Math.min(movingShapeIndex, nextShapes.length));
                nextShapes.splice(restoreIndex, 0, copyShape(movingShapeOriginal));
            }
            if (movingShapeOriginal.tool === "image" || movingShapeDetached)
                shapes = nextShapes;
            recomputeMarkerNumber();
        }
        if (canceledAnnotation) {
            selectedAnnotationShape = canceledAnnotation;
            selectedAnnotationIndex = canceledIndex;
        }

        annotationTransformChanged = false;
        annotationTransformIndex = -1;
        annotationTransformMode = "";
        annotationTransformOriginal = null;
        annotationResizeHorizontalSign = 0;
        annotationResizeFromCenter = false;
        annotationResizeVerticalSign = 0;
        annotationResizeStartPointerX = 0;
        annotationResizeStartPointerY = 0;
        movingShapeDetached = false;
        movingShapeIndex = -1;
        movingShapeOriginal = null;
        liveCanvasTranslate.x = 0;
        liveCanvasTranslate.y = 0;
        edgeStitchDropEdge = "";
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
        stopSelectionPreview();
        hideOcrNotice();
        selectionStartX = 0;
        selectionStartY = 0;
        selectionPointerX = 0;
        selectionPointerY = 0;
        invalidateRedo();
        cancelOcrSession();
        edgeStitchHistory = [];
        edgeStitchPendingSnapshot = null;
        annotationTransformChanged = false;
        annotationTransformIndex = -1;
        annotationTransformMode = "";
        annotationTransformOriginal = null;
        annotationResizeHorizontalSign = 0;
        annotationResizeFromCenter = false;
        annotationResizeVerticalSign = 0;
        annotationResizeStartPointerX = 0;
        annotationResizeStartPointerY = 0;
        selectedAnnotationShape = null;
        shapes = [];
        imageLayerOrderIds = baseImageLayer ? [baseImageLayerId] : [];
        currentShape = null;
        if (baseImageLayer) {
            baseImageLayer = createBaseImageLayer(baseImageLayer.source, baseImageLayer.naturalWidth, baseImageLayer.naturalHeight);
            baseImageFitPending = true;
        } else {
            baseImageFitPending = false;
        }
        var resetSourcePath = baseImageLayer ? String(baseImageLayer.source) : "";
        selectedImageLayerId = baseImageLayer ? baseImageLayerId : "";
        imageResizeLayerId = "";
        imageResizeOriginal = null;
        imageResizePreview = null;
        imageTransformMode = "";
        pendingImagePath = "";
        pendingImageSession = -1;
        lastMoveUndo = null;
        movingShapeDetached = false;
        movingShapeIndex = -1;
        movingShapeOriginal = null;
        cropRect = Qt.rect(0, 0, 0, 0);
        cropDraftRect = Qt.rect(0, 0, 0, 0);
        cropDragging = false;
        cropTargetLayerId = "";
        cropTargetOriginal = null;
        cropWasLastAction = false;
        nextImageLayerId = 1;
        nextMarkerNumber = 1;
        ocrRect = Qt.rect(0, 0, 0, 0);
        ocrDraftRect = Qt.rect(0, 0, 0, 0);
        ocrDragging = false;
        loupeHeld = false;
        loupePointerInside = false;
        inlineTextEditor.visible = false;
        inlineTextEditor.text = "";
        prepareLiveCanvas();
        committedCanvas.requestPaint();
        Qt.callLater(function () {
            if (!root.baseImageLayer || root.baseImageLayer.source !== resetSourcePath)
                return;
            var fittedLayer = root.copyShape(root.baseImageLayer);
            fittedLayer.endX = Math.max(1, captureSurface.width);
            fittedLayer.endY = Math.max(1, captureSurface.height);
            root.baseImageLayer = fittedLayer;
            if (sourceImage.imageStatus === Image.Ready && String(CaptureService.screenshotPath) === resetSourcePath)
                root.baseImageFitPending = false;
        });
    }
    function clearEdgeStitchState() {
        var sourcePath = edgeStitchSourcePath;
        edgeStitchDropEdge = "";
        edgeStitchImagePath = "";
        edgeStitchLayerId = "";
        edgeStitchPreparing = false;
        edgeStitchProcessSession = -1;
        edgeStitchSourcePath = "";
        if (sourcePath !== "")
            Quickshell.execDetached(["rm", "-f", "--", sourcePath]);
    }
    function clearRenderExportState(removeOutput) {
        var inputPath = renderExportInputPath;
        var inputTemporary = renderExportInputTemporary;
        var outputPath = renderExportOutputPath;
        var outputTemporary = renderExportOutputTemporary;
        renderExportCapturePending = false;
        renderExportCropRect = Qt.rect(0, 0, 0, 0);
        renderExportInputPath = "";
        renderExportInputTemporary = false;
        renderExportOperation = "";
        renderExportOperationSession = -1;
        renderExportOutputPath = "";
        renderExportOutputTemporary = false;
        renderExportRunningSession = -1;
        renderExportTargetHeight = 0;
        renderExportTargetWidth = 0;
        if (!renderExportProcess.running)
            renderExportProcess.command = [];
        if (inputTemporary && inputPath !== "")
            Quickshell.execDetached(["rm", "-f", "--", inputPath]);
        if (removeOutput && outputTemporary && outputPath !== "")
            Quickshell.execDetached(["rm", "-f", "--", outputPath]);
    }
    function colorPickerTargetAt(x, y) {
        for (var i = effectiveImageLayerOrderIds.length - 1; i >= 0; --i) {
            var layerId = String(effectiveImageLayerOrderIds[i]);
            var shape = imageResizePreview && imageResizePreview.layerId === layerId ? imageResizePreview : imageLayerById(layerId);
            if (!shape || Boolean(shape.hidden))
                continue;
            var localPoint = pointInShapeLocalSpace(shape, x, y);
            if (localPoint.x < 0 || localPoint.x > localPoint.width || localPoint.y < 0 || localPoint.y > localPoint.height)
                continue;
            var renderedLayer = renderedImageLayerById(layerId);
            if (!renderedLayer || renderedLayer.imageStatus !== Image.Ready || !renderedLayer.imageItem)
                continue;
            var sourceItem = renderedLayer.imageItem;
            var sourceX = localPoint.x - sourceItem.x;
            var sourceY = localPoint.y - sourceItem.y;
            if (sourceX < 0 || sourceX >= sourceItem.width || sourceY < 0 || sourceY >= sourceItem.height)
                continue;
            var pixelWidth = Math.max(1, Number(shape.naturalWidth) || Number(renderedLayer.imageSourceSize.width) || Number(sourceItem.implicitWidth) || Number(sourceItem.width) || 1);
            var pixelHeight = Math.max(1, Number(shape.naturalHeight) || Number(renderedLayer.imageSourceSize.height) || Number(sourceItem.implicitHeight) || Number(sourceItem.height) || 1);
            return {
                "sourceItem": sourceItem,
                "sourceX": sourceX,
                "sourceY": sourceY,
                "pixelX": Math.max(0, Math.min(pixelWidth - 1, Math.floor(sourceX / Math.max(1, sourceItem.width) * pixelWidth))),
                "pixelY": Math.max(0, Math.min(pixelHeight - 1, Math.floor(sourceY / Math.max(1, sourceItem.height) * pixelHeight)))
            };
        }
        return null;
    }
    function commitImageCrop(layerId, cropSelection) {
        var original = cropTargetOriginal || imageLayerById(layerId);
        if (!original || cropSelection.width < 8 || cropSelection.height < 8)
            return false;

        var layerLeft = Math.min(original.startX, original.endX);
        var layerTop = Math.min(original.startY, original.endY);
        var layerWidth = Math.max(1, Math.abs(original.endX - original.startX));
        var layerHeight = Math.max(1, Math.abs(original.endY - original.startY));
        var currentCropX = original.cropX === undefined ? 0 : original.cropX;
        var currentCropY = original.cropY === undefined ? 0 : original.cropY;
        var currentCropWidth = original.cropWidth === undefined ? 1 : original.cropWidth;
        var currentCropHeight = original.cropHeight === undefined ? 1 : original.cropHeight;
        var relativeX = Math.max(0, Math.min(1, (cropSelection.x - layerLeft) / layerWidth));
        var relativeY = Math.max(0, Math.min(1, (cropSelection.y - layerTop) / layerHeight));
        var relativeWidth = Math.max(0.0001, Math.min(1 - relativeX, cropSelection.width / layerWidth));
        var relativeHeight = Math.max(0.0001, Math.min(1 - relativeY, cropSelection.height / layerHeight));
        var croppedLayer = copyShape(original);
        croppedLayer.cropX = currentCropX + relativeX * currentCropWidth;
        croppedLayer.cropY = currentCropY + relativeY * currentCropHeight;
        croppedLayer.cropWidth = relativeWidth * currentCropWidth;
        croppedLayer.cropHeight = relativeHeight * currentCropHeight;
        croppedLayer.startX = cropSelection.x;
        croppedLayer.startY = cropSelection.y;
        croppedLayer.endX = cropSelection.x + cropSelection.width;
        croppedLayer.endY = cropSelection.y + cropSelection.height;
        if (!setImageLayerShape(layerId, croppedLayer))
            return false;

        invalidateRedo();
        lastMoveUndo = {
            "kind": "image-state",
            "layerId": layerId,
            "shape": copyShape(original)
        };
        selectedImageLayerId = layerId;
        cropWasLastAction = false;
        committedCanvas.requestPaint();
        return true;
    }
    function commitText() {
        var value = inlineTextEditor.text.trim();
        if (value !== "") {
            invalidateRedo();
            lastMoveUndo = null;
            var fontSize = textFontSize();
            var nextShapes = shapes.slice();
            nextShapes.push({
                "tool": "text",
                "color": String(selectedColor),
                "opacity": selectedOpacity,
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
    function completeRenderExport(operation, outputPath, targetWidth, targetHeight) {
        if (operation === "ocr") {
            ocrPreparing = false;
            ocrRect = Qt.rect(0, 0, 0, 0);
            OcrService.recognize(outputPath);
        } else if (operation === "reverse") {
            reverseSearchPreparing = false;
            CaptureService.searchScreenshotWithLens(outputPath, targetWidth, targetHeight);
            CaptureService.dismissScreenshotEditor();
        } else if (operation === "save") {
            saving = false;
            CaptureService.finishScreenshotEditing(outputPath);
        }
    }
    function contrastingTextColor(colorValue) {
        var luminance = colorValue.r * 0.299 + colorValue.g * 0.587 + colorValue.b * 0.114;
        return luminance > 0.58 ? "#151515" : "#ffffff";
    }
    function copyEdgeSnapshot(snapshot) {
        if (!snapshot)
            return null;
        var copiedShapes = [];
        var sourceShapes = snapshot.shapes || [];
        for (var i = 0; i < sourceShapes.length; ++i)
            copiedShapes.push(copyShape(sourceShapes[i]));
        return {
            "screenshotPath": String(snapshot.screenshotPath || ""),
            "baseImageLayer": snapshot.baseImageLayer ? copyShape(snapshot.baseImageLayer) : null,
            "shapes": copiedShapes,
            "imageLayerOrderIds": (snapshot.imageLayerOrderIds || []).slice(),
            "cropRect": copyRect(snapshot.cropRect),
            "cropWasLastAction": Boolean(snapshot.cropWasLastAction),
            "nextImageLayerId": Number(snapshot.nextImageLayerId || 1),
            "nextMarkerNumber": Number(snapshot.nextMarkerNumber || 1),
            "logicalSurfaceWidth": Number(snapshot.logicalSurfaceWidth || 0),
            "logicalSurfaceHeight": Number(snapshot.logicalSurfaceHeight || 0),
            "selectedImageLayerId": String(snapshot.selectedImageLayerId || "")
        };
    }
    function copyRect(rectValue) {
        if (!rectValue)
            return Qt.rect(0, 0, 0, 0);
        return Qt.rect(rectValue.x, rectValue.y, rectValue.width, rectValue.height);
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
            "layerId": shape.layerId || "",
            "layerName": shape.layerName || "",
            "isBase": Boolean(shape.isBase),
            "hidden": Boolean(shape.hidden),
            "source": shape.source || "",
            "naturalWidth": shape.naturalWidth || 0,
            "naturalHeight": shape.naturalHeight || 0,
            "decodeWidth": shape.decodeWidth || 0,
            "decodeHeight": shape.decodeHeight || 0,
            "cropX": shape.cropX === undefined ? 0 : shape.cropX,
            "cropY": shape.cropY === undefined ? 0 : shape.cropY,
            "cropWidth": shape.cropWidth === undefined ? 1 : shape.cropWidth,
            "cropHeight": shape.cropHeight === undefined ? 1 : shape.cropHeight,
            "rotation": Number(shape.rotation || 0),
            "opacity": shape.opacity === undefined ? 1 : Number(shape.opacity),
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
            "calloutX": Number(shape.calloutX || 0),
            "calloutY": Number(shape.calloutY || 0),
            "calloutWidth": Number(shape.calloutWidth || 0),
            "calloutHeight": Number(shape.calloutHeight || 0),
            "calloutZoom": Number(shape.calloutZoom || 0),
            "points": copiedPoints
        };
    }
    function copyUndoEntry(entry) {
        if (!entry)
            return null;
        return {
            "kind": entry.kind || "",
            "layerId": entry.layerId || "",
            "index": Number(entry.index || 0),
            "removed": Boolean(entry.removed),
            "shape": entry.shape ? copyShape(entry.shape) : null,
            "imageLayerOrderIds": entry.imageLayerOrderIds ? entry.imageLayerOrderIds.slice() : null
        };
    }
    function createBaseImageLayer(path, naturalWidth, naturalHeight) {
        return {
            "tool": "image",
            "layerId": baseImageLayerId,
            "layerName": qsTr("Screenshot"),
            "isBase": true,
            "hidden": false,
            "source": String(path || ""),
            "naturalWidth": Math.max(0, Number(naturalWidth) || 0),
            "naturalHeight": Math.max(0, Number(naturalHeight) || 0),
            "decodeWidth": 0,
            "decodeHeight": 0,
            "cropX": 0,
            "cropY": 0,
            "cropWidth": 1,
            "cropHeight": 1,
            "rotation": 0,
            "opacity": 1,
            "color": "transparent",
            "width": 1,
            "startX": 0,
            "startY": 0,
            "endX": Math.max(1, captureSurface.width),
            "endY": Math.max(1, captureSurface.height),
            "points": []
        };
    }
    function currentImageLayerIds() {
        var layerIds = [];
        if (baseImageLayer)
            layerIds.push(baseImageLayerId);
        for (var i = 0; i < shapes.length; ++i) {
            if (shapes[i].tool === "image" && shapes[i].layerId)
                layerIds.push(String(shapes[i].layerId));
        }
        return layerIds;
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
        ctx.globalAlpha = shapeOpacity(shape);
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
        if (!shape || shape.tool === "blur" || shape.tool === "pixelate" || shape.tool === "image")
            return;

        ctx.save();
        var shapeRotation = Number(shape.rotation || 0);
        if (Math.abs(shapeRotation) > 0.01) {
            var rotationBounds = rawShapeBounds(shape);
            var rotationCenterX = (rotationBounds.minX + rotationBounds.maxX) / 2;
            var rotationCenterY = (rotationBounds.minY + rotationBounds.maxY) / 2;
            ctx.translate(rotationCenterX, rotationCenterY);
            ctx.rotate(shapeRotation * Math.PI / 180);
            ctx.translate(-rotationCenterX, -rotationCenterY);
        }
        ctx.globalAlpha = shapeOpacity(shape);
        ctx.strokeStyle = shape.color;
        ctx.fillStyle = shape.color;
        ctx.lineWidth = shape.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        if (shape.tool === "callout") {
            if (Number(shape.calloutWidth || 0) <= 0 || Number(shape.calloutHeight || 0) <= 0) {
                var calloutLeft = Math.min(shape.startX, shape.endX);
                var calloutTop = Math.min(shape.startY, shape.endY);
                ctx.strokeRect(calloutLeft, calloutTop, Math.abs(shape.endX - shape.startX), Math.abs(shape.endY - shape.startY));
            }
            ctx.restore();
            return;
        }
        if (shape.tool === "highlight") {
            ctx.globalAlpha *= 0.34;
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
                    var xc = (points[i].x + points[i + 1].x) / 2;
                    var yc = (points[i].y + points[i + 1].y) / 2;
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
    function edgeForImage(shape, offsetX, offsetY, pointerX, pointerY) {
        if (!shape)
            return "";

        var threshold = 10;
        var left = Math.min(shape.startX, shape.endX) + offsetX;
        var right = Math.max(shape.startX, shape.endX) + offsetX;
        var top = Math.min(shape.startY, shape.endY) + offsetY;
        var bottom = Math.max(shape.startY, shape.endY) + offsetY;
        var horizontalOverlap = Math.max(0, Math.min(right, captureSurface.width) - Math.max(left, 0));
        var verticalOverlap = Math.max(0, Math.min(bottom, captureSurface.height) - Math.max(top, 0));
        var nearestEdge = "";
        var nearestDistance = threshold + 1;
        var nearestPointerDistance = Number.MAX_VALUE;
        var distances = [
            {
                "edge": "left",
                "distance": Math.abs(right),
                "eligible": verticalOverlap >= Math.min(24, Math.abs(bottom - top) * 0.25),
                "pointerDistance": Math.abs(pointerX)
            },
            {
                "edge": "right",
                "distance": Math.abs(captureSurface.width - left),
                "eligible": verticalOverlap >= Math.min(24, Math.abs(bottom - top) * 0.25),
                "pointerDistance": Math.abs(captureSurface.width - pointerX)
            },
            {
                "edge": "top",
                "distance": Math.abs(bottom),
                "eligible": horizontalOverlap >= Math.min(24, Math.abs(right - left) * 0.25),
                "pointerDistance": Math.abs(pointerY)
            },
            {
                "edge": "bottom",
                "distance": Math.abs(captureSurface.height - top),
                "eligible": horizontalOverlap >= Math.min(24, Math.abs(right - left) * 0.25),
                "pointerDistance": Math.abs(captureSurface.height - pointerY)
            }
        ];
        for (var i = 0; i < distances.length; ++i) {
            if (!distances[i].eligible || distances[i].distance > threshold)
                continue;

            var boundaryDistance = distances[i].distance;
            if (boundaryDistance < nearestDistance || (boundaryDistance === nearestDistance && distances[i].pointerDistance < nearestPointerDistance)) {
                nearestEdge = distances[i].edge;
                nearestDistance = boundaryDistance;
                nearestPointerDistance = distances[i].pointerDistance;
            }
        }
        return nearestEdge;
    }
    function edgeSnappedOffsetForImage(shape, edge, offsetX, offsetY) {
        if (!shape || edge === "")
            return Qt.point(offsetX, offsetY);

        var left = Math.min(shape.startX, shape.endX);
        var right = Math.max(shape.startX, shape.endX);
        var top = Math.min(shape.startY, shape.endY);
        var bottom = Math.max(shape.startY, shape.endY);
        var snappedX = offsetX;
        var snappedY = offsetY;
        if (edge === "left")
            snappedX = -right;
        else if (edge === "right")
            snappedX = captureSurface.width - left;
        else if (edge === "top")
            snappedY = -bottom;
        else if (edge === "bottom")
            snappedY = captureSurface.height - top;
        return Qt.point(snappedX, snappedY);
    }
    function editorSnapshot() {
        var copiedShapes = [];
        for (var i = 0; i < shapes.length; ++i)
            copiedShapes.push(copyShape(shapes[i]));
        var copiedEdgeHistory = [];
        for (var historyIndex = 0; historyIndex < edgeStitchHistory.length; ++historyIndex)
            copiedEdgeHistory.push(copyEdgeSnapshot(edgeStitchHistory[historyIndex]));
        return {
            "screenshotPath": String(CaptureService.screenshotPath || ""),
            "baseImageLayer": baseImageLayer ? copyShape(baseImageLayer) : null,
            "shapes": copiedShapes,
            "imageLayerOrderIds": effectiveImageLayerOrderIds.slice(),
            "cropRect": copyRect(cropRect),
            "cropWasLastAction": cropWasLastAction,
            "nextImageLayerId": nextImageLayerId,
            "nextMarkerNumber": nextMarkerNumber,
            "logicalSurfaceWidth": logicalSurfaceWidth,
            "logicalSurfaceHeight": logicalSurfaceHeight,
            "selectedImageLayerId": selectedImageLayerId,
            "selectedTool": selectedTool,
            "lastMoveUndo": copyUndoEntry(lastMoveUndo),
            "edgeStitchHistory": copiedEdgeHistory
        };
    }
    function eraseAt(x, y) {
        var radius = 14 + selectedWidth;
        var nextShapes = shapes.slice();
        for (var i = nextShapes.length - 1; i >= 0; --i) {
            var bounds = shapeBounds(nextShapes[i]);
            if (x >= bounds.minX - radius && x <= bounds.maxX + radius && y >= bounds.minY - radius && y <= bounds.maxY + radius) {
                invalidateRedo();
                lastMoveUndo = null;
                selectedAnnotationShape = null;
                var removedImageLayerId = nextShapes[i].tool === "image" ? String(nextShapes[i].layerId || "") : "";
                var nextLayerOrder = effectiveImageLayerOrderIds.filter(function (orderedLayerId) {
                    return orderedLayerId !== removedImageLayerId;
                });
                if (removedImageLayerId !== "" && removedImageLayerId === selectedImageLayerId)
                    selectedImageLayerId = "";
                nextShapes.splice(i, 1);
                shapes = nextShapes;
                if (removedImageLayerId !== "")
                    imageLayerOrderIds = nextLayerOrder;
                recomputeMarkerNumber();
                committedCanvas.requestPaint();
                return;
            }
        }
    }
    function failEdgeStitch(message) {
        edgeStitchSessionToken += 1;
        clearEdgeStitchState();
        saveError = message;
        keyScope.forceActiveFocus();
    }
    function failRenderExport(operation, message) {
        if (operation === "ocr") {
            ocrPreparing = false;
            ocrRect = Qt.rect(0, 0, 0, 0);
            OcrService.reportCaptureError();
        } else if (operation === "reverse") {
            reverseSearchPreparing = false;
            saveError = message || qsTr("Could not prepare the image search");
        } else if (operation === "save") {
            saving = false;
            saveError = message || qsTr("Could not save the edited screenshot");
        }
    }
    function finalizeCalloutShape(shape) {
        if (!shape)
            return null;
        var left = Math.min(shape.startX, shape.endX);
        var top = Math.min(shape.startY, shape.endY);
        var sourceWidth = Math.abs(shape.endX - shape.startX);
        var sourceHeight = Math.abs(shape.endY - shape.startY);
        if (sourceWidth < 12 || sourceHeight < 12)
            return null;
        var zoom = calloutZoomForWidth();
        var maximumTarget = Math.max(112, Math.min(240, Math.max(sourceWidth, sourceHeight) * zoom));
        var aspect = sourceWidth / sourceHeight;
        var calloutWidth = aspect >= 1 ? maximumTarget : maximumTarget * aspect;
        var calloutHeight = aspect >= 1 ? maximumTarget / aspect : maximumTarget;
        calloutWidth = Math.max(84, calloutWidth);
        calloutHeight = Math.max(84, calloutHeight);
        var gap = 24;
        var calloutX = left + sourceWidth + gap;
        if (calloutX + calloutWidth > captureSurface.width)
            calloutX = left - calloutWidth - gap;
        if (calloutX < 0)
            calloutX = Math.max(0, Math.min(captureSurface.width - calloutWidth, left + sourceWidth / 2 - calloutWidth / 2));
        var calloutY = Math.max(0, Math.min(captureSurface.height - calloutHeight, top + sourceHeight / 2 - calloutHeight / 2));
        var result = copyShape(shape);
        result.startX = left;
        result.startY = top;
        result.endX = left + sourceWidth;
        result.endY = top + sourceHeight;
        result.calloutX = calloutX;
        result.calloutY = calloutY;
        result.calloutWidth = calloutWidth;
        result.calloutHeight = calloutHeight;
        result.calloutZoom = zoom;
        return result;
    }
    function finishAnnotationTransform() {
        if (!annotationTransformActive || !annotationTransformOriginal)
            return;

        var original = copyShape(annotationTransformOriginal);
        var finalShape = currentShape ? copyShape(currentShape) : copyShape(original);
        var insertionIndex = Math.max(0, Math.min(annotationTransformIndex, shapes.length));
        var nextShapes = shapes.slice();
        if (movingShapeDetached) {
            nextShapes.splice(insertionIndex, 0, finalShape);
        } else if (insertionIndex < nextShapes.length) {
            nextShapes[insertionIndex] = finalShape;
        } else {
            nextShapes.push(finalShape);
            insertionIndex = nextShapes.length - 1;
        }
        shapes = nextShapes;
        selectedAnnotationShape = copyShape(finalShape);
        selectedAnnotationIndex = insertionIndex;
        if (annotationTransformChanged) {
            invalidateRedo();
            lastMoveUndo = {
                "index": insertionIndex,
                "shape": original
            };
            cropWasLastAction = false;
        }

        annotationTransformChanged = false;
        annotationTransformIndex = -1;
        annotationTransformMode = "";
        annotationTransformOriginal = null;
        annotationResizeHorizontalSign = 0;
        annotationResizeFromCenter = false;
        annotationResizeVerticalSign = 0;
        annotationResizeStartPointerX = 0;
        annotationResizeStartPointerY = 0;
        movingShapeDetached = false;
        movingShapeIndex = -1;
        movingShapeOriginal = null;
        liveCanvasTranslate.x = 0;
        liveCanvasTranslate.y = 0;

        if (finalShape.tool === "blur" || finalShape.tool === "pixelate") {
            currentShape = null;
            prepareLiveCanvas();
            committedCanvas.requestPaint();
            scheduleLivePaint();
        } else {
            currentShape = copyShape(finalShape);
            currentShape.__hideLiveCanvas = true;
            committedCanvas.requestPaint();
        }
        keyScope.forceActiveFocus();
    }
    function finishImageCrop(layerId) {
        finishImageTransform(layerId, "crop");
    }
    function finishImageResize(layerId) {
        finishImageTransform(layerId, "resize");
    }
    function finishImageRotation(layerId) {
        finishImageTransform(layerId, "rotation");
    }
    function finishImageTransform(layerId, mode) {
        if (imageResizeLayerId !== layerId || imageTransformMode !== mode || !imageResizeOriginal || !imageResizePreview)
            return;

        var originalShape = copyShape(imageResizeOriginal);
        var transformedShape = copyShape(imageResizePreview);
        if (imageShapesDiffer(transformedShape, originalShape)) {
            if (setImageLayerShape(layerId, transformedShape)) {
                lastMoveUndo = {
                    "kind": "image-state",
                    "layerId": layerId,
                    "shape": originalShape
                };
                cropWasLastAction = false;
                invalidateRedo();
            }
        }
        imageResizeLayerId = "";
        imageResizeOriginal = null;
        imageResizePreview = null;
        imageTransformMode = "";
        committedCanvas.requestPaint();
    }
    function finishOpacityChange() {
        if (annotationTransformMode === "opacity")
            finishAnnotationTransform();
        else if (imageTransformMode === "opacity" && imageResizeLayerId !== "")
            finishImageTransform(imageResizeLayerId, "opacity");
    }
    function hideOcrNotice() {
        ocrNoticeTimer.stop();
        ocrNoticeVisible = false;
    }
    function hitTestShape(shape, x, y) {
        var threshold = 15;
        if (!shape || Boolean(shape.hidden) || shape.tool === "crop" || shape.tool === "ocr")
            return false;

        if (shape.tool === "image") {
            var localPoint = pointInShapeLocalSpace(shape, x, y);
            return localPoint.x >= -threshold && localPoint.x <= localPoint.width + threshold && localPoint.y >= -threshold && localPoint.y <= localPoint.height + threshold;
        }

        var annotationPoint = pointInAnnotationLocalSpace(shape, x, y);
        x = annotationPoint.x;
        y = annotationPoint.y;
        if (shape.tool === "blur" || shape.tool === "pixelate") {
            var bMinX = Math.min(shape.startX, shape.endX);
            var bMaxX = Math.max(shape.startX, shape.endX);
            var bMinY = Math.min(shape.startY, shape.endY);
            var bMaxY = Math.max(shape.startY, shape.endY);
            return x >= bMinX && x <= bMaxX && y >= bMinY && y <= bMaxY;
        }

        if (shape.tool === "callout") {
            var sourceLeft = Math.min(shape.startX, shape.endX);
            var sourceTop = Math.min(shape.startY, shape.endY);
            var sourceRight = Math.max(shape.startX, shape.endX);
            var sourceBottom = Math.max(shape.startY, shape.endY);
            if (x >= sourceLeft - threshold && x <= sourceRight + threshold && y >= sourceTop - threshold && y <= sourceBottom + threshold)
                return true;

            var calloutLeft = Number(shape.calloutX || 0);
            var calloutTop = Number(shape.calloutY || 0);
            var calloutRight = calloutLeft + Number(shape.calloutWidth || 0);
            var calloutBottom = calloutTop + Number(shape.calloutHeight || 0);
            if (x >= calloutLeft - threshold && x <= calloutRight + threshold && y >= calloutTop - threshold && y <= calloutBottom + threshold)
                return true;

            var connectorRadius = Math.max(10, Number(shape.width || 1) / 2 + 8);
            return distanceSquaredToSegment(x, y, (sourceLeft + sourceRight) / 2, (sourceTop + sourceBottom) / 2, (calloutLeft + calloutRight) / 2, (calloutTop + calloutBottom) / 2) <= connectorRadius * connectorRadius;
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
    function imageLayerById(layerId) {
        if (!layerId)
            return null;
        if (layerId === baseImageLayerId)
            return baseImageLayer;
        for (var i = 0; i < shapes.length; ++i) {
            if (shapes[i].tool === "image" && shapes[i].layerId === layerId)
                return shapes[i];
        }
        return null;
    }
    function imageLayerIndexById(layerId) {
        if (!layerId)
            return -1;
        for (var i = 0; i < shapes.length; ++i) {
            if (shapes[i].tool === "image" && shapes[i].layerId === layerId)
                return i;
        }
        return -1;
    }
    function imageLayerName(path) {
        var normalized = String(path || "");
        var separator = normalized.lastIndexOf("/");
        return separator >= 0 ? normalized.substring(separator + 1) : normalized;
    }
    function imageLayerPosition(layerId) {
        for (var i = 0; i < effectiveImageLayerOrderIds.length; ++i) {
            if (effectiveImageLayerOrderIds[i] === layerId)
                return i;
        }
        return -1;
    }
    function imageLayerStackZ(layerId) {
        var position = imageLayerPosition(layerId);
        return position >= 0 ? position - effectiveImageLayerOrderIds.length : -effectiveImageLayerOrderIds.length - 1;
    }
    function imageShapeForLocalCrop(original, localX, localY, nextWidth, nextHeight) {
        if (!original)
            return null;
        var oldWidth = Math.max(1, Math.abs(original.endX - original.startX));
        var oldHeight = Math.max(1, Math.abs(original.endY - original.startY));
        localX = Math.max(0, Math.min(oldWidth - 1, localX));
        localY = Math.max(0, Math.min(oldHeight - 1, localY));
        nextWidth = Math.max(1, Math.min(oldWidth - localX, nextWidth));
        nextHeight = Math.max(1, Math.min(oldHeight - localY, nextHeight));
        var oldLeft = Math.min(original.startX, original.endX);
        var oldTop = Math.min(original.startY, original.endY);
        var oldCenterX = oldLeft + oldWidth / 2;
        var oldCenterY = oldTop + oldHeight / 2;
        var localCenterDx = localX + nextWidth / 2 - oldWidth / 2;
        var localCenterDy = localY + nextHeight / 2 - oldHeight / 2;
        var radians = Number(original.rotation || 0) * Math.PI / 180;
        var newCenterX = oldCenterX + localCenterDx * Math.cos(radians) - localCenterDy * Math.sin(radians);
        var newCenterY = oldCenterY + localCenterDx * Math.sin(radians) + localCenterDy * Math.cos(radians);
        var currentCropX = original.cropX === undefined ? 0 : Number(original.cropX);
        var currentCropY = original.cropY === undefined ? 0 : Number(original.cropY);
        var currentCropWidth = original.cropWidth === undefined ? 1 : Number(original.cropWidth);
        var currentCropHeight = original.cropHeight === undefined ? 1 : Number(original.cropHeight);
        var cropped = copyShape(original);
        cropped.cropX = currentCropX + localX / oldWidth * currentCropWidth;
        cropped.cropY = currentCropY + localY / oldHeight * currentCropHeight;
        cropped.cropWidth = nextWidth / oldWidth * currentCropWidth;
        cropped.cropHeight = nextHeight / oldHeight * currentCropHeight;
        cropped.startX = newCenterX - nextWidth / 2;
        cropped.startY = newCenterY - nextHeight / 2;
        cropped.endX = newCenterX + nextWidth / 2;
        cropped.endY = newCenterY + nextHeight / 2;
        return cropped;
    }
    function imageShapesDiffer(first, second) {
        if (!first || !second)
            return first !== second;
        var keys = ["startX", "startY", "endX", "endY", "cropX", "cropY", "cropWidth", "cropHeight", "rotation", "opacity", "hidden"];
        for (var i = 0; i < keys.length; ++i) {
            if (Math.abs(Number(first[keys[i]] || 0) - Number(second[keys[i]] || 0)) > 0.01)
                return true;
        }
        return false;
    }
    function initializeBaseImageLayer(forceReset) {
        if (sourceImage.imageStatus !== Image.Ready || !CaptureService.screenshotPath)
            return;

        var sourcePath = String(CaptureService.screenshotPath);
        var naturalWidth = Math.max(1, sourceImage.imageSourceSize.width);
        var naturalHeight = Math.max(1, sourceImage.imageSourceSize.height);
        if (!forceReset && logicalSurfaceReady && !baseImageFitPending && baseImageLayer && baseImageLayer.source === sourcePath && baseImageLayer.naturalWidth > 0 && baseImageLayer.naturalHeight > 0)
            return;

        initializeLogicalSurfaceSize(naturalWidth, naturalHeight);
        baseImageLayer = createBaseImageLayer(sourcePath, naturalWidth, naturalHeight);
        if (imageLayerOrderIds.length === 0)
            imageLayerOrderIds = [baseImageLayerId];
        selectedAnnotationShape = null;
        selectedImageLayerId = baseImageLayerId;
        Qt.callLater(function () {
            if (!root.baseImageLayer || root.baseImageLayer.source !== sourcePath || sourceImage.imageStatus !== Image.Ready)
                return;
            var fittedLayer = root.copyShape(root.baseImageLayer);
            fittedLayer.endX = Math.max(1, captureSurface.width);
            fittedLayer.endY = Math.max(1, captureSurface.height);
            root.baseImageLayer = fittedLayer;
            root.baseImageFitPending = false;
        });
    }
    function initializeLogicalSurfaceSize(naturalWidth, naturalHeight) {
        var sourceWidth = Math.max(1, Number(naturalWidth) || 1);
        var sourceHeight = Math.max(1, Number(naturalHeight) || 1);
        var referenceWidth = screen ? screen.width : Math.max(width, 1280);
        var referenceHeight = screen ? screen.height : Math.max(height, 720);
        var maximumWidth = Math.min(1600, Math.max(640, referenceWidth - 96));
        var maximumHeight = Math.min(1000, Math.max(360, referenceHeight - 260));
        var fitScale = Math.min(maximumWidth / sourceWidth, maximumHeight / sourceHeight);
        logicalSurfaceWidth = Math.max(1, Math.round(sourceWidth * fitScale));
        logicalSurfaceHeight = Math.max(1, Math.round(sourceHeight * fitScale));
        logicalSurfaceReady = logicalSurfaceWidth > 1 && logicalSurfaceHeight > 1;
    }
    function insertImageLayer(path, naturalWidth, naturalHeight) {
        if (!path || naturalWidth <= 0 || naturalHeight <= 0 || captureSurface.width <= 0 || captureSurface.height <= 0) {
            saveError = qsTr("Could not read the selected image");
            return;
        }

        var maximumWidth = Math.max(1, captureSurface.width * 0.46);
        var maximumHeight = Math.max(1, captureSurface.height * 0.46);
        var maximumScale = Math.min(maximumWidth / naturalWidth, maximumHeight / naturalHeight);
        var displayScale = Math.min(1, maximumScale);
        var minimumScale = 64 / Math.max(1, Math.min(naturalWidth, naturalHeight));
        displayScale = Math.min(maximumScale, Math.max(displayScale, minimumScale));

        var displayWidth = Math.max(1, naturalWidth * displayScale);
        var displayHeight = Math.max(1, naturalHeight * displayScale);
        var startX = (captureSurface.width - displayWidth) / 2;
        var startY = (captureSurface.height - displayHeight) / 2;
        var decodeScale = Math.min(1, 2048 / naturalWidth, 2048 / naturalHeight);
        var layerId = "image-" + nextImageLayerId++;
        invalidateRedo();
        var nextShapes = shapes.slice();
        nextShapes.push({
            "tool": "image",
            "layerId": layerId,
            "layerName": imageLayerName(path),
            "isBase": false,
            "hidden": false,
            "source": String(path),
            "naturalWidth": naturalWidth,
            "naturalHeight": naturalHeight,
            "decodeWidth": Math.max(1, Math.round(naturalWidth * decodeScale)),
            "decodeHeight": Math.max(1, Math.round(naturalHeight * decodeScale)),
            "cropX": 0,
            "cropY": 0,
            "cropWidth": 1,
            "cropHeight": 1,
            "rotation": 0,
            "opacity": 1,
            "color": "transparent",
            "width": 1,
            "startX": startX,
            "startY": startY,
            "endX": startX + displayWidth,
            "endY": startY + displayHeight,
            "points": []
        });
        shapes = nextShapes;
        imageLayerOrderIds = normalizedImageLayerOrder(effectiveImageLayerOrderIds.concat([layerId]));
        selectedAnnotationShape = null;
        selectedImageLayerId = layerId;
        selectedTool = "select";
        lastMoveUndo = null;
        cropWasLastAction = false;
        committedCanvas.requestPaint();
        keyScope.forceActiveFocus();
    }
    function invalidateImageComposite() {
        imageCompositeRevision = imageCompositeRevision >= 2.14748e+09 ? 0 : imageCompositeRevision + 1;
    }
    function invalidateRedo() {
        if (redoHistory.length > 0)
            redoHistory = [];
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
    function normalizeCropRectForLayer(layer, startX, startY, endX, endY) {
        if (!layer)
            return Qt.rect(0, 0, 0, 0);
        var layerLeft = Math.min(layer.startX, layer.endX);
        var layerTop = Math.min(layer.startY, layer.endY);
        var layerRight = Math.max(layer.startX, layer.endX);
        var layerBottom = Math.max(layer.startY, layer.endY);
        var left = Math.max(layerLeft, Math.min(layerRight, Math.min(startX, endX)));
        var top = Math.max(layerTop, Math.min(layerBottom, Math.min(startY, endY)));
        var right = Math.max(layerLeft, Math.min(layerRight, Math.max(startX, endX)));
        var bottom = Math.max(layerTop, Math.min(layerBottom, Math.max(startY, endY)));
        return Qt.rect(left, top, Math.max(0, right - left), Math.max(0, bottom - top));
    }
    function normalizedImageLayerOrder(candidateIds) {
        var availableIds = currentImageLayerIds();
        var available = {};
        var orderedIds = [];
        var seen = {};
        for (var i = 0; i < availableIds.length; ++i)
            available[availableIds[i]] = true;

        var requestedIds = candidateIds || [];
        for (var requestedIndex = 0; requestedIndex < requestedIds.length; ++requestedIndex) {
            var requestedId = String(requestedIds[requestedIndex] || "");
            if (!available[requestedId] || seen[requestedId])
                continue;
            orderedIds.push(requestedId);
            seen[requestedId] = true;
        }
        for (var availableIndex = 0; availableIndex < availableIds.length; ++availableIndex) {
            var availableId = availableIds[availableIndex];
            if (!seen[availableId])
                orderedIds.push(availableId);
        }
        return orderedIds;
    }
    function normalizedRotation(angle) {
        var normalized = Number(angle || 0);
        while (normalized > 180)
            normalized -= 360;
        while (normalized <= -180)
            normalized += 360;
        return normalized;
    }
    function openImageLayerPicker() {
        if (inlineTextEditor.visible)
            commitText();

        if (imageInsertBusy || edgeStitchPreparing || renderExportBusy || reverseSearchPreparing || CaptureService.reverseImageSearchBusy || saving || sourceImage.status !== Image.Ready)
            return;

        cancelOcrSession();
        stopColorPicker();
        saveError = "";
        imagePickerSession = imageInsertSessionToken;
        imageLayerPicker.open();
    }
    function parseProcessResult(text, fallbackError) {
        var lines = String(text || "").trim().split("\n");
        for (var i = lines.length - 1; i >= 0; --i) {
            if (lines[i].trim() === "")
                continue;
            try {
                return JSON.parse(lines[i]);
            } catch (error) {}
        }
        return {
            "success": false,
            "error": fallbackError
        };
    }
    function pointInAnnotationLocalSpace(shape, x, y) {
        var angle = Number(shape && shape.rotation || 0);
        if (!shape || Math.abs(angle) <= 0.01)
            return {
                "x": x,
                "y": y
            };
        var bounds = rawShapeBounds(shape);
        var centerX = (bounds.minX + bounds.maxX) / 2;
        var centerY = (bounds.minY + bounds.maxY) / 2;
        var dx = x - centerX;
        var dy = y - centerY;
        var radians = -angle * Math.PI / 180;
        return {
            "x": dx * Math.cos(radians) - dy * Math.sin(radians) + centerX,
            "y": dx * Math.sin(radians) + dy * Math.cos(radians) + centerY
        };
    }
    function pointInShapeLocalSpace(shape, x, y) {
        var left = Math.min(shape.startX, shape.endX);
        var top = Math.min(shape.startY, shape.endY);
        var width = Math.max(1, Math.abs(shape.endX - shape.startX));
        var height = Math.max(1, Math.abs(shape.endY - shape.startY));
        var centerX = left + width / 2;
        var centerY = top + height / 2;
        var dx = x - centerX;
        var dy = y - centerY;
        var radians = -Number(shape.rotation || 0) * Math.PI / 180;
        return {
            "x": dx * Math.cos(radians) - dy * Math.sin(radians) + width / 2,
            "y": dx * Math.sin(radians) + dy * Math.cos(radians) + height / 2,
            "width": width,
            "height": height
        };
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
    function probeImageLayer(path, sessionToken) {
        if (!path || sessionToken !== imageInsertSessionToken || !CaptureService.screenshotEditorVisible)
            return;

        pendingImagePath = String(path);
        pendingImageSession = sessionToken;
        imageProbeProcess.command = ["magick", "identify", "-quiet", "-format", "%w %h", pendingImagePath + "[0]"];
        imageProbeProcess.running = true;
    }
    function pushRedoSnapshot() {
        var nextHistory = redoHistory.slice();
        nextHistory.push(editorSnapshot());
        if (nextHistory.length > 32)
            nextHistory.shift();
        redoHistory = nextHistory;
    }
    function rawShapeBounds(shape) {
        if (!shape)
            return {
                "minX": 0,
                "maxX": 0,
                "minY": 0,
                "maxY": 0
            };
        var minX = Math.min(shape.startX, shape.endX);
        var maxX = Math.max(shape.startX, shape.endX);
        var minY = Math.min(shape.startY, shape.endY);
        var maxY = Math.max(shape.startY, shape.endY);
        if (shape.tool === "callout") {
            minX = Math.min(minX, Number(shape.calloutX || 0));
            minY = Math.min(minY, Number(shape.calloutY || 0));
            maxX = Math.max(maxX, Number(shape.calloutX || 0) + Number(shape.calloutWidth || 0));
            maxY = Math.max(maxY, Number(shape.calloutY || 0) + Number(shape.calloutHeight || 0));
        }
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
    function recognizeRegion(region) {
        if (OcrService.busy || renderExportBusy || renderingOutput || region.width < 8 || region.height < 8)
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
            var outputPath = "/tmp/quickshell-ocr-" + Date.now() + ".png";
            var started = root.startRenderExport("ocr", region, targetWidth, targetHeight, outputPath, editorSession);
            if (!started && root.ocrPreparing) {
                root.ocrPreparing = false;
                root.ocrRect = Qt.rect(0, 0, 0, 0);
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
    function redo() {
        if (annotationTransformActive) {
            cancelAnnotationTransform();
            return;
        }
        if (!canRedo)
            return;
        var nextHistory = redoHistory.slice();
        var snapshot = nextHistory.pop();
        redoHistory = nextHistory;
        restoreEditorSnapshot(snapshot);
    }
    function removeImageLayer(layerId) {
        if (layerId === baseImageLayerId)
            return;
        var index = imageLayerIndexById(layerId);
        if (index < 0)
            return;

        var previousLayerOrder = effectiveImageLayerOrderIds.slice();
        var removedShape = copyShape(shapes[index]);
        invalidateRedo();
        var nextShapes = shapes.slice();
        nextShapes.splice(index, 1);
        shapes = nextShapes;
        imageLayerOrderIds = previousLayerOrder.filter(function (orderedLayerId) {
            return orderedLayerId !== layerId;
        });
        selectedAnnotationShape = null;
        selectedImageLayerId = baseImageLayer ? baseImageLayerId : "";
        selectedTool = "select";
        imageResizeLayerId = "";
        imageResizeOriginal = null;
        imageResizePreview = null;
        imageTransformMode = "";
        lastMoveUndo = {
            "index": index,
            "shape": removedShape,
            "removed": true,
            "imageLayerOrderIds": previousLayerOrder
        };
        cropWasLastAction = false;
        committedCanvas.requestPaint();
    }
    function renderExportIsCurrent(sessionToken, operation, operationSession) {
        if (sessionToken !== renderExportSessionToken || sessionToken !== renderExportRunningSession || operation !== renderExportOperation || !CaptureService.screenshotEditorVisible)
            return false;
        if (operation === "ocr")
            return operationSession === ocrSessionToken && ocrPreparing;
        if (operation === "reverse")
            return operationSession === reverseSearchSessionToken && reverseSearchPreparing;
        if (operation === "save")
            return saving;
        return false;
    }
    function renderExportRectForSize(region, imageWidth, imageHeight) {
        var surfaceWidth = Math.max(1, captureSurface.width);
        var surfaceHeight = Math.max(1, captureSurface.height);
        var sourceRect = region && region.width > 0 && region.height > 0 ? region : Qt.rect(0, 0, surfaceWidth, surfaceHeight);
        var left = Math.floor(Math.max(0, Math.min(surfaceWidth, sourceRect.x)) * imageWidth / surfaceWidth);
        var top = Math.floor(Math.max(0, Math.min(surfaceHeight, sourceRect.y)) * imageHeight / surfaceHeight);
        var right = Math.ceil(Math.max(0, Math.min(surfaceWidth, sourceRect.x + sourceRect.width)) * imageWidth / surfaceWidth);
        var bottom = Math.ceil(Math.max(0, Math.min(surfaceHeight, sourceRect.y + sourceRect.height)) * imageHeight / surfaceHeight);
        left = Math.max(0, Math.min(imageWidth - 1, left));
        top = Math.max(0, Math.min(imageHeight - 1, top));
        right = Math.max(left + 1, Math.min(imageWidth, right));
        bottom = Math.max(top + 1, Math.min(imageHeight, bottom));
        return Qt.rect(left, top, right - left, bottom - top);
    }
    function renderedImageLayerById(layerId) {
        var id = String(layerId || "");
        if (id === baseImageLayerId)
            return sourceImage;
        for (var i = 0; i < insertedImageRepeater.count; ++i) {
            var item = insertedImageRepeater.itemAt(i);
            if (item && item.layerId === id)
                return item;
        }
        return null;
    }
    function requestColorSample(x, y) {
        loupePointerX = x;
        loupePointerY = y;
        if (!colorPickerHeld)
            return;
        var target = colorPickerTargetAt(x, y);
        if (!target) {
            colorPickerSourceItem = null;
            colorPickerCommitPending = false;
            return;
        }
        colorPickerSourceItem = target.sourceItem;
        colorPickerSourceX = target.sourceX;
        colorPickerSourceY = target.sourceY;
        colorPickerPixelX = target.pixelX;
        colorPickerPixelY = target.pixelY;
        colorSampler.requestPaint();
    }
    function resetEditorDefaults() {
        cancelRenderExport();
        imageInsertSessionToken += 1;
        imagePickerSession = -1;
        reverseSearchSessionToken += 1;
        reverseSearchPreparing = false;
        cancelEdgeStitch();
        edgeStitchHistory = [];
        edgeStitchPendingSnapshot = null;
        selectedTool = Config.captureEditorTool || "pen";
        selectedColor = Config.captureEditorColor || "#ff3b30";
        selectedWidth = Math.max(1, Number(Config.captureEditorWidth) || 6);
        selectedOpacity = 1;
        stopColorPicker();
        loupeZoom = 2.5;
        logicalSurfaceHeight = 1;
        logicalSurfaceReady = false;
        logicalSurfaceWidth = 1;
        baseImageLayer = createBaseImageLayer(CaptureService.screenshotPath, 0, 0);
        baseImageFitPending = true;
        clearAll();
    }
    function resizeSelectedAnnotation(pointerX, pointerY) {
        if (annotationTransformMode !== "resize" || !annotationTransformOriginal || annotationResizeHorizontalSign === 0 || annotationResizeVerticalSign === 0)
            return;

        var originalFrame = selectionRectForShape(annotationTransformOriginal);
        var width = Math.max(1, originalFrame.width);
        var height = Math.max(1, originalFrame.height);
        var centerX = originalFrame.x + width / 2;
        var centerY = originalFrame.y + height / 2;
        var angle = Number(annotationTransformOriginal.rotation || 0) * Math.PI / 180;
        var pointerDx = Number(pointerX || 0) - annotationResizeStartPointerX;
        var pointerDy = Number(pointerY || 0) - annotationResizeStartPointerY;
        var localDx = pointerDx * Math.cos(angle) + pointerDy * Math.sin(angle);
        var localDy = -pointerDx * Math.sin(angle) + pointerDy * Math.cos(angle);
        var fromCenter = annotationResizeFromCenter;
        var horizontalSpan = annotationResizeHorizontalSign * width * (fromCenter ? 0.5 : 1);
        var verticalSpan = annotationResizeVerticalSign * height * (fromCenter ? 0.5 : 1);
        var diagonalSquared = horizontalSpan * horizontalSpan + verticalSpan * verticalSpan;
        var scale = 1 + (localDx * horizontalSpan + localDy * verticalSpan) / Math.max(1, diagonalSquared);
        scale = Math.max(0.1, Math.min(8, scale));

        var nextCenterX = centerX;
        var nextCenterY = centerY;
        if (!fromCenter) {
            var fixedLocalX = -annotationResizeHorizontalSign * width / 2;
            var fixedLocalY = -annotationResizeVerticalSign * height / 2;
            var fixedWorldX = centerX + fixedLocalX * Math.cos(angle) - fixedLocalY * Math.sin(angle);
            var fixedWorldY = centerY + fixedLocalX * Math.sin(angle) + fixedLocalY * Math.cos(angle);
            var centeredPreview = scaledAnnotationShape(annotationTransformOriginal, scale, centerX, centerY);
            var previewFrame = selectionRectForShape(centeredPreview);
            var nextHalfX = annotationResizeHorizontalSign * previewFrame.width / 2;
            var nextHalfY = annotationResizeVerticalSign * previewFrame.height / 2;
            nextCenterX = fixedWorldX + nextHalfX * Math.cos(angle) - nextHalfY * Math.sin(angle);
            nextCenterY = fixedWorldY + nextHalfX * Math.sin(angle) + nextHalfY * Math.cos(angle);
        }

        annotationTransformChanged = Math.abs(scale - 1) > 0.001;
        updateAnnotationTransformPreview(scaledAnnotationShape(annotationTransformOriginal, scale, nextCenterX, nextCenterY));
    }
    function restoreEditorSnapshot(snapshot) {
        if (!snapshot)
            return;
        var restoredScreenshotPath = String(snapshot.screenshotPath || "");
        var sourcePathChanged = restoredScreenshotPath !== String(CaptureService.screenshotPath || "");
        annotationTransformChanged = false;
        annotationTransformIndex = -1;
        annotationTransformMode = "";
        annotationTransformOriginal = null;
        annotationResizeHorizontalSign = 0;
        annotationResizeFromCenter = false;
        annotationResizeVerticalSign = 0;
        annotationResizeStartPointerX = 0;
        annotationResizeStartPointerY = 0;
        selectedAnnotationShape = null;
        currentShape = null;
        stopSelectionPreview();
        selectionStartX = 0;
        selectionStartY = 0;
        selectionPointerX = 0;
        selectionPointerY = 0;
        movingShapeDetached = false;
        movingShapeIndex = -1;
        movingShapeOriginal = null;
        imageResizeLayerId = "";
        imageResizeOriginal = null;
        imageResizePreview = null;
        imageTransformMode = "";
        cropDragging = false;
        cropDraftRect = Qt.rect(0, 0, 0, 0);
        cropTargetLayerId = "";
        cropTargetOriginal = null;
        ocrDragging = false;
        ocrDraftRect = Qt.rect(0, 0, 0, 0);
        inlineTextEditor.visible = false;
        inlineTextEditor.text = "";
        if (sourcePathChanged)
            CaptureService.screenshotPath = restoredScreenshotPath;

        var restoredBaseLayer = snapshot.baseImageLayer ? copyShape(snapshot.baseImageLayer) : createBaseImageLayer(restoredScreenshotPath, 0, 0);
        restoreLogicalSurfaceSize(snapshot, restoredBaseLayer);
        baseImageLayer = restoredBaseLayer;
        baseImageFitPending = !logicalSurfaceReady;
        var restoredShapes = [];
        var sourceShapes = snapshot.shapes || [];
        for (var i = 0; i < sourceShapes.length; ++i)
            restoredShapes.push(copyShape(sourceShapes[i]));
        shapes = restoredShapes;
        imageLayerOrderIds = normalizedImageLayerOrder(snapshot.imageLayerOrderIds || []);
        cropRect = copyRect(snapshot.cropRect);
        cropWasLastAction = Boolean(snapshot.cropWasLastAction);
        nextImageLayerId = Number(snapshot.nextImageLayerId || 1);
        nextMarkerNumber = Number(snapshot.nextMarkerNumber || 1);
        selectedImageLayerId = String(snapshot.selectedImageLayerId || baseImageLayerId);
        selectedTool = String(snapshot.selectedTool || "pen");
        lastMoveUndo = copyUndoEntry(snapshot.lastMoveUndo);
        var restoredEdgeHistory = [];
        var sourceHistory = snapshot.edgeStitchHistory || [];
        for (var historyIndex = 0; historyIndex < sourceHistory.length; ++historyIndex)
            restoredEdgeHistory.push(copyEdgeSnapshot(sourceHistory[historyIndex]));
        edgeStitchHistory = restoredEdgeHistory;
        loupeHeld = false;
        prepareLiveCanvas();
        committedCanvas.requestPaint();
        scheduleLivePaint();
        if (sourcePathChanged || sourceImage.imageStatus === Image.Error || sourceImage.imageStatus === Image.Null)
            retrySourceImage();
        keyScope.forceActiveFocus();
    }
    function restoreLogicalSurfaceSize(snapshot, fallbackLayer) {
        var restoredWidth = Number(snapshot && snapshot.logicalSurfaceWidth || 0);
        var restoredHeight = Number(snapshot && snapshot.logicalSurfaceHeight || 0);
        if ((restoredWidth <= 1 || restoredHeight <= 1) && fallbackLayer) {
            restoredWidth = Math.abs(Number(fallbackLayer.endX || 0) - Number(fallbackLayer.startX || 0));
            restoredHeight = Math.abs(Number(fallbackLayer.endY || 0) - Number(fallbackLayer.startY || 0));
        }
        if (restoredWidth <= 1 || restoredHeight <= 1) {
            logicalSurfaceReady = false;
            return false;
        }
        logicalSurfaceWidth = restoredWidth;
        logicalSurfaceHeight = restoredHeight;
        logicalSurfaceReady = true;
        return true;
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
    function reverseImageSearch() {
        if (inlineTextEditor.visible)
            commitText();

        if (imageInsertBusy || edgeStitchPreparing || renderExportBusy || reverseSearchPreparing || CaptureService.reverseImageSearchBusy || saving || sourceImage.status !== Image.Ready)
            return;

        cancelOcrSession();
        reverseSearchPreparing = true;
        saveError = "";
        CaptureService.clearReverseImageSearchStatus();
        committedCanvas.requestPaint();
        liveCanvas.requestPaint();
        var searchSession = ++reverseSearchSessionToken;
        Qt.callLater(function () {
            if (searchSession !== root.reverseSearchSessionToken || !CaptureService.screenshotEditorVisible) {
                root.reverseSearchPreparing = false;
                return;
            }

            var scaleX = sourceImage.sourceSize.width / Math.max(1, captureSurface.width);
            var scaleY = sourceImage.sourceSize.height / Math.max(1, captureSurface.height);
            var targetWidth = root.cropActive ? Math.max(1, Math.round(root.cropRect.width * scaleX)) : Math.max(1, sourceImage.sourceSize.width);
            var targetHeight = root.cropActive ? Math.max(1, Math.round(root.cropRect.height * scaleY)) : Math.max(1, sourceImage.sourceSize.height);
            var outputPath = "/tmp/quickshell-reverse-image-" + Date.now() + ".png";
            var exportRegion = root.cropActive ? root.cropRect : null;
            var started = root.startRenderExport("reverse", exportRegion, targetWidth, targetHeight, outputPath, searchSession);
            if (!started && root.reverseSearchPreparing) {
                root.reverseSearchPreparing = false;
                root.saveError = qsTr("Could not render the image search");
            }
        });
    }
    function rotateSelectedAnnotation(angle) {
        if (annotationTransformMode !== "rotation" || !annotationTransformOriginal)
            return;
        var preview = copyShape(annotationTransformOriginal);
        preview.rotation = normalizedRotation(angle);
        annotationTransformChanged = Math.abs(normalizedRotation(preview.rotation - Number(annotationTransformOriginal.rotation || 0))) > 0.01;
        updateAnnotationTransformPreview(preview);
    }
    function saveEditedImage() {
        if (inlineTextEditor.visible)
            commitText();

        if (imageInsertBusy || edgeStitchPreparing || renderExportBusy || reverseSearchPreparing || saving || sourceImage.status !== Image.Ready)
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
            var targetWidth = root.cropActive ? Math.max(1, Math.round(root.cropRect.width * scaleX)) : Math.max(1, sourceImage.sourceSize.width);
            var targetHeight = root.cropActive ? Math.max(1, Math.round(root.cropRect.height * scaleY)) : Math.max(1, sourceImage.sourceSize.height);
            var exportRegion = root.cropActive ? root.cropRect : null;
            var started = root.startRenderExport("save", exportRegion, targetWidth, targetHeight, outputPath, -1);
            if (!started && root.saving) {
                root.saving = false;
                root.saveError = qsTr("Could not render the edited screenshot");
            }
        });
    }
    function scaledAnnotationShape(shape, scaleFactor, targetCenterX, targetCenterY) {
        function scaledX(value) {
            return nextCenterX + (Number(value || 0) - centerX) * scale;
        }
        function scaledY(value) {
            return nextCenterY + (Number(value || 0) - centerY) * scale;
        }

        var result = copyShape(shape);
        var bounds = rawShapeBounds(shape);
        var centerX = (bounds.minX + bounds.maxX) / 2;
        var centerY = (bounds.minY + bounds.maxY) / 2;
        var nextCenterX = targetCenterX === undefined ? centerX : Number(targetCenterX);
        var nextCenterY = targetCenterY === undefined ? centerY : Number(targetCenterY);
        var scale = Math.max(0.1, Math.min(8, Number(scaleFactor || 1)));
        result.startX = scaledX(shape.startX);
        result.startY = scaledY(shape.startY);
        result.endX = scaledX(shape.endX);
        result.endY = scaledY(shape.endY);
        for (var i = 0; i < result.points.length; ++i) {
            result.points[i].x = scaledX(shape.points[i].x);
            result.points[i].y = scaledY(shape.points[i].y);
        }
        if (shape.tool === "callout") {
            result.calloutX = scaledX(shape.calloutX);
            result.calloutY = scaledY(shape.calloutY);
            result.calloutWidth = Math.max(8, Number(shape.calloutWidth || 0) * scale);
            result.calloutHeight = Math.max(8, Number(shape.calloutHeight || 0) * scale);
        }
        if (shape.width !== undefined)
            result.width = Math.max(1, Math.min(128, Number(shape.width || 1) * scale));
        if (Number(shape.fontSize || 0) > 0)
            result.fontSize = Math.max(8, Math.min(512, Number(shape.fontSize) * scale));
        if (Number(shape.markerSize || 0) > 0)
            result.markerSize = Math.max(12, Math.min(512, Number(shape.markerSize) * scale));
        return result;
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
            var incrementalPen = root.currentShape && root.currentShape.tool === "pen" && root.currentShape.__dragStartX === undefined && !root.currentShape.__annotationTransform && root.shapeOpacity(root.currentShape) >= 0.999;
            if (liveCanvas.clearBeforePaint || !incrementalPen || pendingDirtyRect.width <= 0 || pendingDirtyRect.height <= 0)
                liveCanvas.requestPaint();
            else
                liveCanvas.markDirty(pendingDirtyRect);
        });
    }
    function scheduleSelectionPreview(x, y) {
        selectionPointerX = x;
        selectionPointerY = y;
        if (selectionPreviewFrameId >= 0)
            return;

        selectionPreviewFrameId = liveCanvas.requestAnimationFrame(function () {
            root.selectionPreviewFrameId = -1;
            root.applySelectionPreview();
        });
    }
    function selectImageLayer(layerId) {
        if (!imageLayerById(layerId))
            return;
        selectedAnnotationShape = null;
        selectedImageLayerId = layerId;
        if (selectedTool !== "crop")
            selectedTool = "select";
        currentShape = null;
        liveCanvasTranslate.x = 0;
        liveCanvasTranslate.y = 0;
        prepareLiveCanvas();
        scheduleLivePaint();
        keyScope.forceActiveFocus();
    }
    function selectionRectForShape(shape) {
        if (!shape || shape.tool === "image")
            return Qt.rect(0, 0, 0, 0);

        var bounds = rawShapeBounds(shape);
        var strokeWidth = Math.max(1, Number(shape.width) || 1);
        var padding = Math.max(5, strokeWidth / 2 + 3);
        if (shape.tool === "highlight")
            padding = Math.max(padding, strokeWidth * 1.5 + 3);
        else if (shape.tool === "arrow")
            padding = Math.max(padding, 12 + strokeWidth * 1.4);
        else if (shape.tool === "blur" || shape.tool === "pixelate" || shape.tool === "number" || shape.tool === "text")
            padding = 4;

        var centerX = (bounds.minX + bounds.maxX) / 2;
        var centerY = (bounds.minY + bounds.maxY) / 2;
        var frameWidth = Math.max(14, bounds.maxX - bounds.minX + padding * 2);
        var frameHeight = Math.max(14, bounds.maxY - bounds.minY + padding * 2);
        return Qt.rect(centerX - frameWidth / 2, centerY - frameHeight / 2, frameWidth, frameHeight);
    }
    function setImageLayerOrder(layerIds) {
        if (!layerIds || layerIds.length === 0)
            return;

        var currentOrder = effectiveImageLayerOrderIds.slice();
        var nextOrder = normalizedImageLayerOrder(layerIds);
        if (currentOrder.length < 2 || nextOrder.length !== currentOrder.length)
            return;

        var changed = false;
        for (var compareIndex = 0; compareIndex < currentOrder.length; ++compareIndex) {
            if (currentOrder[compareIndex] !== nextOrder[compareIndex]) {
                changed = true;
                break;
            }
        }
        if (!changed)
            return;

        invalidateRedo();
        imageLayerOrderIds = nextOrder;
        lastMoveUndo = {
            "kind": "layer-order",
            "imageLayerOrderIds": currentOrder
        };
        selectedTool = "select";
        committedCanvas.requestPaint();
    }
    function setImageLayerShape(layerId, shape) {
        if (!layerId || !shape)
            return false;
        if (layerId === baseImageLayerId) {
            baseImageLayer = copyShape(shape);
            return true;
        }

        var index = imageLayerIndexById(layerId);
        if (index < 0)
            return false;
        var nextShapes = shapes.slice();
        nextShapes[index] = copyShape(shape);
        shapes = nextShapes;
        return true;
    }
    function setImageLayerVisibility(layerId, visible) {
        var layer = imageLayerById(layerId);
        if (!layer)
            return;

        if (imageResizeLayerId === layerId && imageTransformMode !== "")
            finishImageTransform(layerId, imageTransformMode);
        if (currentShape && currentShape.layerId === layerId && currentShape.__dragStartX !== undefined)
            cancelShapeMove();

        layer = imageLayerById(layerId);
        var nextVisible = Boolean(visible);
        var currentlyVisible = !Boolean(layer.hidden);
        if (currentlyVisible === nextVisible)
            return;

        var previousLayer = copyShape(layer);
        var updatedLayer = copyShape(layer);
        updatedLayer.hidden = !nextVisible;
        if (!setImageLayerShape(layerId, updatedLayer))
            return;

        invalidateRedo();
        lastMoveUndo = {
            "kind": "image-state",
            "layerId": layerId,
            "shape": previousLayer
        };
        cropWasLastAction = false;
        committedCanvas.requestPaint();
        if (colorPickerHeld && loupePointerInside)
            requestColorSample(editorPointer.mouseX, editorPointer.mouseY);
        keyScope.forceActiveFocus();
    }
    function shapeBounds(shape) {
        var bounds = rawShapeBounds(shape);
        var angle = Number(shape && shape.rotation || 0);
        if (Math.abs(angle) <= 0.01)
            return bounds;

        var width = Math.max(1, bounds.maxX - bounds.minX);
        var height = Math.max(1, bounds.maxY - bounds.minY);
        var centerX = (bounds.minX + bounds.maxX) / 2;
        var centerY = (bounds.minY + bounds.maxY) / 2;
        var radians = angle * Math.PI / 180;
        var halfWidth = Math.abs(Math.cos(radians)) * width / 2 + Math.abs(Math.sin(radians)) * height / 2;
        var halfHeight = Math.abs(Math.sin(radians)) * width / 2 + Math.abs(Math.cos(radians)) * height / 2;
        return {
            "minX": centerX - halfWidth,
            "maxX": centerX + halfWidth,
            "minY": centerY - halfHeight,
            "maxY": centerY + halfHeight
        };
    }
    function shapeOpacity(shape) {
        return Math.max(0.1, Math.min(1, Number(shape && shape.opacity !== undefined ? shape.opacity : 1)));
    }
    function showOcrNotice(success, text) {
        var detail = String(text || "").replace(/\s+/g, " ").trim();
        if (detail.length > 240)
            detail = detail.substring(0, 239) + "…";
        if (detail === "")
            detail = success ? qsTr("Text copied to the clipboard") : qsTr("Could not recognize text");

        ocrNoticeError = !success;
        ocrNoticeText = detail;
        ocrNoticeVisible = true;
        ocrNoticeTimer.restart();
    }
    function startColorPicker() {
        if (colorPickerHeld || colorPickerCommitPending || imageInsertBusy || edgeStitchPreparing || renderingOutput)
            return;
        colorPickerColor = selectedColor;
        colorPickerCommitPending = false;
        colorPickerHeld = true;
        if (loupePointerInside)
            requestColorSample(editorPointer.mouseX, editorPointer.mouseY);
    }
    function startEdgeStitch(shape, edge) {
        if (!shape || shape.tool !== "image" || shape.isBase || !shape.source || !shape.layerId || edgeStitchPreparing || edge === "")
            return;

        cancelOcrSession();
        edgeStitchDropEdge = "";
        edgeStitchImagePath = String(shape.source);
        edgeStitchLayerId = String(shape.layerId);
        edgeStitchPreparing = true;
        saveError = "";
        edgeStitchPendingSnapshot = {
            "screenshotPath": String(CaptureService.screenshotPath || ""),
            "baseImageLayer": baseImageLayer ? copyShape(baseImageLayer) : null,
            "shapes": shapes.map(copyShape),
            "imageLayerOrderIds": effectiveImageLayerOrderIds.slice(),
            "cropRect": Qt.rect(cropRect.x, cropRect.y, cropRect.width, cropRect.height),
            "cropWasLastAction": cropWasLastAction,
            "nextImageLayerId": nextImageLayerId,
            "nextMarkerNumber": nextMarkerNumber,
            "logicalSurfaceWidth": logicalSurfaceWidth,
            "logicalSurfaceHeight": logicalSurfaceHeight,
            "selectedImageLayerId": String(shape.layerId)
        };
        liveCanvasTranslate.x = 0;
        liveCanvasTranslate.y = 0;
        currentShape = null;
        movingShapeIndex = -1;
        movingShapeOriginal = null;
        prepareLiveCanvas();
        committedCanvas.requestPaint();
        liveCanvas.requestPaint();

        var stitchSession = ++edgeStitchSessionToken;
        Qt.callLater(function () {
            if (stitchSession !== root.edgeStitchSessionToken || !CaptureService.screenshotEditorVisible)
                return;

            var scaleX = sourceImage.sourceSize.width / Math.max(1, captureSurface.width);
            var scaleY = sourceImage.sourceSize.height / Math.max(1, captureSurface.height);
            var exportItem = root.cropActive ? cropExportSurface : captureSurface;
            var targetWidth = root.cropActive ? Math.max(1, Math.round(root.cropRect.width * scaleX)) : Math.max(1, sourceImage.sourceSize.width);
            var targetHeight = root.cropActive ? Math.max(1, Math.round(root.cropRect.height * scaleY)) : Math.max(1, sourceImage.sourceSize.height);
            var sourcePath = "/tmp/quickshell-edge-stitch-source-" + Date.now() + ".png";
            root.edgeStitchSourcePath = sourcePath;
            var started = exportItem.grabToImage(function (result) {
                var saved = result.saveToFile(sourcePath);
                if (stitchSession !== root.edgeStitchSessionToken || !CaptureService.screenshotEditorVisible) {
                    if (saved)
                        Quickshell.execDetached(["rm", "-f", "--", sourcePath]);
                    return;
                }
                if (!saved) {
                    root.edgeStitchPendingSnapshot = null;
                    root.failEdgeStitch(qsTr("Could not prepare the image stitch"));
                    return;
                }

                var orientation = edge === "left" || edge === "right" ? "horizontal" : "vertical";
                var imageFirst = edge === "left" || edge === "top";
                var paths = imageFirst ? [root.edgeStitchImagePath, sourcePath] : [sourcePath, root.edgeStitchImagePath];
                root.edgeStitchProcessSession = stitchSession;
                edgeStitchProcess.command = ["python3", "-u", Config.quickshellDir + "/backend/python/capture/screenshot_stitcher.py", "merge", "--orientation", orientation, "--output", CaptureService.stitchedScreenshotPath()].concat(paths);
                edgeStitchProcess.running = true;
            }, Qt.size(targetWidth, targetHeight));
            if (!started) {
                root.edgeStitchPendingSnapshot = null;
                root.failEdgeStitch(qsTr("Could not render the image stitch"));
            }
        });
    }
    function startRenderExport(operation, region, targetWidth, targetHeight, outputPath, operationSession) {
        if (renderExportBusy || operation === "" || outputPath === "" || captureSurface.width < 1 || captureSurface.height < 1)
            return false;

        var sessionToken = ++renderExportSessionToken;
        renderExportOperation = operation;
        renderExportOperationSession = operationSession;
        renderExportOutputPath = outputPath;
        renderExportOutputTemporary = operation !== "save";
        renderExportRunningSession = sessionToken;
        renderExportTargetWidth = Math.max(1, Math.round(targetWidth));
        renderExportTargetHeight = Math.max(1, Math.round(targetHeight));

        if (canUseOriginalForRenderExport()) {
            var sourceWidth = Math.max(1, Math.round(Number(baseImageLayer.naturalWidth) || sourceImage.sourceSize.width));
            var sourceHeight = Math.max(1, Math.round(Number(baseImageLayer.naturalHeight) || sourceImage.sourceSize.height));
            renderExportInputPath = String(CaptureService.screenshotPath);
            renderExportInputTemporary = false;
            renderExportCropRect = renderExportRectForSize(region, sourceWidth, sourceHeight);
            return startRenderExportProcess(sessionToken);
        }

        var maximumDimension = 2048;
        var captureScale = Math.min(1, maximumDimension / Math.max(captureSurface.width, captureSurface.height));
        var captureWidth = Math.max(1, Math.round(captureSurface.width * captureScale));
        var captureHeight = Math.max(1, Math.round(captureSurface.height * captureScale));
        var inputPath = "/tmp/quickshell-editor-export-" + Date.now() + "-" + sessionToken + ".bmp";
        renderExportInputPath = inputPath;
        renderExportInputTemporary = true;
        renderExportCropRect = renderExportRectForSize(region, captureWidth, captureHeight);
        renderExportCapturePending = true;
        var started = captureSurface.grabToImage(function (result) {
            if (!root.renderExportIsCurrent(sessionToken, operation, operationSession))
                return;

            var saved = result.saveToFile(inputPath);
            root.renderExportCapturePending = false;
            if (!root.renderExportIsCurrent(sessionToken, operation, operationSession)) {
                if (saved)
                    Quickshell.execDetached(["rm", "-f", "--", inputPath]);
                return;
            }
            if (!saved || !root.startRenderExportProcess(sessionToken)) {
                var failedOperation = root.renderExportOperation;
                root.clearRenderExportState(true);
                root.failRenderExport(failedOperation, qsTr("Could not render the screenshot"));
            }
        }, Qt.size(captureWidth, captureHeight));
        if (!started) {
            var failedOperation = renderExportOperation;
            clearRenderExportState(true);
            failRenderExport(failedOperation, qsTr("Could not render the screenshot"));
            return false;
        }
        return true;
    }
    function startRenderExportProcess(sessionToken) {
        if (sessionToken !== renderExportSessionToken || sessionToken !== renderExportRunningSession || renderExportInputPath === "" || renderExportOutputPath === "")
            return false;

        var crop = renderExportCropRect;
        var cropGeometry = Math.max(1, Math.round(crop.width)) + "x" + Math.max(1, Math.round(crop.height)) + "+" + Math.max(0, Math.round(crop.x)) + "+" + Math.max(0, Math.round(crop.y));
        var command = ["nice", "-n", "10", "magick", "-limit", "thread", "2", "-limit", "memory", "256MiB", "-limit", "map", "512MiB", renderExportInputPath + "[0]", "-crop", cropGeometry, "+repage"];
        if (renderExportTargetWidth !== Math.round(crop.width) || renderExportTargetHeight !== Math.round(crop.height))
            command = command.concat(["-filter", "Lanczos", "-resize", renderExportTargetWidth + "x" + renderExportTargetHeight + "!"]);

        var format = renderExportOperation === "save" ? String(Config.captureScreenshotFormat || "png").toLowerCase() : "png";
        if (format === "jpeg")
            command = command.concat(["-strip", "-quality", String(Math.max(1, Math.min(100, Number(Config.captureScreenshotQuality) || 90))), renderExportOutputPath]);
        else if (format === "webp")
            command = command.concat(["-strip", "-quality", String(Math.max(1, Math.min(100, Number(Config.captureScreenshotQuality) || 90))), "-define", "webp:method=4", renderExportOutputPath]);
        else
            command = command.concat(["-define", "png:compression-level=3", renderExportOutputPath]);
        renderExportProcess.command = command;
        renderExportProcess.running = true;
        return true;
    }
    function stopColorPicker() {
        colorPickerHeld = false;
        if (!colorPickerCommitPending || colorPickerSourceItem === null) {
            colorPickerCommitPending = false;
            colorPickerSourceItem = null;
        }
        colorSampler.requestPaint();
    }
    function stopSelectionPreview() {
        if (selectionPreviewFrameId < 0)
            return;

        liveCanvas.cancelRequestAnimationFrame(selectionPreviewFrameId);
        selectionPreviewFrameId = -1;
    }
    function syncInsertedImageRenderIds() {
        var availableIds = [];
        var available = {};
        for (var i = 0; i < shapes.length; ++i) {
            if (shapes[i].tool !== "image" || !shapes[i].layerId)
                continue;
            var layerId = String(shapes[i].layerId);
            availableIds.push(layerId);
            available[layerId] = true;
        }

        var nextIds = [];
        var included = {};
        for (var currentIndex = 0; currentIndex < insertedImageRenderIds.length; ++currentIndex) {
            var currentId = String(insertedImageRenderIds[currentIndex]);
            if (!available[currentId] || included[currentId])
                continue;
            nextIds.push(currentId);
            included[currentId] = true;
        }
        for (var availableIndex = 0; availableIndex < availableIds.length; ++availableIndex) {
            var availableId = availableIds[availableIndex];
            if (!included[availableId])
                nextIds.push(availableId);
        }

        if (nextIds.length !== insertedImageRenderIds.length) {
            insertedImageRenderIds = nextIds;
            return;
        }
        for (var compareIndex = 0; compareIndex < nextIds.length; ++compareIndex) {
            if (nextIds[compareIndex] !== insertedImageRenderIds[compareIndex]) {
                insertedImageRenderIds = nextIds;
                return;
            }
        }
    }
    function textFontSize() {
        return Math.round(selectedWidth * 3);
    }
    function toolSupportsOpacity(tool) {
        return ["pen", "highlight", "line", "arrow", "rectangle", "ellipse", "text", "number", "blur", "pixelate", "callout"].indexOf(String(tool || "")) >= 0;
    }
    function topImageLayerAt(x, y) {
        for (var i = effectiveImageLayerOrderIds.length - 1; i >= 0; --i) {
            var layer = imageLayerById(effectiveImageLayerOrderIds[i]);
            if (layer && hitTestShape(layer, x, y))
                return layer;
        }
        return null;
    }
    function undo() {
        if (annotationTransformActive) {
            cancelAnnotationTransform();
            return;
        }
        if (!canUndo)
            return;
        pushRedoSnapshot();
        selectedAnnotationShape = null;

        if (shapes.length === 0 && !cropActive && !lastMoveUndo && edgeStitchHistory.length > 0) {
            var historyList = edgeStitchHistory.slice();
            var snapshot = historyList.pop();
            edgeStitchHistory = historyList;
            if (snapshot) {
                CaptureService.screenshotPath = snapshot.screenshotPath;
                var restoredBaseLayer = snapshot.baseImageLayer ? copyShape(snapshot.baseImageLayer) : createBaseImageLayer(snapshot.screenshotPath, 0, 0);
                restoreLogicalSurfaceSize(snapshot, restoredBaseLayer);
                baseImageLayer = restoredBaseLayer;
                baseImageFitPending = !logicalSurfaceReady;
                shapes = snapshot.shapes.map(copyShape);
                imageLayerOrderIds = normalizedImageLayerOrder(snapshot.imageLayerOrderIds || []);
                cropRect = snapshot.cropRect;
                cropWasLastAction = snapshot.cropWasLastAction;
                nextImageLayerId = snapshot.nextImageLayerId;
                nextMarkerNumber = snapshot.nextMarkerNumber;
                selectedImageLayerId = snapshot.selectedImageLayerId || baseImageLayerId;
                selectedTool = "select";
                lastMoveUndo = null;
                committedCanvas.requestPaint();
                retrySourceImage();
                return;
            }
        }
        if (cropActive && cropWasLastAction) {
            cropRect = Qt.rect(0, 0, 0, 0);
            cropWasLastAction = false;
            return;
        }
        if (lastMoveUndo) {
            if (lastMoveUndo.kind === "image-state") {
                setImageLayerShape(lastMoveUndo.layerId, lastMoveUndo.shape);
                selectedImageLayerId = lastMoveUndo.layerId;
                selectedTool = "select";
                lastMoveUndo = null;
                cropWasLastAction = false;
                committedCanvas.requestPaint();
                return;
            }
            if (lastMoveUndo.kind === "layer-order") {
                imageLayerOrderIds = normalizedImageLayerOrder(lastMoveUndo.imageLayerOrderIds || []);
                lastMoveUndo = null;
                committedCanvas.requestPaint();
                return;
            }
            var restoredShapes = shapes.slice();
            var restoreIndex;
            if (lastMoveUndo.removed) {
                restoreIndex = Math.max(0, Math.min(lastMoveUndo.index, restoredShapes.length));
                restoredShapes.splice(restoreIndex, 0, copyShape(lastMoveUndo.shape));
                if (lastMoveUndo.shape.tool === "image")
                    selectedImageLayerId = lastMoveUndo.shape.layerId;
            } else {
                restoreIndex = Math.max(0, Math.min(lastMoveUndo.index, Math.max(0, restoredShapes.length - 1)));
                if (restoredShapes.length > 0)
                    restoredShapes.splice(restoreIndex, 1, copyShape(lastMoveUndo.shape));
                else
                    restoredShapes.push(copyShape(lastMoveUndo.shape));
            }
            shapes = restoredShapes;
            if (lastMoveUndo.imageLayerOrderIds)
                imageLayerOrderIds = normalizedImageLayerOrder(lastMoveUndo.imageLayerOrderIds);
            lastMoveUndo = null;
            cropWasLastAction = false;
            recomputeMarkerNumber();
            committedCanvas.requestPaint();
            return;
        }
        if (shapes.length === 0)
            return;

        var nextShapes = shapes.slice();
        var removedShape = nextShapes.pop();
        var nextLayerOrder = effectiveImageLayerOrderIds.filter(function (orderedLayerId) {
            return !removedShape || removedShape.tool !== "image" || orderedLayerId !== removedShape.layerId;
        });
        shapes = nextShapes;
        if (removedShape && removedShape.tool === "image") {
            imageLayerOrderIds = nextLayerOrder;
            if (removedShape.layerId === selectedImageLayerId)
                selectedImageLayerId = "";
        }
        cropWasLastAction = false;
        recomputeMarkerNumber();
        committedCanvas.requestPaint();
    }
    function updateAnnotationTransformPreview(preview) {
        if (!preview || !annotationTransformActive)
            return;
        var waitingForLiveHandoff = currentShape && currentShape.__waitingForLiveHandoff;
        var waitingForCommit = currentShape && currentShape.__waitingForCommit;
        preview.__annotationTransform = true;
        if (waitingForLiveHandoff)
            preview.__waitingForLiveHandoff = true;
        if (waitingForCommit)
            preview.__waitingForCommit = true;
        currentShape = preview;
        scheduleLivePaint();
    }
    function updateImageCrop(layerId, localX, localY, width, height) {
        if (imageResizeLayerId !== layerId || imageTransformMode !== "crop" || !imageResizeOriginal)
            return;

        var croppedShape = imageShapeForLocalCrop(imageResizeOriginal, localX, localY, width, height);
        if (croppedShape)
            imageResizePreview = croppedShape;
    }
    function updateImageResize(layerId, x, y, width, height) {
        if (imageResizeLayerId !== layerId || imageTransformMode !== "resize" || !imageResizeOriginal || !imageResizePreview)
            return;

        var resizedShape = copyShape(imageResizePreview);
        resizedShape.startX = x;
        resizedShape.startY = y;
        resizedShape.endX = x + width;
        resizedShape.endY = y + height;
        imageResizePreview = resizedShape;
    }
    function updateImageRotation(layerId, angle) {
        if (imageResizeLayerId !== layerId || imageTransformMode !== "rotation" || !imageResizeOriginal || !imageResizePreview)
            return;

        var rotatedShape = copyShape(imageResizePreview);
        rotatedShape.rotation = angle;
        imageResizePreview = rotatedShape;
    }
    function updateOpacity(opacityValue) {
        var nextOpacity = Math.max(0.1, Math.min(1, Number(opacityValue) || 1));
        if (selectedTool === "select" && selectedAnnotationShape) {
            if (annotationTransformMode !== "opacity")
                beginOpacityChange();
            if (annotationTransformMode !== "opacity" || !annotationTransformOriginal)
                return;
            var annotationPreview = copyShape(annotationTransformOriginal);
            annotationPreview.opacity = nextOpacity;
            annotationTransformChanged = Math.abs(nextOpacity - shapeOpacity(annotationTransformOriginal)) > 0.001;
            updateAnnotationTransformPreview(annotationPreview);
            return;
        }
        if (selectedTool === "select" && selectedImageLayer) {
            if (imageTransformMode !== "opacity")
                beginOpacityChange();
            if (imageTransformMode !== "opacity" || !imageResizePreview)
                return;
            var preview = copyShape(imageResizePreview);
            preview.opacity = nextOpacity;
            imageResizePreview = preview;
            return;
        }
        if (toolSupportsOpacity(selectedTool))
            selectedOpacity = nextOpacity;
    }

    color: editorPresented ? Config.alpha(Config.md3.background, 0.95) : "transparent"
    implicitHeight: screen ? Math.max(1, screen.height - Config.barHeight) : 820
    implicitWidth: screen ? Math.max(1, screen.width) : 1180
    minimumSize: Qt.size(screen ? Math.min(560, screen.width) : 560, screen ? Math.min(520, screen.height) : 520)
    title: qsTr("SownteeShell Screenshot Editor")
    visible: true

    Component.onCompleted: {
        resetEditorDefaults();
    }
    Component.onDestruction: {
        cancelRenderExport();
        imageInsertSessionToken += 1;
        cancelOcrSession();
        cancelEdgeStitch();
    }
    onBaseImageLayerChanged: invalidateImageComposite()
    onClosed: {
        if (CaptureService.screenshotEditorVisible)
            root.cancelEditor();
    }
    onEditorReadyChanged: {
        if (editorReady)
            editorPresented = true;
    }
    onImageLayerOrderIdsChanged: invalidateImageComposite()
    onImageLoadEnabledChanged: invalidateImageComposite()
    onImageResizePreviewChanged: invalidateImageComposite()
    onSelectedAnnotationShapeChanged: {
        if (selectedAnnotationShape === null)
            selectedAnnotationIndex = -1;
    }
    onSelectedToolChanged: {
        if (selectedTool !== "select") {
            if (annotationTransformActive)
                cancelAnnotationTransform();
            selectedAnnotationShape = null;
        }
    }
    onShapesChanged: {
        syncInsertedImageRenderIds();
        invalidateImageComposite();
    }

    Connections {
        function onFinished(success, text) {
            if (!CaptureService.screenshotEditorVisible)
                return;
            root.showOcrNotice(success, success ? text : OcrService.statusText);
        }

        target: OcrService
    }
    Connections {
        function onScreenshotEditorSessionChanged() {
            root.editorPresented = false;
            root.resetEditorDefaults();
            root.retrySourceImage();
        }

        target: CaptureService
    }
    Timer {
        id: ocrNoticeTimer

        interval: 3600
        repeat: false

        onTriggered: root.ocrNoticeVisible = false
    }
    ImageFilePicker {
        id: imageLayerPicker

        title: qsTr("Add image")

        onAccepted: path => {
            if (root.imagePickerSession !== root.imageInsertSessionToken || !CaptureService.screenshotEditorVisible)
                return;
            if (path !== "")
                root.probeImageLayer(path, root.imagePickerSession);

            keyScope.forceActiveFocus();
        }
        onCanceled: keyScope.forceActiveFocus()
        onFailed: message => {
            if (root.imagePickerSession === root.imageInsertSessionToken)
                root.saveError = message;
            keyScope.forceActiveFocus();
        }
    }
    Process {
        id: renderExportProcess

        command: []

        stderr: StdioCollector {
            id: renderExportError
        }

        onExited: (exitCode, exitStatus) => {
            var operation = root.renderExportOperation;
            var operationSession = root.renderExportOperationSession;
            var outputPath = root.renderExportOutputPath;
            var sessionToken = root.renderExportRunningSession;
            var targetWidth = root.renderExportTargetWidth;
            var targetHeight = root.renderExportTargetHeight;
            var current = root.renderExportIsCurrent(sessionToken, operation, operationSession);
            var errorMessage = renderExportError.text.trim();
            root.clearRenderExportState(exitCode !== 0 || !current);
            if (!current)
                return;
            if (exitCode !== 0) {
                root.failRenderExport(operation, errorMessage);
                return;
            }
            root.completeRenderExport(operation, outputPath, targetWidth, targetHeight);
        }
    }
    Process {
        id: imageProbeProcess

        command: []

        stderr: StdioCollector {
            id: imageProbeError
        }
        stdout: StdioCollector {
            id: imageProbeOutput
        }

        onExited: (exitCode, exitStatus) => {
            var path = root.pendingImagePath;
            var sessionToken = root.pendingImageSession;
            root.pendingImagePath = "";
            root.pendingImageSession = -1;
            if (sessionToken !== root.imageInsertSessionToken || !CaptureService.screenshotEditorVisible)
                return;

            var dimensions = imageProbeOutput.text.trim().split(/\s+/);
            var naturalWidth = dimensions.length >= 2 ? Number(dimensions[0]) : 0;
            var naturalHeight = dimensions.length >= 2 ? Number(dimensions[1]) : 0;
            if (exitCode === 0 && naturalWidth > 0 && naturalHeight > 0)
                root.insertImageLayer(path, naturalWidth, naturalHeight);
            else
                root.saveError = imageProbeError.text.trim() || qsTr("Could not read the selected image");
            keyScope.forceActiveFocus();
        }
    }
    Process {
        id: edgeStitchProcess

        command: []

        stderr: StdioCollector {
            id: edgeStitchError
        }
        stdout: StdioCollector {
            id: edgeStitchOutput
        }

        onExited: (exitCode, exitStatus) => {
            var processSession = root.edgeStitchProcessSession;
            var result = root.parseProcessResult(edgeStitchOutput.text, edgeStitchError.text.trim() || qsTr("Could not stitch the images"));
            if (processSession !== root.edgeStitchSessionToken || !CaptureService.screenshotEditorVisible) {
                if (result.success && result.path)
                    Quickshell.execDetached(["rm", "-f", "--", String(result.path)]);
                return;
            }
            if (exitCode === 0 && result.success && result.path) {
                var stitchedPath = String(result.path);
                root.invalidateRedo();
                root.edgeStitchSessionToken += 1;
                if (root.edgeStitchPendingSnapshot) {
                    var historyList = root.edgeStitchHistory.slice();
                    historyList.push(root.edgeStitchPendingSnapshot);
                    root.edgeStitchHistory = historyList;
                    root.edgeStitchPendingSnapshot = null;
                }
                root.clearEdgeStitchState();
                CaptureService.screenshotPath = stitchedPath;
                root.logicalSurfaceReady = false;
                root.baseImageLayer = root.createBaseImageLayer(stitchedPath, Number(result.width) || 0, Number(result.height) || 0);
                root.baseImageFitPending = true;
                root.shapes = [];
                root.imageLayerOrderIds = [root.baseImageLayerId];
                root.cropRect = Qt.rect(0, 0, 0, 0);
                root.cropWasLastAction = false;
                root.lastMoveUndo = null;
                root.selectedAnnotationShape = null;
                root.selectedImageLayerId = root.baseImageLayerId;
                root.selectedTool = "select";
                root.committedCanvas.requestPaint();
                root.retrySourceImage();
                keyScope.forceActiveFocus();
            } else {
                root.edgeStitchPendingSnapshot = null;
                root.failEdgeStitch(String(result.error || qsTr("Could not stitch the images")));
            }
        }
    }
    Item {
        id: keyScope

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.cancelEditor()
        Keys.onPressed: event => {
            if (root.imageInsertBusy || root.edgeStitchPreparing) {
                event.accepted = true;
            } else if (event.key === Qt.Key_Alt) {
                root.startColorPicker();
                event.accepted = true;
            } else if (event.key === Qt.Key_G && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                root.loupeHeld = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.saveEditedImage();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace) {
                root.clearAll();
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                root.undo();
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_R) {
                root.redo();
                event.accepted = true;
            }
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_G) {
                root.loupeHeld = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Alt) {
                root.stopColorPicker();
                event.accepted = true;
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.chromeMargin
        spacing: root.bottomControlSpacing
        visible: root.editorPresented

        Item {
            id: headerContent

            Layout.fillWidth: true
            Layout.preferredHeight: 40 + (root.compactChrome && root.ocrNoticeVisible ? 36 : 0)

            RowLayout {
                id: headerRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 40
                spacing: 14

                Text {
                    id: headerTitle

                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    text: qsTr("Edit screenshot")
                }
                Item {
                    Layout.fillWidth: true
                }
                RowLayout {
                    id: shortcutActions

                    spacing: 7

                    ScreenshotShortcutButton {
                        actionText: root.saving ? qsTr("Saving…") : qsTr("Save")
                        enabled: !root.imageInsertBusy && !root.edgeStitchPreparing && !root.saving && !root.reverseSearchPreparing && sourceImage.status === Image.Ready
                        shortcutKeys: ["Enter"]
                        showShortcutKeys: !root.compactChrome
                        tone: "primary"

                        onClicked: root.saveEditedImage()
                    }
                    ScreenshotShortcutButton {
                        actionText: qsTr("Clear")
                        enabled: !root.imageInsertBusy && !root.edgeStitchPreparing && (root.shapes.length > 0 || root.cropActive || root.ocrRect.width > 0 || inlineTextEditor.visible || root.lastMoveUndo !== null)
                        shortcutKeys: ["Backspace"]
                        showShortcutKeys: !root.compactChrome

                        onClicked: root.clearAll()
                    }
                    ScreenshotShortcutButton {
                        actionText: qsTr("Undo")
                        enabled: !root.imageInsertBusy && !root.edgeStitchPreparing && root.canUndo
                        shortcutKeys: ["Ctrl", "Z"]
                        showShortcutKeys: !root.compactChrome

                        onClicked: root.undo()
                    }
                    ScreenshotShortcutButton {
                        actionText: qsTr("Redo")
                        enabled: !root.imageInsertBusy && !root.edgeStitchPreparing && root.canRedo
                        shortcutKeys: ["Ctrl", "R"]
                        showShortcutKeys: !root.compactChrome

                        onClicked: root.redo()
                    }
                    ScreenshotShortcutButton {
                        actionText: qsTr("Cancel")
                        shortcutKeys: ["Esc"]
                        showShortcutKeys: !root.compactChrome
                        tone: "error"

                        onClicked: root.cancelEditor()
                    }
                }
            }
            ScreenshotStatusPill {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: root.compactChrome ? headerRow.bottom : undefined
                anchors.topMargin: root.compactChrome ? 6 : 0
                anchors.verticalCenter: root.compactChrome ? undefined : parent.verticalCenter
                detailText: root.ocrNoticeText
                error: root.ocrNoticeError
                maximumWidth: root.compactChrome ? Math.max(0, headerContent.width - 16) : Math.max(0, headerContent.width - Math.max(headerTitle.implicitWidth, shortcutActions.implicitWidth) * 2 - 32)
                shown: root.ocrNoticeVisible
            }
        }
        Item {
            id: editorArea

            Layout.bottomMargin: layersPanel.visible ? layersPanel.height + (root.height < 720 ? 10 : 16) : 0
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true

            Rectangle {
                id: imageFrame

                readonly property real fittedScale: Math.max(0.01, Math.min((editorArea.width - 8) / Math.max(1, width), (editorArea.height - 8) / Math.max(1, height)))

                anchors.centerIn: parent
                border.color: Config.alpha(Config.md3.on_surface, 0.18)
                border.width: 1
                color: Config.md3.surface_container
                height: captureSurface.height + 2
                scale: fittedScale
                transformOrigin: Item.Center
                width: captureSurface.width + 2

                Item {
                    id: captureSurface

                    anchors.centerIn: parent
                    clip: root.edgeStitchDropEdge === ""
                    height: root.logicalSurfaceHeight
                    width: root.logicalSurfaceWidth

                    Item {
                        id: imageCompositeSurface

                        anchors.fill: parent
                        z: root.imageLayerStackZ(root.baseImageLayerId)

                        Item {
                            id: baseImageSurface

                            anchors.fill: parent
                            z: root.imageLayerStackZ(root.baseImageLayerId)

                            ScreenshotImageLayer {
                                id: sourceImage

                                loadEnabled: root.imageLoadEnabled
                                offsetX: root.currentShape && root.currentShape.layerId === root.baseImageLayerId ? liveCanvasTranslate.x : 0
                                offsetY: root.currentShape && root.currentShape.layerId === root.baseImageLayerId ? liveCanvasTranslate.y : 0
                                shapeData: root.imageResizePreview && root.imageResizePreview.layerId === root.baseImageLayerId ? root.imageResizePreview : root.baseImageLayer || {
                                    "source": CaptureService.screenshotPath,
                                    "startX": 0,
                                    "startY": 0,
                                    "endX": captureSurface.width,
                                    "endY": captureSurface.height,
                                    "cropX": 0,
                                    "cropY": 0,
                                    "cropWidth": 1,
                                    "cropHeight": 1
                                }

                                onImageStatusChanged: {
                                    root.invalidateImageComposite();
                                    if (imageStatus === Image.Ready)
                                        Qt.callLater(function () {
                                            root.initializeBaseImageLayer(false);
                                        });
                                }
                            }
                        }
                        Repeater {
                            id: insertedImageRepeater

                            model: root.insertedImageRenderIds

                            delegate: ScreenshotImageLayer {
                                required property int index
                                readonly property string layerId: String(modelData || "")
                                readonly property var layerShape: root.imageLayerById(layerId)
                                required property var modelData

                                hidden: root.edgeStitchPreparing && root.edgeStitchLayerId === layerId
                                offsetX: root.currentShape && root.currentShape.tool === "image" && root.currentShape.layerId === layerId ? liveCanvasTranslate.x : 0
                                offsetY: root.currentShape && root.currentShape.tool === "image" && root.currentShape.layerId === layerId ? liveCanvasTranslate.y : 0
                                shapeData: root.imageResizePreview && root.imageResizePreview.layerId === layerId ? root.imageResizePreview : layerShape || {
                                    "source": "",
                                    "startX": 0,
                                    "startY": 0,
                                    "endX": 0,
                                    "endY": 0
                                }
                                z: root.imageLayerStackZ(layerId)

                                onImageStatusChanged: root.invalidateImageComposite()
                            }
                        }
                    }
                    Repeater {
                        model: root.blurShapes

                        delegate: BlurRegion {
                            required property var modelData

                            shapeData: modelData
                            sourceItem: imageCompositeSurface
                            sourceLive: root.imageCompositeLive
                            sourceRevision: root.imageCompositeRevision
                            surfaceHeight: captureSurface.height
                            surfaceWidth: captureSurface.width
                            z: imageCompositeSurface.z + 0.25
                        }
                    }
                    Repeater {
                        model: root.pixelateShapes

                        delegate: PixelateRegion {
                            required property var modelData

                            shapeData: modelData
                            sourceItem: imageCompositeSurface
                            sourceLive: root.imageCompositeLive
                            sourceRevision: root.imageCompositeRevision
                            surfaceHeight: captureSurface.height
                            surfaceWidth: captureSurface.width
                            z: imageCompositeSurface.z + 0.25
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
                        sourceItem: imageCompositeSurface
                        sourceLive: root.imageCompositeLive
                        sourceRevision: root.imageCompositeRevision
                        surfaceHeight: captureSurface.height
                        surfaceWidth: captureSurface.width
                        visible: root.currentShape !== null && root.currentShape.tool === "blur"
                        z: imageCompositeSurface.z + 0.25
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
                        sourceItem: imageCompositeSurface
                        sourceLive: root.imageCompositeLive
                        sourceRevision: root.imageCompositeRevision
                        surfaceHeight: captureSurface.height
                        surfaceWidth: captureSurface.width
                        visible: root.currentShape !== null && root.currentShape.tool === "pixelate"
                        z: imageCompositeSurface.z + 0.25
                    }
                    Canvas {
                        id: colorSampler

                        antialiasing: false
                        height: 1
                        renderStrategy: Canvas.Immediate
                        visible: (root.colorPickerHeld || root.colorPickerCommitPending) && !root.renderingOutput
                        width: 1
                        z: -100000

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, 1, 1);
                            if ((!root.colorPickerHeld && !root.colorPickerCommitPending) || !root.colorPickerSourceItem)
                                return;

                            try {
                                ctx.drawImage(root.colorPickerSourceItem, root.colorPickerPixelX, root.colorPickerPixelY, 1, 1, 0, 0, 1, 1);
                                var pixel = ctx.getImageData(0, 0, 1, 1).data;
                                ctx.clearRect(0, 0, 1, 1);
                                root.acceptColorSample(pixel[0], pixel[1], pixel[2], pixel[3]);
                            } catch (error) {
                                ctx.clearRect(0, 0, 1, 1);
                                root.colorPickerCommitPending = false;
                                if (!root.colorPickerHeld)
                                    root.colorPickerSourceItem = null;
                            }
                        }
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
                            if (root.currentShape && root.currentShape.__waitingForCommit)
                                root.currentShape.__waitingForCommit = false;
                        }
                    }
                    Repeater {
                        model: root.calloutShapes

                        delegate: ScreenshotZoomCallout {
                            required property var modelData

                            anchors.fill: parent
                            shapeData: modelData
                            sourceItem: baseImageSurface
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
                            var incrementalPen = shape && shape.tool === "pen" && shape.__dragStartX === undefined && !shape.__annotationTransform && root.shapeOpacity(shape) >= 0.999;
                            if (clearBeforePaint || !incrementalPen) {
                                ctx.clearRect(0, 0, width, height);
                                clearBeforePaint = false;
                            }
                            if (incrementalPen)
                                root.drawIncrementalPen(ctx, shape);
                            else
                                root.drawShape(ctx, shape);

                            liveCanvas.opacity = 1;
                        }
                        onPainted: {
                            if (!root.currentShape || !root.currentShape.__waitingForLiveHandoff)
                                return;

                            var detachIndex = root.movingShapeIndex;
                            if (detachIndex >= 0 && detachIndex < root.shapes.length) {
                                var nextShapes = root.shapes.slice();
                                nextShapes.splice(detachIndex, 1);
                                root.movingShapeDetached = true;
                                root.shapes = nextShapes;
                            }
                            delete root.currentShape.__waitingForLiveHandoff;
                            root.currentShape.__waitingForCommit = true;
                            committedCanvas.requestPaint();
                        }
                    }
                    ScreenshotZoomCallout {
                        anchors.fill: parent
                        offsetX: liveCanvasTranslate.x
                        offsetY: liveCanvasTranslate.y
                        shapeData: root.currentShape || {
                            "startX": 0,
                            "startY": 0,
                            "endX": 0,
                            "endY": 0,
                            "calloutX": 0,
                            "calloutY": 0,
                            "calloutWidth": 0,
                            "calloutHeight": 0
                        }
                        sourceItem: baseImageSurface
                        visible: root.currentShape !== null && root.currentShape.tool === "callout" && Number(root.currentShape.calloutWidth || 0) > 0 && !root.renderingOutput
                    }
                    MouseArea {
                        id: editorPointer

                        anchors.fill: parent
                        cursorShape: root.colorPickerHeld || root.selectedTool === "loupe" || root.loupeHeld ? Qt.CrossCursor : root.selectedTool === "select" ? Qt.ArrowCursor : (root.selectedTool === "eraser" || root.selectedTool === "text" || root.selectedTool === "number" ? Qt.PointingHandCursor : Qt.CrossCursor)
                        hoverEnabled: true

                        onCanceled: {
                            root.stopSelectionPreview();
                            root.selectionStartX = 0;
                            root.selectionStartY = 0;
                            root.selectionPointerX = 0;
                            root.selectionPointerY = 0;
                            if (root.colorPickerHeld) {
                                root.colorPickerCommitPending = false;
                                return;
                            }
                            root.cropDragging = false;
                            root.cropDraftRect = Qt.rect(0, 0, 0, 0);
                            root.cropTargetLayerId = "";
                            root.cropTargetOriginal = null;
                            root.ocrDragging = false;
                            root.ocrDraftRect = Qt.rect(0, 0, 0, 0);
                            if (root.selectedTool === "select") {
                                if (root.annotationTransformActive)
                                    root.cancelAnnotationTransform();
                                else
                                    root.cancelShapeMove();
                            } else {
                                root.currentShape = null;
                                root.prepareLiveCanvas();
                            }
                        }
                        onEntered: {
                            root.loupePointerInside = true;
                            if (root.colorPickerHeld || root.selectedTool === "loupe" || root.loupeHeld) {
                                root.loupePointerX = mouseX;
                                root.loupePointerY = mouseY;
                            }
                        }
                        onExited: root.loupePointerInside = false
                        onPositionChanged: mouse => {
                            if (root.colorPickerHeld || root.selectedTool === "loupe" || root.loupeHeld) {
                                root.loupePointerX = mouse.x;
                                root.loupePointerY = mouse.y;
                            }
                            if (root.colorPickerHeld) {
                                if (pressed) {
                                    root.colorPickerCommitPending = true;
                                    root.requestColorSample(mouse.x, mouse.y);
                                } else if (!root.colorPickerCommitPending) {
                                    root.requestColorSample(mouse.x, mouse.y);
                                }
                                return;
                            }
                            if (!pressed)
                                return;

                            if (root.selectedTool === "loupe" || root.loupeHeld)
                                return;

                            if (root.selectedTool === "select") {
                                if (root.currentShape && root.currentShape.__dragStartX !== undefined) {
                                    if (root.currentShape.__waitingForLiveHandoff || root.currentShape.__waitingForCommit)
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
                                        root.edgeStitchDropEdge = root.currentShape.tool === "image" && !root.currentShape.isBase ? root.edgeForImage(root.currentShape, liveCanvasTranslate.x, liveCanvasTranslate.y, mouse.x, mouse.y) : "";
                                        if (root.edgeStitchDropEdge !== "") {
                                            var snappedOffset = root.edgeSnappedOffsetForImage(root.currentShape, root.edgeStitchDropEdge, liveCanvasTranslate.x, liveCanvasTranslate.y);
                                            liveCanvasTranslate.x = snappedOffset.x;
                                            liveCanvasTranslate.y = snappedOffset.y;
                                        }
                                    }
                                }
                                return;
                            }

                            if (root.selectedTool === "eraser") {
                                root.eraseAt(mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "crop" && root.cropDragging) {
                                root.scheduleSelectionPreview(mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "ocr" && root.ocrDragging) {
                                root.scheduleSelectionPreview(mouse.x, mouse.y);
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
                            if (root.colorPickerHeld || root.selectedTool === "loupe" || root.loupeHeld) {
                                root.loupePointerX = mouse.x;
                                root.loupePointerY = mouse.y;
                            }
                            if (root.colorPickerHeld) {
                                root.colorPickerCommitPending = true;
                                root.requestColorSample(mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "loupe" || root.loupeHeld)
                                return;

                            if (root.selectedTool === "select") {
                                root.edgeStitchDropEdge = "";
                                for (var i = root.shapes.length - 1; i >= 0; i--) {
                                    if (root.shapes[i].tool !== "image" && root.hitTestShape(root.shapes[i], mouse.x, mouse.y)) {
                                        root.selectedImageLayerId = "";
                                        root.selectedAnnotationShape = root.copyShape(root.shapes[i]);
                                        root.selectedAnnotationIndex = i;
                                        root.movingShapeDetached = false;
                                        root.movingShapeIndex = i;
                                        root.movingShapeOriginal = root.copyShape(root.shapes[i]);
                                        var selectedShape = root.copyShape(root.shapes[i]);
                                        selectedShape.__dragStartX = mouse.x;
                                        selectedShape.__dragStartY = mouse.y;

                                        liveCanvasTranslate.x = 0;
                                        liveCanvasTranslate.y = 0;
                                        root.currentShape = selectedShape;
                                        root.currentShape.__waitingForLiveHandoff = true;
                                        root.prepareLiveCanvas();
                                        root.scheduleLivePaint();
                                        return;
                                    }
                                }
                                var selectedImageShape = root.topImageLayerAt(mouse.x, mouse.y);
                                if (selectedImageShape) {
                                    root.selectedAnnotationShape = null;
                                    root.selectedImageLayerId = selectedImageShape.layerId;
                                    root.movingShapeDetached = false;
                                    root.movingShapeIndex = selectedImageShape.isBase ? -1 : root.imageLayerIndexById(selectedImageShape.layerId);
                                    root.movingShapeOriginal = root.copyShape(selectedImageShape);
                                    var movableImageShape = root.copyShape(selectedImageShape);
                                    movableImageShape.__dragStartX = mouse.x;
                                    movableImageShape.__dragStartY = mouse.y;
                                    liveCanvasTranslate.x = 0;
                                    liveCanvasTranslate.y = 0;
                                    root.currentShape = movableImageShape;
                                    committedCanvas.requestPaint();
                                    return;
                                }
                                root.movingShapeDetached = false;
                                root.movingShapeIndex = -1;
                                root.movingShapeOriginal = null;
                                root.currentShape = null;
                                root.selectedAnnotationShape = null;
                                root.selectedImageLayerId = "";
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
                                root.stopSelectionPreview();
                                root.selectionStartX = mouse.x;
                                root.selectionStartY = mouse.y;
                                root.selectionPointerX = mouse.x;
                                root.selectionPointerY = mouse.y;
                                root.cropTargetLayerId = "";
                                root.cropTargetOriginal = null;
                                root.cropDragging = true;
                                root.cropDraftRect = Qt.rect(mouse.x, mouse.y, 0, 0);
                                return;
                            }
                            if (root.selectedTool === "ocr") {
                                if (OcrService.busy || root.ocrPreparing)
                                    return;

                                root.hideOcrNotice();
                                root.stopSelectionPreview();
                                root.selectionStartX = mouse.x;
                                root.selectionStartY = mouse.y;
                                root.selectionPointerX = mouse.x;
                                root.selectionPointerY = mouse.y;
                                OcrService.clearStatus();
                                root.ocrDragging = true;
                                root.ocrDraftRect = Qt.rect(mouse.x, mouse.y, 0, 0);
                                return;
                            }
                            root.prepareLiveCanvas();
                            root.currentShape = {
                                "tool": root.selectedTool,
                                "color": String(root.selectedColor),
                                "opacity": root.selectedOpacity,
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
                            if (root.colorPickerHeld) {
                                root.colorPickerCommitPending = true;
                                root.requestColorSample(mouse.x, mouse.y);
                                return;
                            }
                            if (root.selectedTool === "loupe" || root.loupeHeld)
                                return;

                            if (root.selectedTool === "select") {
                                if (root.currentShape && root.currentShape.__dragStartX !== undefined) {
                                    var shapeWasDetached = root.movingShapeDetached;
                                    delete root.currentShape.__waitingForLiveHandoff;
                                    delete root.currentShape.__waitingForCommit;
                                    var finalShape = root.copyShape(root.currentShape);
                                    var requestedStitchEdge = root.edgeStitchDropEdge;
                                    root.edgeStitchDropEdge = "";
                                    if (finalShape.tool === "image" && requestedStitchEdge !== "") {
                                        liveCanvasTranslate.x = 0;
                                        liveCanvasTranslate.y = 0;
                                        root.currentShape = null;
                                        root.movingShapeDetached = false;
                                        root.movingShapeIndex = -1;
                                        root.movingShapeOriginal = null;
                                        root.prepareLiveCanvas();
                                        root.scheduleLivePaint();
                                        root.startEdgeStitch(finalShape, requestedStitchEdge);
                                        return;
                                    }
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
                                        if (finalShape.tool === "callout") {
                                            finalShape.calloutX += dx;
                                            finalShape.calloutY += dy;
                                        }
                                    }

                                    delete finalShape.__dragStartX;
                                    delete finalShape.__dragStartY;
                                    delete finalShape.__waitingForLiveHandoff;
                                    delete finalShape.__waitingForCommit;
                                    delete finalShape.__hideLiveCanvas;

                                    var nextShapesList = root.shapes.slice();
                                    var insertionIndex;
                                    if (finalShape.tool === "image") {
                                        if (finalShape.isBase) {
                                            insertionIndex = -1;
                                            root.baseImageLayer = finalShape;
                                        } else {
                                            insertionIndex = root.imageLayerIndexById(finalShape.layerId);
                                            if (insertionIndex >= 0) {
                                                nextShapesList[insertionIndex] = finalShape;
                                            } else {
                                                insertionIndex = Math.max(0, Math.min(root.movingShapeIndex, nextShapesList.length));
                                                nextShapesList.splice(insertionIndex, 0, finalShape);
                                            }
                                            root.shapes = nextShapesList;
                                        }
                                    } else {
                                        insertionIndex = Math.max(0, Math.min(root.movingShapeIndex, nextShapesList.length));
                                        if (shapeWasDetached)
                                            nextShapesList.splice(insertionIndex, 0, finalShape);
                                        else if (insertionIndex < nextShapesList.length)
                                            nextShapesList[insertionIndex] = finalShape;
                                        else
                                            nextShapesList.push(finalShape);
                                        root.shapes = nextShapesList;
                                    }
                                    root.selectedAnnotationShape = finalShape.tool === "image" ? null : root.copyShape(finalShape);
                                    root.selectedAnnotationIndex = finalShape.tool === "image" ? -1 : insertionIndex;
                                    if (Math.abs(moveDx) > 0.01 || Math.abs(moveDy) > 0.01) {
                                        root.invalidateRedo();
                                        root.lastMoveUndo = finalShape.tool === "image" ? {
                                            "kind": "image-state",
                                            "layerId": finalShape.layerId,
                                            "shape": root.copyShape(root.movingShapeOriginal)
                                        } : {
                                            "index": insertionIndex,
                                            "shape": root.copyShape(root.movingShapeOriginal)
                                        };
                                        root.cropWasLastAction = false;
                                    }
                                    root.movingShapeDetached = false;
                                    root.movingShapeIndex = -1;
                                    root.movingShapeOriginal = null;

                                    if (finalShape.tool === "image") {
                                        liveCanvasTranslate.x = 0;
                                        liveCanvasTranslate.y = 0;
                                        root.currentShape = null;
                                        root.prepareLiveCanvas();
                                        root.scheduleLivePaint();
                                    } else if (finalShape.tool !== "blur" && finalShape.tool !== "pixelate") {
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
                            if (root.selectedTool === "crop" && root.cropDragging) {
                                root.stopSelectionPreview();
                                var nextCrop = root.cropTargetOriginal ? root.normalizeCropRectForLayer(root.cropTargetOriginal, root.selectionStartX, root.selectionStartY, mouse.x, mouse.y) : root.normalizeCropRect(root.selectionStartX, root.selectionStartY, mouse.x, mouse.y);
                                root.cropDragging = false;
                                root.selectionStartX = 0;
                                root.selectionStartY = 0;
                                root.selectionPointerX = 0;
                                root.selectionPointerY = 0;
                                if (nextCrop.width >= 8 && nextCrop.height >= 8) {
                                    if (root.cropTargetLayerId !== "") {
                                        root.commitImageCrop(root.cropTargetLayerId, nextCrop);
                                    } else {
                                        root.invalidateRedo();
                                        root.lastMoveUndo = null;
                                        root.cropRect = nextCrop;
                                        root.cropWasLastAction = true;
                                    }
                                }
                                root.cropDraftRect = Qt.rect(0, 0, 0, 0);
                                root.cropTargetLayerId = "";
                                root.cropTargetOriginal = null;
                                return;
                            }
                            if (root.selectedTool === "ocr" && root.ocrDragging) {
                                root.stopSelectionPreview();
                                var nextOcr = root.normalizeCropRect(root.selectionStartX, root.selectionStartY, mouse.x, mouse.y);
                                root.ocrDragging = false;
                                root.selectionStartX = 0;
                                root.selectionStartY = 0;
                                root.selectionPointerX = 0;
                                root.selectionPointerY = 0;
                                root.ocrDraftRect = Qt.rect(0, 0, 0, 0);
                                root.recognizeRegion(nextOcr);
                                return;
                            }
                            if (!root.currentShape || root.selectedTool === "eraser")
                                return;

                            root.currentShape.endX = mouse.x;
                            root.currentShape.endY = mouse.y;
                            var committedShape = root.currentShape.tool === "callout" ? root.finalizeCalloutShape(root.currentShape) : root.copyShape(root.currentShape);
                            if (!committedShape) {
                                root.currentShape = null;
                                root.prepareLiveCanvas();
                                root.scheduleLivePaint();
                                return;
                            }
                            root.invalidateRedo();
                            root.lastMoveUndo = null;
                            var nextShapes = root.shapes.slice();
                            nextShapes.push(committedShape);
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
                        onWheel: wheel => {
                            if (root.colorPickerHeld) {
                                wheel.accepted = true;
                                return;
                            }
                            if (root.selectedTool !== "loupe" && !root.loupeHeld)
                                return;
                            var steps = wheel.angleDelta.y / 120;
                            if (Math.abs(steps) < 0.01)
                                steps = wheel.pixelDelta.y > 0 ? 1 : wheel.pixelDelta.y < 0 ? -1 : 0;
                            root.loupeZoom = Math.max(1.5, Math.min(4, root.loupeZoom + steps * 0.25));
                            wheel.accepted = true;
                        }
                    }
                    ScreenshotShapeSelection {
                        frameRect: root.selectedFrameRect
                        offsetX: root.selectedFrameOffsetX
                        offsetY: root.selectedFrameOffsetY
                        resizeEnabled: true
                        rotationAngle: root.selectedFrameRotation
                        rotationEnabled: root.annotationSupportsRotation(root.selectedFrameShape)
                        visible: root.selectedTool === "select" && root.selectedFrameShape !== null && frameRect.width > 0 && frameRect.height > 0 && !root.renderingOutput && !root.imageInsertBusy
                        z: 20

                        onResizeCanceled: root.cancelAnnotationTransform()
                        onResizeFinished: root.finishAnnotationTransform()
                        onResizeRequested: (pointerX, pointerY) => {
                            return root.resizeSelectedAnnotation(pointerX, pointerY);
                        }
                        onResizeStarted: (horizontalSign, verticalSign, pointerX, pointerY, modifiers) => {
                            return root.beginAnnotationResize(horizontalSign, verticalSign, pointerX, pointerY, modifiers);
                        }
                        onRotationCanceled: root.cancelAnnotationTransform()
                        onRotationFinished: root.finishAnnotationTransform()
                        onRotationRequested: angle => {
                            return root.rotateSelectedAnnotation(angle);
                        }
                        onRotationStarted: root.beginAnnotationTransform("rotation")
                    }
                    ScreenshotMagnifierLoupe {
                        anchors.fill: parent
                        pointerX: root.loupePointerX
                        pointerY: root.loupePointerY
                        sourceItem: baseImageSurface
                        surfaceHeight: captureSurface.height
                        surfaceWidth: captureSurface.width
                        visible: !root.colorPickerHeld && !root.renderingOutput && root.loupePointerInside && (root.selectedTool === "loupe" || root.loupeHeld) && sourceImage.status === Image.Ready
                        z: 30
                        zoom: root.loupeZoom
                    }
                    ScreenshotColorPicker {
                        anchors.fill: parent
                        pickedColor: root.colorPickerColor
                        pointerX: root.loupePointerX
                        pointerY: root.loupePointerY
                        sourceItem: root.colorPickerSourceItem
                        sourceX: root.colorPickerSourceX
                        sourceY: root.colorPickerSourceY
                        surfaceHeight: captureSurface.height
                        surfaceWidth: captureSurface.width
                        visible: root.colorPickerHeld && root.loupePointerInside && root.colorPickerSourceItem !== null && !root.renderingOutput
                        z: 31
                    }
                    Item {
                        id: edgeStitchPreview

                        readonly property bool horizontalEdge: root.edgeStitchDropEdge === "left" || root.edgeStitchDropEdge === "right"

                        Accessible.ignored: true
                        anchors.fill: parent
                        visible: root.currentShape && root.currentShape.tool === "image" && root.edgeStitchDropEdge !== "" && !root.edgeStitchPreparing

                        Rectangle {
                            color: Config.md3.tertiary
                            height: edgeStitchPreview.horizontalEdge ? parent.height : 6
                            radius: 3
                            width: edgeStitchPreview.horizontalEdge ? 6 : parent.width
                            x: root.edgeStitchDropEdge === "right" ? parent.width - width : 0
                            y: root.edgeStitchDropEdge === "bottom" ? parent.height - height : 0
                        }
                        Rectangle {
                            color: Config.md3.tertiary_container
                            height: 42
                            radius: 14
                            width: 42
                            x: root.edgeStitchDropEdge === "left" ? 10 : root.edgeStitchDropEdge === "right" ? parent.width - width - 10 : (parent.width - width) / 2
                            y: root.edgeStitchDropEdge === "top" ? 10 : root.edgeStitchDropEdge === "bottom" ? parent.height - height - 10 : (parent.height - height) / 2

                            Text {
                                anchors.centerIn: parent
                                color: Config.md3.on_tertiary_container
                                font.family: Config.fontName
                                font.pixelSize: 24
                                font.weight: Font.Bold
                                text: root.edgeStitchDropEdge === "left" ? "←" : root.edgeStitchDropEdge === "right" ? "→" : root.edgeStitchDropEdge === "top" ? "↑" : "↓"
                            }
                        }
                    }
                    ScreenshotImageSelection {
                        layerId: root.selectedImageLayerId
                        removable: root.selectedImageLayerId !== root.baseImageLayerId
                        shapeData: root.imageResizePreview || root.selectedImageLayer || {
                            "startX": 0,
                            "startY": 0,
                            "endX": 0,
                            "endY": 0
                        }
                        surfaceHeight: captureSurface.height
                        surfaceWidth: captureSurface.width
                        visible: root.selectedTool === "select" && !root.colorPickerHeld && !root.loupeHeld && root.selectedImageLayer !== null && !Boolean(root.selectedImageLayer.hidden) && (!root.currentShape || root.currentShape.tool !== "image") && !root.renderingOutput && !root.imageInsertBusy

                        onCropCanceled: layerId => {
                            return root.cancelImageCrop(layerId);
                        }
                        onCropFinished: layerId => {
                            return root.finishImageCrop(layerId);
                        }
                        onCropRequested: (layerId, localX, localY, width, height) => {
                            return root.updateImageCrop(layerId, localX, localY, width, height);
                        }
                        onCropStarted: layerId => {
                            return root.beginImageCrop(layerId);
                        }
                        onRemoveRequested: layerId => {
                            return root.removeImageLayer(layerId);
                        }
                        onResizeCanceled: layerId => {
                            return root.cancelImageResize(layerId);
                        }
                        onResizeFinished: layerId => {
                            return root.finishImageResize(layerId);
                        }
                        onResizeRequested: (layerId, x, y, width, height) => {
                            return root.updateImageResize(layerId, x, y, width, height);
                        }
                        onResizeStarted: layerId => {
                            return root.beginImageResize(layerId);
                        }
                        onRotationCanceled: layerId => {
                            return root.cancelImageRotation(layerId);
                        }
                        onRotationFinished: layerId => {
                            return root.finishImageRotation(layerId);
                        }
                        onRotationRequested: (layerId, angle) => {
                            return root.updateImageRotation(layerId, angle);
                        }
                        onRotationStarted: layerId => {
                            return root.beginImageRotation(layerId);
                        }
                    }
                    Item {
                        id: cropOverlay

                        anchors.fill: parent
                        visible: root.displayedCropRect.width >= 2 && root.displayedCropRect.height >= 2 && !root.renderingOutput && !root.ocrPreparing

                        Rectangle {
                            color: "#88000000"
                            height: Math.max(0, root.displayedCropRect.y)
                            visible: !root.cropDragging
                            width: parent.width
                            x: 0
                            y: 0
                        }
                        Rectangle {
                            color: "#88000000"
                            height: Math.max(0, parent.height - y)
                            visible: !root.cropDragging
                            width: parent.width
                            x: 0
                            y: root.displayedCropRect.y + root.displayedCropRect.height
                        }
                        Rectangle {
                            color: "#88000000"
                            height: root.displayedCropRect.height
                            visible: !root.cropDragging
                            width: Math.max(0, root.displayedCropRect.x)
                            x: 0
                            y: root.displayedCropRect.y
                        }
                        Rectangle {
                            color: "#88000000"
                            height: root.displayedCropRect.height
                            visible: !root.cropDragging
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
                        color: "transparent"
                        height: root.displayedOcrRect.height
                        visible: width >= 2 && height >= 2 && !root.renderingOutput && !root.ocrPreparing
                        width: root.displayedOcrRect.width
                        x: root.displayedOcrRect.x
                        y: root.displayedOcrRect.y
                    }
                    Item {
                        id: inlineTextFrame

                        property real resizeStartHeight: 0
                        property real resizeStartPointerX: 0
                        property real resizeStartPointerY: 0
                        property real resizeStartSelectedWidth: 0
                        property real resizeStartTextBoxWidth: 0
                        property real resizeStartWidth: 0
                        readonly property color selectionColor: "#42a5f5"

                        function updateTextSize(pointerX, pointerY) {
                            var dx = pointerX - resizeStartPointerX;
                            var dy = pointerY - resizeStartPointerY;
                            var horizontalScale = dx / Math.max(1, resizeStartWidth);
                            var verticalScale = dy / Math.max(1, resizeStartHeight);
                            var scale = Math.max(0.1, 1 + (horizontalScale + verticalScale) / 2);
                            root.selectedWidth = Math.max(2, Math.min(24, resizeStartSelectedWidth * scale));
                            var maximumTextBoxWidth = Math.max(80, captureSurface.width - inlineTextEditor.x - 16);
                            root.inlineTextBoxWidth = Math.max(80, Math.min(maximumTextBoxWidth, resizeStartTextBoxWidth * scale));
                        }

                        Accessible.ignored: true
                        height: inlineTextEditor.height + 10
                        visible: inlineTextEditor.visible && !root.renderingOutput
                        width: inlineTextEditor.width + 14
                        x: inlineTextEditor.x - 7
                        y: inlineTextEditor.y - 5
                        z: 2

                        Rectangle {
                            anchors.fill: parent
                            border.color: inlineTextFrame.selectionColor
                            border.width: 1
                            color: "transparent"
                        }
                        Repeater {
                            model: ["top-left", "top-right", "bottom-left", "bottom-right"]

                            delegate: Rectangle {
                                id: textResizeHandle

                                required property string modelData

                                border.color: inlineTextFrame.selectionColor
                                border.width: 1
                                color: "#ffffff"
                                height: 8
                                radius: 1
                                width: 8
                                x: modelData.indexOf("right") >= 0 ? inlineTextFrame.width - width / 2 : -width / 2
                                y: modelData.indexOf("bottom") >= 0 ? inlineTextFrame.height - height / 2 : -height / 2

                                MouseArea {
                                    id: textResizePointer

                                    anchors.fill: parent
                                    anchors.margins: -8
                                    cursorShape: Qt.SizeFDiagCursor
                                    enabled: textResizeHandle.modelData === "bottom-right"
                                    hoverEnabled: enabled
                                    preventStealing: true

                                    onCanceled: {
                                        root.inlineTextBoxWidth = inlineTextFrame.resizeStartTextBoxWidth;
                                        root.selectedWidth = inlineTextFrame.resizeStartSelectedWidth;
                                    }
                                    onPositionChanged: mouse => {
                                        if (!pressed)
                                            return;
                                        var pointerPosition = textResizePointer.mapToItem(captureSurface, mouse.x, mouse.y);
                                        inlineTextFrame.updateTextSize(pointerPosition.x, pointerPosition.y);
                                    }
                                    onPressed: mouse => {
                                        var pointerPosition = textResizePointer.mapToItem(captureSurface, mouse.x, mouse.y);
                                        inlineTextFrame.resizeStartPointerX = pointerPosition.x;
                                        inlineTextFrame.resizeStartPointerY = pointerPosition.y;
                                        inlineTextFrame.resizeStartSelectedWidth = root.selectedWidth;
                                        inlineTextFrame.resizeStartTextBoxWidth = inlineTextEditor.width;
                                        inlineTextFrame.resizeStartWidth = inlineTextFrame.width;
                                        inlineTextFrame.resizeStartHeight = inlineTextFrame.height;
                                    }
                                }
                            }
                        }
                    }
                    TextInput {
                        id: inlineTextEditor

                        clip: true
                        color: Config.alpha(root.selectedColor, root.selectedOpacity)
                        font.family: Config.fontName
                        font.pixelSize: root.textFontSize()
                        font.weight: Font.DemiBold
                        height: Math.max(32, font.pixelSize * 1.35)
                        selectedTextColor: Config.md3.background
                        selectionColor: Config.md3.tertiary
                        verticalAlignment: TextInput.AlignVCenter
                        visible: false
                        width: Math.min(captureSurface.width - x - 16, Math.max(root.inlineTextBoxWidth, contentWidth + 18))
                        z: 1

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
                    visible: root.edgeStitchPreparing && root.cropActive
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
                    availableWidth: root.layersPanelInline ? Math.max(320, toolbarViewport.width - layersPanel.width - root.bottomControlSpacing) : toolbarViewport.width
                    height: implicitHeight
                    opacityAvailable: root.toolbarOpacityAvailable
                    reverseSearchBusy: root.imageInsertBusy || root.reverseSearchPreparing || CaptureService.reverseImageSearchBusy
                    selectedColor: root.selectedColor
                    selectedOpacity: root.toolbarOpacity
                    selectedTool: root.selectedTool
                    selectedWidth: root.selectedWidth
                    width: implicitWidth
                    x: {
                        if (toolbar.implicitWidth > toolbarViewport.width)
                            return 0;

                        var centeredX = (toolbarViewport.width - toolbar.implicitWidth) / 2;
                        if (!root.layersPanelInline)
                            return centeredX;

                        var maximumX = toolbarViewport.width - layersPanel.width - root.bottomControlSpacing - toolbar.implicitWidth;
                        return Math.max(0, Math.min(centeredX, maximumX));
                    }

                    onColorSelected: colorValue => {
                        return root.selectedColor = colorValue;
                    }
                    onOpacityChangeFinished: root.finishOpacityChange()
                    onOpacityChangeStarted: root.beginOpacityChange()
                    onOpacitySelected: opacityValue => {
                        return root.updateOpacity(opacityValue);
                    }
                    onReverseSearchRequested: root.reverseImageSearch()
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
    ScreenshotLayersPanel {
        id: layersPanel

        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.layersPanelInline ? root.chromeMargin + Math.max(0, (toolbarViewport.height - height) / 2) : root.chromeMargin + toolbarViewport.height + root.bottomControlSpacing
        anchors.right: parent.right
        anchors.rightMargin: root.chromeMargin
        height: implicitHeight
        imageInsertEnabled: !root.imageInsertBusy && !root.editorChromeBusy
        layers: root.layerPanelItems
        selectedLayerId: root.selectedImageLayerId
        visible: root.editorPresented && layers.length > 0 && sourceImage.status === Image.Ready && !root.editorChromeBusy
        width: Math.min(implicitWidth, Math.max(0, root.width - root.chromeMargin * 2))
        z: 20

        onImageInsertRequested: root.openImageLayerPicker()
        onLayerOrderRequested: layerIds => {
            return root.setImageLayerOrder(layerIds);
        }
        onLayerRemoveRequested: layerId => {
            return root.removeImageLayer(layerId);
        }
        onLayerSelected: layerId => {
            return root.selectImageLayer(layerId);
        }
        onLayerVisibilityRequested: (layerId, visible) => {
            return root.setImageLayerVisibility(layerId, visible);
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Config.alpha(Config.md3.scrim, Config.lightTheme ? 0.38 : 0.58)
        visible: root.edgeStitchPreparing
        z: 99

        MouseArea {
            anchors.fill: parent
        }
        LoadingIndicator {
            anchors.centerIn: parent
            animated: root.edgeStitchPreparing
            color: Config.md3.primary
            height: 52
            width: 52
        }
    }
}
