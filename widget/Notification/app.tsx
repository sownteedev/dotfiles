import { Astal, Gtk, Gdk } from "astal/gtk3"
import Notifd from "gi://AstalNotifd"
import Notification from "./Notification"
import { type Subscribable } from "astal/binding"
import { Variable, bind, timeout } from "astal"
import GLib from "gi://GLib"

const TIMEOUT_DELAY = 5000

class NotifiationMap implements Subscribable {
	// the underlying map to keep track of id widget pairs
	private map: Map<number, Gtk.Widget> = new Map()
	private timeouts: Map<number, number> = new Map()

	// it makes sense to use a Variable under the hood and use its
	// reactivity implementation instead of keeping track of subscribers ourselves
	private var: Variable<Array<Gtk.Widget>> = Variable([])

	// notify subscribers to rerender when state changes
	private notifiy() {
		this.var.set([...this.map.values()].reverse())
	}

	constructor() {
		const notifd = Notifd.get_default()

		/**
		 * uncomment this if you want to
		 * ignore timeout by senders and enforce our own timeout
		 * note that if the notification has any actions
		 * they might not work, since the sender already treats them as resolved
		 */
		// notifd.ignoreTimeout = true

		notifd.connect("notified", (_, id) => {
			this.set(id, Notification({
				notification: notifd.get_notification(id)!,

				// When hovering, clear the timeout
				onHover: () => {
					const timeoutId = this.timeouts.get(id);
					if (timeoutId) {
						GLib.source_remove(timeoutId);
						this.timeouts.delete(id);
					}
				},

				// When mouse leaves, start a new timeout
				onHoverLost: () => {
					const timeoutId = timeout(TIMEOUT_DELAY, () => {
						this.delete(id);
					});
					this.timeouts.set(id, Number(timeoutId));
				},

				// Setup initial timeout
				setup: () => {
					const timeoutId = timeout(TIMEOUT_DELAY, () => {
						this.delete(id);
					});
					this.timeouts.set(id, Number(timeoutId));
				}
			}))
		})

		// notifications can be closed by the outside before
		// any user input, which have to be handled too
		notifd.connect("resolved", (_, id) => {
			this.delete(id)
		})
	}

	private set(key: number, value: Gtk.Widget) {
		// in case of replacecment destroy previous widget
		this.map.get(key)?.destroy()
		this.map.set(key, value)
		this.notifiy()
	}

	private delete(key: number) {
		const timeoutId = this.timeouts.get(key);
		if (timeoutId) {
			GLib.source_remove(timeoutId);
			this.timeouts.delete(key);
		}
		this.map.get(key)?.destroy()
		this.map.delete(key)
		this.notifiy()
	}

	// needed by the Subscribable interface
	get() {
		return this.var.get()
	}

	// needed by the Subscribable interface
	subscribe(callback: (list: Array<Gtk.Widget>) => void) {
		return this.var.subscribe(callback)
	}
}

export default function NotificationPopups(gdkmonitor: Gdk.Monitor) {
	const { TOP, RIGHT } = Astal.WindowAnchor
	const notifs = new NotifiationMap()

	return <window
		className="NotificationPopups"
		gdkmonitor={gdkmonitor}
		anchor={TOP}>
		<box vertical spacing={10}>
			{bind(notifs)}
		</box>
	</window>
}

