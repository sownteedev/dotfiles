import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { bind, Variable, exec, GLib } from "astal";
import Auth from "gi://AstalAuth";

const passwordVar = Variable("");
const authenticating = Variable(false);
const errorMessage = Variable("");
const hasPasswordError = Variable(false);
const css = `background-image: url("/tmp/backdrop-lock.png"); background-size: cover;`;

function hide() {
    App.get_window("lock-screen")!.hide();
}

const Time = ({ time }: { time: Variable<string> }) => {
    return (
        <label
            className="TimeLockScreen"
            label={bind(time)}
        />
    );
};

const Date = ({ date }: { date: Variable<string> }) => {
    return (
        <label
            className={"DateLockScreen"}
            label={bind(date)}
        />
    );
};

const MediaPlayer = () => {};

export const LockScreen = () => {
    let pam: any = null;
    let timeoutId: number | null = null;
    let passwordEntry: Gtk.Entry | null = null;
    let clockTimerId: number | null = null;

    const time = Variable("");
    const date = Variable("");

    const updateClock = () => {
        const now = GLib.DateTime.new_now_local();
        time.set(now.format("%H : %M")!);
        date.set(now.format("%A, %d %B %Y")!);
        return true;
    };

    const startClock = () => {
        updateClock();
        if (!clockTimerId) {
            clockTimerId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, updateClock);
        }
    };

    const stopClock = () => {
        if (clockTimerId) {
            GLib.source_remove(clockTimerId);
            clockTimerId = null;
        }
    };

    const resetState = () => {
        authenticating.set(false);
        passwordVar.set("");
        if (timeoutId) {
            GLib.source_remove(timeoutId);
            timeoutId = null;
        }
    };

    const authenticate = () => {
        if (passwordVar.get() === "") return;

        authenticating.set(true);
        errorMessage.set("");
        hasPasswordError.set(false);

        if (timeoutId) {
            GLib.source_remove(timeoutId);
        }

        timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 5000, () => {
            resetState();
            if (pam) {
                pam = null;
            }
            return false;
        });

        try {
            const success = Auth.Pam.authenticate(
                passwordVar.get(),
                (_: any, task: any) => {
                    if (timeoutId) {
                        GLib.source_remove(timeoutId);
                        timeoutId = null;
                    }

                    try {
                        Auth.Pam.authenticate_finish(task);
                        hide();
                        resetState();
                    } catch (error) {
                        errorMessage.set("Wrong password. Please try again.");
                        hasPasswordError.set(true);
                        authenticating.set(false);
                        // Keep password and focus cursor on entry
                        if (passwordEntry) {
                            passwordEntry.grab_focus();
                        }
                    }
                }
            );

            if (!success) {
                errorMessage.set("Failed to start authentication");
                hasPasswordError.set(true);
                authenticating.set(false);
                if (passwordEntry) {
                    passwordEntry.grab_focus();
                }
            }
        } catch (error) {
            errorMessage.set("Authentication error occurred");
            hasPasswordError.set(true);
            authenticating.set(false);
            if (passwordEntry) {
                passwordEntry.grab_focus();
            }
        }
    };

    const cleanup = () => {
        if (timeoutId) {
            GLib.source_remove(timeoutId);
            timeoutId = null;
        }
        stopClock();
        passwordVar.drop();
        authenticating.drop();
        errorMessage.drop();
        hasPasswordError.drop();
        time.drop();
        date.drop();
    };

    return (
        <window
            name="lock-screen"
            layer={Astal.Layer.OVERLAY}
            anchor={
                Astal.WindowAnchor.TOP |
                Astal.WindowAnchor.LEFT |
                Astal.WindowAnchor.RIGHT |
                Astal.WindowAnchor.BOTTOM
            }
            keymode={Astal.Keymode.EXCLUSIVE}
            application={App}
            className="lock-screen"
            css={css}
            exclusivity={Astal.Exclusivity.IGNORE}
            visible={false}
            onShow={startClock}
            onHide={() => {
                stopClock();
                resetState();
            }}
            onDestroy={cleanup}
        >
            <centerbox vertical>
                <box
                    halign={Gtk.Align.CENTER}
                    valign={Gtk.Align.CENTER}
                    vertical
                >
                    <Time time={time} />
                    <Date date={date} />
                </box>
                <box halign={Gtk.Align.CENTER}>{/* <MediaPlayer /> */}</box>
                <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                    <box
                        className={bind(hasPasswordError).as((error) =>
                            error
                                ? "password-entry-box error"
                                : "password-entry-box"
                        )}
                    >
                        <entry
                            className={"password-entry"}
                            visibility={false}
                            onActivate={authenticate}
                            xalign={0.5}
                            placeholderText="Enter your password"
                            sensitive={bind(authenticating).as((auth) => !auth)}
                            setup={(self: Gtk.Entry) => {
                                passwordEntry = self;
                            }}
                            onChanged={(self: Gtk.Entry) => {
                                passwordVar.set(self.text);
                                if (hasPasswordError.get()) {
                                    hasPasswordError.set(false);
                                }
                                if (self.text.length > 0) {
                                    self.get_style_context()?.add_class(
                                        "has-text"
                                    );
                                } else {
                                    self.get_style_context()?.remove_class(
                                        "has-text"
                                    );
                                }
                            }}
                            text={bind(passwordVar)}
                        />
                    </box>
                </box>
            </centerbox>
        </window>
    );
};

export default LockScreen;
