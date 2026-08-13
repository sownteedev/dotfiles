pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool available: true
    readonly property bool busy: checking || upgrading
    property Process checkProcess: Process {
        command: ["sh", "-c", "if ! command -v yay >/dev/null 2>&1; then printf '__YAY_MISSING__\\n'; exit 0; fi\n" + "if command -v checkupdates >/dev/null 2>&1; then\n" + "    repo_updates=$(checkupdates 2>&1); repo_status=$?\n" + "    if [ \"$repo_status\" -eq 2 ]; then repo_updates=''; repo_status=0; fi\n" + "else\n" + "    repo_updates=$(yay -Qu --repo --color never 2>&1); repo_status=$?\n" + "    if [ \"$repo_status\" -eq 1 ] && [ -z \"$repo_updates\" ]; then repo_status=0; fi\n" + "fi\n" + "aur_updates=$(yay -Qua --color never 2>&1); aur_status=$?\n" + "if [ \"$aur_status\" -eq 1 ] && [ -z \"$aur_updates\" ]; then aur_status=0; fi\n" + "if [ \"$repo_status\" -ne 0 ] || [ \"$aur_status\" -ne 0 ]; then printf '__CHECK_FAILED__\\n'; exit 0; fi\n" + "{ printf '%s\\n' \"$repo_updates\"; printf '%s\\n' \"$aur_updates\"; } | awk 'NF && !seen[$1]++'"]

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
            root.checking = false;
            root.lastCheckedAt = Date.now();
            if (!root.receivedResult && exitCode !== 0)
                root.error = "Could not check for updates";
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
    property string activeUpgradeResultPath: ""
    property int upgradePollMisses: 0
    property bool upgradeResultReceived: false
    property string upgradeResultText: ""
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
    property Timer upgradePollTimer: Timer {
        interval: 1500
        repeat: false

        onTriggered: root.pollUpgradeResult()
    }
    property bool upgrading: false
    property bool upgradeTerminalExited: false
    property Process upgradeTerminal: Process {
        onExited: (exitCode, exitStatus) => {
            root.upgradeTerminalExited = true;
            if (root.upgrading)
                root.pollUpgradeResult();
        }
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

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
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
        checkProcess.running = true;
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
    function upgrade() {
        if (!available || busy)
            return;

        // Keep yay and AUR builds unprivileged; pkexec is used only when yay
        // invokes pacman for the repository transaction.
        activeUpgradeResultPath = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-update-result-" + Date.now();
        upgradePollMisses = 0;
        upgradeResultReceived = false;
        upgradeResultText = "";
        upgradeTerminalExited = false;
        upgrading = true;
        error = "";
        var upgradeCommand = "result_file=" + shellQuote(activeUpgradeResultPath) + "; printf 'started\\n' > \"$result_file\"; " + "print -r -- 'Updating repository and AUR packages…'; print; " + "/usr/bin/yay --sudo /usr/bin/pkexec -Syu --noconfirm " + "--answerclean None --answerdiff None --answeredit None; result=$?; " + "printf '%s\\n' \"$result\" > \"$result_file\"; " + "print; " + "if [ $result -eq 0 ]; then print -r -- 'Upgrade complete.'; " + "else print -r -- \"Upgrade failed (exit $result).\"; fi; " + "print -rn -- 'Press any key to close…'; read -rk 1; exit $result";
        var terminalCommand = "exec /usr/bin/zsh -c " + shellQuote(upgradeCommand);
        upgradeTerminal.command = ["blackbox-terminal", "--command", terminalCommand];
        upgradeTerminal.running = true;
        upgradePollTimer.restart();
    }
}
