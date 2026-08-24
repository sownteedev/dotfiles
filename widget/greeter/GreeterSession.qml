pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

QtObject {
    id: root

    property string activeUser: configuredUser
    readonly property string configuredUser: Quickshell.env("GREETD_DEFAULT_USER") || ""
    readonly property var fallbackSession: ({
            "id": "niri",
            "name": "Niri",
            "comment": qsTr("Scrollable Wayland compositor"),
            "desktop": "niri",
            "command": ["niri-session"]
        })
    readonly property bool greetdAvailable: Greetd.available
    property Connections greetdConnections: Connections {
        function onAuthFailure(failureMessage) {
            root.launching = false;
            root.pendingResponse = "";
            root.waitingForResponse = false;
            root.working = false;
            root.message = failureMessage || qsTr("Authentication failed");
            root.inputResetRequested();
        }
        function onAuthMessage(authMessage, error, responseRequired, echoResponse) {
            root.prompt = authMessage || qsTr("Password");
            if (!responseRequired) {
                root.message = authMessage;
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
            root.message = error ? authMessage : "";
            root.inputResetRequested();
        }
        function onError(errorMessage) {
            root.launching = false;
            root.pendingResponse = "";
            root.waitingForResponse = false;
            root.working = false;
            root.message = errorMessage || qsTr("The greeter lost its connection");
            root.inputResetRequested();
        }
        function onLaunched() {
            root.message = qsTr("Opening %1…").arg(root.sessionLabel);
        }
        function onReadyToLaunch() {
            root.message = qsTr("Opening %1…").arg(root.sessionLabel);
            root.working = true;
            root.launching = true;
            root.launchTimer.restart();
        }

        target: Greetd
    }
    property Timer launchTimer: Timer {
        interval: 280

        onTriggered: {
            var desktop = String(root.selectedSession.desktop || root.selectedSession.id || "");
            var sessionId = String(root.selectedSession.id || desktop);
            Greetd.launch(root.sessionCommand, ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=" + desktop, "XDG_SESSION_DESKTOP=" + sessionId, "DESKTOP_SESSION=" + sessionId], true);
        }
    }
    property bool launching: false
    property string message: ""
    property string pendingResponse: ""
    property string prompt: qsTr("Password")
    readonly property var selectedSession: sessions.length > 0 ? sessions[Math.max(0, Math.min(selectedSessionIndex, sessions.length - 1))] : fallbackSession
    property int selectedSessionIndex: 0
    readonly property var sessionCommand: ["systemd-cat", "--identifier=greetd-session", "--"].concat(selectedSession.command)
    readonly property string sessionLabel: selectedSession.name
    property Process sessionScanner: Process {
        command: ["python3", Quickshell.shellPath("scripts/list_sessions.py")]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.loadSessions(text)
        }
    }
    property var sessions: [fallbackSession]
    property bool waitingForResponse: false
    property bool working: false

    signal inputResetRequested

    function cancel() {
        if (Greetd.available && Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();

        pendingResponse = "";
        launching = false;
        waitingForResponse = false;
        working = false;
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
        var preferred = String(Quickshell.env("GREETD_SESSION_NAME") || "").toLowerCase();
        var nextIndex = 0;
        for (var i = 0; i < sessions.length; ++i) {
            var session = sessions[i];
            if (preferred !== "" && (String(session.name).toLowerCase() === preferred || String(session.id).toLowerCase() === preferred)) {
                nextIndex = i;
                break;
            }
            if (preferred === "" && String(session.id).toLowerCase() === "niri")
                nextIndex = i;
        }
        selectedSessionIndex = nextIndex;
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
    function respond(response) {
        if (!Greetd.available || !waitingForResponse)
            return;

        waitingForResponse = false;
        working = true;
        message = qsTr("Checking credentials…");
        Greetd.respond(response);
    }
    function selectSession(index) {
        if (index < 0 || index >= sessions.length || working)
            return;

        selectedSessionIndex = index;
        message = "";
    }
    function start(user, password) {
        var loginName = String(user || configuredUser).trim();
        if (loginName === "") {
            message = qsTr("Enter a user name");
            return;
        }
        if (password === "") {
            message = qsTr("Enter your password");
            return;
        }
        if (!Greetd.available) {
            message = qsTr("Preview mode · greetd is not connected");
            return;
        }
        cancel();
        activeUser = loginName;
        pendingResponse = password;
        message = qsTr("Starting authentication…");
        working = true;
        Greetd.createSession(loginName);
    }
}
