import { Gtk } from "astal/gtk3";
import Apps from "gi://AstalApps";

function tb_override<T extends object, U extends object>(
    target: T,
    source: U
): T & U {
    for (const key in source) {
        if (Object.prototype.hasOwnProperty.call(source, key)) {
            (target as any)[key] = source[key];
        }
    }
    return target as T & U;
}

interface IconOptions {
    icon_name: string | string[];
    size: number;
    path: boolean;
}

function lookupIcon(
    args:
        | { icon_name?: string | string[]; size?: number; path?: boolean }
        | string
        | string[]
): string | undefined {
    if (typeof args === "string") {
        return lookupIcon({ icon_name: args });
    } else if (Array.isArray(args)) {
        let path: string | undefined;
        if (args.length >= 1) {
            for (const value of args) {
                path = lookupIcon(value);
                if (path) {
                    return path;
                }
            }
            return undefined;
        }
    }

    if (!args || !("icon_name" in args) || !args.icon_name) {
        return undefined;
    }

    const options = args as IconOptions;

    const iconNames: string[] = [];
    if (typeof options.icon_name === "string") {
        iconNames.push(
            options.icon_name,
            options.icon_name.toLowerCase(),
            options.icon_name.toUpperCase()
        );
    } else if (Array.isArray(options.icon_name)) {
        options.icon_name.forEach((name) => iconNames.push(name));
    }

    args = tb_override(
        {
            icon_name: "",
            size: 128,
            path: true,
        },
        args as any
    );

    const theme = Gtk.IconTheme.get_default();
    let iconInfo, path;

    for (const name of iconNames) {
        iconInfo = theme.lookup_icon(
            name,
            options.size,
            Gtk.IconLookupFlags.USE_BUILTIN
        );

        if (iconInfo) {
            path = iconInfo.get_filename();

            if (path) {
                if (options.path) {
                    const match = path.match(/.*\/([^\/]+)\.[^\.]+$/);
                    return match ? match[1] : undefined;
                } else {
                    const iconStr = iconInfo.load_icon().to_string();
                    return iconStr !== null ? iconStr : undefined;
                }
            }
        }
    }

    return undefined;
}

const appInfoCache = new Map<string, any>();
const MAX_CACHE_SIZE = 50;

let appManager: Apps.Apps | null = null;
const getAppManager = () => {
    if (!appManager) {
        appManager = new Apps.Apps();
    }
    return appManager;
};

const getIcon = (appId: string) => {
    if (!appId) return null;

    // Check cache first
    if (appInfoCache.has(appId)) {
        return appInfoCache.get(appId);
    }

    // Use the single app manager instance
    const appList = getAppManager().get_list();
    for (const app of appList) {
        if (
            app.entry.toLowerCase().includes(appId.toLowerCase()) ||
            app.icon_name === appId ||
            app.iconName === appId ||
            app.name === appId ||
            app.wm_class === appId
        ) {
            // Limit cache size
            if (appInfoCache.size >= MAX_CACHE_SIZE) {
                const firstKey = appInfoCache.keys().next().value;
                if (firstKey) {
                    appInfoCache.delete(firstKey);
                }
            }
            appInfoCache.set(appId, app);
            return app;
        }
    }

    const commonKeywords = [
        "browser",
        "web",
        "music",
        "media",
        "video",
        "audio",
        "terminal",
        "editor",
        "code",
        "chat",
        "mail",
        "photo",
        "image",
        "settings",
        "control",
    ];

    for (const keyword of commonKeywords) {
        if (appId.toLowerCase().includes(keyword)) {
            const keywordResults = getAppManager().fuzzy_query(keyword);
            if (keywordResults.length > 0) {
                // Limit cache size
                if (appInfoCache.size >= MAX_CACHE_SIZE) {
                    const firstKey = appInfoCache.keys().next().value;
                    if (firstKey) {
                        appInfoCache.delete(firstKey);
                    }
                }
                appInfoCache.set(appId, keywordResults[0]);
                return keywordResults[0];
            }
        }
    }

    // Cache null result to avoid repeated failed lookups
    if (appInfoCache.size >= MAX_CACHE_SIZE) {
        const firstKey = appInfoCache.keys().next().value;
        if (firstKey) {
            appInfoCache.delete(firstKey);
        }
    }
    appInfoCache.set(appId, null);
    return null;
};

export { lookupIcon, getIcon };
