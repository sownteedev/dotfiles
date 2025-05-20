import { Astal, Gtk } from "astal/gtk3"
import Mpris from "gi://AstalMpris"
import { bind } from "astal"

function lengthStr(length: number) {
	const hours = Math.floor(length / 3600)
	const min = Math.floor((length % 3600) / 60)
	const sec = Math.floor(length % 60)
	const min0 = hours > 0 && min < 10 ? "0" : ""
	const sec0 = sec < 10 ? "0" : ""
	
	return hours > 0 
		? `${hours}:${min0}${min}:${sec0}${sec}`
		: `${min}:${sec0}${sec}`
}

function MediaPlayer({ player }: { player: Mpris.Player }) {
	const { START, END } = Gtk.Align

	const title = bind(player, "title").as(t =>
		t || "Unknown Track")

	const artist = bind(player, "artist").as(a =>
		a || "Unknown Artist")

	const coverArt = bind(player, "coverArt").as(c =>
		`background-image: url('${c}')`)

	const playerIcon = bind(player, "entry").as(e =>
		Astal.Icon.lookup_icon(e) ? e : "audio-x-generic-symbolic")

	const position = bind(player, "position").as(p => player.length > 0
		? p / player.length : 0)

	const playIcon = bind(player, "playbackStatus").as(s =>
		s === Mpris.PlaybackStatus.PLAYING
			? "media-playback-pause-symbolic"
			: "media-playback-start-symbolic"
	)

	return <box className="MediaPlayer">
		<box className="cover-art" css={coverArt} />
		<box vertical>
			<box vertical spacing={5}>
				<box className="title">
					<label truncate hexpand halign={START} label={title} />
					<icon icon={playerIcon} />
				</box>
				<box className="artist">
					<label halign={START} valign={START} vexpand wrap label={artist} />
				</box>
			</box>
			<box vertical spacing={5}>
			<slider
				className={"slider"}
				visible={bind(player, "length").as(l => l > 0)}
				onDragged={({ value }) => player.position = value * player.length}
				value={position}
			/>
				<centerbox className="actions">
					<label
						hexpand
						className="position"
						halign={START}
						visible={bind(player, "length").as(l => l > 0)}
						label={bind(player, "position").as(lengthStr)}
					/>
					<box>
						<button
							onClicked={() => player.previous()}
							visible={bind(player, "canGoPrevious")}>
							<icon icon="media-skip-backward-symbolic" />
						</button>
						<button
							onClicked={() => player.play_pause()}
							visible={bind(player, "canPause")}>
							<icon icon={playIcon} />
						</button>
						<button
							onClicked={() => player.next()}
							visible={bind(player, "canGoNext")}>
							<icon icon="media-skip-forward-symbolic" />
						</button>
					</box>
					<label
						className="length"
						hexpand
						halign={END}
						visible={bind(player, "length").as(l => l > 0)}
						label={bind(player, "length").as(l => l > 0 ? lengthStr(l) : "0:00")}
					/>
				</centerbox>
			</box>
		</box>
	</box>
}

export default function MprisPlayers({ gdkmonitor }: any) {
	const mpris = Mpris.get_default()
	const Anchor = Astal.WindowAnchor;
	let window: any;

	window = (
		<window
			gdkmonitor={gdkmonitor}
			anchor={Anchor.TOP}
			css="background-color: transparent;"
		>
			<box vertical>
				{bind(mpris, "players").as(arr => arr.map(player => (
					<MediaPlayer player={player} />
				)))}
			</box>
		</window>
	);

	return window;

}
