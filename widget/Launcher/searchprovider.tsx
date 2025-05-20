import { Gtk, Widget } from "astal/gtk3"
import { bind, Gio, GLib } from "astal"
import { any } from "../../utils/common"
import GdkPixbuf from "gi://GdkPixbuf"
import Pango from "gi://Pango?version=1.0"

type IconData = [number, number, number, boolean, number, number, number[], Uint8Array]
type Meta = { id: string, name: string, description: string, icon: string, icon_data: IconData, gicon?: unknown, clipboard_text?: string}

function decodeVContainer(vcontainer: GLib.Variant): any[] {
	if (!vcontainer) return []
	
	const childrenCount = vcontainer.n_children()
	const result: any[] = new Array(childrenCount)

	for (let i = 0; i < childrenCount; i++) {
		const variant = vcontainer.get_child_value(i)
		result[i] = variant.is_container() 
			? variant.get_data_as_bytes() 
			: variant.unpack()
	}

	return result
}

function getVarDictValue(vardict: GLib.Variant, key: string): any {
	if (!vardict) return undefined

	const childrenCount = vardict.n_children()
	for (let i = 0; i < childrenCount; i++) {
		const entry = vardict.get_child_value(i)
		if (!entry) continue
		
		const entryKey = entry.get_child_value(0)?.get_string()?.[0]
		if (entryKey !== key) continue
		
		const value = entry.get_child_value(1)
		if (!value) return undefined
		
		return value.is_container() ? decodeVContainer(value) : value.unpack()
	}
	return undefined
}

const getBus = (() => {
	let bus: Gio.DBusConnection | null = null
	let pending = false
	
	return (): Gio.DBusConnection | null => {
		if (bus) return bus
		
		if (!pending) {
			pending = true
			Gio.bus_get(Gio.BusType.SESSION, null, (_, task) => {
				bus = Gio.bus_get_finish(task)
				pending = false
			})
		}
		
		return bus
	}
})()

class SearchProvider {
	name: string
	obj: string
	iface: string

	constructor(name: string, obj: string, iface: string) {
		this.name = name
		this.obj = obj
		this.iface = iface
	}

	ActivateResult(
		identifier: string, 
		terms: string[], 
		timestamp: number, 
		callback: (tb: any[]) => void = () => {}
	) {
		if (!getBus()) {
			return
		}
		return getBus()!.call(
			this.name,
			this.obj,
			this.iface,
			"ActivateResult",
			GLib.Variant.new_tuple([
				GLib.Variant.new_strv([identifier]), 
				GLib.Variant.new("(as)", terms)
			]),
			GLib.VariantType.new("(aa{sv})"),
			Gio.DBusCallFlags.NONE,
			-1,
			null,
			(_, task) => {
				const tb: any[] = []
				if (!getBus()) {
					return
				}
				const result = getBus()!.call_finish(task)

				if (result) {
					const variantArray = result.get_child_value(0)
					for (let i = 0; i < variantArray.n_children(); i++) {
						const value = variantArray.get_child_value(i).unpack()
						tb.push(value)
					}
					return callback(tb)
				}
			}
		)
	}

	GetInitialResultSet(terms: string[], callback: (result: string[]) => void) {
		if (!getBus()) {
			return
		}
		return getBus()!.call(
			this.name,
			this.obj,
			this.iface,
			"GetInitialResultSet",
			GLib.Variant.new_tuple([GLib.Variant.new_strv(terms)]),
			GLib.VariantType.new("(as)"),
			Gio.DBusCallFlags.NONE,
			-1,
			null,
			(_, task) => {
				const tb: string[] = []
				if (!getBus()) {
					return
				}
				const result = getBus()!.call_finish(task)

				if (result) {
					const variantArray = result.get_child_value(0)
					for (let i = 0; i < variantArray.n_children(); i++) {
						const value = variantArray.get_child_value(i).unpack() as string
						tb.push(value)
					}
					return callback(tb)
				}
			}
		)
	}

