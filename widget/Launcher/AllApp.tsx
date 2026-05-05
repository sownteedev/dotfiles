import Apps from "gi://AstalApps";
import { App, Gtk } from "astal/gtk3";
import { bind, Variable } from "astal";

function hide() {
    App.get_window("launcher")!.hide();
}

// Memoize display name calculation
const getDisplayName = (name: string): string => {
    return name.length > 15 ? name.substring(0, 15) + "..." : name;
};

function AppGridItem({ app }: { app: Apps.Application }) {
    // Use memoized display name
    const displayName = getDisplayName(app.name);

    return (
        <button
            className="app-grid-item"
            cursor="hand1"
            widthRequest={140}
            onClicked={() => {
                hide();
                app.launch();
            }}
        >
            <box
                vertical
                spacing={12}
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.START}
            >
                <icon icon={app.iconName} className="app-grid-icon" />
                <label
                    className="app-grid-name"
                    label={displayName}
                    truncate
                    xalign={0.5}
                />
            </box>
        </button>
    );
}

// Sort function - extracted to avoid recreating on each render
const sortApps = (appList: Apps.Application[]): Apps.Application[] => {
    return [...appList].sort((a, b) => {
        return a.name.localeCompare(b.name, undefined, {
            sensitivity: "base",
            numeric: true,
        });
    });
};

export default function AllApp({
    apps,
    searchText,
}: {
    apps: Apps.Apps;
    searchText: Variable<string>;
}) {
    const allApps = Variable<Apps.Application[]>([]);

    // Load all apps - only called once
    const loadApps = () => {
        try {
            const appList = apps.get_list();
            // Sort apps alphabetically by name (create new array to avoid mutating original)
            const sortedApps = sortApps(appList || []);
            allApps.set(sortedApps);
        } catch (error) {
            console.error("Error loading apps:", error);
            allApps.set([]);
        }
    };

    // Load apps on mount
    loadApps();

    // Filter apps based on search from parent
    // This creates a new array but is necessary for filtering
    const filteredApps = bind(searchText).as((query) => {
        const appList = allApps.get();
        if (!query.trim()) {
            return appList;
        }
        const queryLower = query.toLowerCase();
        return appList.filter(
            (app) =>
                app.name.toLowerCase().includes(queryLower) ||
                app.description?.toLowerCase().includes(queryLower),
        );
    });

    const cleanup = () => {
        allApps.drop();
        // Note: filteredApps is derived from searchText and allApps,
        // so it will be cleaned up automatically when those are dropped
    };

    return (
        <box
            className="all-apps-container"
            vertical
            halign={Gtk.Align.CENTER}
            onDestroy={cleanup}
        >
            {/* Applications Grid */}
            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="all-apps-scrollable"
                vexpand
            >
                <box className="all-apps-grid" vertical>
                    {filteredApps.as((apps) => {
                        if (apps.length === 0) {
                            return (
                                <box
                                    className="all-apps-empty"
                                    halign={Gtk.Align.CENTER}
                                    valign={Gtk.Align.CENTER}
                                    vexpand
                                >
                                    <label
                                        className="all-apps-empty-label"
                                        label="No applications found"
                                    />
                                </box>
                            );
                        }

                        const COLUMNS = 6;
                        const rows: Apps.Application[][] = [];

                        // Efficiently chunk apps into rows
                        for (let i = 0; i < apps.length; i += COLUMNS) {
                            rows.push(apps.slice(i, i + COLUMNS));
                        }

                        // Map rows to JSX - this is necessary for rendering
                        return rows.map((row) => (
                            <box
                                className="all-apps-grid-row"
                                halign={Gtk.Align.CENTER}
                                spacing={20}
                            >
                                {row.map((app) => (
                                    <AppGridItem app={app} />
                                ))}
                            </box>
                        ));
                    })}
                </box>
            </scrollable>
        </box>
    );
}
