import { Gtk } from "astal/gtk3";
import { Variable, bind, exec } from "astal";

const sanitize_utf8 = (text: string): string => {
	if (!text) {
		return ""
	}
	const regex = /[\x00-\x1F\x7F]/g;
	return text.replace(regex, "");
}

const truncate_text = (text: string, length: number): string => {
	if (!text) {
		return ""
	}
	text = sanitize_utf8(text)
	if (text.length > length) {
		return text.substring(0, length) + "...";
	}
	return text
}

const getActiveWindow = () => {
	let out: any
	try {
		out = exec("niri msg --json windows")
	} catch (err) {
		return null
	}

	let windows: any;
	try {
		windows = JSON.parse(out);
	} catch (error) {
		return null
	}

	for (const window of windows) {
		if (window.is_focused) {
			return window;
		}
	}
	return null
}

export default () => {
	const active_window = Variable({}).poll(500, () => {
		return getActiveWindow() || {}
	})

	return <box className={"ActiveClient"}>
		<box orientation={Gtk.Orientation.VERTICAL}>
			<label className={"app-id"} halign={Gtk.Align.START} label={bind(active_window).as((window: any) => {
				return (sanitize_utf8(window.app_id || "Desktop")).toLowerCase()
			})}></label>

			<label className={"window-title"} halign={Gtk.Align.START} ellipsize={Gtk.Align.END} label={bind(active_window).as((window: any) => {
				return truncate_text(window.title || "niri", 40)
			})}></label>
		</box>
	</box>
}
