import { bind, exec, GLib, Variable } from "astal"
import { Gtk, Astal } from "astal/gtk3"
import { type EventBox } from "astal/gtk3/widget"
import Notifd from "gi://AstalNotifd"
import { fileExists } from "../../utils/file"

const iconCache = new Map<string, boolean>()
const isIcon = (icon: string) => {
	if (!icon) return false
	if (iconCache.has(icon)) return iconCache.get(icon)
	
	const result = !!Astal.Icon.lookup_icon(icon)
	iconCache.set(icon, result)
	return result
}

const formatTime = (time: number) => {
	const date = GLib.DateTime.new_from_unix_local(time)
	const hours = date.get_hour().toString().padStart(2, '0')
	const minutes = date.get_minute().toString().padStart(2, '0')
	return `${hours}:${minutes}`
}

const urgency = (n: Notifd.Notification) => {
	const { LOW, NORMAL, CRITICAL } = Notifd.Urgency
	switch (n.urgency) {
		case LOW: return "low"
		case CRITICAL: return "critical"
		case NORMAL:
		default: return "normal"
	}
}

type Props = {
	setup(self: EventBox): void
	onHoverLost(self: EventBox): void
	onHover(self: EventBox): void
	notification: Notifd.Notification
}

export default function Notification(props: Props) {
	const { notification: n, onHoverLost, onHover, setup } = props
	const { START, CENTER, END } = Gtk.Align

	const showActions = Variable(false)

	return <eventbox
		className={`Notification ${urgency(n)}`}
		setup={setup}
		onHoverLost={onHoverLost}
		onHover={onHover}>
		<box className="notification-container">
			{n.image && fileExists(n.image) && <box
				valign={START}
				className="image"
				css={`background-image: url('${n.image}')`}>
			</box>}
			{n.image && isIcon(n.image) && <box
				expand={false}
				valign={START}
				className="icon-image">
				<icon icon={n.image} expand halign={CENTER} valign={CENTER} />
			</box>}
			<box vertical>
				<box>
					<label
						className="notification-summary"
						halign={START}
						xalign={0}
						label={n.summary}
						hexpand
					/>
					<box halign={END}>
						<label
							className="notification-time"
							halign={START}
							label={formatTime(n.time)}
						/>
						<button
							className="notification-expand-button"
							onClicked={() => showActions.set(!showActions.get())}
							css={`background-color: transparent;`}
						>
							<icon icon={"expand-down"} className={bind(showActions).as(shown => shown ? "expanded" : "")} />
						</button>
					</box>
				</box>
				{n.body && <label
					className="notification-body"
					wrap
					useMarkup
					halign={START}
					xalign={0}
					justifyFill
					label={n.body}
				/>}
				<revealer
					transitionDuration={200}
					transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
					revealChild={bind(showActions)}
				>
					<box className="notification-actions">
						<box>
							<button
								onClicked={() => n.dismiss()}>
								<label label="Close" halign={CENTER} hexpand />
							</button>
						</box>
						{n.get_actions().length > 0 && <box>
							{n.get_actions().map(({ label, id }) => (
								<button
									hexpand
									onClicked={() => n.invoke(id)}>
									<label label={label} halign={CENTER} hexpand />
								</button>
							))}
						</box>}
					</box>
				</revealer>
			</box>
		</box>
	</eventbox>
}
