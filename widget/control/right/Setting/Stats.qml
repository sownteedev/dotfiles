import QtQuick
import QtQuick.Layouts
import "../../../../"
import "../../../../components"
import "../../../../service"

Item {
    id: root

    property string expandedChart: ""

    function syncProcessMode() {
        SysStats.processMode = controlRightWindow.active ? expandedChart : "none";
    }
    function toggleProcessChart(chartName) {
        expandedChart = expandedChart === chartName ? "" : chartName;
    }

    anchors.fill: parent

    Component.onDestruction: SysStats.processMode = "none"
    onExpandedChartChanged: syncProcessMode()

    Connections {
        function onActiveChanged() {
            root.syncProcessMode();
        }

        target: controlRightWindow
    }
    SettingsPageTransition {
        panelActive: controlRightWindow.active
        targetItem: root
    }
    Connections {
        function onStatsUpdated() {
            if (!controlRightWindow.active || !root.visible)
                return;
            cpuChart.requestPaint();
            memoryChart.requestPaint();
            gpuChart.requestPaint();
        }

        target: SysStats
    }
    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: charts.implicitHeight
        contentWidth: width

        ColumnLayout {
            id: charts

            spacing: 35
            width: parent.width

            StatChart {
                id: cpuChart

                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                expandable: true
                expanded: root.expandedChart === "cpu"
                historyData: SysStats.cpuHistory
                lineColor: Config.md3.primary
                modelText: SysStats.cpuModelName
                processList: SysStats.topCpu
                processManagerEnabled: true
                processRevision: SysStats.processRevision
                processTitle: "CPU Processes"
                processValueSuffix: "%"
                terminatingPid: SysStats.terminatingPid
                terminationError: SysStats.terminationError
                title: "CPU"
                valueText: SysStats.currentCpu + "%" + (SysStats.cpuTemp > 0 ? " (" + SysStats.cpuTemp + "°C)" : "")

                onClicked: root.toggleProcessChart("cpu")
                onTerminateRequested: (pid, name) => SysStats.terminateProcess(pid, name)
            }
            StatChart {
                id: memoryChart

                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                expandable: true
                expanded: root.expandedChart === "ram"
                historyData: SysStats.ramHistory
                lineColor: Config.md3.secondary
                modelText: SysStats.ramModelName
                processList: SysStats.topRam
                processManagerEnabled: true
                processRevision: SysStats.processRevision
                processTitle: "Memory Processes"
                processValueSuffix: " MiB"
                terminatingPid: SysStats.terminatingPid
                terminationError: SysStats.terminationError
                title: "Memory"
                valueText: SysStats.currentRam + "%" + (SysStats.ramUsedText !== "" ? " (" + SysStats.ramUsedText + ")" : "")

                onClicked: root.toggleProcessChart("ram")
                onTerminateRequested: (pid, name) => SysStats.terminateProcess(pid, name)
            }
            StatChart {
                id: gpuChart

                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                expandable: true
                expanded: root.expandedChart === "gpu"
                historyData: SysStats.gpuHistory
                historyData2: SysStats.gpuMemHistory
                lineColor: Config.md3.tertiary
                lineColor2: Config.md3.secondary
                modelText: SysStats.gpuModelName
                processList: SysStats.topGpu
                processManagerEnabled: true
                processRevision: SysStats.processRevision
                processTitle: "GPU Processes"
                processValueSuffix: " MiB"
                terminatingPid: SysStats.terminatingPid
                terminationError: SysStats.terminationError
                title: "GPU (dGPU)"
                valueText: "<font color='" + Config.md3.tertiary + "'>GPU: " + SysStats.currentGpu + "% (" + SysStats.gpuTemp + "°C)</font>" + "<font color='" + Config.md3.on_surface_variant + "'> | </font>" + "<font color='" + Config.md3.secondary + "'>VRAM: " + SysStats.currentGpuMemPct + "% (" + SysStats.gpuMemText + ")</font>"

                onClicked: root.toggleProcessChart("gpu")
                onTerminateRequested: (pid, name) => SysStats.terminateProcess(pid, name)
            }
        }
    }
}
