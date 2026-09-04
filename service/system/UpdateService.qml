pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    property string activeUpgradeResultPath: ""
    property bool available: true
    readonly property bool busy: checking || upgrading
    property Process checkProcess: Process {
        command: [Config.quickshellDir + "/scripts/system/package-updates.sh", "check"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.receivedResult = true;
                var output = text.trim();
                if (output === "__YAY_MISSING__") {
                    root.available = false;
                    root.error = "yay is not installed";
                    root.packages = [];
                    return;
                }
                root.available = true;
                if (output === "__CHECK_FAILED__") {
                    root.error = "Could not check for updates";
                    return;
                }

                root.error = "";
                root.packages = output === "" ? [] : output.split(/\r?\n/);
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.checkTimeout.stop();
            root.checking = false;
            root.lastCheckedAt = Date.now();
            if (!root.receivedResult && exitCode !== 0 && root.error === "")
                root.error = "Could not check for updates";
        }
    }
    property Timer checkTimeout: Timer {
        interval: 45 * 1000
        repeat: false

        onTriggered: {
            if (!root.checking)
                return;
            root.checkProcess.running = false;
            root.checking = false;
            root.lastCheckedAt = Date.now();
            root.error = "Update check timed out";
        }
    }
    property bool checking: false
    property string error: ""
    property double lastCheckedAt: 0
    property var packages: []
    property Timer periodicRefresh: Timer {
        interval: 2 * 60 * 60 * 1000
        repeat: true
        running: true

        onTriggered: root.refresh(false)
    }
    property bool receivedResult: false
    property Timer startupRefresh: Timer {
        interval: 2500
        repeat: false
        running: true

        onTriggered: root.refresh(true)
    }
    readonly property string statusText: {
        if (!available)
            return "yay missing";
        if (upgrading)
            return "Updating…";
        if (checking)
            return "Checking…";
        if (error !== "")
            return "Check failed";
        if (updateCount === 0)
            return "Up to date";
        return updateCount + (updateCount === 1 ? " update" : " updates");
    }
    readonly property int updateCount: packages.length
    property int upgradePollMisses: 0
    property Timer upgradePollTimer: Timer {
        interval: 1500
        repeat: false

        onTriggered: root.pollUpgradeResult()
    }
    property Process upgradeResultQuery: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.upgradeResultText = text.trim();
                root.upgradeResultReceived = root.upgradeResultText !== "";
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.upgrading)
                return;
            if (exitCode === 0 && root.upgradeResultReceived) {
                if (root.upgradeResultText === "started") {
                    root.upgradePollMisses = 0;
                    root.upgradePollTimer.restart();
                } else {
                    root.finishUpgradeTracking();
                }
                return;
            }

            root.upgradePollMisses += 1;
            if (root.upgradeTerminalExited && root.upgradePollMisses >= 4) {
                console.warn("[UpdateService] Upgrade terminal exited without a result marker");
                root.finishUpgradeTracking();
                return;
            }
            root.upgradePollTimer.restart();
        }
    }
    property bool upgradeResultReceived: false
    property string upgradeResultText: ""
    property Process upgradeTerminal: Process {
        onExited: (exitCode, exitStatus) => {
            root.upgradeTerminalExited = true;
            if (root.upgrading)
                root.pollUpgradeResult();
        }
    }
    property bool upgradeTerminalExited: false
    property bool upgrading: false

    function finishUpgradeTracking() {
        var completedResultPath = activeUpgradeResultPath;
        upgradePollTimer.stop();
        upgrading = false;
        activeUpgradeResultPath = "";
        if (completedResultPath)
            Quickshell.execDetached(["rm", "-f", completedResultPath]);
        refresh(true);
    }
    function pollUpgradeResult() {
        if (!upgrading || !activeUpgradeResultPath)
            return;
        if (upgradeResultQuery.running) {
            upgradePollTimer.restart();
            return;
        }

        upgradeResultReceived = false;
        upgradeResultText = "";
        upgradeResultQuery.command = ["sh", "-c", "[ -s \"$1\" ] || exit 3; cat -- \"$1\"", "upgrade-result", activeUpgradeResultPath];
        upgradeResultQuery.running = true;
    }
    function refresh(force) {
        if (busy)
            return;
        if (!force && lastCheckedAt > 0 && Date.now() - lastCheckedAt < 15 * 60 * 1000)
            return;

        checking = true;
        receivedResult = false;
        error = "";
        checkProcess.running = false;
        checkTimeout.restart();
        checkProcess.running = true;
    }
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
    }
    function upgrade() {
        if (!available || busy)
            return;

        activeUpgradeResultPath = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-update-result-" + Date.now();
        upgradePollMisses = 0;
        upgradeResultReceived = false;
        upgradeResultText = "";
        upgradeTerminalExited = false;
        upgrading = true;
        error = "";
        var upgradeCommand = "exec " + shellQuote(Config.quickshellDir + "/scripts/system/package-updates.sh") + " upgrade " + shellQuote(activeUpgradeResultPath);
        var terminalCommand = "exec /usr/bin/zsh -c " + shellQuote(upgradeCommand);
        upgradeTerminal.command = ["blackbox-terminal", "--command", terminalCommand];
        upgradeTerminal.running = true;
        upgradePollTimer.restart();
    }
}
