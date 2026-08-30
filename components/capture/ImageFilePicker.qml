import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property Process pickerProcess: Process {
        id: pickerProcess

        command: []

        stderr: StdioCollector {
            id: pickerError
        }
        stdout: StdioCollector {
            id: pickerOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                var output = pickerOutput.text.trim();
                if (output !== "")
                    root.accepted(output);
                else
                    root.canceled();
            } else if (exitCode === 1) {
                root.canceled();
            } else {
                root.failed(pickerError.text.trim() || qsTr("Could not open the image picker"));
            }
        }
    }
    readonly property bool running: pickerProcess.running
    property string title: qsTr("Add image")

    signal accepted(string path)
    signal canceled
    signal failed(string message)

    function open() {
        if (running)
            return;
        var args = ["--file-selection", "--modal", "--title=" + title, "--file-filter=" + qsTr("Images") + " | *.png *.jpg *.jpeg *.webp *.bmp *.gif *.avif *.tif *.tiff"];
        pickerProcess.command = ["zenity"].concat(args);
        pickerProcess.running = true;
    }
}
