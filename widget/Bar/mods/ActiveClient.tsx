import { Gtk } from "astal/gtk3";
import { Variable, bind, exec, GLib } from "astal";
import Gio from "gi://Gio";
import { sanitizeUtf8, truncateText } from "../../../utils/common";

const getActiveWindow = () => {
    const windows = JSON.parse(exec("niri msg --json windows"));

    for (const window of windows) {
        if (window.is_focused) {
            return window;
        }
    }
    return null;
};

export default () => {
    const active_window = Variable<any>(getActiveWindow() || {});

    let proc: Gio.Subprocess | null = null;
    try {
        proc = new Gio.Subprocess({
            argv: ["niri", "msg", "event-stream"],
            flags: Gio.SubprocessFlags.STDOUT_PIPE,
        });
        proc.init(null);
        const stdout = proc.get_stdout_pipe();
        const dataStream = new Gio.DataInputStream({
            base_stream: stdout,
        });

        const readLine = () => {
            dataStream.read_line_async(GLib.PRIORITY_DEFAULT, null, (stream, res) => {
                try {
                    if (!stream) return;
                    const [line] = stream.read_line_finish(res);
                    if (line !== null) {
                        active_window.set(getActiveWindow() || {});
                        readLine();
                    }
                } catch (err) {}
            });
        };
        readLine();
    } catch (err) {
        console.error("Failed to start niri event-stream in ActiveClient:", err);
        active_window.poll(1000, () => getActiveWindow() || {});
    }

    const cleanup = () => {
        active_window.drop();
        if (proc) {
            try {
                proc.force_exit();
            } catch (err) {}
        }
    };

    return (
        <box className={"ActiveClient"} onDestroy={cleanup}>
            <box vertical>
                <label
                    className={"app-id"}
                    halign={Gtk.Align.START}
                    label={bind(active_window).as((window: any) => {
                        return sanitizeUtf8(
                            window.app_id || "Desktop"
                        ).toLowerCase();
                    })}
                ></label>

                <label
                    className={"window-title"}
                    halign={Gtk.Align.START}
                    label={bind(active_window).as((window: any) => {
                        return truncateText(window.title || "niri", 40);
                    })}
                ></label>
            </box>
        </box>
    );
};
