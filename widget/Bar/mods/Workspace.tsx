import { bind, Variable, exec, GLib } from "astal";
import Gio from "gi://Gio";

import { Gtk, Gdk } from "astal/gtk3";
import { map } from "../../../utils/common";
import { getIcon } from "../../../utils/icon";

// Store dragged window info
let draggedWindowId: number | null = null;
let draggedFromWorkspace: number | null = null;

// Global variable to track dragging state
const isDragging = Variable(false);

// Drag target for receiving drops
const targetEntry = new Gtk.TargetEntry(
    "text/plain",
    Gtk.TargetFlags.SAME_APP,
    0,
);

interface Window {
    id: number;
    title: string;
    app_id: string;
    pid: number;
    workspace_id: number;
    is_focused: boolean;
    is_floating: boolean;
    layout: {
        pos_in_scrolling_layout: [number, number] | null;
    } | null;
}

// Cache monitor data to avoid repeated exec calls
let cachedMonitors: any[] | null = null;

const getNiriMonitors = () => {
    if (cachedMonitors) {
        return cachedMonitors;
    }

    const monitors = JSON.parse(exec("niri msg --json outputs"));

    const monitorArray = [];
    const monitorOrder = [
        "eDP-1",
        "eDP-2",
        "HDMI-A-1",
        "HDMI-A-2",
        "DP-1",
        "DP-2",
    ];

    for (const name of monitorOrder) {
        if (monitors[name]) {
            monitorArray.push({
                name: name,
                id: name.replace("-", "_"),
                logical: monitors[name].logical,
            });
        }
    }

    cachedMonitors = monitorArray;
    return monitorArray;
};

// Combine both exec calls into one function to reduce overhead
const getNiriData = () => {
    const workspaces = JSON.parse(exec("niri msg --json workspaces"));
    const windows = JSON.parse(exec("niri msg --json windows"));
    return { workspaces, windows };
};

let previousWorkspaceState: { hash: string; data: any } | null = null;
let lastCallTime = 0;
const THROTTLE_DELAY = 150;

const getWorkspaceData = () => {
    const now = Date.now();
    if (now - lastCallTime < THROTTLE_DELAY && previousWorkspaceState) {
        return previousWorkspaceState.data;
    }
    lastCallTime = now;

    const { workspaces, windows } = getNiriData();

    const windowsByWorkspace: { [key: number]: Window[] } = {};
    for (const window of windows) {
        if (!windowsByWorkspace[window.workspace_id]) {
            windowsByWorkspace[window.workspace_id] = [];
        }
        windowsByWorkspace[window.workspace_id].push(window);
    }

    for (const workspaceId in windowsByWorkspace) {
        windowsByWorkspace[workspaceId].sort((a, b) => {
            const posA =
                a.layout?.pos_in_scrolling_layout?.[0] ??
                Number.MAX_SAFE_INTEGER;
            const posB =
                b.layout?.pos_in_scrolling_layout?.[0] ??
                Number.MAX_SAFE_INTEGER;
            return posA - posB;
        });
    }

    // Lightweight hash - avoid expensive JSON.stringify
    let stateHash = "";
    for (const w of workspaces) {
        stateHash += `${w.id}:${w.idx}:${w.is_active ? 1 : 0}|`;
    }
    for (const w of windows) {
        const pos = w.layout?.pos_in_scrolling_layout?.[0] ?? 0;
        stateHash += `${w.id}:${w.workspace_id}:${
            w.is_focused ? 1 : 0
        }:${pos},`;
    }

    if (previousWorkspaceState && previousWorkspaceState.hash === stateHash) {
        return previousWorkspaceState.data;
    }

    const monitors = getNiriMonitors();
    const outputWorkspaces: { [key: string]: any[] } = {};

    for (const workspace of workspaces) {
        if (!outputWorkspaces[workspace.output]) {
            outputWorkspaces[workspace.output] = [];
        }
        outputWorkspaces[workspace.output].push({
            id: workspace.idx,
            is_active: workspace.is_active,
            workspace_id: workspace.idx,
            windows: windowsByWorkspace[workspace.id] || [],
        });
    }

    const workspaceData: any[] = [];
    for (const monitor of monitors) {
        const monitorWorkspaces = outputWorkspaces[monitor.name] || [];
        monitorWorkspaces.sort((a, b) => a.id - b.id);

        workspaceData.push({
            monitor: monitor.id,
            name: monitor.name,
            workspaces: monitorWorkspaces,
        });
    }

    previousWorkspaceState = {
        hash: stateHash,
        data: workspaceData,
    };

    return workspaceData;
};