	GetResultMetas(results: string[], callback: (metas: Meta[]) => void) {
		if (!getBus()) {
			return
		}
		return getBus()!.call(
			this.name,
			this.obj,
			this.iface,
			"GetResultMetas",
			GLib.Variant.new_tuple([GLib.Variant.new_strv(results)]),
			GLib.VariantType.new("(aa{sv})"),
			Gio.DBusCallFlags.NONE,
			-1,
			null,
			(_, task) => {
				const tb: Meta[] = []
				if (!getBus()) {
					return
				}
				const result = getBus()!.call_finish(task)

				if (result) {
					const array = result.get_child_value(0)
					for (let i = 0; i < array.n_children(); i++) {
						const vardict = array.get_child_value(i)

						tb.push({
							id: getVarDictValue(vardict, "id"),
							name: getVarDictValue(vardict, "name"),
							description: getVarDictValue(vardict, "description"),
							icon: getVarDictValue(vardict, "icon"),
							icon_data: getVarDictValue(vardict, "icon-data"),
							gicon: getVarDictValue(vardict, "gicon"),
							clipboard_text: getVarDictValue(vardict, "clipboardText"),
						})
					}
					return callback(tb)
				}
			}
		)
	}
}

class SearchProviderWidget {
	title: string
	icon_name: string
	max_items: number
	provider: SearchProvider
	icon_list: any
	item_list: any

	constructor(title: string, icon_name: string, max_items: number, provider: SearchProvider) {
		this.title = title
		this.icon_name = icon_name
		this.max_items = max_items
		this.provider = provider

        this.icon_list = <box orientation={Gtk.Orientation.VERTICAL} setup={(box: any) => {
            for (let i = 0; i < this.max_items; i++) {
                const icon = <icon />
                const label = <label max_width_chars={30} ellipsize={Pango.EllipsizeMode.END} />
                const desc = <label max_width_chars={50} ellipsize={Pango.EllipsizeMode.END} className="description" />
                
                box.add(<revealer>
                        <button valign={Gtk.Align.START} halign={Gtk.Align.START}>
                            <box spacing={10}>
                                {icon}
                                {label}
                                {desc}
                            </box>
                        </button>
                    </revealer>
                )
            }
        }} />

		this.item_list = <revealer transition_type={Gtk.RevealerTransitionType.SLIDE_UP} setup={(revealer: any) => {
			for (const child of this.icon_list.children) {
				revealer.hook(child, "notify::reveal-child", () => {
					revealer.reveal_child = any(this.icon_list.children, (c: any) => c.reveal_child)
				})
			}
		}}>
			<box className="other-container" spacing={5}>
				<box spacing={10} className="app-widget" valign={Gtk.Align.START}>
					<box spacing={10} className="app-widget" valign={Gtk.Align.START}>
						<icon icon={this.icon_name} />
						<label label={this.title} />
					</box>
				</box>
				{this.icon_list}
			</box>
		</revealer>
	}

	UpdateLauncherItem(revealer: any, data: Meta | null) {
		const button = revealer.get_children()[0]
		const box = button.get_children()[0]
		const [icon, label, desc] = box.get_children()

		if (data && data.name) {
			label.label = data.name
			desc.label = data.description || ""
			const hints = data.icon_data

			if (hints && hints.length > 0) {
				icon.pixbuf = GdkPixbuf.Pixbuf.new_from_bytes(
					hints[7],
					GdkPixbuf.Colorspace.RGB,
					Boolean(hints[4]),
					Number(hints[5]),
					Number(hints[1]),
					Number(hints[2]),
					Number(hints[3])
				)
			} else if (data.icon) {
				const [filetype, bytes] = data.icon
				// Handle icon loading here
			}
		} else {
			label.label = ""
			desc.label = ""
		}
	}

	filter(query: string) {
		if (query && query.length > 0) {
			const terms = query.match(/\S+/g) || []

			this.provider.GetInitialResultSet(terms, (result) => {
				if (result && result.length > 0) {
					const tb: string[] = []

					for (let i = 0; i < this.max_items; i++) {
						if (result[i] !== undefined) {
							tb[i] = result[i]
						} else {
							break
						}
					}

					this.provider.GetResultMetas(tb, (metas) => {
						if (metas && metas.length > 0) {
							this.icon_list.children.forEach((value: any, index: number) => {
								this.UpdateLauncherItem(value, metas[index])
							})
						}
					})
				}
			})
		} else {
			this.icon_list.children.forEach((value: any) => {
				this.UpdateLauncherItem(value, null)
			})
		}
	}
}

export { SearchProvider, SearchProviderWidget }