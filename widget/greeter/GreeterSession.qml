pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Services.Pam

QtObject {
    id: root

    property string activeUser: configuredUser
    property bool authenticationFailed: false
    property var authenticationNotices: []
    property int authenticationRevision: 0
    readonly property bool checkingLockout: lockoutStatusProcess.running || lockoutCheckPending
    readonly property string configuredUser: Quickshell.env("GREETD_DEFAULT_USER") || ""
    readonly property string defaultSessionId: String(greeterSettings.defaultSession || "niri")
    readonly property string displayMessage: {
        if (!hasError || !authenticationFailed || lockoutUser !== activeUser || lockoutReason === "")
            return message;
        if (lockoutPermanent)
            return lockoutReason + "\n" + qsTr("Contact your administrator to unlock the account.");
        if (lockoutRemainingSeconds === 0)
            return lockoutExact ? qsTr("Wait has ended. Try signing in again.") : qsTr("Estimated wait has ended. Try signing in again.");
        var minutes = String(Math.floor(lockoutRemainingSeconds / 60)).padStart(2, "0");
        var seconds = String(lockoutRemainingSeconds % 60).padStart(2, "0");
        return lockoutReason + "\n" + (lockoutExact ? qsTr("Try again in %1") : qsTr("Try again in about %1")).arg(minutes + ":" + seconds);
    }
    readonly property int exitTransitionDuration: 400
    readonly property var fallbackSession: ({
            "id": "niri",
            "name": "Niri",
            "comment": qsTr("Scrollable Wayland compositor"),
            "desktop": "niri",
            "command": ["niri-session"]
        })
    readonly property bool greetdAvailable: !pamTestMode && Greetd.available
    property Connections greetdConnections: Connections {
        function onAuthFailure(failureMessage) {
            root.failAuthentication(root.authenticationFailureMessage(false), true);
        }
        function onAuthMessage(authMessage, error, responseRequired, echoResponse) {
            root.prompt = authMessage || qsTr("Password");
            if (!responseRequired) {
                root.rememberAuthenticationNotice(authMessage);
                root.hasError = error;
                root.message = root.authenticationNotices.join("\n");
                return;
            }
            if (root.pendingResponse !== "") {
                var response = root.pendingResponse;
                root.pendingResponse = "";
                Greetd.respond(response);
                return;
            }
            root.waitingForResponse = true;
            root.working = false;
            root.hasError = error;
            root.message = error ? authMessage : "";
            root.inputResetRequested();
        }
        function onError(errorMessage) {
            if (root.authenticationFailed && !root.working && !root.launching && Greetd.state === GreetdState.Inactive && errorMessage === "unable to send message: Connection refused (os error 111)")
                return;
            root.failAuthentication(errorMessage || qsTr("The greeter lost its connection"), false);
        }
        function onLaunched() {
            root.message = qsTr("Opening %1…").arg(root.sessionLabel);
        }
        function onReadyToLaunch() {
            root.authenticationRevision++;
            root.lockoutCheckPending = false;
            root.authenticationFailed = false;
            root.authenticationNotices = [];
            root.resetLockoutCountdown();
            root.hasError = false;
            root.message = qsTr("Opening %1…").arg(root.sessionLabel);
            root.working = true;
            root.launching = true;
            if (root.rememberLastSession)
                lastSessionState.sessionId = String(root.selectedSession.id || "");
            root.launchTimer.restart();
        }

        target: root.pamTestMode ? null : Greetd
    }
    property FileView greeterSettingsFile: FileView {
        blockLoading: true
        path: Quickshell.env("GREETD_SETTINGS_PATH") || "/var/lib/sownteeshell/greeter/settings.json"
        printErrors: false
        watchChanges: true

        adapter: JsonAdapter {
            id: greeterSettings

            property string defaultSession: "niri"
            property bool rememberLastSession: false
        }

        onFileChanged: reload()
    }
    property bool hasError: false
    readonly property string hostName: hostNameFile.loaded ? hostNameFile.text().trim() : ""
    property FileView hostNameFile: FileView {
        path: "/proc/sys/kernel/hostname"
        printErrors: false
    }
    property FileView lastSessionFile: FileView {
        atomicWrites: true
        path: (Quickshell.env("XDG_CACHE_HOME") || "/tmp") + "/last-session.json"
        printErrors: false

        adapter: JsonAdapter {
            id: lastSessionState

            property string sessionId: ""
        }

        onAdapterUpdated: writeAdapter()
    }
    readonly property string lastSessionId: String(lastSessionState.sessionId || "")
    property Timer launchTimer: Timer {
        interval: root.exitTransitionDuration + 80

        onTriggered: {
            if (root.pamTestMode) {
                Qt.quit();
                return;
            }
            var desktop = String(root.selectedSession.desktop || root.selectedSession.id || "");
            var sessionId = String(root.selectedSession.id || desktop);
            Greetd.launch(root.sessionCommand, ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=" + desktop, "XDG_SESSION_DESKTOP=" + sessionId, "DESKTOP_SESSION=" + sessionId], true);
        }
    }
    property bool launching: false
    property bool lockoutCheckPending: false
    property int lockoutCheckRevision: -1
    property string lockoutCheckUser: ""
    property double lockoutDeadline: 0
    property bool lockoutExact: false
    property string lockoutNotice: ""
    property bool lockoutPermanent: false
    property string lockoutReason: ""
    property int lockoutRemainingSeconds: 0
    property Process lockoutStatusProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.applyLockoutStatus(text, root.lockoutCheckRevision, root.lockoutCheckUser)
        }

        onExited: Qt.callLater(root.checkLockoutStatus)
    }
    property Timer lockoutTimer: Timer {
        interval: 1000
        repeat: true
        running: root.lockoutDeadline > 0 && root.lockoutRemainingSeconds > 0

        onTriggered: root.updateLockoutCountdown()
    }
    property string lockoutUser: ""
    property string message: ""
    readonly property bool pamTestMode: Quickshell.env("SOWNTEE_GREETER_PAM_TEST") === "1"
    property string pendingResponse: ""
    property string prompt: qsTr("Password")
    readonly property bool rememberLastSession: greeterSettings.rememberLastSession
    readonly property var selectedSession: sessions.length > 0 ? sessions[Math.max(0, Math.min(selectedSessionIndex, sessions.length - 1))] : fallbackSession
    property int selectedSessionIndex: 0
    readonly property var sessionCommand: ["systemd-cat", "--identifier=greetd-session", "--"].concat(selectedSession.command)
    readonly property string sessionHelper: Quickshell.env("SOWNTEE_CORE_BINARY") || Quickshell.shellPath("../../backend/rust/core-daemon/run-core-daemon")
    readonly property string sessionLabel: selectedSession.name
    property Process sessionScanner: Process {
        command: [root.sessionHelper, "greeter-sessions"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.loadSessions(text)
        }
    }
    property var sessions: [fallbackSession]
    property PamContext testPam: PamContext {
        config: "greetd"
        user: root.configuredUser

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.authenticationRevision++;
                root.lockoutCheckPending = false;
                root.pendingResponse = "";
                root.waitingForResponse = false;
                root.authenticationFailed = false;
                root.authenticationNotices = [];
                root.resetLockoutCountdown();
                root.hasError = false;
                root.message = qsTr("PAM verified. Closing test without starting a session.");
                root.working = true;
                root.launching = true;
                root.inputResetRequested();
                root.launchTimer.restart();
            } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
                root.failAuthentication(root.authenticationFailureMessage(result === PamResult.MaxTries), true);
            } else if (!root.hasError) {
                root.failAuthentication(qsTr("PAM authentication could not complete."), false);
            }
        }
        onError: error => root.failAuthentication(qsTr("PAM error: %1").arg(PamError.toString(error)), false)
        onPamMessage: {
            root.prompt = message || qsTr("Password");
            if (!responseRequired) {
                root.rememberAuthenticationNotice(message);
                root.hasError = messageIsError;
                root.message = root.authenticationNotices.join("\n");
                return;
            }
            if (root.pendingResponse !== "" && !responseVisible) {
                var response = root.pendingResponse;
                root.pendingResponse = "";
                respond(response);
                return;
            }
            root.pendingResponse = "";
            root.waitingForResponse = true;
            root.working = false;
            root.hasError = messageIsError;
            root.message = message;
            root.inputResetRequested();
        }
    }
    property bool waitingForResponse: false
    property bool working: false

    signal inputResetRequested

    function applyLockoutStatus(output, revision, user) {
        if (revision !== authenticationRevision || user !== activeUser || !authenticationFailed || working || launching)
            return;
        var status;
        try {
            status = JSON.parse(output);
        } catch (error) {
            return;
        }
        if (status.known !== true)
            return;
        if (status.locked !== true) {
            if (lockoutUser === user && lockoutReason !== "") {
                resetLockoutCountdown();
                message = qsTr("Lockout is no longer active. Try signing in again.");
            }
            return;
        }
        var deadline = Number(status.unlockAt);
        var failures = Number(status.failures);
        if (!Number.isFinite(deadline) || deadline < 0 || !Number.isFinite(failures) || failures < 1)
            return;
        lockoutUser = user;
        lockoutReason = qsTr("The account is locked due to %1 failed logins.").arg(failures);
        lockoutExact = true;
        lockoutPermanent = deadline === 0;
        lockoutDeadline = deadline;
        updateLockoutCountdown();
    }
    function applyPreferredSession() {
        if (sessions.length === 0 || working)
            return;
        var preferred = "";
        if (rememberLastSession && lastSessionId !== "")
            preferred = lastSessionId;
        else if (defaultSessionId.toLowerCase() !== "auto")
            preferred = defaultSessionId;
        else
            preferred = String(Quickshell.env("GREETD_SESSION_NAME") || "");
        preferred = preferred.toLowerCase();

        var nextIndex = 0;
        var niriIndex = -1;
        for (var index = 0; index < sessions.length; ++index) {
            var session = sessions[index];
            var sessionId = String(session.id || "").toLowerCase();
            var sessionName = String(session.name || "").toLowerCase();
            if (sessionId === "niri")
                niriIndex = index;
            if (preferred !== "" && (sessionId === preferred || sessionName === preferred)) {
                selectedSessionIndex = index;
                return;
            }
        }
        selectedSessionIndex = niriIndex >= 0 ? niriIndex : nextIndex;
    }
    function authenticationFailureMessage(maxTries) {
        if (authenticationNotices.length > 0)
            return authenticationNotices.join("\n");
        if (maxTries)
            return qsTr("Maximum authentication attempts reached. Wait before trying again or contact your administrator.");
        return qsTr("Authentication failed. Check your credentials and try again.");
    }
    function cancel() {
        authenticationRevision++;
        lockoutCheckPending = false;
        launchTimer.stop();
        if (testPam.active)
            testPam.abort();
        if (greetdAvailable && Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();

        pendingResponse = "";
        launching = false;
        waitingForResponse = false;
        working = false;
        authenticationFailed = false;
        authenticationNotices = [];
        hasError = false;
        message = "";
    }
    function checkLockoutStatus() {
        if (!lockoutCheckPending || lockoutStatusProcess.running)
            return;
        lockoutCheckPending = false;
        lockoutCheckRevision = authenticationRevision;
        lockoutCheckUser = activeUser;
        lockoutStatusProcess.command = [sessionHelper, "greeter-auth-status", activeUser];
        lockoutStatusProcess.running = true;
    }
    function failAuthentication(errorMessage, rejected) {
        launchTimer.stop();
        authenticationFailed = rejected;
        launching = false;
        pendingResponse = "";
        waitingForResponse = false;
        working = false;
        hasError = true;
        message = errorMessage;
        if (rejected) {
            lockoutCheckPending = true;
            checkLockoutStatus();
        }
        inputResetRequested();
    }
    function loadSessions(output) {
        var discovered;
        try {
            discovered = JSON.parse(String(output || "[]"));
        } catch (error) {
            console.warn("[GreeterSession] Invalid session list:", error);
            return;
        }
        if (!Array.isArray(discovered) || discovered.length === 0)
            return;

        sessions = discovered;
        applyPreferredSession();
    }
    function powerOff() {
        if (!greetdAvailable) {
            message = qsTr("Preview mode · power off is disabled");
            return;
        }
        Quickshell.execDetached(["poweroff"]);
    }
    function reboot() {
        if (!greetdAvailable) {
            message = qsTr("Preview mode · restart is disabled");
            return;
        }
        Quickshell.execDetached(["reboot"]);
    }
    function rememberAuthenticationNotice(notice) {
        var text = String(notice || "").trim();
        if (text !== "" && authenticationNotices.indexOf(text) === -1) {
            authenticationNotices = authenticationNotices.concat([text]);
            var match = /^\((\d+) minutes? left to unlock\)$/.exec(text);
            if (match) {
                var seconds = Number(match[1]) * 60;
                if (seconds > 0 && seconds <= 2147483647) {
                    lockoutNotice = text;
                    var deadline = Date.now() + seconds * 1000;
                    if (lockoutUser === activeUser && (lockoutDeadline > Date.now() || lockoutPermanent)) {
                        if (!lockoutExact && !lockoutPermanent)
                            lockoutDeadline = Math.min(lockoutDeadline, deadline);
                    } else {
                        lockoutUser = activeUser;
                        lockoutDeadline = deadline;
                        lockoutPermanent = false;
                        lockoutExact = false;
                    }
                    lockoutReason = authenticationNotices.filter(notice => notice !== text).join("\n") || qsTr("Account temporarily locked.");
                    updateLockoutCountdown();
                }
            }
        }
    }
    function resetLockoutCountdown() {
        lockoutDeadline = 0;
        lockoutRemainingSeconds = 0;
        lockoutNotice = "";
        lockoutReason = "";
        lockoutUser = "";
        lockoutExact = false;
        lockoutPermanent = false;
    }
    function respond(response) {
        if ((!greetdAvailable && !pamTestMode) || !waitingForResponse)
            return;

        waitingForResponse = false;
        working = true;
        authenticationFailed = false;
        hasError = false;
        message = qsTr("Checking credentials…");
        if (pamTestMode)
            testPam.respond(response);
        else
            Greetd.respond(response);
    }
    function selectSession(index) {
        if (index < 0 || index >= sessions.length || working)
            return;

        selectedSessionIndex = index;
        hasError = false;
        message = "";
    }
    function start(user, password) {
        if (working || launching || checkingLockout)
            return;
        var loginName = String(user || configuredUser).trim();
        if (loginName === "") {
            message = qsTr("Enter a user name");
            return;
        }
        if (password === "") {
            message = qsTr("Enter your password");
            return;
        }
        if (!greetdAvailable && !pamTestMode) {
            failAuthentication(qsTr("Greetd is not connected. Use Test Greeter for PAM authentication."), false);
            return;
        }
        if (pamTestMode && (configuredUser === "" || loginName !== configuredUser)) {
            failAuthentication(qsTr("PAM test only supports the current desktop user."), false);
            return;
        }
        updateLockoutCountdown();
        if (lockoutUser === loginName && (lockoutPermanent || lockoutRemainingSeconds > 0)) {
            activeUser = loginName;
            hasError = true;
            authenticationFailed = true;
            message = lockoutReason;
            lockoutCheckPending = true;
            checkLockoutStatus();
            inputResetRequested();
            return;
        }
        resetLockoutCountdown();
        cancel();
        activeUser = loginName;
        pendingResponse = password;
        message = qsTr("Starting authentication…");
        working = true;
        if (pamTestMode) {
            if (!testPam.start())
                failAuthentication(qsTr("Unable to start PAM authentication."), false);
        } else {
            Greetd.createSession(loginName);
        }
    }
    function updateLockoutCountdown() {
        lockoutRemainingSeconds = Math.max(0, Math.ceil((lockoutDeadline - Date.now()) / 1000));
    }

    onDefaultSessionIdChanged: applyPreferredSession()
    onLastSessionIdChanged: applyPreferredSession()
    onRememberLastSessionChanged: applyPreferredSession()
}