const AppIcon = (props: any) => {
    const appId = props.app_id;
    const isFocused = props.is_focused;
    const windowId = props.id;
    const workspaceId = props.workspace_id;
    const position = props.position;

    const app = getIcon(appId);
    const appName = app?.name || appId;
    const iconName = app?.iconName || "application-x-executable";

    const setupDragAndDrop = (self: Gtk.Widget) => {
        // Setup as drag source
        self.drag_source_set(
            Gdk.ModifierType.BUTTON1_MASK,
            [targetEntry],
            Gdk.DragAction.MOVE,
        );

        self.connect(
            "drag-begin",
            (_widget: Gtk.Widget, context: Gdk.DragContext) => {
                draggedWindowId = windowId;
                draggedFromWorkspace = workspaceId;
                isDragging.set(true);
                self.get_style_context().add_class("dragging");

                // Create drag icon that follows cursor
                Gtk.drag_set_icon_name(context, iconName, 16, 16);
            },
        );

        self.connect("drag-end", () => {
            draggedWindowId = null;
            draggedFromWorkspace = null;
            isDragging.set(false);
            self.get_style_context().remove_class("dragging");
        });

        // Setup as drop target (for reordering within workspace)
        self.drag_dest_set(
            Gtk.DestDefaults.ALL,
            [targetEntry],
            Gdk.DragAction.MOVE,
        );

        self.connect("drag-drop", () => {
            if (draggedWindowId !== null && draggedWindowId !== windowId) {
                if (draggedFromWorkspace === workspaceId) {
                    // Same workspace: reorder
                    exec(
                        `niri msg action focus-window --id ${draggedWindowId}`,
                    );
                    exec(`niri msg action move-column-to-index ${position}`);
                } else {
                    // Different workspace: move to workspace then to position
                    const targetWindowId = draggedWindowId;
                    exec(
                        `niri msg action move-window-to-workspace --window-id ${targetWindowId} ${workspaceId}`,
                    );
                    // Use GLib.timeout_add instead of setTimeout for proper GTK integration
                    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
                        exec(
                            `niri msg action focus-window --id ${targetWindowId}`,
                        );
                        exec(
                            `niri msg action move-column-to-index ${position}`,
                        );
                        return false; // Don't repeat
                    });
                }
                return true;
            }
            return false;
        });

        // Visual feedback
        self.connect("drag-motion", () => {
            if (draggedWindowId !== windowId) {
                self.get_style_context().add_class("drop-target");
            }
            return true;
        });

        self.connect("drag-leave", () => {
            self.get_style_context().remove_class("drop-target");
        });
    };

    return (
        <button
            className={`app-icon ${isFocused ? "focused" : ""}`}
            setup={setupDragAndDrop}
            onButtonPressEvent={(self: any, event: Gdk.Event) => {
                if (event.get_button()[1] === 3) {
                    exec(`niri msg action close-window --id ${windowId}`);
                    return true;
                }
                return false;
            }}
            onClicked={() => {
                exec(`niri msg action focus-window --id ${windowId}`);
            }}
            cursor={"grab"}
        >
            <box spacing={3} valign={Gtk.Align.CENTER}>
                <icon icon={iconName} />
                {isFocused && <label className="app-name" label={appName} />}
            </box>
        </button>
    );
};

const WorkspaceButton = (props: any) => {
    const setupDropTarget = (self: Gtk.Widget) => {
        // Setup as drop target
        self.drag_dest_set(
            Gtk.DestDefaults.ALL,
            [targetEntry],
            Gdk.DragAction.MOVE,
        );

        self.connect("drag-drop", () => {
            if (draggedWindowId !== null) {
                // Move window to this workspace
                exec(
                    `niri msg action move-window-to-workspace --window-id ${draggedWindowId} ${props.workspace_id}`,
                );
                return true;
            }
            return false;
        });

        // Visual feedback on drag over
        self.connect("drag-motion", () => {
            self.get_style_context().add_class("drag-over");
            return true;
        });

        self.connect("drag-leave", () => {
            self.get_style_context().remove_class("drag-over");
        });
    };

    return (
        <box
            className={`workspace-button${props.is_active ? " active" : ""}`}
            spacing={10}
            setup={setupDropTarget}
        >
            <label className={`txt-ws`}>{props.workspace_id}</label>
            {props.windows.length > 0 && (
                <box
                    className="app-icons"
                    orientation={Gtk.Orientation.HORIZONTAL}
                    spacing={5}
                >
                    {map(props.windows, (window: Window, index: number) => (
                        <AppIcon
                            id={window.id}
                            app_id={window.app_id}
                            title={window.title}
                            is_focused={window.is_focused}
                            workspace_id={props.workspace_id}
                            position={index + 1}
                        />
                    ))}
                </box>
            )}
        </box>
    );
};

