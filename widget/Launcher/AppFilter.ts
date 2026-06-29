import Apps from "gi://AstalApps";
import GLib from "gi://GLib";

function isExecutableValid(exec: string | null): boolean {
    if (!exec) return false;
    const tokens = exec.trim().split(/\s+/).map(t => {
        if ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'"))) {
            return t.slice(1, -1);
        }
        return t;
    });
    if (tokens.length === 0) return false;
    let binaryIndex = 0;
    if (tokens[0] === "env") {
        binaryIndex = 1;
        while (binaryIndex < tokens.length && tokens[binaryIndex].includes("=")) {
            binaryIndex++;
        }
    }
    if (binaryIndex >= tokens.length) return false;
    const binary = tokens[binaryIndex];
    if (GLib.path_is_absolute(binary)) {
        return GLib.file_test(binary, GLib.FileTest.IS_EXECUTABLE);
    } else {
        return GLib.find_program_in_path(binary) !== null;
    }
}

export function filterApp(app: Apps.Application): boolean {
    // 1. Basic GDesktopAppInfo controls
    if (app.app) {
        if (typeof app.app.should_show === 'function' && !app.app.should_show()) {
            return false;
        }
        if (typeof app.app.get_nodisplay === 'function' && app.app.get_nodisplay()) {
            return false;
        }
        // Terminal check: hide apps that require terminal
        if (typeof (app.app as any).get_string === "function") {
            const isTerminal = (app.app as any).get_string("Terminal") === "true";
            if (isTerminal) return false;
        }
    }

    // 2. Check if binary is runnable on the system
    if (!isExecutableValid(app.executable)) {
        return false;
    }

    return true;
}
