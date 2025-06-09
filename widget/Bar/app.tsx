import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, bind, GLib, exec, execAsync } from "astal"
import Mpris from "gi://AstalMpris"
import Battery from "gi://AstalBattery"
import Network from "gi://AstalNetwork"
import Tray from "gi://AstalTray"
import ActiveClient from "./mods/ActiveClient"
import Workspace from "./mods/Workspace"
import MediaCava from "./mods/MediaCava"
import { truncateText } from "../../utils/common"
import { Stack } from "astal/gtk3/widget"

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
	const showBatteryName = Variable(false)

	const cleanup = () => {
		showBatteryName.drop();
	};

	return <eventbox onHover={() => showBatteryName.set(true)} onHoverLost={() => showBatteryName.set(false)} onDestroy={cleanup}>
		<box className="Battery">
			<icon icon={bind(bat, "battery_icon_name")} />
			<revealer transitionDuration={200} transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT} revealChild={bind(showBatteryName)}>
				<label label={bind(bat, "percentage").as(p => Math.floor(p * 100) + "%")}/>
			</revealer>
		</box>
	</eventbox >
}

const Wifi = () => {
	const network = Network.get_default()
	const wifiState = Variable.derive([bind(network, "wifi")], (wifi) => wifi)
	const showWifiName = Variable(false)

	const cleanup = () => {
		showWifiName.drop();
		wifiState.drop();
	};

	return <eventbox onHover={() => showWifiName.set(true)} onHoverLost={() => showWifiName.set(false)} onDestroy={cleanup}>
		<box className="Wifi">
			<icon icon={bind(wifiState).as(wifi => wifi.iconName || "")}/>

			<revealer transitionDuration={200} transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT} revealChild={bind(showWifiName)}>
				<label label={bind(wifiState).as(wifi => wifi.ssid || "")}/>
			</revealer>
		</box>
	</eventbox >
}

const Media = () => {
	const mpris = Mpris.get_default();

	const showMediaPlayer = Variable(false)
	const showPlayButton = Variable(false)
	
	// Debounce hover events to prevent spam
	let hoverTimeout: number | null = null
	let hoverLostTimeout: number | null = null
	
	const cleanup = () => {
		showMediaPlayer.drop();
		showPlayButton.drop();
		
		// Cleanup timeouts
		if (hoverTimeout) GLib.source_remove(hoverTimeout);
		if (hoverLostTimeout) GLib.source_remove(hoverLostTimeout);
	};

	return <box className="Media" onDestroy={cleanup}>
		{bind(mpris, "players").as((arr) => arr[0] ? (
			<box spacing={5}>
				<eventbox 
					onHover={() => {
						// Clear any pending hover lost timeout
						if (hoverLostTimeout) {
							GLib.source_remove(hoverLostTimeout);
							hoverLostTimeout = null;
						}
						
						// Debounce hover events to prevent spam
						if (hoverTimeout) {
							GLib.source_remove(hoverTimeout);
						}
						
						hoverTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
							showPlayButton.set(true)
							showMediaPlayer.set(true)
							hoverTimeout = null;
							return false;
						});
					}} 
					onHoverLost={() => {
						// Clear any pending hover timeout
						if (hoverTimeout) {
							GLib.source_remove(hoverTimeout);
							hoverTimeout = null;
						}
						
						// Debounce hover lost events
						if (hoverLostTimeout) {
							GLib.source_remove(hoverLostTimeout);
						}
						
						hoverLostTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
							showPlayButton.set(false)
							showMediaPlayer.set(false)
							hoverLostTimeout = null;
							return false;
						});
					}}
					cursor={"hand1"}
				>
					<circularprogress
					className={"progress-media"}
					endAt={bind(arr[0], "length").as(l => l > 0 ? l : 0)}
					rounded={true}
					value={bind(arr[0], "position").as(p => arr[0].length > 0 ? p / arr[0].length : 0)}
					child={
						<overlay>
							<box className="cover-art" css={bind(arr[0], "coverArt").as((c) => {
								if (!c || c === "") return "background-color: rgba(255, 255, 255, 0.1);"
								return `background-image: url('${c}'); background-size: cover; background-position: center;`
							})} />
							<revealer 
								transitionType={Gtk.RevealerTransitionType.CROSSFADE}
								transitionDuration={200}
								revealChild={bind(showPlayButton)}
							>
								<button
									className="play-pause-bar"
									onClicked={() => arr[0].play_pause()}
									visible={bind(arr[0], "canPause")}
									>
									<icon
										icon={bind(arr[0], "playbackStatus").as(s => s === Mpris.PlaybackStatus.PLAYING ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")} 
									/>
								</button>
							</revealer>
						</overlay>
					}
					/>
				</eventbox>
				<revealer transitionDuration={200} transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT} revealChild={bind(showMediaPlayer)}>
					<box vertical valign={Gtk.Align.CENTER}>
						<label className="title" halign={Gtk.Align.START} label={bind(arr[0], "title").as((t) => truncateText(t || "Unknown Track", 50))} />
						<label className="artist" halign={Gtk.Align.START} label={bind(arr[0], "artist").as((a) => a || "Unknown Artist")} />
					</box>
				</revealer>
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
			<box halign={Gtk.Align.START} spacing={25}>
				<ActiveClient />
				<Media />
				{/* <MediaCava /> */}
			</box>
			<box>
				<Workspace />
			</box>
			<box halign={Gtk.Align.END} spacing={25} css={"margin-right: 20px"} >
				<SysTray />
				<Wifi />
				<BatteryLevel />
				<KhoangTrang />
				<button onClick={() => execAsync("astal -i sownteeastal -t control-menu")}>
					<box vertical>
						<Time />
						<Date />
					</box>
				</button>

			</box>
		</centerbox>
	</window >
}