// Empty workspace drop zone component
const EmptyWorkspaceDropZone = (props: {
    monitorName: string;
    nextWorkspaceId: number;
}) => {
    const setupDropZone = (self: Gtk.Widget) => {
        // Setup as drop target
        self.drag_dest_set(
            Gtk.DestDefaults.ALL,
            [targetEntry],
            Gdk.DragAction.MOVE,
        );

        self.connect("drag-drop", () => {
            if (draggedWindowId !== null) {
                // Create new workspace by moving window to next available ID
                // Niri will automatically create the workspace if it doesn't exist
                exec(
                    `niri msg action move-window-to-workspace --window-id ${draggedWindowId} ${props.nextWorkspaceId}`,
                );
                return true;
            }
            return false;
        });

        // Visual feedback on drag over
        self.connect("drag-motion", () => {
            if (draggedWindowId !== null) {
                self.get_style_context().add_class("drop-zone");
            }
            return true;
        });

        self.connect("drag-leave", () => {
            self.get_style_context().remove_class("drop-zone");
        });
    };

    return (
        <box
            className="empty-workspace-drop-zone"
            spacing={10}
            setup={setupDropZone}
        >
            <label className="txt-ws">+</label>
        </box>
    );
};

const MonitorWorkspaces = (props: any) => {
    let monitorNumber;
    monitorNumber = 1;

    const activeWorkspaces = props.workspaces.filter(
        (ws: any) => ws.windows && ws.windows.length > 0,
    );

    // Find the highest workspace ID to create a new one
    const getNextWorkspaceId = () => {
        const allWorkspaceIds = props.workspaces.map(
            (ws: any) => ws.workspace_id,
        );
        if (allWorkspaceIds.length === 0) return 1;
        return Math.max(...allWorkspaceIds) + 1;
    };

    const nextWorkspaceId = getNextWorkspaceId();

    return (
        <box
            className={`monitor-workspaces monitor-${monitorNumber}`}
            spacing={20}
        >
            {...map(activeWorkspaces, (ws: any) => (
                <WorkspaceButton
                    id={ws.id}
                    monitor={monitorNumber}
                    monitor_name={props.name}
                    is_active={ws.is_active}
                    workspace_id={ws.workspace_id}
                    windows={ws.windows}
                />
            ))}
            {/* Empty drop zone to create new workspace - only show when dragging */}
            <revealer
                transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
                transitionDuration={200}
                revealChild={bind(isDragging)}
            >
                <EmptyWorkspaceDropZone
                    monitorName={props.name}
                    nextWorkspaceId={nextWorkspaceId}
                />
            </revealer>
        </box>
    );
};

export default () => {
    const workspaceData = Variable(getWorkspaceData());

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
                        workspaceData.set(getWorkspaceData());
                        readLine();
                    }
                } catch (err) {}
            });
        };
        readLine();
    } catch (err) {
        console.error("Failed to start niri event-stream in Workspace:", err);
        workspaceData.poll(1000, getWorkspaceData);
    }

    const cleanup = () => {
        workspaceData.drop();
        previousWorkspaceState = null;
        cachedMonitors = null;
        if (proc) {
            try {
                proc.force_exit();
            } catch (err) {}
        }
    };

    const setupMainDropZone = (self: Gtk.Widget) => {
        // Setup as drop target for empty space in main container
        self.drag_dest_set(
            Gtk.DestDefaults.ALL,
            [targetEntry],
            Gdk.DragAction.MOVE,
        );

        self.connect(
            "drag-drop",
            (context: Gdk.DragContext, x: number, y: number) => {
                if (draggedWindowId !== null) {
                    // Get workspace data to find next workspace ID
                    const ws = workspaceData.get();
                    if (Array.isArray(ws) && ws.length > 0) {
                        // Find the monitor that contains the drop (use first monitor for now)
                        const monitor = ws[0];
                        const allWorkspaceIds = monitor.workspaces.map(
                            (ws: any) => ws.workspace_id,
                        );
                        const nextWorkspaceId =
                            allWorkspaceIds.length === 0
                                ? 1
                                : Math.max(...allWorkspaceIds) + 1;

                        // Create new workspace by moving window
                        exec(
                            `niri msg action move-window-to-workspace --window-id ${draggedWindowId} ${nextWorkspaceId}`,
                        );
                        return true;
                    }
                }
                return false;
            },
        );

        self.connect("drag-motion", () => {
            if (draggedWindowId !== null) {
                self.get_style_context().add_class("drop-zone");
            }
            return true;
        });

        self.connect("drag-leave", () => {
            self.get_style_context().remove_class("drop-zone");
        });
    };

    return (
        <box
            className={"Workspaces"}
            onDestroy={cleanup}
            setup={setupMainDropZone}
        >
            {bind(workspaceData).as((ws: any) => {
                if (!Array.isArray(ws)) {
                    return <label label="Loading workspaces..." />;
                }

                return ws.map((monitor: any) => (
                    <MonitorWorkspaces
                        name={monitor.name}
                        workspaces={monitor.workspaces}
                    />
                ));
            })}
        </box>
    );
};
