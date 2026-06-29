import { Astal, App, Gtk } from "astal/gtk3";
import { Variable, bind, timeout } from "astal";
import TopControl from "./mods/TopControl";
import ControlButtons from "./mods/Button";
import Content from "./mods/Content/app";
import CalendarTodoWeather from "./mods/API/app";

let toggleControlMenuInstance: (() => void) | null = null;

export function toggleControlMenu() {
    if (toggleControlMenuInstance) {
        toggleControlMenuInstance();
    }
}

export default function Control() {
    const revealed = Variable(false);
    const windowVisible = Variable(false);
    const current_timeout_ref: any = { timer: null };

    const toggle = () => {
        if (windowVisible.get()) {
            revealed.set(false);
            if (current_timeout_ref.timer) {
                current_timeout_ref.timer.cancel();
            }
            current_timeout_ref.timer = timeout(300, () => {
                if (!revealed.get()) {
                    windowVisible.set(false);
                }
                current_timeout_ref.timer = null;
            });
        } else {
            windowVisible.set(true);
            revealed.set(true);
        }
    };

    toggleControlMenuInstance = toggle;

    const cleanup = () => {
        revealed.drop();
        windowVisible.drop();
        if (current_timeout_ref.timer) {
            current_timeout_ref.timer.cancel();
        }
    };

    return (
        <window
            name="control-menu"
            className="control-menu"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            layer={Astal.Layer.TOP}
            visible={bind(windowVisible)}
            onDestroy={cleanup}
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
