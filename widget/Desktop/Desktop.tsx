import { Gdk } from "astal/gtk3";
import Global from "../../Global";
import createWallpaper from "./Component";

const Desktop = (gdkmonitor: Gdk.Monitor) => {
    return createWallpaper({
        wallpaperPath: Global.Wallpaper,
        windowNamePrefix: "desktop",
        gdkmonitor,
    });
};

export default Desktop;
