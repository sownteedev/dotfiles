pragma Singleton
import QtQuick
import "../../"
import ".."

QtObject {
    id: statsRoot

    property Connections coreConnections: Connections {
        function onStatsUpdated(data) {
            statsRoot.handleStatsData(data);
        }

        target: CoreService
    }
    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string cpuModelName: ""
    property int cpuTemp: 0
    property int currentCpu: 0
    property int currentGpu: 0
    property int currentGpuMemPct: 0
    property int currentRam: 0
    property string downloadSpeed: "0 B/s"
    property var gpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var gpuMemHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string gpuMemText: ""
    property string gpuModelName: ""
    property int gpuTemp: 0
    property real maxNetworkSpeed: 1048576
    property int memoryDetailsActivePid: -1
    property bool memoryDetailsBusy: false
    property int memoryDetailsQuerySerial: 0
    property string networkInterface: ""
    property int pendingMemoryDetailsPid: -1

    // Stats are only displayed inside ControlRight. The core daemon keeps no
    // sampler while this panel is closed.
    property bool pollingEnabled: false
    property double prevCpuIdle: 0
    property double prevCpuTotal: 0
    property var processMemoryDetails: null
    property int processMemoryDetailsPid: -1
    property int processMemoryDetailsRequestedPid: -1
    property double processMemoryDetailsTimestamp: 0
    property string processMode: "none"
    property int processRevision: 0
    property var ramHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string ramModelName: ""
    property string ramUsedText: ""
    property var rxHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool statsInitialized: false
    property int terminatingPid: -1
    property string terminatingProcessName: ""
    property string terminationError: ""
    property Timer terminationErrorTimer: Timer {
        interval: 3200

        onTriggered: statsRoot.terminationError = ""
    }
    property ListModel topCpu: ListModel {
    }
    property ListModel topGpu: ListModel {
    }
    property ListModel topRam: ListModel {
    }
    property var txHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string uploadSpeed: "0 B/s"
    property string uptimeText: "Uptime 0h, 0m"

    signal statsUpdated

    function addStatsSample(historyArray, newValue) {
        var arr = historyArray.slice();
        arr.shift();
        arr.push(newValue);
        return arr;
    }
    function clearProcessMemoryDetails() {
        memoryDetailsQuerySerial++;
        memoryDetailsActivePid = -1;
        memoryDetailsBusy = false;
        pendingMemoryDetailsPid = -1;
        processMemoryDetails = null;
        processMemoryDetailsPid = -1;
        processMemoryDetailsRequestedPid = -1;
        processMemoryDetailsTimestamp = 0;
    }
    function clearProcessModels() {
        topCpu.clear();
        topRam.clear();
        topGpu.clear();
        clearProcessMemoryDetails();
        processRevision++;
    }
    function finishProcessMemoryDetailsQuery(serial, completedPid, details) {
        if (serial !== memoryDetailsQuerySerial)
            return;
        memoryDetailsActivePid = -1;
        memoryDetailsBusy = false;
        if (completedPid > 1) {
            processMemoryDetailsPid = completedPid;
            processMemoryDetails = details && Number(details.pid) === completedPid ? details : {
                "pid": completedPid,
                "process_count": 0,
                "measured_process_count": 0,
                "rss_mib": null,
                "pss_mib": null,
                "pss_dirty_mib": null,
                "private_mib": null
            };
            processMemoryDetailsTimestamp = Date.now();
        }

        var nextPid = pendingMemoryDetailsPid;
        pendingMemoryDetailsPid = -1;
        if (nextPid > 1 && nextPid === processMemoryDetailsRequestedPid)
            Qt.callLater(function () {
                statsRoot.startProcessMemoryDetailsQuery(nextPid);
            });
    }
    function finishTermination(success) {
        if (!success) {
            terminationError = qsTr("Could not end %1").arg(terminatingProcessName || qsTr("process"));
            terminationErrorTimer.restart();
        }
        terminatingPid = -1;
        terminatingProcessName = "";
    }
    function formatSpeed(bytes) {
        if (bytes < 1024) {
            return bytes.toFixed(0) + " B/s";
        } else if (bytes < 1048576) {
            return (bytes / 1024).toFixed(1) + " KB/s";
        } else {
            return (bytes / 1048576).toFixed(1) + " MB/s";
        }
    }
    function handleStatsData(data) {
        if (!data)
            return;
        try {
            if (data.cpu_model !== undefined)
                cpuModelName = data.cpu_model;
            if (data.gpu_model !== undefined)
                gpuModelName = data.gpu_model;
            if (data.uptime_seconds !== undefined)
                updateUptime(data.uptime_seconds);

            var cpuVal = 0;
            if (prevCpuTotal > 0) {
                var totald = data.cpu_total - prevCpuTotal;
                var idled = data.cpu_idle - prevCpuIdle;
                cpuVal = totald > 0 ? (totald - idled) * 100 / totald : 0;
            }
            prevCpuTotal = data.cpu_total;
            prevCpuIdle = data.cpu_idle;

            var gpuMemPct = data.gpu_mem_total > 0 ? Math.round(data.gpu_mem_used * 100 / data.gpu_mem_total) : 0;
            var rxRate = Math.max(0, Number(data.rx_rate) || 0);
            var txRate = Math.max(0, Number(data.tx_rate) || 0);
            networkInterface = data.network_interface || "";
            downloadSpeed = formatSpeed(rxRate);
            uploadSpeed = formatSpeed(txRate);

            if (data.top_cpu !== undefined)
                updateProcessModel(topCpu, data.top_cpu);
            if (data.top_ram !== undefined)
                updateProcessModel(topRam, data.top_ram);
            if (data.top_gpu !== undefined)
                updateProcessModel(topGpu, data.top_gpu);

            if (!statsInitialized) {
                initStatsHistory(cpuVal, data.ram_usage, data.gpu_usage, gpuMemPct);
            } else {
                cpuHistory = addStatsSample(cpuHistory, cpuVal);
                ramHistory = addStatsSample(ramHistory, data.ram_usage);
                gpuHistory = addStatsSample(gpuHistory, data.gpu_usage);
                gpuMemHistory = addStatsSample(gpuMemHistory, gpuMemPct);
                rxHistory = addStatsSample(rxHistory, rxRate);
                txHistory = addStatsSample(txHistory, txRate);

                var currentMax = 1024;
                for (var index = 0; index < rxHistory.length; index++) {
                    if (rxHistory[index] > currentMax)
                        currentMax = rxHistory[index];
                    if (txHistory[index] > currentMax)
                        currentMax = txHistory[index];
                }
                maxNetworkSpeed = currentMax;
            }

            currentCpu = Math.round(cpuVal);
            currentRam = Math.round(data.ram_usage);
            currentGpu = Math.round(data.gpu_usage);
            currentGpuMemPct = gpuMemPct;
            cpuTemp = data.cpu_temp === "N/A" ? 0 : data.cpu_temp;

            var ramUsedFixed = data.ram_used_gb.toFixed(1);
            var ramTotalFixed = data.ram_total_gb.toFixed(1);
            ramUsedText = ramUsedFixed + " GiB / " + ramTotalFixed + " GiB";
            ramModelName = ramTotalFixed + " GiB RAM";
            gpuTemp = data.gpu_temp;

            var gpuUsedGb = (data.gpu_mem_used / 1024).toFixed(1);
            var gpuTotalGb = (data.gpu_mem_total / 1024).toFixed(1);
            gpuMemText = gpuUsedGb + " GiB / " + gpuTotalGb + " GiB";
            statsUpdated();
        } catch (error) {
            console.error("SysStats data error:", error);
        }
    }
    function initStatsHistory(cpuVal, ramVal, gpuVal, gpuMemVal) {
        var arrCpu = [];
        var arrRam = [];
        var arrGpu = [];
        var arrGpuMem = [];
        var arrRx = [];
        var arrTx = [];
        for (var i = 0; i < 60; i++) {
            arrCpu.push(cpuVal);
            arrRam.push(ramVal);
            arrGpu.push(gpuVal);
            arrGpuMem.push(gpuMemVal);
            arrRx.push(0);
            arrTx.push(0);
        }
        cpuHistory = arrCpu;
        ramHistory = arrRam;
        gpuHistory = arrGpu;
        gpuMemHistory = arrGpuMem;
        rxHistory = arrRx;
        txHistory = arrTx;
        statsInitialized = true;
    }
    function requestProcessMemoryDetails(pid) {
        var processId = Math.trunc(Number(pid));
        if (processId <= 1 || processMode !== "ram")
            return;

        processMemoryDetailsRequestedPid = processId;
        if (processMemoryDetailsPid === processId && Date.now() - processMemoryDetailsTimestamp < 2500)
            return;
        if (memoryDetailsBusy) {
            if (memoryDetailsActivePid !== processId)
                pendingMemoryDetailsPid = processId;
            return;
        }
        startProcessMemoryDetailsQuery(processId);
    }
    function sendProcessMode() {
        CoreService.setStatsMode(processMode);
    }
    function startProcessMemoryDetailsQuery(pid) {
        if (pid <= 1 || processMode !== "ram")
            return;
        memoryDetailsActivePid = pid;
        memoryDetailsBusy = true;
        var serial = ++memoryDetailsQuerySerial;
        CoreService.sendRequest("process.memory", {
            "pid": pid
        }, result => statsRoot.finishProcessMemoryDetailsQuery(serial, pid, result), message => statsRoot.finishProcessMemoryDetailsQuery(serial, pid, null));
    }
    function terminateProcess(pid, name) {
        var processId = Math.trunc(Number(pid));
        if (processId <= 1 || terminatingPid > 1)
            return;

        terminationError = "";
        terminatingPid = processId;
        terminatingProcessName = String(name || "");
        CoreService.sendRequest("process.terminate", {
            "pid": processId
        }, result => statsRoot.finishTermination(true), message => statsRoot.finishTermination(false));
    }
    function updateProcessModel(target, incoming) {
        if (!incoming)
            return;

        var valuesByPid = {};
        for (var incomingIndex = 0; incomingIndex < incoming.length; incomingIndex++) {
            var incomingPid = Math.trunc(Number(incoming[incomingIndex].pid));
            if (incomingPid > 0)
                valuesByPid["$" + incomingPid] = incoming[incomingIndex];
        }

        // Preserve the order of processes already on screen so rows do not jump
        // every sample. Remove vanished rows and append newcomers afterwards.
        for (var modelIndex = target.count - 1; modelIndex >= 0; modelIndex--) {
            var currentPid = target.get(modelIndex).pid;
            var incomingItem = valuesByPid["$" + currentPid];
            if (incomingItem === undefined) {
                target.remove(modelIndex);
            } else {
                target.setProperty(modelIndex, "name", String(incomingItem.name || ""));
                target.setProperty(modelIndex, "val", Number(incomingItem.val) || 0);
                delete valuesByPid["$" + currentPid];
            }
        }

        for (var appendIndex = 0; appendIndex < incoming.length; appendIndex++) {
            var item = incoming[appendIndex];
            var itemPid = Math.trunc(Number(item.pid));
            if (itemPid > 0 && valuesByPid["$" + itemPid] !== undefined) {
                target.append({
                    "pid": itemPid,
                    "name": String(item.name || ""),
                    "val": Number(item.val) || 0
                });
                delete valuesByPid["$" + itemPid];
            }
        }
        processRevision++;
    }
    function updateUptime(secondsValue) {
        var seconds = Math.max(0, Number(secondsValue) || 0);
        var hours = Math.floor(seconds / 3600);
        var minutes = Math.floor((seconds % 3600) / 60);
        uptimeText = "Uptime " + hours + "h, " + minutes + "m";
    }

    Component.onDestruction: CoreService.setStatsEnabled(false)
    onPollingEnabledChanged: {
        if (pollingEnabled) {
            prevCpuTotal = 0;
            prevCpuIdle = 0;
            downloadSpeed = "0 B/s";
            uploadSpeed = "0 B/s";
            CoreService.setStatsMode(processMode);
            CoreService.setStatsEnabled(true);
        } else {
            CoreService.setStatsEnabled(false);
            processMode = "none";
        }
    }
    onProcessModeChanged: {
        clearProcessModels();
        sendProcessMode();
    }
}
