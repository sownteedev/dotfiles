import { bind, GLib, Variable } from "astal"
import { Gtk, Astal } from "astal/gtk3"
import { type EventBox } from "astal/gtk3/widget"
import Notifd from "gi://AstalNotifd"
import { fileExists } from "../../utils/file"

const iconCache = new Map<string, boolean>()
const MAX_CACHE_SIZE = 200

const isIcon = (icon: string) => {
	if (!icon) return false
	if (iconCache.has(icon)) return iconCache.get(icon)
	
	const result = !!Astal.Icon.lookup_icon(icon)
	
	// Limit cache size to prevent memory leak
	if (iconCache.size >= MAX_CACHE_SIZE) {
		const firstKey = iconCache.keys().next().value
		if (firstKey) {
			iconCache.delete(firstKey)
		}
	}
	
	iconCache.set(icon, result)
	return result
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
		onHover={onHover}
		onDestroy={() => {
			showActions.drop();
		}}>
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
			{!n.image && <button
				className="default-icon-notification"
				valign={Gtk.Align.START}>
				<icon icon="default-notification-symbolic" />
			</button>}
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
							label={"now"}
						/>
						<button
							className="notification-expand-button"
							cursor={"hand1"}
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
								cursor={"hand1"}
								onClicked={() => n.dismiss()}>
								<label label="Close" halign={CENTER} hexpand />
							</button>
						</box>
						{n.get_actions().length > 0 && <box>
							{n.get_actions().map(({ label, id }) => (
								<button
									cursor={"hand1"}
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
