import Apps from "gi://AstalApps";
import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { bind, Variable } from "astal";
import AllApp from "./AllApp";
import { filterApp } from "./AppFilter";


const MAX_ITEMS = 5;
const CACHE_SIZE_LIMIT = 30; // Reduced cache size for better memory management

// Singleton Apps instance to avoid memory leak
let appsInstance: Apps.Apps | null = null;
const getAppsInstance = () => {
    if (!appsInstance) {
        appsInstance = new Apps.Apps();
    }
    return appsInstance;
};

// LRU Cache implementation for query results
class LRUCache {
    private cache = new Map<string, Apps.Application[]>();
    private maxSize: number;

    constructor(maxSize: number) {
        this.maxSize = maxSize;
    }

    get(key: string): Apps.Application[] | undefined {
        if (!this.cache.has(key)) {
            return undefined;
        }
        // Move to end (most recently used)
        const value = this.cache.get(key)!;
        this.cache.delete(key);
        this.cache.set(key, value);
        return value;
    }

    set(key: string, value: Apps.Application[]): void {
        if (this.cache.has(key)) {
            // Update existing: move to end
            this.cache.delete(key);
        } else if (this.cache.size >= this.maxSize) {
            // Remove least recently used (first item)
            const firstKey = this.cache.keys().next().value;
            if (firstKey !== undefined) {
                this.cache.delete(firstKey);
            }
        }
        this.cache.set(key, value);
    }

    clear(): void {
        this.cache.clear();
    }

    get size(): number {
        return this.cache.size;
    }
}

const queryCache = new LRUCache(CACHE_SIZE_LIMIT);

function hide() {
    App.get_window("launcher")!.hide();
}

function AppButton({ app }: { app: Apps.Application }) {
    return (
        <button
            className="AppButton"
            cursor={"hand1"}
            onClicked={() => {
                hide();
                app.launch();
            }}
        >
            <box>
                <icon icon={app.iconName} />
                <box valign={Gtk.Align.CENTER} vertical spacing={5}>
                    <label
                        className="name"
                        truncate
                        xalign={0}
                        label={app.name}
                    />
                    {app.description && (
                        <label
                            className="description"
                            wrap
                            xalign={0}
                            label={app.description}
                        />
                    )}
                </box>
            </box>
        </button>
    );
}

