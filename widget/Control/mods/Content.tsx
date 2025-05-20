import { bind, exec, execAsync, GLib, Variable } from "astal";
import Network from "gi://AstalNetwork";
import Gtk from "gi://Gtk";

const network = Network.get_default();
const wifi = network.wifi;

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

const WifiList = () => {
    const isScanning = Variable(false);
	const networksReady = Variable(false);
    let cachedNetworks: any = null;

    const CurrentNetwork = () => (
        <box className="current-wifi" vertical spacing={10}>
            <centerbox>
                <box spacing={10} halign={Gtk.Align.START}>
                    <icon icon={bind(wifi, "iconName")} />
                    <label
                        label={bind(wifi, "ssid").as(ssid => ssid || "Not Connected")}
                        xalign={0}
                    />
                </box>
                <label label="" />
                <button halign={Gtk.Align.END} onClicked={() => {
                    if (!isScanning.get()) {
                        startScan();
                    } else {
                        isScanning.set(false);
                    }
                }}>
                    <icon icon="reload-icon-v2" />
                </button>
            </centerbox>
            <box className="wifi-details" vertical spacing={10}>
                <box>
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
                <box>
                    <label label="Frequency:" />
                    <label
                        label={bind(wifi, "frequency").as(freq =>
                            freq ? `${(freq / 1000).toFixed(1)} GHz` : "N/A"
                        )}
                        xalign={1}
                        hexpand
                    />
                </box>
                <box>
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
					className="no-networks"
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
					<box spacing={10}>
						<icon icon={item.icon_name} />
						<label
							label={item.ssid}
							xalign={0}
							hexpand
						/>
					</box>
				</button>
			);
		});
	};

    return (
        <box vertical spacing={20} className="wifi-container">
            {CurrentNetwork()}
            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="wifi-list"
            >
                <box vertical spacing={5}>
                    {bind(networksReady).as((ready) => {
                        if (ready && !isScanning.get()) {
                            isScanning.set(true);
                        }
                        
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
        </box>
    );
};

const NotificationList = () => {
    return (
        <box vertical spacing={10} className="notification-container">
            <label label="Notification" />
        </box>
    );
}

const BluetoothList = () => {
    return (
        <box vertical spacing={10} className="bluetooth-container">
            <label label="Bluetooth" />
        </box>
    );
}

const InputOutputList = () => {
    return (
        <box vertical spacing={10} className="input-output-container">
            <label label="Input/Output" />
        </box>
    );
}

export default () => {
    const buttons = [
        {
            label: "Notifications",
            icon: "notification-symbolic",
        },
        {
            label: "Wi-Fi",
            icon: "network-wireless-symbolic",
        },
        {
            label: "Bluetooth",
            icon: "bluetooth-symbolic",
        },
        {
            label: "Volume",
            icon: "audio-volume-high-symbolic",
        },
    ];

    const content = Variable(<NotificationList />);
    const buttonSelected = Variable(0);
    return (
        <box vertical className="content-container" spacing={30}>
            <box spacing={10} className="button-container" halign={Gtk.Align.CENTER}>
                {buttons.map((button, index) => (
                    <button
                        className={bind(buttonSelected).as((selected) => {
                            if (selected === index) {
                                return "active";
                            }
                            return "";
                        })}
                        onClicked={() => {
                            if (button.label === "Wi-Fi") {
                                content.set(<WifiList />);
                                buttonSelected.set(index);
                            } else if (button.label === "Notifications") {
                                content.set(<NotificationList />);
                                buttonSelected.set(index);
                            } else if (button.label === "Bluetooth") {
                                content.set(<BluetoothList />);
                                buttonSelected.set(index);
                            } else if (button.label === "Volume") {
                                content.set(<InputOutputList />);
                                buttonSelected.set(index);
                            }
                        }}>
                        {bind(buttonSelected).as((selected) => {
                            if (selected === index) {
                                return <box spacing={10}>
                                    <icon icon={button.icon} />
                                    <label label={button.label} />
                                </box>
                            }
                            return <icon icon={button.icon} />
                        })}
                    </button>
                ))}
            </box>
            <box vertical spacing={10}>
                {bind(content).as((content) => {
                    return content;
                })}
            </box>
        </box>
    );
}