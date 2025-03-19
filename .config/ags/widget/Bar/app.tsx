import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, bind, GLib } from "astal"
import Mpris from "gi://AstalMpris"
import Battery from "gi://AstalBattery"
import Network from "gi://AstalNetwork"
import Tray from "gi://AstalTray"
import ActiveClient from "./mods/ActiveClient"
import Workspace from "./mods/Workspace"
import NetworkWindow from "../Network"
const SysTray = () => {
	const tray = Tray.get_default()

	return <box className={"SysTray"} spacing={25}>
		{bind(tray, "items").as(items => items.map(item => (
			<menubutton
				tooltipMarkup={bind(item, "tooltipMarkup")}
				usePopover={false}
				actionGroup={bind(item, "actionGroup").as(ag => ["dbusmenu", ag])}
				menuModel={bind(item, "menuModel")}>
				<icon className={"SysTrayIcon"} gicon={bind(item, "gicon")} />
			</menubutton>)
		))}
	</box>
}

const KhoangTrang = () => {
	return <label className={"Chia"} label={"│"} />
}

const Date = ({ format = "%a, %d %b %Y" }) => {
	const date = Variable<string>("").poll(1000, () =>
		GLib.DateTime.new_now_local().format(format)!)

	return <label
		className={"Date"}
		halign={Gtk.Align.END}
		onDestroy={() => date.drop()}
		label={date()}
	/>
}

const Time = ({ format = "%I : %M %p" }) => {
	const time = Variable<string>("").poll(1000, () =>
		GLib.DateTime.new_now_local().format(format)!)

	return <label
		className="Time"
		halign={Gtk.Align.END}
		onDestroy={() => time.drop()}
		label={time()}
	/>
}

const BatteryLevel = () => {
	const bat = Battery.get_default()

	return <button>
		<box>
			<icon
				className="BatteryIcon"
				tooltip_text={bind(bat, "percentage").as(function(p) {
					return Math.floor(p * 100) + "%";
				})}
				icon={bind(bat, "battery_icon_name")}
			/>
		</box>
	</button >
}

let networkWindow: any = null
const Wifi = () => {
	const network = Network.get_default()
	const windowVisible = Variable(false)
	const wifiState = Variable.derive([bind(network, "wifi")], (wifi) => wifi)

	const toggleNetworkWindow = () => {
		if (windowVisible.get() && networkWindow != null) {
			networkWindow.hide();
			windowVisible.set(false);
		} else {
			if (networkWindow == null) {
				networkWindow = NetworkWindow(Gdk.Monitor);
			}
			if (networkWindow) {
				networkWindow.show_all();
			}
			windowVisible.set(true);
		}
	};

	return <button
		visible={bind(wifiState).as((v) => v != null)}
		onClick={toggleNetworkWindow}
		setup={(self) => {
			self.hook(self, "destroy", () => {
				windowVisible.drop()
				wifiState.drop()
			})
		}}>
		{bind(wifiState).as((w) => {
			return <icon
				tooltipText={bind(w, "ssid").as(String)}
				className="Wifi"
				icon={bind(w, "iconName")}
			/>
		})
		}
	</button>
}

const Media = () => {
	const mpris = Mpris.get_default();

	return <box className="Media">
		{bind(mpris, "players").as((arr) => arr[0] ? (
			<box>
				<box className="cover-art" css={bind(arr[0], "coverArt").as((c) => `background-image: url('${c || ""}')`)} />
				<box orientation={Gtk.Orientation.VERTICAL}>
					<label className="title" halign={Gtk.Align.START} label={bind(arr[0], "title").as((t) => t || "Unknown Track")} />
					<label className="artist" halign={Gtk.Align.START} label={bind(arr[0], "artist").as((a) => a || "Unknown Artist")} />
				</box>
			</box>
		) : (
			<label label="" />
		))}
	</box>
};

export default function Bar(gdkmonitor: Gdk.Monitor) {
	const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

	return <window
		className="Bar"
		gdkmonitor={gdkmonitor}
		exclusivity={Astal.Exclusivity.EXCLUSIVE}
		anchor={TOP | LEFT | RIGHT}
		application={App}>
		<centerbox>
			<box halign={Gtk.Align.START}>
				<Workspace />
				<ActiveClient />
			</box>
			<box>
				<Media />
			</box>
			<box halign={Gtk.Align.END} spacing={25} css={"margin-right: 20px"} >
				<SysTray />
				<Wifi />
				<BatteryLevel />
				<KhoangTrang />
				<box orientation={Gtk.Orientation.VERTICAL}>
					<Time />
					<Date />
				</box>
			</box>
		</centerbox>
	</window >
}
