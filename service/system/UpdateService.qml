pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import ".."

QtObject {
    id: root

    property string activeUpgradeResultPath: ""
    property bool available: true
    readonly property bool busy: checking || upgrading
    property Timer checkWatchdog: Timer {
        interval: 55 * 1000
        repeat: false

        onTriggered: {
            if (!root.checking)
                return;
            root.checking = false;
            root.error = qsTr("Update check timed out");
            root.lastCheckedAt = Date.now();
        }
    }
    property bool checking: true
    property Connections coreConnections: Connections {
        function onUpdatesFailed(message) {
            root.checkWatchdog.stop();
            root.checking = false;
            root.error = message;
            root.lastCheckedAt = Date.now();
        }
        function onUpdatesUpdated(data) {
            root.applyResult(data);
        }

        target: CoreService
    }
    property string error: ""
    property double lastCheckedAt: 0
    property var packages: []
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

    function applyResult(result) {
        checkWatchdog.stop();
        checking = false;
        if (!result) {
            error = qsTr("Could not check for updates");
            lastCheckedAt = Date.now();
            return;
        }
        available = result.available !== false;
        error = String(result.error || "");
        lastCheckedAt = Number(result.checkedAt || Date.now());
        if (!available)
            packages = [];
        else if (error === "")
            packages = Array.isArray(result.packages) ? result.packages : [];
    }
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
        error = "";
        checkWatchdog.restart();
        CoreService.requestUpdateCheck(force === true);
    }
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
    }
    function upgrade() {
        if (!available || busy)
            return;

        activeUpgradeResultPath = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/sownteeshell-update-result-" + Date.now();
        upgradePollMisses = 0;
        upgradeResultReceived = false;
        upgradeResultText = "";
        upgradeTerminalExited = false;
        upgrading = true;
        error = "";
        var upgradeCommand = "exec " + shellQuote(Config.sownteeshellDir + "/scripts/system/package-updates.sh") + " upgrade " + shellQuote(activeUpgradeResultPath);
        var terminalCommand = "exec /usr/bin/zsh -c " + shellQuote(upgradeCommand);
        upgradeTerminal.command = ["blackbox-terminal", "--command", terminalCommand];
        upgradeTerminal.running = true;
        upgradePollTimer.restart();
    }

    Component.onCompleted: {
        CoreService.setUpdatesEnabled(true);
        checkWatchdog.restart();
    }
    Component.onDestruction: {
        checkWatchdog.stop();
        CoreService.setUpdatesEnabled(false);
    }
}
