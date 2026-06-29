import { bind, GLib, Variable } from "astal";
import { Astal, Gtk } from "astal/gtk3";
import Notifd from "gi://AstalNotifd";
import { fileExists } from "../../../../utils/file";

const iconCache = new Map<string, boolean>();
const MAX_CACHE_SIZE = 500;

const isIcon = (icon: string) => {
    if (!icon) return false;
    if (iconCache.has(icon)) return iconCache.get(icon);

    const result = !!Astal.Icon.lookup_icon(icon);

    // Limit cache size to prevent memory leak
    if (iconCache.size >= MAX_CACHE_SIZE) {
        const firstKey = iconCache.keys().next().value;
        if (firstKey) {
            iconCache.delete(firstKey);
        }
    }

    iconCache.set(icon, result);
    return result;
};
const formatTimeAgo = (time: number, now: number): string => {
    const diff = now - time;
 
    if (diff < 60) {
        return "now";
    }
 
    if (diff < 3600) {
        const minutes = Math.floor(diff / 60);
        return `${minutes}m ago`;
    }
 
    if (diff < 86400) {
        const hours = Math.floor(diff / 3600);
        return `${hours}h ago`;
    }
 
    const date = GLib.DateTime.new_from_unix_local(time);
    const day = date.get_day_of_month().toString().padStart(2, "0");
    const month = date.get_month().toString().padStart(2, "0");
    const year = date.get_year().toString();
 
    const dateNow = GLib.DateTime.new_from_unix_local(now);
    const currentYear = dateNow.get_year();
    if (date.get_year() === currentYear) {
        return `${day}/${month}`;
    }
 
    return `${day}/${month}/${year}`;
};

