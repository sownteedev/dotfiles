import Apps from "gi://AstalApps";
import { App, Gtk } from "astal/gtk3";
import { bind, Variable } from "astal";
import { filterApp } from "./AppFilter";

function hide() {
    App.get_window("launcher")!.hide();
}

// Memoize display name calculation
const getDisplayName = (name: string): string => {
    return name.length > 15 ? name.substring(0, 15) + "..." : name;
};

function AppGridItem({ app }: { app: Apps.Application }) {
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

function FolderGridItem({
    folderName,
    folderApps,
    onClick,
}: {
    folderName: string;
    folderApps: Apps.Application[];
    onClick: () => void;
}) {
    const previewIcons = folderApps.slice(0, 4);

    const renderMiniIcon = (app?: Apps.Application) => {
        if (app) {
            return <icon icon={app.iconName} className="folder-mini-icon" />;
        }
        return <box className="folder-mini-icon-placeholder" />;
    };

    return (
        <button
            className="app-grid-item folder-grid-item"
            cursor="hand1"
            widthRequest={140}
            onClicked={onClick}
        >
            <box
                vertical
                spacing={12}
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.START}
            >
                <box className="folder-icon-wrapper" halign={Gtk.Align.CENTER} vertical spacing={6} widthRequest={72} heightRequest={72}>
                    <box spacing={6}>
                        {renderMiniIcon(previewIcons[0])}
                        {renderMiniIcon(previewIcons[1])}
                    </box>
                    <box spacing={6}>
                        {renderMiniIcon(previewIcons[2])}
                        {renderMiniIcon(previewIcons[3])}
                    </box>
                </box>
                <label
                    className="app-grid-name"
                    label={folderName}
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

const CATEGORIES = [
    { id: "all", name: "All", icon: "view-grid-symbolic" },
    { id: "development", name: "Development", icon: "applications-development-symbolic" },
    { id: "internet", name: "Internet", icon: "applications-internet-symbolic" },
    { id: "multimedia", name: "Multimedia", icon: "applications-multimedia-symbolic" },
    { id: "system", name: "System", icon: "applications-system-symbolic" },
];

const getAppCategory = (app: Apps.Application): string => {
    const cats = (app.categories || []).map(c => c.toLowerCase());
    const name = app.name.toLowerCase();
    const exec = (app.executable || "").toLowerCase();

    // Helper to check if string contains any keyword
    const matchesKeywords = (str: string, keywords: string[]) => 
        keywords.some(kw => str.includes(kw));

    // 1. Development
    const devCats = ["development", "ide", "texteditor", "programming", "guidesigner", "translation", "documentation", "debugger", "compiler", "database"];
    const devKws = ["code", "neovim", "nvim", "datagrip", "designer", "linguist", "assistant", "jshell", "studio", "develop", "builder", "git"];
    if (
        cats.some(c => devCats.includes(c)) ||
        matchesKeywords(name, devKws) ||
        matchesKeywords(exec, devKws)
    ) {
        return "development";
    }
    
    // 2. Internet
    const netCats = ["network", "webbrowser", "chat", "instantmessaging", "email", "news", "p2p", "ircclient", "filetransfer", "telephony", "videoconference"];
    const netKws = ["chrome", "firefox", "browser", "telegram", "vesktop", "discord", "mail", "connect", "remote", "chat", "download", "torrent"];
    if (
        cats.some(c => netCats.includes(c)) ||
        matchesKeywords(name, netKws) ||
        matchesKeywords(exec, netKws)
    ) {
        return "internet";
    }
    
    // 3. Multimedia
    const mediaCats = ["audiovideo", "audio", "video", "player", "music", "graphics", "image", "photography", "recorder", "midi", "mixer", "sequencer", "tuner", "tv"];
    const mediaKws = ["spotify", "mpv", "vlc", "music", "player", "video", "audio", "draw", "paint", "image", "photo", "record", "obs", "sound"];
    if (
        cats.some(c => mediaCats.includes(c)) ||
        matchesKeywords(name, mediaKws) ||
        matchesKeywords(exec, mediaKws)
    ) {
        return "multimedia";
    }
    
    // 4. System & Settings
    const sysCats = ["system", "settings", "monitor", "preferences", "hardware", "terminal", "emulator", "core", "security", "administration", "filesystem", "fileservice", "hardwaresettings", "package-manager", "printing", "utility", "filemanager"];
    const sysKws = ["avahi", "fcitx", "look", "nvidia", "volume", "sound-control", "lstopo", "system", "settings", "config", "control", "perf", "monitor", "terminal", "console", "disk", "file", "htop", "btop"];
    if (
        cats.some(c => sysCats.includes(c)) ||
        matchesKeywords(name, sysKws) ||
        matchesKeywords(exec, sysKws)
    ) {
        return "system";
    }
    
    return "other";
};

interface FolderItem {
    isFolder: true;
    name: string;
    apps: Apps.Application[];
}

type GridItem = Apps.Application | FolderItem;

const chunkFolderApps = (apps: Apps.Application[]): Apps.Application[][] => {
    const COLUMNS = 4;
    const rows: Apps.Application[][] = [];
    for (let i = 0; i < apps.length; i += COLUMNS) {
        rows.push(apps.slice(i, i + COLUMNS));
    }
    return rows;
};

export default function AllApp({
    apps,
    searchText,
}: {
    apps: Apps.Apps;
    searchText: Variable<string>;
}) {
    const allApps = Variable<Apps.Application[]>([]);
    const currentCategory = Variable<string>("all");
    const activeFolder = Variable<FolderItem | null>(null);

    // Load all apps - only called once
    const loadApps = () => {
        try {
            let appList = apps.get_list() || [];
            // Filter out terminal applications (CLI only)
            appList = appList.filter(filterApp);
            const sortedApps = sortApps(appList);
            allApps.set(sortedApps);
        } catch (error) {
            console.error("Error loading apps:", error);
            allApps.set([]);
        }
    };

    // Load apps on mount
    loadApps();

    // Filter apps based on search query and category selection
    const filteredApps = Variable.derive(
        [searchText, currentCategory],
        (query, cat) => {
            let appList = allApps.get();

            // 1. Filter by search query if any
            if (query.trim()) {
                const queryLower = query.toLowerCase();
                appList = appList.filter(
                    (app) =>
                        app.name.toLowerCase().includes(queryLower) ||
                        app.description?.toLowerCase().includes(queryLower),
                );
                // Return search results directly (no folders)
                return appList;
            }

            // 2. Filter by category if not "all"
            if (cat !== "all") {
                appList = appList.filter((app) => getAppCategory(app) === cat);
            }

            // 3. Automatically group apps into folders by their first word if size >= 3
            const EXCLUDED_PREFIXES = new Set([
                "the", "a", "an", "my", "open", "system", 
                "gnome", "kde", "xfce", "windows", "microsoft"
            ]);

            // Map to store groups (lowercasePrefix -> { originalName: string, apps: Application[] })
            const groups = new Map<string, { originalName: string; apps: Apps.Application[] }>();

            // First pass: group everything by prefix (stripping numbers for dynamic grouping like Qt5/Qt6 -> Qt)
            for (const app of appList) {
                const name = app.name.trim();
                const firstWord = name.split(/\s+/)[0];
                const cleanWord = firstWord.replace(/^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$/g, "");
                const cleanLower = cleanWord.toLowerCase();
                const baseLower = cleanLower.replace(/\d+$/, "");

                // Check if prefix is valid
                if (baseLower.length < 2 || EXCLUDED_PREFIXES.has(baseLower)) {
                    continue;
                }

                if (!groups.has(baseLower)) {
                    const folderDisplayName = cleanWord.replace(/\d+$/, "");
                    groups.set(baseLower, {
                        originalName: folderDisplayName,
                        apps: []
                    });
                }
                groups.get(baseLower)!.apps.push(app);
            }

            // Second pass: filter groups with size >= 3 and build folder items
            const folders: FolderItem[] = [];
            const groupedAppIds = new Set<string>();

            for (const [key, val] of groups.entries()) {
                if (val.apps.length >= 3) {
                    folders.push({
                        isFolder: true,
                        name: val.originalName,
                        apps: val.apps
                    });

                    for (const app of val.apps) {
                        groupedAppIds.add(app.name + "::" + app.executable);
                    }
                }
            }

            // Filter remaining apps that are not grouped
            const remainingApps = appList.filter(app => {
                const key = app.name + "::" + app.executable;
                return !groupedAppIds.has(key);
            });

            const result: GridItem[] = [...remainingApps, ...folders];

            return result.sort((a, b) => {
                const nameA = "isFolder" in a && a.isFolder ? a.name : (a as Apps.Application).name;
                const nameB = "isFolder" in b && b.isFolder ? b.name : (b as Apps.Application).name;
                return nameA.localeCompare(nameB, undefined, {
                    sensitivity: "base",
                    numeric: true,
                });
            });
        },
    );

    const cleanup = () => {
        allApps.drop();
        currentCategory.drop();
        filteredApps.drop();
        activeFolder.drop();
    };

    return (
        <box
            className="all-apps-container"
            vertical
            onDestroy={cleanup}
            spacing={15}
        >
            <overlay>
                {/* Main Content Layout */}
                <box vertical spacing={15}>
                    {/* Top Scrollable Applications Grid */}
                    <scrollable
                        vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                        hscrollbarPolicy={Gtk.PolicyType.NEVER}
                        className="all-apps-scrollable"
                        hexpand
                        vexpand
                    >
                        <box className="all-apps-grid" vertical>
                            {bind(filteredApps).as((items) => {
                                if (items.length === 0) {
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
                                const rows: GridItem[][] = [];

                                // Chunk items into rows
                                for (let i = 0; i < items.length; i += COLUMNS) {
                                    rows.push(items.slice(i, i + COLUMNS));
                                }

                                // Map rows to JSX
                                return rows.map((row) => (
                                    <box
                                        className="all-apps-grid-row"
                                        halign={Gtk.Align.CENTER}
                                        spacing={20}
                                    >
                                        {row.map((item) => {
                                            if ("isFolder" in item && item.isFolder) {
                                                return (
                                                    <FolderGridItem
                                                        folderName={item.name}
                                                        folderApps={item.apps}
                                                        onClick={() => activeFolder.set(item)}
                                                    />
                                                );
                                            } else {
                                                return <AppGridItem app={item as Apps.Application} />;
                                            }
                                        })}
                                    </box>
                                ));
                            })}
                        </box>
                    </scrollable>

                    {/* Bottom Category Selector Bar */}
                    <box className="all-apps-categories" halign={Gtk.Align.CENTER} spacing={10}>
                        {CATEGORIES.map((cat) => (
                            <button
                                className={bind(currentCategory).as(
                                    (curr) => `category-btn ${curr === cat.id ? "active" : ""}`
                                )}
                                onClicked={() => {
                                    currentCategory.set(cat.id);
                                    activeFolder.set(null); // Close folder when switching tabs
                                }}
                                cursor="hand1"
                            >
                                <box spacing={8} valign={Gtk.Align.CENTER}>
                                    <icon icon={cat.icon} className="category-icon" />
                                    <label label={cat.name} className="category-label" />
                                </box>
                            </button>
                        ))}
                    </box>
                </box>

                {/* Folder Overlay Modal */}
                {bind(activeFolder).as((folder) => {
                    if (!folder) return <box visible={false} />;

                    return (
                        <box className="folder-modal-backdrop" halign={Gtk.Align.FILL} valign={Gtk.Align.FILL}>
                            <box className="folder-modal-content" vertical halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} spacing={25} widthRequest={680} heightRequest={400}>
                                <box className="folder-modal-header" spacing={10}>
                                    <label className="folder-modal-title" label={folder.name} hexpand />
                                    <button className="folder-modal-close" onClicked={() => activeFolder.set(null)} cursor="hand1">
                                        <icon icon="window-close-symbolic" />
                                    </button>
                                </box>
                                <scrollable className="folder-modal-scroll" hscrollbarPolicy={Gtk.PolicyType.NEVER} vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}>
                                    <box className="folder-modal-grid" vertical spacing={15}>
                                        {chunkFolderApps(folder.apps).map((row) => (
                                            <box spacing={15} halign={Gtk.Align.CENTER}>
                                                {row.map((app) => (
                                                    <AppGridItem app={app} />
                                                ))}
                                            </box>
                                        ))}
                                    </box>
                                </scrollable>
                            </box>
                        </box>
                    );
                })}
            </overlay>
        </box>
    );
}
