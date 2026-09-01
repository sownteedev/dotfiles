import "../../service"
import QtQuick

QtObject {
    id: root

    property Connections portalFilePickerConnections: Connections {
        function onAccepted(requestId, paths, uris) {
            if (requestId !== root.requestId)
                return;
            root.requestId = "";
            if (paths.length > 0)
                root.accepted(paths[0]);
            else
                root.failed(qsTr("The selected image is not available as a local file"));
        }
        function onCanceled(requestId) {
            if (requestId !== root.requestId)
                return;
            root.requestId = "";
            root.canceled();
        }
        function onFailed(requestId, message) {
            if (requestId !== root.requestId)
                return;
            root.requestId = "";
            root.failed(message || qsTr("Could not open the image picker"));
        }

        target: PortalFilePickerService
    }
    property string requestId: ""
    readonly property bool running: requestId !== ""
    property string title: qsTr("Add image")

    signal accepted(string path)
    signal canceled
    signal failed(string message)

    function open() {
        if (running)
            return false;
        if (PortalFilePickerService.active) {
            root.failed(qsTr("Another file picker is already open"));
            return false;
        }

        requestId = PortalFilePickerService.nextRequestId("screenshot-image");
        var started = PortalFilePickerService.open(requestId, {
            "title": title,
            "filters": [
                {
                    "name": qsTr("Images"),
                    "patterns": ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.gif", "*.avif", "*.tif", "*.tiff"]
                }
            ]
        });
        if (!started) {
            requestId = "";
            root.failed(qsTr("Could not open the image picker"));
        }
        return started;
    }

    Component.onDestruction: PortalFilePickerService.cancel(requestId)
}
