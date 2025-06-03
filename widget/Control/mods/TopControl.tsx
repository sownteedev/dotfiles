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

const uptime = Variable(getUptime()).poll(60000, getUptime);

export default () => {
    const cleanup = () => {
        uptime.drop();
    };

    return (
        <centerbox className="top-control" onDestroy={cleanup}>
            <box className="uptime" spacing={15} halign={Gtk.Align.START}>
                <icon icon="media-playlist-shuffle-symbolic"/>
                <label label={bind(uptime)} />
            </box>
            <box/>
            <box
                halign={Gtk.Align.END}
                className="image"
                css={`background-image: url("${Global.ProfileImage}")`}
            />
        </centerbox>
    );
};
