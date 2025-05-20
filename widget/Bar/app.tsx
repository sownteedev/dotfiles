import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, bind, GLib } from "astal"
import Mpris from "gi://AstalMpris"
import Battery from "gi://AstalBattery"
import Network from "gi://AstalNetwork"
import Tray from "gi://AstalTray"
import ActiveClient from "./mods/ActiveClient"
import Workspace from "./mods/Workspace"
import { truncateText } from "../../utils/common"
import MediaPlayer from "../MediaPlayer"

const SysTray = () => {
	const tray = Tray.get_default()
	return <box spacing={25}>
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

const Wifi = () => {
	const network = Network.get_default()
	const wifiState = Variable.derive([bind(network, "wifi")], (wifi) => wifi)

	return <button>
		{
			bind(wifiState).as((w) => {
				return <icon
					tooltipText={bind(w, "ssid").as(String)}
					className="Wifi"
					icon={bind(w, "iconName")}
				/>
			})
		}
	</button >
}

let mprisWindow: any = null
const Media = () => {
	const mpris = Mpris.get_default();
	const windowVisible = Variable(false)
	const toggleMediaPlayer = () => {
		if (windowVisible.get() && mprisWindow != null) {
			mprisWindow.hide();
			windowVisible.set(false);
		} else {
			if (mprisWindow == null) {
				mprisWindow = MediaPlayer(Gdk.Monitor);
		}
			if (mprisWindow) {
				mprisWindow.show_all();
			}
			windowVisible.set(true);
		}
	}

	return <button className="Media" onClick={toggleMediaPlayer}>
		{bind(mpris, "players").as((arr) => arr[0] ? (
			<box>
				<box className="cover-art" css={bind(arr[0], "coverArt").as((c) => `background-image: url('${c || ""}')`)} />
				<box vertical>
					<label className="title" halign={Gtk.Align.START} label={bind(arr[0], "title").as((t) => truncateText(t || "Unknown Track", 50))} />
					<label className="artist" halign={Gtk.Align.START} label={bind(arr[0], "artist").as((a) => a || "Unknown Artist")} />
				</box>
			</box>
		) : (
			<label label="" />
		))}
	</button>
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
				<ActiveClient />
				{/* <Media /> */}
			</box>
			<box>
				<Workspace />
			</box>
			<box halign={Gtk.Align.END} spacing={25} css={"margin-right: 20px"} >
				<SysTray />
				<Wifi />
				<BatteryLevel />
				<KhoangTrang />
				<box vertical>
					<Time />
					<Date />
				</box>
			</box>
		</centerbox>
	</window >
}
