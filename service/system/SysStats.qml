pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: statsRoot

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
    property Process memoryDetailsQuery: Process {
        id: memoryDetailsQuery

        property int requestedPid: -1

        stdout: StdioCollector {
            id: memoryDetailsOutput
        }

        onExited: exitCode => {
            var completedPid = requestedPid;
            var details = null;
            if (exitCode === 0) {
                try {
                    details = JSON.parse(memoryDetailsOutput.text.trim());
                } catch (error) {
                    details = null;
                }
            }
            if (completedPid > 1) {
                statsRoot.processMemoryDetailsPid = completedPid;
                statsRoot.processMemoryDetails = details && Number(details.pid) === completedPid ? details : {
                    "pid": completedPid,
                    "process_count": 0,
                    "measured_process_count": 0,
                    "rss_mib": null,
                    "pss_mib": null,
                    "pss_dirty_mib": null,
                    "private_mib": null
                };
                statsRoot.processMemoryDetailsTimestamp = Date.now();
            }
            requestedPid = -1;

            var nextPid = statsRoot.pendingMemoryDetailsPid;
            statsRoot.pendingMemoryDetailsPid = -1;
            if (nextPid > 1 && nextPid === statsRoot.processMemoryDetailsRequestedPid)
                Qt.callLater(function () {
                    statsRoot.startProcessMemoryDetailsQuery(nextPid);
                });
        }
    }
    property string networkInterface: ""
    property int pendingMemoryDetailsPid: -1

    // Stats are only displayed inside ControlRight. Keeping the sampler alive
    // while that panel is closed needlessly wakes Python and nvidia-smi.
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
    property Process statsStream: Process {
        id: statsStream

        // The launcher builds the Rust sampler only when missing or stale and
        // falls back to Python when Cargo is unavailable.
        command: [statsRoot.getStatsLauncherPath()]
        running: statsRoot.pollingEnabled
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    var data = JSON.parse(line);

                    if (data.cpu_model !== undefined)
                        statsRoot.cpuModelName = data.cpu_model;
                    if (data.gpu_model !== undefined)
                        statsRoot.gpuModelName = data.gpu_model;
                    if (data.uptime_seconds !== undefined)
                        statsRoot.updateUptime(data.uptime_seconds);

                    var cpuVal = 0;
                    if (statsRoot.prevCpuTotal > 0) {
                        var totald = data.cpu_total - statsRoot.prevCpuTotal;
                        var idled = data.cpu_idle - statsRoot.prevCpuIdle;
                        cpuVal = totald > 0 ? (totald - idled) * 100 / totald : 0;
                    }
                    statsRoot.prevCpuTotal = data.cpu_total;
                    statsRoot.prevCpuIdle = data.cpu_idle;

                    var gpuMemPct = data.gpu_mem_total > 0 ? Math.round(data.gpu_mem_used * 100 / data.gpu_mem_total) : 0;

                    var rxRate = Math.max(0, Number(data.rx_rate) || 0);
                    var txRate = Math.max(0, Number(data.tx_rate) || 0);
                    statsRoot.networkInterface = data.network_interface || "";
                    statsRoot.downloadSpeed = statsRoot.formatSpeed(rxRate);
                    statsRoot.uploadSpeed = statsRoot.formatSpeed(txRate);

                    if (data.top_cpu !== undefined)
                        statsRoot.updateProcessModel(statsRoot.topCpu, data.top_cpu);
                    if (data.top_ram !== undefined)
                        statsRoot.updateProcessModel(statsRoot.topRam, data.top_ram);
                    if (data.top_gpu !== undefined)
                        statsRoot.updateProcessModel(statsRoot.topGpu, data.top_gpu);

                    if (!statsRoot.statsInitialized) {
                        statsRoot.initStatsHistory(cpuVal, data.ram_usage, data.gpu_usage, gpuMemPct);
                    } else {
                        statsRoot.cpuHistory = statsRoot.addStatsSample(statsRoot.cpuHistory, cpuVal);
                        statsRoot.ramHistory = statsRoot.addStatsSample(statsRoot.ramHistory, data.ram_usage);
                        statsRoot.gpuHistory = statsRoot.addStatsSample(statsRoot.gpuHistory, data.gpu_usage);
                        statsRoot.gpuMemHistory = statsRoot.addStatsSample(statsRoot.gpuMemHistory, gpuMemPct);
                        statsRoot.rxHistory = statsRoot.addStatsSample(statsRoot.rxHistory, rxRate);
                        statsRoot.txHistory = statsRoot.addStatsSample(statsRoot.txHistory, txRate);

                        var currentMax = 1024; // min 1KB/s
                        for (var i = 0; i < statsRoot.rxHistory.length; i++) {
                            if (statsRoot.rxHistory[i] > currentMax)
                                currentMax = statsRoot.rxHistory[i];
                            if (statsRoot.txHistory[i] > currentMax)
                                currentMax = statsRoot.txHistory[i];
                        }
                        statsRoot.maxNetworkSpeed = currentMax;
                    }

                    statsRoot.currentCpu = Math.round(cpuVal);
                    statsRoot.currentRam = Math.round(data.ram_usage);
                    statsRoot.currentGpu = Math.round(data.gpu_usage);
                    statsRoot.currentGpuMemPct = gpuMemPct;

                    statsRoot.cpuTemp = data.cpu_temp === "N/A" ? 0 : data.cpu_temp;

                    var ramUsedFixed = data.ram_used_gb.toFixed(1);
                    var ramTotalFixed = data.ram_total_gb.toFixed(1);
                    statsRoot.ramUsedText = ramUsedFixed + " GiB / " + ramTotalFixed + " GiB";
                    statsRoot.ramModelName = ramTotalFixed + " GiB RAM";
                    statsRoot.gpuTemp = data.gpu_temp;

                    var gpuUsedGb = (data.gpu_mem_used / 1024).toFixed(1);
                    var gpuTotalGb = (data.gpu_mem_total / 1024).toFixed(1);
                    statsRoot.gpuMemText = gpuUsedGb + " GiB / " + gpuTotalGb + " GiB";

                    statsRoot.statsUpdated();
                } catch (e) {
                    console.error("SysStats JSON parse error:", e);
                }
            }
        }

        Component.onDestruction: running = false
        onStarted: statsRoot.sendProcessMode()
    }
    property int terminatingPid: -1
    property string terminatingProcessName: ""
    property string terminationError: ""
    property Timer terminationErrorTimer: Timer {
        interval: 3200

        onTriggered: statsRoot.terminationError = ""
    }
    property Process terminator: Process {
        id: terminator

        onExited: exitCode => {
            if (exitCode !== 0) {
                statsRoot.terminationError = qsTr("Could not end %1").arg(statsRoot.terminatingProcessName || qsTr("process"));
                statsRoot.terminationErrorTimer.restart();
            }
            statsRoot.terminatingPid = -1;
            statsRoot.terminatingProcessName = "";
        }
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
        pendingMemoryDetailsPid = -1;
        processMemoryDetails = null;
        processMemoryDetailsPid = -1;
        processMemoryDetailsRequestedPid = -1;
        processMemoryDetailsTimestamp = 0;
        if (memoryDetailsQuery.running) {
            memoryDetailsQuery.requestedPid = -1;
            memoryDetailsQuery.running = false;
        }
    }
    function clearProcessModels() {
        topCpu.clear();
        topRam.clear();
        topGpu.clear();
        clearProcessMemoryDetails();
        processRevision++;
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
    function getStatsLauncherPath() {
        return resolveLocalPath("../../backend/rust/system-stats/run-system-stats");
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
        if (memoryDetailsQuery.running) {
            if (memoryDetailsQuery.requestedPid !== processId)
                pendingMemoryDetailsPid = processId;
            return;
        }
        startProcessMemoryDetailsQuery(processId);
    }
    function resolveLocalPath(relativePath) {
        var path = Qt.resolvedUrl(relativePath).toString();
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        return path;
    }
    function sendProcessMode() {
        if (statsStream.running)
            statsStream.write(processMode + "\n");
    }
    function startProcessMemoryDetailsQuery(pid) {
        if (pid <= 1 || processMode !== "ram")
            return;
        memoryDetailsQuery.requestedPid = pid;
        memoryDetailsQuery.command = [getStatsLauncherPath(), "--process-memory", String(pid)];
        memoryDetailsQuery.running = true;
    }
    function terminateProcess(pid, name) {
        var processId = Math.trunc(Number(pid));
        if (processId <= 1 || terminator.running)
            return;

        terminationError = "";
        terminatingPid = processId;
        terminatingProcessName = String(name || "");
        terminator.command = [getStatsLauncherPath(), "--terminate-tree", String(processId)];
        terminator.running = true;
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

    onPollingEnabledChanged: {
        if (pollingEnabled) {
            prevCpuTotal = 0;
            prevCpuIdle = 0;
            downloadSpeed = "0 B/s";
            uploadSpeed = "0 B/s";
        } else {
            processMode = "none";
        }
    }
    onProcessModeChanged: {
        clearProcessModels();
        sendProcessMode();
    }
}