export default function Applauncher() {
    const { CENTER } = Gtk.Align;
    const apps = getAppsInstance();
    const text = Variable("");
    const listLength = Variable(0);
    const showAllApps = Variable(false);

    // Query result with caching
    const list = text((queryText) => {
        const trimmed = queryText.trim();

        if (trimmed === "") {
            listLength.set(0);
            return [];
        }

        // Check cache first
        let results = queryCache.get(trimmed);
        if (!results) {
            // Perform query and filter results
            const rawResults = apps.fuzzy_query(trimmed);
            results = rawResults ? rawResults.filter(filterApp) : [];
            // Cache result (LRU will handle size limit)
            queryCache.set(trimmed, results);
        }
        // TypeScript: results is guaranteed to be defined here
        const sliced = results.slice(0, MAX_ITEMS);
        listLength.set(sliced.length);
        return sliced;
    });

    const onEnter = () => {
        const results = list.get();
        if (results.length > 0) {
            // Get full results from cache or query
            const queryText = text.get().trim();
            let fullResults = queryCache.get(queryText);
            if (!fullResults) {
                const rawResults = apps.fuzzy_query(queryText);
                fullResults = rawResults ? rawResults.filter(filterApp) : [];
                queryCache.set(queryText, fullResults);
            }
            if (fullResults && fullResults.length > 0) {
                fullResults[0].launch();
                hide();
            }
        }
    };

    // Cleanup function
    const cleanup = () => {
        // Drop variables
        text.drop();
        listLength.drop();
        showAllApps.drop();
        // Note: list is derived from text, so it will be cleaned up automatically
        // Clear cache to free memory when window is destroyed
        queryCache.clear();
    };

    return (
        <window
            name="launcher"
            className="launcher"
            exclusivity={Astal.Exclusivity.IGNORE}
            keymode={Astal.Keymode.ON_DEMAND}
            application={App}
            visible={false}
            onShow={() => {
                text.set("");
                showAllApps.set(false);
            }}
            onKeyPressEvent={function (self: Gtk.Window, event: Gdk.Event) {
                if (event.get_keyval()[1] === Gdk.KEY_Escape) self.hide();
            }}
            onDestroy={cleanup}
        >
            <box>
                <eventbox expand onClick={hide} />
                <box hexpand={false} vertical halign={CENTER}>
                    <box className="Applauncher" vertical>
                        <box spacing={15} halign={CENTER}>
                            <icon className="search-icon" icon="search-svg" />
                            <box
                                className={bind(text).as((t) => {
                                    const hasText = t.trim() !== "";
                                    return hasText
                                        ? "search-entry-box has-text"
                                        : "search-entry-box";
                                })}
                            >
                                <entry
                                    className="search-entry"
                                    placeholderText={"Search"}
                                    text={text()}
                                    hexpand={true}
                                    onChanged={(self: Gtk.Entry) => {
                                        text.set(self.text);
                                    }}
                                    onActivate={onEnter}
                                />
                            </box>
                            <button
                                className="all-apps-button"
                                cursor="hand1"
                                onClicked={() => {
                                    showAllApps.set(!showAllApps.get());
                                    if (showAllApps.get()) {
                                        text.set("");
                                    }
                                }}
                            >
                                {bind(showAllApps).as((show) => (
                                    <icon
                                        icon={
                                            show
                                                ? "view-list-symbolic"
                                                : "view-grid-symbolic"
                                        }
                                    />
                                ))}
                            </button>
                        </box>
                        {bind(showAllApps).as((showAll) =>
                            showAll ? (
                                <AllApp apps={apps} searchText={text} />
                            ) : (
                                <revealer
                                    transitionDuration={200}
                                    transitionType={
                                        Gtk.RevealerTransitionType.SLIDE_DOWN
                                    }
                                    revealChild={bind(text).as(
                                        (t) => t.trim() !== "",
                                    )}
                                >
                                    <box
                                        spacing={15}
                                        vertical
                                        className="app-list-container"
                                        css={bind(listLength).as((length) => {
                                            // Calculate min-height based on number of items
                                            // Button: padding 15px top + 15px bottom = 30px
                                            // Icon: 60px
                                            // Total button height ≈ 90px (có thể cần điều chỉnh)
                                            // Spacing between items: 15px
                                            const BUTTON_HEIGHT = 90;
                                            const SPACING = 15;
                                            const minHeight =
                                                length > 0
                                                    ? length * BUTTON_HEIGHT +
                                                      (length - 1) * SPACING
                                                    : 0;
                                            const adjustedHeight = Math.max(
                                                0,
                                                minHeight - 50,
                                            );
                                            return `margin-top: 15px; min-height: ${adjustedHeight}px;`;
                                        })}
                                    >
                                        {list.as((list) =>
                                            list.map((app) => (
                                                <AppButton app={app} />
                                            )),
                                        )}
                                        <box
                                            halign={CENTER}
                                            className="not-found"
                                            vertical
                                            visible={bind(list).as((l) => {
                                                const queryText = text
                                                    .get()
                                                    .trim();
                                                return (
                                                    l.length === 0 &&
                                                    queryText !== ""
                                                );
                                            })}
                                        >
                                            <icon icon="system-search-symbolic" />
                                            <label label="No match found" />
                                        </box>
                                    </box>
                                </revealer>
                            ),
                        )}
                    </box>
                </box>
                <eventbox expand onClick={hide} />
            </box>
        </window>
    );
}
