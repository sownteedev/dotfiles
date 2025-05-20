import { Gtk } from 'astal/gtk3';

function tb_override<T extends object, U extends object>(target: T, source: U): T & U {
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

function lookupIcon(args: { icon_name?: string | string[]; size?: number; path?: boolean } | string | string[]): string | undefined {
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

    if (!args || !('icon_name' in args) || !args.icon_name) {
        return undefined;
    }

    const options = args as IconOptions;

    const iconNames: string[] = [];
    if (typeof options.icon_name === 'string') {
        iconNames.push(
            options.icon_name,
            options.icon_name.toLowerCase(),
            options.icon_name.toUpperCase()
        );
    } else if (Array.isArray(options.icon_name)) {
        options.icon_name.forEach(name => iconNames.push(name));
    }

    args = tb_override({
        icon_name: "",
        size: 128,
        path: true,
    }, args as any);

    const theme = Gtk.IconTheme.get_default();
    let iconInfo, path;
    
    for (const name of iconNames) {
        iconInfo = theme.lookup_icon(name, options.size, Gtk.IconLookupFlags.USE_BUILTIN);

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

export { lookupIcon };