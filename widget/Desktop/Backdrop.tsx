import { Gdk } from "astal/gtk3";
import createWallpaper from "./Component";

const Backdrop = (gdkmonitor: Gdk.Monitor) => {
    return createWallpaper({
        wallpaperPath: "/tmp/backdrop.png",
        windowNamePrefix: "backdrop",
        gdkmonitor,
    });
};

export default Backdrop;
