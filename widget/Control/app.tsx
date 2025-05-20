import { Astal, App } from "astal/gtk3";
import TopControl from "./mods/TopControl";
import ControlButtons from "./mods/Button";
import Content from "./mods/Content";

export default function Control() {
    return <window
        name="control-menu"
        className="control-menu"
        anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        layer={Astal.Layer.TOP}
        visible={false}
        keymode={Astal.Keymode.ON_DEMAND}
        application={App}>
        <box vertical className="control-menu-container" spacing={20}>
            <TopControl />
            <ControlButtons />
            <Content />
        </box>
    </window>
}