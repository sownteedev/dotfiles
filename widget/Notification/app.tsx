import { Astal, Gtk, Gdk } from "astal/gtk3";
import Notifd from "gi://AstalNotifd";
import Notification from "./Notification";
import { type Subscribable } from "astal/binding";
import { Variable, bind, timeout } from "astal";
import GLib from "gi://GLib";

const TIMEOUT_DELAY = 5000;

class NotifiationMap implements Subscribable {
    // the underlying map to keep track of id widget pairs
    private map: Map<number, Gtk.Widget> = new Map();
    private timeouts: Map<number, number> = new Map();
    private signalIds: number[] = [];
    private notifd: Notifd.Notifd;

    // it makes sense to use a Variable under the hood and use its
    // reactivity implementation instead of keeping track of subscribers ourselves
    private var: Variable<Array<Gtk.Widget>> = Variable([]);

    // notify subscribers to rerender when state changes
    private notifiy() {
        this.var.set([...this.map.values()]);
    }

    constructor() {
        this.notifd = Notifd.get_default();

        /**
         * uncomment this if you want to
         * ignore timeout by senders and enforce our own timeout
         * note that if the notification has any actions
         * they might not work, since the sender already treats them as resolved
         */
        // notifd.ignoreTimeout = true

        const notifiedId = this.notifd.connect(
            "notified",
            (_: any, id: any) => {
                this.set(
                    id,
                    Notification({
                        notification: this.notifd.get_notification(id)!,

                        // When hovering, clear the timeout
                        onHover: () => {
                            const timeoutId = this.timeouts.get(id);
                            if (timeoutId) {
                                GLib.source_remove(timeoutId);
                                this.timeouts.delete(id);
                            }
                        },

                        // When mouse leaves, start a new timeout
                        onHoverLost: () => {
                            const timeoutId = timeout(TIMEOUT_DELAY, () => {
                                this.delete(id);
                            });
                            this.timeouts.set(id, Number(timeoutId));
                        },

                        // Setup initial timeout
                        setup: () => {
                            const timeoutId = timeout(TIMEOUT_DELAY, () => {
                                this.delete(id);
                            });
                            this.timeouts.set(id, Number(timeoutId));
                        },
                    })
                );
            }
        );
        this.signalIds.push(notifiedId);

        // notifications can be closed by the outside before
        // any user input, which have to be handled too
        const resolvedId = this.notifd.connect(
            "resolved",
            (_: any, id: any) => {
                this.delete(id);
            }
        );
        this.signalIds.push(resolvedId);
    }

    private set(key: number, value: Gtk.Widget) {
        // in case of replacecment destroy previous widget
        const old = this.map.get(key);
        if (old) {
            old.destroy();
        }

        const revealer = (
            <revealer
                transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
                transitionDuration={350}
                revealChild={false}
            >
                {value}
            </revealer>
        ) as Gtk.Revealer;

        this.map.set(key, revealer);
        this.notifiy();

        // Trigger the slide-down animation shortly after insertion
        timeout(50, () => {
            if (this.map.get(key) === revealer) {
                revealer.set_reveal_child(true);
            }
        });
    }

    private delete(key: number) {
        console.log(`Deleting notification ${key}`);
        const timeoutId = this.timeouts.get(key);
        if (timeoutId) {
            GLib.source_remove(timeoutId);
            this.timeouts.delete(key);
        }

        const revealer = this.map.get(key) as Gtk.Revealer | undefined;
        if (revealer) {
            revealer.set_reveal_child(false);

            // Wait for slide-up animation to complete before destroying the widget
            timeout(350, () => {
                if (this.map.get(key) === revealer) {
                    revealer.destroy();
                    this.map.delete(key);
                    this.notifiy();
                }
            });
        }
    }

    // needed by the Subscribable interface
    get() {
        return this.var.get();
    }

    // needed by the Subscribable interface
    subscribe(callback: (list: Array<Gtk.Widget>) => void) {
        return this.var.subscribe(callback);
    }

    // Cleanup method to prevent memory leaks
    cleanup() {
        // Clear all timeouts
        this.timeouts.forEach((timeoutId) => {
            GLib.source_remove(timeoutId);
        });
        this.timeouts.clear();

        // Destroy all widgets
        this.map.forEach((widget) => {
            widget.destroy();
        });
        this.map.clear();

        // Disconnect signal handlers
        this.signalIds.forEach((id) => {
            this.notifd.disconnect(id);
        });
        this.signalIds = [];

        // Drop the Variable
        this.var.drop();
    }
}

export default function NotificationPopups(gdkmonitor: Gdk.Monitor) {
    const { TOP } = Astal.WindowAnchor;
    const notifs = new NotifiationMap();

    return (
        <window
            className="NotificationPopups"
            gdkmonitor={gdkmonitor}
            anchor={TOP}
            onDestroy={() => notifs.cleanup()}
        >
            <box vertical noImplicitDestroy>
                {bind(notifs)}
            </box>
        </window>
    );
}
