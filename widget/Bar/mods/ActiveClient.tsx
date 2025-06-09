import { Gtk } from "astal/gtk3";
import { Variable, bind, exec } from "astal";
import { sanitizeUtf8, truncateText } from "../../../utils/common";

const getActiveWindow = () => {
	const windows = JSON.parse(exec("niri msg --json windows"));

	for (const window of windows) {
		if (window.is_focused) {
			return window;
		}
	}
	return null
}

export default () => {
	const active_window = Variable({}).poll(200, () => {
		return getActiveWindow() || {}
	})

	const cleanup = () => {
		active_window.drop();
	};

	return <box className={"ActiveClient"} onDestroy={cleanup}>
		<box vertical>
			<label className={"app-id"} halign={Gtk.Align.START} label={bind(active_window).as((window: any) => {
				return (sanitizeUtf8(window.app_id || "Desktop")).toLowerCase()
			})}></label>

			<label className={"window-title"} halign={Gtk.Align.START} label={bind(active_window).as((window: any) => {
				return truncateText(window.title || "niri", 40)
			})}></label>
		</box>
	</box>
}
