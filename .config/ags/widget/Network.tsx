import { bind, GLib, Variable, execAsync } from "astal";
import Network from "gi://AstalNetwork";
import { Gtk, Astal } from "astal/gtk3";

const showNetworks = Variable(false);
const network = Network.get_default();
const wifi = network.wifi;
const isEnabled = Variable(wifi?.enabled || false);
const airplaneMode = Variable(false);

// Helper functions
const removeDuplicates = (list: any[]) => {
	const seen: Record<string, boolean> = {};
	const result: any[] = [];
	for (const item of list) {
		if (item.ssid && !seen[item.ssid]) {
			result.push(item);
			seen[item.ssid] = true;
		}
	}
	return result;
};

const sortByPriority = (list: any[]) => {
	return list.sort((a, b) => (b.strength || 0) - (a.strength || 0));
};

const connectToAccessPoint = (accessPoint: any) => {
	if (!accessPoint || !accessPoint.ssid) {
		return;
	}
	execAsync(`nmcli device wifi connect ${accessPoint.bssid}`);
};

// Components
const AirplaneMode = () => (
	<box className="airplane-mode" orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
		<label
			label="Airplane Mode"
			xalign={0}
			hexpand
		/>
		<switch
			active={bind(airplaneMode)}
			onStateSet={(_, state) => {
				if (state) {
					wifi.enabled = false;
					isEnabled.set(false);
				}
				airplaneMode.set(state);
				return true;
			}}
		/>
	</box>
);

const WifiToggle = () => (
	<box className="wifi-toggle" orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
		<label
			label="Wi-Fi"
			xalign={0}
			hexpand
		/>
		<switch
			active={bind(wifi, "enabled")}
			onStateSet={(_, state) => {
				wifi.enabled = state;
				isEnabled.set(state);
				return true;
			}}
		/>
	</box>
);

const CurrentNetwork = () => (
	<box className="current-network" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
		<box orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
			<icon icon={bind(wifi, "iconName")} />
			<label
				label={bind(wifi, "ssid").as(ssid => ssid || "Not Connected")}
				xalign={0}
			/>
		</box>
		<box className="network-details" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
			<box orientation={Gtk.Orientation.HORIZONTAL}>
				<label label="Signal Strength:" />
				<label
					label={bind(wifi, "strength").as(strength => {
						if (!strength) return "N/A";
						if (strength >= 80) return "Excellent";
						if (strength >= 60) return "Good";
						if (strength >= 40) return "Fair";
						return "Weak";
					})}
					xalign={1}
					hexpand
				/>
			</box>
			<box orientation={Gtk.Orientation.HORIZONTAL}>
				<label label="Frequency:" />
				<label
					label={bind(wifi, "frequency").as(freq =>
						freq ? `${(freq / 1000).toFixed(1)} GHz` : "N/A"
					)}
					xalign={1}
					hexpand
				/>
			</box>
			<box orientation={Gtk.Orientation.HORIZONTAL}>
				<label label="Bandwidth:" />
				<label
					label={bind(wifi, "bandwidth").as(bw =>
						bw ? `${bw} Mbps` : "N/A"
					)}
					xalign={1}
					hexpand
				/>
			</box>
		</box>
	</box>
);

const VisibleNetworks = () => {
	const isScanning = Variable(false);
	const networksReady = Variable(false);
	let cachedNetworks: any = null;

	const startScan = () => {
		if (wifi.enabled) {
			isScanning.set(true);
			networksReady.set(false);
			cachedNetworks = null;

			wifi.scan();

			GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
				cachedNetworks = wifi.access_points;
				isScanning.set(false);
				networksReady.set(true);
				return false;
			});
		}
	};

	const renderNetworks = () => {
		if (!networksReady.get()) {
			return [
				<label
					label="Scanning for networks..."
					xalign={0.5}
				/>
			];
		}

		const list: any[] = [];
		if (cachedNetworks) {
			for (const ap of cachedNetworks) {
				if (ap && ap.ssid && ap.ssid !== "") {
					list.push(ap);
				}
			}
		}

		const uniqueList = removeDuplicates(list);
		sortByPriority(uniqueList);

		if (uniqueList.length === 0) {
			return [
				<label
					label="No networks found"
					xalign={0.5}
				/>
			];
		}

		return uniqueList.map(item => {
			const isActive = wifi.active_access_point &&
				wifi.active_access_point.ssid === item.ssid;

			return (
				<button
					className={`network-item${isActive ? " active" : ""}`}
					onClicked={() => connectToAccessPoint(item)}
				>
					<box orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
						<icon icon={item.icon_name} />
						<label
							label={item.ssid}
							xalign={0}
							hexpand
						/>
						<label
							label={`${item.strength}%`}
							xalign={1}
						/>
					</box>
				</button>
			);
		});
	};

	return (
		<box className="visible-networks" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
			<button
				className="network-selector"
				onClicked={() => {
					showNetworks.set(!showNetworks.get());
					if (showNetworks.get()) {
						startScan();
					} else {
						isScanning.set(false);
						networksReady.set(false);
						cachedNetworks = null;
					}
				}}
			>
				<box orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
					<icon icon="network-wireless-symbolic" />
					<box hexpand>
						<label
							label={bind(isScanning).as(scanning =>
								scanning ? "Scanning..." : "Available Networks"
							)}
							xalign={0}
						/>
					</box>
					<icon
						icon="pan-down-symbolic"
						className={bind(showNetworks).as(shown => shown ? "expanded" : "")}
					/>
				</box>
			</button>
			<revealer
				transitionDuration={200}
				transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
				revealChild={bind(showNetworks)}
			>
				<scrollable
					vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
					hscrollbarPolicy={Gtk.PolicyType.NEVER}
					className="network-list"
				>
					<box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
						{bind(networksReady).as(() => {
							if (!wifi.enabled) {
								return [
									<label
										label="Wi-Fi is disabled"
										xalign={0.5}
									/>
								];
							}
							return renderNetworks();
						})}
					</box>
				</scrollable>
			</revealer>
		</box>
	);
};

// Export the network window component
export const NetworkWindow = ({ gdkmonitor }: any) => {
	const Anchor = Astal.WindowAnchor;
	let window: any;

	window = (
		<window
			className="NetworkWindow"
			gdkmonitor={gdkmonitor}
			anchor={Anchor.TOP | Anchor.RIGHT}
		>
			<box
				orientation={Gtk.Orientation.VERTICAL}
				spacing={15}
				css="padding: 15px;"
			>
				<AirplaneMode />
				<WifiToggle />
				<CurrentNetwork />
				<VisibleNetworks />
			</box>
		</window>
	);

	return window;
};

export default NetworkWindow;
