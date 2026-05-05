import { Astal, App, Gtk } from "astal/gtk3";
import { Variable, bind } from "astal";
import TopControl from "./mods/TopControl";
import ControlButtons from "./mods/Button";
import Content from "./mods/Content/app";
import CalendarTodoWeather from "./mods/API/app";

const revealed = Variable(false);

export default function Control() {
    return (
        <window
            name="control-menu"
            className="control-menu"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            layer={Astal.Layer.TOP}
            visible={false}
            css={bind(revealed).as((v) => (v ? "" : "pointer-events: none;"))}
            onShow={() => revealed.set(true)}
            onHide={() => revealed.set(false)}
            keymode={Astal.Keymode.ON_DEMAND}
            application={App}
        >
            <revealer
                transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
                transitionDuration={300}
                revealChild={bind(revealed)}
            >
                <box vertical className="control-menu-container" spacing={20}>
                    <TopControl />
                    <ControlButtons />
                    <Content />
                    <CalendarTodoWeather />
                </box>
            </revealer>
        </window>
    );
}