const NotificationList = () => {
    const notifd = Notifd.get_default();
    const notifications = Variable<any[]>(notifd.notifications);
    const allNotifications = Variable<any[]>([...notifd.notifications]);
    const notificationCount = Variable(allNotifications.get().length);

    const timeRefresher = Variable(Date.now());

    // Store timeout IDs for cleanup
    let timeRefresherId: number | null = null;
    let notificationConnections: number[] = [];

    // Cleanup function
    const cleanup = () => {
        if (timeRefresherId) {
            GLib.source_remove(timeRefresherId);
            timeRefresherId = null;
        }
        // Disconnect signal handlers
        notificationConnections.forEach((id) => {
            if (notifd.disconnect) {
                notifd.disconnect(id);
            }
        });
        notificationConnections = [];
        // Cleanup variables
        notifications.drop();
        allNotifications.drop();
        notificationCount.drop();
        timeRefresher.drop();
    };

    timeRefresherId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 60000, () => {
        timeRefresher.set(Date.now());
        return true;
    });

    // Setup notification handlers only once
    const notifiedId = notifd.connect(
        "notified",
        (_source: any, id: any, replaced: any) => {
            const notification = notifd.get_notification(id);
            const currentNotifs = [...notifd.notifications];

            if (notification) {
                if (replaced) {
                    // If replaced, update the existing notification in allNotifications
                    const existing = allNotifications.get();
                    const updated = existing.map((n) =>
                        n.id === id ? notification : n,
                    );
                    allNotifications.set(updated);
                } else {
                    // New notification, add to the beginning
                    allNotifications.set([
                        notification,
                        ...allNotifications.get(),
                    ]);
                }
            }

            // Sync notifications with current notifd state
            notifications.set(currentNotifs);
            // allNotifications is already updated above (adds new or replaces existing)
            // Don't override it with currentNotifs to preserve history
            notificationCount.set(currentNotifs.length);
        },
    );

    const resolvedId = notifd.connect(
        "resolved",
        (_source: any, id: any, reason: any) => {
            const currentNotifs = [...notifd.notifications];
            // Only sync notifications with current notifd state
            // Keep allNotifications as history - don't remove notifications that were resolved externally
            notifications.set(currentNotifs);
            // Don't update allNotifications here - keep it as a history of all received notifications
            // Only update notificationCount based on current active notifications
            notificationCount.set(currentNotifs.length);
        },
    );

    notificationConnections.push(notifiedId, resolvedId);

    const NotificationItem = ({ notification }: { notification: any }) => {
        const showActions = Variable(false);
        const reveal = Variable(true);
        const dragX = Variable(0);
        const dragOpacity = Variable(1.0);
        let startX = 0;
        let isDragging = false;
        let snapTimerId: number | null = null;

        const dismissWithAnim = () => {
            reveal.set(false);
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
                if (typeof notification.dismiss === "function") {
                    notification.dismiss();
                }

                const currentNotifs = allNotifications.get();
                const filteredNotifs = currentNotifs.filter(
                    (n) => n.id !== notification.id,
                );

                allNotifications.set(filteredNotifs);
                notifications.set(
                    [...notifd.notifications].filter(
                        (n) => n.id !== notification.id,
                    ),
                );
                notificationCount.set(filteredNotifs.length);
                return false;
            });
        };

        const snapBack = () => {
            if (snapTimerId) {
                GLib.source_remove(snapTimerId);
            }
            const startValX = dragX.get();
            const startValOpacity = dragOpacity.get();
            const steps = 10;
            let count = 0;

            snapTimerId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 16, () => {
                count++;
                if (count >= steps) {
                    dragX.set(0);
                    dragOpacity.set(1.0);
                    snapTimerId = null;
                    return false;
                }
                const t = count / steps;
                const factor = 1 - (1 - t) * (1 - t);
                dragX.set(startValX * (1 - factor));
                dragOpacity.set(startValOpacity + (1.0 - startValOpacity) * factor);
                return true;
            });
        };

        return (
            <revealer
                transitionDuration={200}
                transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
                revealChild={bind(reveal)}
                onDestroy={() => {
                    showActions.drop();
                    reveal.drop();
                    dragX.drop();
                    dragOpacity.drop();
                    if (snapTimerId) {
                        GLib.source_remove(snapTimerId);
                    }
                }}
            >
                <eventbox
                    onButtonPressEvent={(self, event) => {
                        const [success, x, y] = event.get_root_coords();
                        startX = x;
                        isDragging = true;
                        return false;
                    }}
                    onButtonReleaseEvent={(self, event) => {
                        if (!isDragging) return false;
                        isDragging = false;
                        const [success, x, y] = event.get_root_coords();
                        const deltaX = x - startX;
                        if (deltaX > 150) {
                            dismissWithAnim();
                        } else {
                            snapBack();
                        }
                        return false;
                    }}
                    onMotionNotifyEvent={(self, event) => {
                        if (!isDragging) return false;
                        const [success, x, y] = event.get_root_coords();
                        const deltaX = x - startX;
                        if (deltaX > 0) {
                            dragX.set(deltaX);
                            dragOpacity.set(Math.max(0.1, 1 - deltaX / 350));
                        }
                        return false;
                    }}
                >
                    <box
                        className="notification-item"
                        marginLeft={bind(dragX)}
                        marginRight={bind(dragX).as(x => -x)}
                        opacity={bind(dragOpacity)}
                    >
                        {notification.image && fileExists(notification.image) && (
                            <box
                                valign={Gtk.Align.START}
                                className="image-list"
                                css={`
                                    background-image: url("${notification.image}");
                                `}
                            ></box>
                        )}
                        {notification.image && isIcon(notification.image) && (
                            <box
                                expand={false}
                                valign={Gtk.Align.START}
                                className="icon-image-list"
                            >
                                <icon
                                    icon={notification.image}
                                    expand
                                    halign={Gtk.Align.CENTER}
                                    valign={Gtk.Align.CENTER}
                                />
                            </box>
                        )}
                        {!notification.image && (
                            <button
                                className="default-icon-notification-list"
                                valign={Gtk.Align.START}
                            >
                                <icon icon="default-notification" />
                            </button>
                        )}
                        <box vertical>
                            <box>
                                <label
                                    className="notification-summary-list"
                                    halign={Gtk.Align.START}
                                    xalign={0}
                                    label={notification.summary}
                                    hexpand
                                    wrap
                                />
                                <box halign={Gtk.Align.END} valign={Gtk.Align.START}>
                                    <label
                                        className="notification-time-list"
                                        halign={Gtk.Align.START}
                                        label={bind(timeRefresher).as((refreshedTime) =>
                                            formatTimeAgo(notification.time, Math.floor(refreshedTime / 1000)),
                                        )}
                                    />
                                    <button
                                        className="notification-expand-button-list"
                                        cursor={"hand1"}
                                        onClicked={() =>
                                            showActions.set(!showActions.get())
                                        }
                                        css={`
                                            background-color: transparent;
                                        `}
                                    >
                                        <icon
                                            icon={"expand-down"}
                                            className={bind(showActions).as((shown) =>
                                                shown ? "expanded" : "",
                                            )}
                                        />
                                    </button>
                                </box>
                            </box>
                            {notification.body && (
                                <label
                                    className="notification-body-list"
                                    wrap
                                    useMarkup
                                    halign={Gtk.Align.START}
                                    xalign={0}
                                    justifyFill
                                    label={notification.body}
                                />
                            )}
                            <revealer
                                transitionDuration={200}
                                transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
                                revealChild={bind(showActions)}
                            >
                                <box className="notification-actions-list">
                                    <box>
                                        <button
                                            cursor={"hand1"}
                                            onClicked={dismissWithAnim}
                                        >
                                            <label
                                                label="Close"
                                                halign={Gtk.Align.CENTER}
                                                hexpand
                                            />
                                        </button>
                                    </box>
                                    {notification.get_actions().length > 0 && (
                                        <box spacing={15}>
                                            {notification
                                                .get_actions()
                                                .map(
                                                    ({
                                                        label,
                                                        id,
                                                    }: {
                                                        label: string;
                                                        id: string;
                                                    }) => (
                                                        <button
                                                            cursor={"hand1"}
                                                            hexpand
                                                            onClicked={() => {
                                                                notification.invoke(id);
                                                                // Remove setTimeout to prevent memory leak
                                                                notifications.set([
                                                                    ...notifd.notifications,
                                                                ]);
                                                            }}
                                                        >
                                                            <label
                                                                label={label}
                                                                halign={
                                                                    Gtk.Align.CENTER
                                                                }
                                                                hexpand
                                                            />
                                                        </button>
                                                    ),
                                                )}
                                        </box>
                                    )}
                                </box>
                            </revealer>
                        </box>
                    </box>
                </eventbox>
            </revealer>
        );
    };

    return (
        <box
            vertical
            spacing={10}
            className="notification-container"
            onDestroy={cleanup}
            setup={(self: any) => {
                // Sync notifications with current notifd state when component mounts
                // allNotifications will accumulate over time as notifications are received
                const currentNotifs = [...notifd.notifications];
                notifications.set(currentNotifs);
                // Only add current notifications to allNotifications if they're not already there
                const existingIds = new Set(
                    allNotifications.get().map((n) => n.id),
                );
                const newNotifs = currentNotifs.filter(
                    (n) => !existingIds.has(n.id),
                );
                if (newNotifs.length > 0) {
                    allNotifications.set([
                        ...newNotifs,
                        ...allNotifications.get(),
                    ]);
                }
                notificationCount.set(currentNotifs.length);
            }}
        >
            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="notification-container-scrollable"
            >
                <box vertical className="notification-list">
                    {bind(allNotifications).as((notifs) => {
                        if (notifs.length === 0) {
                            return (
                                <icon
                                    icon="no-noti"
                                    className="no-notifications"
                                    xalign={0.5}
                                />
                            );
                        }

                        const sortedNotifs = [...notifs].sort(
                            (a, b) => b.time - a.time,
                        );

                        return sortedNotifs.map((notification) => (
                            <NotificationItem notification={notification} />
                        ));
                    })}
                </box>
            </scrollable>
            <centerbox>
                <label
                    label={bind(allNotifications).as(
                        (notifs) => `${notifs.length} notifications`,
                    )}
                    xalign={0}
                    valign={Gtk.Align.END}
                />
                <box />
                <button
                    className="notification-clear-all-button"
                    halign={Gtk.Align.END}
                    valign={Gtk.Align.END}
                    cursor={"hand1"}
                    onClicked={() => {
                        notifd.notifications.forEach((notification: any) =>
                            notification.dismiss(),
                        );
                        notifications.set([]);
                        allNotifications.set([]);
                        notificationCount.set(0);
                    }}
                >
                    <icon icon="clear" />
                </button>
            </centerbox>
        </box>
    );
};

export default NotificationList;
