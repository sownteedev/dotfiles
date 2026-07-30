pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool available: true
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
    property Timer postUpgradeRefresh: Timer {
        interval: 2 * 60 * 1000
        repeat: false

        onTriggered: root.refresh(true)
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
        if (checking)
            return "Checking…";
        if (error !== "")
            return "Check failed";
        if (updateCount === 0)
            return "Up to date";
        return updateCount + (updateCount === 1 ? " update" : " updates");
    }
    readonly property int updateCount: packages.length

    function refresh(force) {
        if (checking)
            return;
        if (!force && lastCheckedAt > 0 && Date.now() - lastCheckedAt < 15 * 60 * 1000)
            return;

        checking = true;
        receivedResult = false;
        error = "";
        checkProcess.running = false;
        checkProcess.running = true;
    }
    function upgrade() {
        if (!available || checking)
            return;

        // Authenticate once for the whole transaction. SUDO_USER tells yay to
        // drop back to the desktop user for AUR downloads and package builds.
        var upgradeCommand = "update_user=$(/usr/bin/id -un); update_home=$HOME; " + "print -r -- 'Updating repository and AUR packages…'; print; " + "/usr/bin/pkexec /usr/bin/env SUDO_USER=\"$update_user\" USER=\"$update_user\" " + "HOME=\"$update_home\" /usr/bin/yay -Syu --noconfirm " + "--answerclean None --answerdiff None --answeredit None; result=$?; " + "print; " + "if [ $result -eq 0 ]; then print -r -- 'Upgrade complete.'; " + "else print -r -- \"Upgrade failed (exit $result).\"; fi; " + "print -rn -- 'Press any key to close…'; read -rk 1; exit $result";
        Quickshell.execDetached(["blackbox-terminal", "--", "/usr/bin/zsh", "-c", upgradeCommand]);
        postUpgradeRefresh.restart();
    }
}
