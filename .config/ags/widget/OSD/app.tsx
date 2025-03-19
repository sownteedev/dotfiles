import Wp from "gi://AstalWp"
import { bind, timeout } from "astal";
import { Astal, Gdk, App, Gtk } from "astal/gtk3"
import Brightness from "./brightness";

const SHOW_TIME: number = 2000

const createVolumeIndicator = (device: any, class_name: any) => {
	return <box className={`${class_name}`} visible={false}>
		<box className={"indicator"}>
			<icon icon={bind(device, "volume-icon")} />
			<label label={bind(device, "volume").as((vol) => `${Math.floor((vol ? vol : 0) * 100)}%`)} />
		</box>

		<box className="slider-container">
			<slider className="volume-slider" hexpand={true} onDragged={(slider) => device.volume = slider.value} value={bind(device, "volume")} />
		</box>
	</box>
}

const createMuteIndicator = (device: any, class_name: any) => {
	return <box className={`${class_name}-mute`} visible={false}>
		<icon icon={bind(device, "volume-icon")} />
	</box>
}

const createBrightnessIndicator = (brightness: any) => {
	return <box className="brightness-indicator" visible={false}>
		<box className={"indicator"}>
			<icon icon="display-brightness-symbolic" />
			<label label={bind(brightness, "screen").as((level) => `${Math.floor((level ? level : 0) * 100)}%`)} />
		</box>
		<box className="slider-container">
			<slider className="brightness-slider" hexpand={true} onDragged={(slider) => brightness.screen = slider.value} value={bind(brightness, "screen")} />
		</box>
	</box>
}

const createOSDWidget = (current_timeout_ref: any) => {
	const speaker = Wp.get_default()!.audio.default_speaker
	const mic = Wp.get_default()!.audio.default_microphone
	const brightness = Brightness.get_default()

	return <box
		className={"OSD"}
		vertical={true}
		setup={(self) => {
			const speaker_vol = self.children[0]
			const speaker_mute = self.children[1]
			const mic_vol = self.children[2]
			const mic_mute = self.children[3]
			const brightness_indicator = self.children[4]

			const showOSD = (widget: any) => {
				speaker_vol.visible = false
				mic_vol.visible = false
				speaker_mute.visible = false
				mic_mute.visible = false
				brightness_indicator.visible = false

				widget.visible = true
				if (current_timeout_ref.timer) {
					current_timeout_ref.timer.cancel()
				}

				current_timeout_ref.timer = timeout(SHOW_TIME, () => {
					widget.visible = false
					current_timeout_ref.timer = null
				})
			}

			bind(speaker, "volume").subscribe(() => {
				showOSD(speaker_vol)
			})
			bind(speaker, "mute").subscribe((muted: any) => {
				showOSD(muted ? speaker_mute : speaker_vol)
			})
			bind(mic, "volume").subscribe(() => {
				showOSD(mic_vol)
			})
			bind(mic, "mute").subscribe((muted: any) => {
				showOSD(muted ? mic_mute : mic_vol)
			})
			bind(brightness, "screen").subscribe(() => {
				showOSD(brightness_indicator)
			})
		}}>
		{createVolumeIndicator(speaker, "volume-indicator")}
		{createMuteIndicator(speaker, "volume-indicator")}
		{createVolumeIndicator(mic, "mic-indicator")}
		{createMuteIndicator(mic, "mic-indicator")}
		{createBrightnessIndicator(brightness)}
	</box>
}

export default function OSD(gdkmonitor: Gdk.Monitor) {
	const current_timeout_ref: any = { timer: null }

	return <window
		className="OSDWindow"
		gdkmonitor={gdkmonitor}
		application={App}
		anchor={Astal.WindowAnchor.BOTTOM}
		onDestroy={() => {
			if (current_timeout_ref.timer) {
				current_timeout_ref.timer.cancel()
			}
		}}>
		{createOSDWidget(current_timeout_ref)}
	</window>
}
