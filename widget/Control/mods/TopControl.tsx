import { bind, exec, Variable } from "astal";
import { Gtk } from "astal/gtk3";
import Global from "../../../Global";

function getUptime() {
    const output = exec("cat /proc/uptime");
    const seconds = parseInt(output.split(" ")[0]);
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `Uptime ${hours}h, ${minutes}m`;
}

// Singleton pattern for uptime Variable
let uptime: ReturnType<typeof Variable<string>> | null = null;
const getUptimeVar = () => {
    if (!uptime) {
        uptime = Variable(getUptime()).poll(60000, getUptime);
    }
    return uptime;
};

export default () => {
    const uptimeVar = getUptimeVar();

    return (
        <centerbox className="top-control">
            <box className="uptime" spacing={15} halign={Gtk.Align.START}>
                <icon icon="media-playlist-shuffle-symbolic" />
                <label label={bind(uptimeVar)} />
            </box>
            <box />
            <box
                halign={Gtk.Align.END}
                className="image"
                css={`
                    background-image: url("${Global.ProfileImage}");
                `}
            />
        </centerbox>
    );
};

// Export cleanup for global resource management
export const cleanupTopControl = () => {
    if (uptime) {
        uptime.drop();
        uptime = null;
    }
};
