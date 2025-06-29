import { bind, exec, execAsync, GLib, Variable } from "astal";
import { Astal, Gtk, Gdk } from "astal/gtk3";
import Network from "gi://AstalNetwork";
import Bluetooth from "gi://AstalBluetooth";
import Wp from "gi://AstalWp"
import Notifd from "gi://AstalNotifd"
import Battery from "gi://AstalBattery"
import PowerProfiles from "gi://AstalPowerProfiles";
import { sanitizeUtf8, truncateText } from "../../../utils/common";
import { fileExists } from "../../../utils/file";

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

const getIPAddress = async () => {
    const info = await execAsync(`curl https://ipinfo.io/ip`);
    return info.toString().trim().slice(0, info.length - 2) + "?";
};
export const IPAddress = Variable("");
export { getIPAddress };
getIPAddress().then(ip => IPAddress.set(ip));

// Auto refresh IP address when wifi state changes
let wifiStateTimeout: number | null = null;
const refreshIPOnWifiChange = () => {
    if (wifiStateTimeout) {
        GLib.source_remove(wifiStateTimeout);
    }
    wifiStateTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
        if (wifi.enabled && wifi.active_access_point) {
            getIPAddress().then(ip => IPAddress.set(ip));
        } else {
            IPAddress.set("N/A");
        }
        wifiStateTimeout = null;
        return false;
    });
};

// Listen to wifi state changes
wifi.connect("notify::state", refreshIPOnWifiChange);

const WifiList = () => {
    const isScanning = Variable(false);
	const networksReady = Variable(false);
    let cachedNetworks: any = null;

    // Track the current view and selected network
    const showPasswordEntry = Variable(false);
    const selectedNetwork = Variable<any>(null);
    const passwordText = Variable("");
    const connectionError = Variable("");
    const storedConnections = Variable(new Set<string>());
    
    // Store timeout IDs for cleanup
    let scanTimeoutId: number | null = null;
    let autoStartTimeoutId: number | null = null;
    let forgetTimeoutIds: number[] = [];
    
    // Cleanup function
    const cleanup = () => {
        if (scanTimeoutId) {
            GLib.source_remove(scanTimeoutId);
            scanTimeoutId = null;
        }
        if (autoStartTimeoutId) {
            GLib.source_remove(autoStartTimeoutId);
            autoStartTimeoutId = null;
        }
        // Cleanup forget timeouts
        forgetTimeoutIds.forEach(id => {
            GLib.source_remove(id);
        });
        forgetTimeoutIds = [];
        // Cleanup variables
        isScanning.drop();
        networksReady.drop();
        showPasswordEntry.drop();
        selectedNetwork.drop();
        passwordText.drop();
        connectionError.drop();
        storedConnections.drop();
    };

    const CurrentNetwork = () => (
        <box className="current-wifi" vertical spacing={10}>
            <centerbox>
                <box spacing={10} halign={Gtk.Align.START}>
                    <icon icon={bind(wifi, "iconName")} />
                    <label label={bind(wifi, "ssid").as(ssid => ssid || "Not Connected")}/>
                </box>
                <label label="" />
                <button halign={Gtk.Align.END} cursor={"hand1"} onClicked={() => {
                    if (!isScanning.get()) {
                        startScan();
                    } else {
                        isScanning.set(false);
                    }
                }}
                >
                    <icon icon="reload-icon-v2" />
                </button>
            </centerbox>
            <box className="wifi-details" vertical spacing={10}>
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
                <box>
                    <label label="IP Address:" />
                    <label
                        label={bind(IPAddress).as(ip => ip || "N/A")}
                        xalign={1}
                        hexpand
                    />
                </box>
            </box>
        </box>
    );

	const startScan = () => {
		if (wifi.enabled) {
			updateStoredConnections();
			isScanning.set(true);
			networksReady.set(false);
			cachedNetworks = null;

			wifi.scan();

            // Clear existing timeout before setting new one
            if (scanTimeoutId) {
                GLib.source_remove(scanTimeoutId);
            }

			scanTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
				cachedNetworks = wifi.access_points;
				isScanning.set(false);
				networksReady.set(true);
                scanTimeoutId = null;
				return false;
			});
		}
	};

    // Auto-start scan when component is first created
    autoStartTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
        if (wifi.enabled && !isScanning.get()) {
            startScan();
        }
        return false;
    });

	// Update stored connections list
	const updateStoredConnections = async () => {
		try {
			const result = await execAsync('nmcli -g NAME,TYPE connection show');
			const connections = result.toString().trim().split('\n');
			const wifiConnections = new Set<string>();
			
			connections.forEach(line => {
				const [name, type] = line.split(':');
				if (type === '802-11-wireless') {
					wifiConnections.add(name);
				}
			});
			
			storedConnections.set(wifiConnections);
		} catch {
			storedConnections.set(new Set<string>());
		}
	};

	// Forget WiFi connection
	const forgetWifi = async (ssid: string) => {
		try {
			await execAsync(`nmcli connection delete "${ssid}"`);
			connectionError.set(`Forgotten "${ssid}"`);
			const timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
				connectionError.set("");
				return false;
			});
			forgetTimeoutIds.push(timeoutId);
			updateStoredConnections();
			startScan();
		} catch (error) {
			connectionError.set(`Failed to forget: ${String(error)}`);
			const timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 3000, () => {
				connectionError.set("");
				return false;
			});
			forgetTimeoutIds.push(timeoutId);
		}
	};

    // Improved connect function with password support
    const connectToWifi = async (accessPoint: any, password?: string) => {
        if (!accessPoint || !accessPoint.ssid) {
            return;
        }
        
        connectionError.set("Connecting...");
        
        try {
            let command: string;
            
            if (password) {
                // Nếu có password, xóa connection cũ trước (nếu có) để tránh lỗi key-mgmt
                try {
                    await execAsync(`nmcli connection delete "${accessPoint.ssid}"`);
                } catch {
                    // Ignore error if connection doesn't exist
                }
                
                // Connect with password
                command = `nmcli device wifi connect "${accessPoint.ssid}" password "${password}"`;
            } else {
                // Connect directly (for open networks)
                command = `nmcli device wifi connect "${accessPoint.bssid}"`;
            }
            
            const result = await execAsync(command);
            const resultStr = result.toString();
            
            if (resultStr.includes("error") || resultStr.includes("failed")) {
                connectionError.set("Connection failed: " + resultStr);
            } else {
                connectionError.set("");
                showPasswordEntry.set(false);
                selectedNetwork.set(null);
                passwordText.set("");
                
                // Use GLib.timeout_add instead of setTimeout
                GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
                    startScan();
                    return false;
                });
                
                // Refresh IP address after successful connection
                GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
                    getIPAddress().then(ip => IPAddress.set(ip));
                    return false;
                });
            }
        } catch (error) {}
    };

    const PasswordEntry = () => {
        return (
            <box vertical spacing={20} className="password-entry">
                <centerbox className="password-entry-header">
                    <box spacing={10} halign={Gtk.Align.START}>
                        <icon icon={selectedNetwork.get()?.icon_name || "network-wireless-symbolic"} />
                        <label label={`Connect to ${selectedNetwork.get()?.ssid}`} />
                    </box>
                    <box />
                    <button halign={Gtk.Align.END} cursor={"hand1"} onClicked={() => {
                        showPasswordEntry.set(false);
                        selectedNetwork.set(null);
                        passwordText.set("");
                        connectionError.set("");
                    }}
                    >
                        <icon icon="go-previous-symbolic" />
                    </button>
                </centerbox>
                
                <box vertical spacing={15} className="password-entry-body">
                    <label label="Password" xalign={0} />
                    <entry
                        placeholderText="Enter WiFi password"
                        onActivate={() => {
                            connectToWifi(selectedNetwork.get(), passwordText.get());
                        }}
                        onChanged={(self: Gtk.Entry) => {
                            passwordText.set(self.text);
                        }}
                        className={bind(connectionError).as(error => {
                            if (error.includes("Connecting")) {
                                return "status-connecting";
                            };
                            if (error.includes("Wrong password")) {
                                return "status-error";
                            }
                            return "";
                        })}
                    />
                    <box halign={Gtk.Align.END}>
                        <button
                            className="connect-button"
                            cursor={"hand1"}
                            onClicked={() => {
                                connectToWifi(selectedNetwork.get(), passwordText.get());
                            }}
                        >
                            {bind(connectionError).as(error => {
                                if (error.includes("Connecting")) {
                                    return <label label="Connecting..." />;
                                }
                                return <label label="Connect" />;
                            })}
                        </button>
                    </box>
                </box>
            </box>
        );
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
			const isActiveNetwork = wifi.active_access_point &&
				wifi.active_access_point.ssid === item.ssid;

            return (
                <box className={`network-item${isActiveNetwork ? " active" : ""}`}>
                    <button
                    cursor={"hand1"}
					onClicked={async () => {
                        if (isActiveNetwork) {
                            return;
                        }
                        
                        const needsPassword = (item.wpa_flags > 0 || item.rsn_flags > 0);
                        
                        if (needsPassword) {
                            // Kiểm tra xem có stored connection không
                            if (storedConnections.get().has(item.ssid)) {
                                // Có stored connection - thử kết nối
                                try {
                                    connectionError.set("Connecting...");
                                    const result = await execAsync(`nmcli connection up "${item.ssid}"`);
                                    const resultStr = result.toString();
                                    
                                    if (!resultStr.includes("error") && !resultStr.includes("failed")) {
                                        // Kết nối thành công với stored connection
                                        connectionError.set("");
                                        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
                                            startScan();
                                            return false;
                                        });
                                        
                                        // Refresh IP address after successful connection
                                        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
                                            getIPAddress().then(ip => IPAddress.set(ip));
                                            return false;
                                        });
                                        return;
                                    }
                                } catch {
                                    // Fail khi kết nối với stored connection
                                }
                            }
                            
                            // Chưa có stored connection hoặc kết nối fail -> hiện PasswordEntry
                            selectedNetwork.set(item);
                            showPasswordEntry.set(true);
                            passwordText.set("");
                            connectionError.set("");
                        } else {
                            connectToWifi(item);
                        }
                    }}
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
                    <box>
                        {storedConnections.get().has(item.ssid) && 
                        <button className="forget-wifi-button" cursor={"hand1"} onClicked={() => forgetWifi(item.ssid)}>
                            <icon icon="edit-delete-symbolic" className="forget-wifi-icon" />
                        </button>}
                        {(item.wpa_flags > 0 || item.rsn_flags > 0) && 
                            <icon icon="security-high-symbolic" className="security-icon" />
                        }
                    </box>
                </box>
            )
		});
	};

    return (
        <box vertical spacing={20} className="wifi-container" onDestroy={cleanup}>
            {bind(wifi, "enabled").as(enabled => {
                if (!enabled) {
                    return (
                        <box vertical spacing={20}>
                        {
                        bind(Variable.derive([bind(network, "wifi")], (wifi) => wifi)).as((w) => <icon icon={bind(w, "iconName")} css={"font-size: 150px; margin-top: 200px"}/>)
                        }
                            <label label="Wifi is disabled" xalign={0.5} css={"font-size: 20px; font-weight: 500"} />
                        </box>
                    );
                }

                return (
                    <box vertical spacing={20}>
                        {bind(showPasswordEntry).as(show => {
                            if (show) {
                                return (
                                    <>
                                        {CurrentNetwork()}
                                        <PasswordEntry />
                                    </>
                                );
                            } else {
                                return (
                                    <>
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
                                                    return renderNetworks();
                                                })}
                                            </box>
                                        </scrollable>
                                    </>
                                );
                            }
                        })}
                    </box>
                );
            })}
        </box>
    );
};


const iconCache = new Map<string, boolean>()
const MAX_CACHE_SIZE = 500

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
const formatTimeAgo = (time: number): string => {
    const now = GLib.DateTime.new_now_local().to_unix();
    const diff = now - time;
    
    if (diff < 60) {
        return "now";
    }
    
    if (diff < 3600) {
        const minutes = Math.floor(diff / 60);
        return `${minutes}m ago`;
    }
    
    if (diff < 86400) {
        const hours = Math.floor(diff / 3600);
        return `${hours}h ago`;
    }
    
    const date = GLib.DateTime.new_from_unix_local(time);
    const day = date.get_day_of_month().toString().padStart(2, '0');
    const month = (date.get_month()).toString().padStart(2, '0');
    const year = date.get_year().toString();
    
    const currentYear = GLib.DateTime.new_now_local().get_year();
    if (date.get_year() === currentYear) {
        return `${day}/${month}`;
    }
    
    return `${day}/${month}/${year}`;
}

const NotificationList = () => {
    const notifd = Notifd.get_default();
    const notifications = Variable<any[]>(notifd.notifications);
    const allNotifications = Variable<any[]>([...notifd.notifications]);
    const notificationCount = Variable(allNotifications.get().length);
    
    const timeRefresher = Variable(Date.now());
    
    // Store timeout IDs for cleanup
    let timeRefresherId: number | null = null;
    let pollingTimeoutId: number | null = null;
    let notificationConnections: number[] = [];
    
    // Cleanup function
    const cleanup = () => {
        if (timeRefresherId) {
            GLib.source_remove(timeRefresherId);
            timeRefresherId = null;
        }
        if (pollingTimeoutId) {
            GLib.source_remove(pollingTimeoutId);
            pollingTimeoutId = null;
        }
        // Disconnect signal handlers
        notificationConnections.forEach(id => {
            if (notifd.disconnect) {
                notifd.disconnect(id);
            }
        });
        notificationConnections = [];
        // Cleanup variables
        notifications.drop();
        allNotifications.drop();
        notificationCount.drop();
        timeRefresher.drop();
    };
    
    timeRefresherId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 60000, () => {
        timeRefresher.set(Date.now());
        return true;
    });
    
    // Setup notification handlers only once
    const notifiedId = notifd.connect("notified", (_source, id, replaced) => {
        const notification = notifd.get_notification(id);
        if (notification) {
            allNotifications.set([notification, ...allNotifications.get()]);
        }
        
        notifications.set([...notifd.notifications]);
        notificationCount.set(notifd.notifications.length);
    });
    
    const resolvedId = notifd.connect("resolved", (_source, id, reason) => {
        notifications.set([...notifd.notifications]);
        notificationCount.set(notifd.notifications.length);
    });
    
    notificationConnections.push(notifiedId, resolvedId);
    
    // Polling with cleanup
    let lastCount = notifications.get().length;
    pollingTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
        const currentCount = notifd.notifications.length;
        if (currentCount !== lastCount) {
            notifications.set([...notifd.notifications]);
            notificationCount.set(currentCount);
            lastCount = currentCount;
        }
        return true;
    });

    const NotificationItem = ({ notification }: { notification: any }) => {
        const showActions = Variable(false);

        return (
            <box className="notification-item" onDestroy={() => {
                // Cleanup showActions variable when component is destroyed
                showActions.drop();
            }}>
                {notification.image && fileExists(notification.image) && <box
                    valign={Gtk.Align.START}
                    className="image-list"
                    css={`background-image: url('${notification.image}')`}>
                </box>}
                {notification.image && isIcon(notification.image) && <box
                    expand={false}
                    valign={Gtk.Align.START}
                    className="icon-image-list">
                    <icon icon={notification.image} expand halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} />
                </box>}
                {!notification.image && <button
                    className="default-icon-notification-list"
                    valign={Gtk.Align.START}>
                    <icon icon="default-notification-symbolic" />
                </button>}
                <box vertical>
                    <box>
                        <label
                            className="notification-summary-list"
                            halign={Gtk.Align.START}
                            xalign={0}
                            label={notification.summary}
                            hexpand
                            wrap
                        />
                        <box halign={Gtk.Align.END}>
                            <label
                                className="notification-time-list"
                                halign={Gtk.Align.START}
                                label={bind(timeRefresher).as(() => formatTimeAgo(notification.time))}
                            />
                            <button
                                className="notification-expand-button-list"
                                cursor={"hand1"}
                                onClicked={() => showActions.set(!showActions.get())}
                                css={`background-color: transparent;`}
                            >
                                <icon icon={"expand-down"} className={bind(showActions).as(shown => shown ? "expanded" : "")} />
                            </button>
                        </box>
                    </box>
                    {notification.body && <label
                        className="notification-body-list"
                        wrap
                        useMarkup
                        halign={Gtk.Align.START}
                        xalign={0}
                        justifyFill
                        label={notification.body}
                    />}
                    <revealer
                        transitionDuration={200}
                        transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
                        revealChild={bind(showActions)}
                    >
                        <box className="notification-actions-list">
                            <box>
                                <button
                                    cursor={"hand1"}
                                    onClicked={() => {
                                        if (typeof notification.dismiss === 'function') {
                                            notification.dismiss();
                                        }
                                        
                                        const currentNotifs = allNotifications.get();
                                        const filteredNotifs = currentNotifs.filter(n => 
                                            n.id !== notification.id
                                        );
                                        
                                        allNotifications.set(filteredNotifs);
                                        notifications.set([...notifd.notifications].filter(n => n.id !== notification.id));
                                        notificationCount.set(filteredNotifs.length);
                                    }}>
                                    <label label="Close" halign={Gtk.Align.CENTER} hexpand />
                                </button>
                            </box>
                            {notification.get_actions().length > 0 && <box>
                                {notification.get_actions().map(({ label, id }: { label: string, id: string }) => (
                                    <button
                                        cursor={"hand1"}
                                        hexpand
                                        onClicked={() => {
                                            notification.invoke(id);
                                            // Remove setTimeout to prevent memory leak
                                            notifications.set([...notifd.notifications]);
                                        }}>
                                        <label label={label} halign={Gtk.Align.CENTER} hexpand />
                                    </button>
                                ))}
                            </box>}
                        </box>
                    </revealer>
                </box>
            </box>
        );
    }

    return (
        <box vertical spacing={10} className="notification-container" onDestroy={cleanup}>
            <scrollable
                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                className="notification-container-scrollable"
            >
                <box vertical className="notification-list">
                    {bind(allNotifications).as(notifs => {
                        if (notifs.length === 0) {
                            return <icon icon="no-notification" className="no-notifications" xalign={0.5} />
                        }
                        
                        const sortedNotifs = [...notifs].sort((a, b) => b.time - a.time);
                        
                        return sortedNotifs.map(notification => (
                            <NotificationItem notification={notification} />
                        ));
                    })}
                </box>
            </scrollable>
            <centerbox>
                <label label={bind(allNotifications).as(notifs => `${notifs.length} notifications`)} xalign={0} valign={Gtk.Align.END} />
                <box />
                <button
                    className="notification-clear-all-button"
                    halign={Gtk.Align.END}
                    valign={Gtk.Align.END}
                    cursor={"hand1"}
                    onClicked={() => {
                        notifd.notifications.forEach(notification => notification.dismiss());
                        notifications.set([]);
                        allNotifications.set([]);
                        notificationCount.set(0);
                    }}>
                    <icon icon="clear" />
                </button>
            </centerbox>
        </box>
    );
}

const BluetoothList = () => {
    const bluetooth = Bluetooth.get_default();
    const isScanning = Variable(false);
    const scanTimeoutId = Variable<number | null>(null);
    
    // Cleanup function
    const cleanup = () => {
        const timeoutId = scanTimeoutId.get();
        if (timeoutId) {
            GLib.source_remove(timeoutId);
        }
        isScanning.drop();
        scanTimeoutId.drop();
    };
    
    const startDiscovery = () => {
        if (!bluetooth?.adapter) {
            console.error("No bluetooth adapter available");
            return;
        }
        
        try {
            isScanning.set(true);
            bluetooth.adapter.start_discovery();
            
            // Auto-stop discovery after 30 seconds
            const timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 30000, () => {
                try {
                    if (bluetooth?.adapter) {
                        bluetooth.adapter.stop_discovery();
                    }
                } catch (e) {
                    // Ignore error if already stopped
                }
                isScanning.set(false);
                scanTimeoutId.set(null);
                return false;
            });
            scanTimeoutId.set(timeoutId);
            
        } catch (error) {
            console.error("Failed to start discovery:", error);
            isScanning.set(false);
        }
    };
    
    const stopDiscovery = () => {
        if (!bluetooth?.adapter) {
            console.error("No bluetooth adapter available");
            return;
        }
        
        try {
            bluetooth.adapter.stop_discovery();
            isScanning.set(false);
            
            const timeoutId = scanTimeoutId.get();
            if (timeoutId) {
                GLib.source_remove(timeoutId);
                scanTimeoutId.set(null);
            }
        } catch (error) {
            console.error("Failed to stop discovery:", error);
        }
    };
    
    const DeviceItem = ({ device }: { device: any }) => {
        const isConnecting = Variable(false);
        const isPairing = Variable(false);
        
        const deviceCleanup = () => {
            isConnecting.drop();
            isPairing.drop();
        };

        const handlePair = async () => {
            if (!device || device.paired || isPairing.get()) return;
            
            try {
                isPairing.set(true);
                await device.pair();
            } catch (error) {
                console.error("Failed to pair device:", error);
            } finally {
                isPairing.set(false);
            }
        };

        const handleConnect = async () => {
            if (!device || device.connected || isConnecting.get()) return;
            
            try {
                isConnecting.set(true);
                await device.connect_device();
            } catch (error) {
                console.error("Failed to connect device:", error);
            } finally {
                isConnecting.set(false);
            }
        };

        const handleDisconnect = async () => {
            if (!device || !device.connected || isConnecting.get()) return;
            
            try {
                isConnecting.set(true);
                await device.disconnect_device();
            } catch (error) {
                console.error("Failed to disconnect device:", error);
            } finally {
                isConnecting.set(false);
            }
        };

        const toggleTrust = () => {
            if (!device) return;
            
            try {
                device.trusted = !device.trusted;
            } catch (error) {
                console.error("Failed to toggle trust:", error);
            }
        };

        return (
            <box className="bluetooth-device" onDestroy={deviceCleanup}>
                <box spacing={10} hexpand halign={Gtk.Align.START}>
                    <icon icon={device?.icon || "bluetooth-symbolic"} className="bluetooth-device-icon" />
                    <box vertical spacing={5} hexpand>
                        <label 
                            label={sanitizeUtf8(device?.alias || device?.name || "Unknown device")} 
                            xalign={0} 
                            className="bluetooth-device-name"
                        />
                        <box spacing={10}>
                            {device?.connected && 
                                <label label="Connected" className="status-label connected" />
                            }
                            {device?.paired && 
                                <label label="Paired" className="status-label paired" />
                            }
                            {device?.trusted && 
                                <label label="Trusted" className="status-label trusted" />
                            }
                            {device?.battery_percentage >= 0 && 
                                <label label={`${device.battery_percentage}%`} className="status-label battery" />
                            }
                        </box>
                    </box>
                </box>

                <box spacing={5} halign={Gtk.Align.END}>
                    {/* Pair Button */}
                    <button 
                        className={`action-button pair ${device?.paired ? "active" : ""}`}
                        sensitive={device && !device.paired && !isPairing.get()}
                        onClicked={handlePair}
                        tooltipText={device?.paired ? "Already paired" : "Pair device"}
                        cursor={"hand1"}
                    >
                        {bind(isPairing).as(pairing => {
                            if (pairing) {
                                return <icon icon="sync-synchronizing-symbolic" />;
                            }
                            return <icon icon={device?.paired ? "emblem-ok-symbolic" : "channel-secure-symbolic"} />;
                        })}
                    </button>
                    
                    {/* Trust Button */}
                    <button 
                        className={`action-button trust ${device?.trusted ? "active" : ""}`}
                        sensitive={device?.paired}
                        onClicked={toggleTrust}
                        tooltipText={device?.trusted ? "Remove trust" : "Trust device"}
                        cursor={"hand1"}
                    >
                        <icon icon={device?.trusted ? "security-high-symbolic" : "security-medium-symbolic"} />
                    </button>
                    
                    {/* Connect Button */}
                    <button 
                        className={`action-button connect ${device?.connected ? "active" : ""}`}
                        sensitive={device?.paired && !isConnecting.get()}
                        onClicked={device?.connected ? handleDisconnect : handleConnect}
                        tooltipText={device?.connected ? "Disconnect" : "Connect"}
                        cursor={"hand1"}
                    >
                        {bind(isConnecting).as(connecting => {
                            if (connecting) {
                                return <icon icon="sync-synchronizing-symbolic" />;
                            }
                            return <icon icon={device?.connected ? "network-wireless-disconnected-symbolic" : "network-wireless-symbolic"} />;
                        })}
                    </button>
                </box>
            </box>
        );
    };

    return (
        <box vertical spacing={15} className="bluetooth-container" onDestroy={cleanup}>
            {/* Check if bluetooth is available */}
            {!bluetooth ? (
                <box vertical spacing={20} className="bluetooth-unavailable">
                    <icon icon="bluetooth-disabled-symbolic" className="disabled-icon" />
                    <label label="Bluetooth not available" xalign={0.5} className="disabled-text" />
                </box>
            ) : !bluetooth.adapter ? (
                <box vertical spacing={20} className="bluetooth-no-adapter">
                    <icon icon="bluetooth-disabled-symbolic" className="disabled-icon" />
                    <label label="No Bluetooth adapter found" xalign={0.5} className="disabled-text" />
                </box>
            ) : (
                bind(bluetooth, "is_powered").as(powered => {
                    if (!powered) {
                        return (
                            <box vertical spacing={20} className="bluetooth-disabled">
                                <icon icon="bluetooth-disabled-symbolic" css={"font-size: 150px; margin-top: 200px"} />
                                <label label="Bluetooth is disabled" xalign={0.5} css={"font-size: 20px; font-weight: 500"} />
                            </box>
                        );
                    }
                    
                    return (
                        <box vertical spacing={15}>
                            {/* Header with scan button */}
                            <centerbox className="bluetooth-header">
                                <label label="Bluetooth Devices" className="section-title" halign={Gtk.Align.START} />
                                <box />
                                <button 
                                    className={`scan-button ${bind(isScanning).as(scanning => scanning ? "active" : "")}`}
                                    halign={Gtk.Align.END} 
                                    cursor={"hand1"}
                                    onClicked={() => {
                                        if (isScanning.get()) {
                                            stopDiscovery();
                                        } else {
                                            startDiscovery();
                                        }
                                    }}
                                >
                                    <icon icon={bind(isScanning).as(scanning => 
                                        scanning ? "process-stop-symbolic" : "reload-icon-v2"
                                    )} />
                                </button>
                            </centerbox>

                            {/* Device list */}
                            <scrollable
                                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                                className="bluetooth-devices-scroll"
                            >
                                <box vertical spacing={30} className="devices-list">
                                    {bind(bluetooth, "devices").as(devices => {
                                        if (!devices || devices.length === 0) {
                                            return <label label="No devices found" xalign={0.5} className="no-devices" />;
                                        }
                                        
                                        // Sort devices: connected first, then paired, then by signal strength
                                        const sortedDevices = [...devices].sort((a, b) => {
                                            if (a?.connected && !b?.connected) return -1;
                                            if (!a?.connected && b?.connected) return 1;
                                            if (a?.paired && !b?.paired) return -1;
                                            if (!a?.paired && b?.paired) return 1;
                                            return (b?.rssi || -100) - (a?.rssi || -100);
                                        });
                                        
                                        return sortedDevices.map((device, index) => (
                                            <DeviceItem device={device} />
                                        ));
                                    })}
                                </box>
                            </scrollable>
                        </box>
                    );
                })
            )}
        </box>
    );
}

const InputOutputList = () => {
    const wp = Wp.get_default()!;
    const audio = wp.audio;
    
    const defaultSpeaker = audio.defaultSpeaker;
    const defaultMicrophone = audio.defaultMicrophone;

    const streams = Variable(audio.get_streams()).observe(audio, "stream-added", () => audio.get_streams()).observe(audio, "stream-removed", () => audio.get_streams())

    const cleanup = () => {
        streams.drop();
    };
    
    const ApplicationItem = () => {
        return (
            <box vertical spacing={10} className="application-volume-container">
                <label label="Applications" className="application-title" xalign={0}/>
                <box vertical spacing={10}>
                    {bind(streams).as(streams => {
                        if (!streams || streams.length === 0) {
                            return <label label="No active audio applications" xalign={0.5} className="no-applications" />;
                        }
                        
                        return streams?.map(stream => {
                            return (
                                <box vertical className={"application-volume-item"}>
                                    <centerbox>
                                        <label label={stream.description} halign={Gtk.Align.START}/>
                                        <box/>
                                        <box spacing={5} halign={Gtk.Align.END}>
                                            <button className="action-button" onClicked={() => stream.mute = !stream.mute} cursor={"hand1"}>
                                                <icon icon={bind(stream, "mute").as(muted => muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")} />
                                            </button>
                                            <label label={bind(stream, "volume").as(vol => `${Math.floor((vol ? vol : 0) * 100)}%`)} xalign={1}/>
                                        </box>
                                    </centerbox>
                                    <slider
                                        className="volume-slider-application" 
                                        hexpand 
                                        onDragged={(slider) => stream.volume = slider.value} 
                                        value={bind(stream, "volume")}
                                        cursor={"hand1"}
                                    />
                                </box>
                            );
                        });
                    })}
                </box>
            </box>
        );
    };

    const VolumeSlider = ({ endpoint, label }: { endpoint: any, label: string }) => {
        if (!endpoint) return null;
        
        const isInputDevice = label.includes("Input");
        
        return (
            <box className="volume-slider-control" vertical spacing={5}>
                <box spacing={10}>
                    <button
                        className={bind(endpoint, "mute").as(muted => `mute-button ${muted ? "muted" : ""}`)}
                        onClicked={() => endpoint.mute = !endpoint.mute}
                        cursor={"hand1"}
                    >
                        <icon icon={bind(endpoint, "mute").as(muted => {
                            if (isInputDevice) {
                                return muted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic";
                            } else {
                                return muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic";
                            }
                        })} />
                    </button>
                    <label 
                        label={bind(endpoint, "volume").as((vol) => `${Math.floor((vol ? vol : 0) * 100)}%`)} 
                        className="volume-percentage"
                    />
                </box>
                <slider 
                    className="volume-slider" 
                    hexpand 
                    onDragged={(slider) => endpoint.volume = slider.value} 
                    value={bind(endpoint, "volume")} 
                    cursor={"hand1"}
                />
            </box>
        );
    };
    
    return (
        <scrollable onDestroy={cleanup}
            vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
            hscrollbarPolicy={Gtk.PolicyType.NEVER}
            className="audio-container"
        >
            <box vertical spacing={20}>
                <ApplicationItem />

                <Gtk.Separator visible />

                {/* Output Devices Section */}
                <box vertical spacing={10}>
                    <box vertical spacing={15}>
                        <label label="Output Devices" className="section-title" xalign={0} />
                        <box spacing={5}>
                            {defaultSpeaker ? (
                                <box vertical>
                                    <button
                                        className="device-dropdown-button"
                                        cursor={"hand1"}
                                        onClicked={(self) => {
                                            const menu = new Gtk.Menu();
                                            
                                            audio.speakers.forEach(speaker => {
                                                const menuItem = new Gtk.MenuItem();
                                                menuItem.set_label(speaker.description);
                                                
                                                menuItem.connect("activate", () => {
                                                    speaker.isDefault = true;
                                                    menu.hide();
                                                });
                                                
                                                menu.append(menuItem);
                                            });
                                            
                                            menu.show_all();
                                            menu.popup_at_widget(self, Gdk.Gravity.SOUTH_WEST, Gdk.Gravity.NORTH_WEST, null);
                                        }}
                                    >
                                        <box spacing={10}>
                                            <box hexpand>
                                                <label
                                                    label={bind(defaultSpeaker, "description").as(desc => truncateText(sanitizeUtf8(desc || ""), 60))}
                                                    wrap
                                                    xalign={0}
                                                />
                                            </box>
                                            <icon icon="pan-down-symbolic" />
                                        </box>
                                    </button>
                                </box>
                            ) : (
                                <label label="No default output device" xalign={0.5} className="no-devices" />
                            )}
                        </box>
                    </box>

                    {/* Default Output Volume Control */}
                    {defaultSpeaker ? (
                        <VolumeSlider endpoint={defaultSpeaker} label="Output Volume" />
                    ) : (
                        <label label="No default output device" xalign={0.5} className="no-devices" />
                    )}
                </box>

                <Gtk.Separator visible />

                {/* Input Devices Section */}
                <box vertical spacing={10}>
                    <box vertical spacing={15}>
                        <label label="Input Devices" className="section-title" xalign={0} />
                        <box spacing={5}>
                            {defaultMicrophone ? (
                                <box vertical>
                                    <button
                                        className="device-dropdown-button"
                                        cursor={"hand1"}
                                        onClicked={(self) => {
                                            const menu = new Gtk.Menu();
                                            
                                            audio.microphones.forEach(mic => {
                                                const menuItem = new Gtk.MenuItem();
                                                menuItem.set_label(mic.description);
                                                
                                                menuItem.connect("activate", () => {
                                                    mic.isDefault = true;
                                                    menu.hide();
                                                });
                                                
                                                menu.append(menuItem);
                                            });
                                            
                                            menu.show_all();
                                            menu.popup_at_widget(self, Gdk.Gravity.SOUTH_WEST, Gdk.Gravity.NORTH_WEST, null);
                                        }}
                                    >
                                        <box spacing={10}>
                                            <box vertical hexpand>
                                                <label
                                                    label={bind(defaultMicrophone, "description").as(desc => truncateText(sanitizeUtf8(desc || ""), 60))}
                                                    wrap
                                                    xalign={0}
                                                    className="device-name"
                                                />
                                            </box>
                                            <icon icon="pan-down-symbolic" />
                                        </box>
                                    </button>
                                </box>
                            ) : (
                                <label label="No default input device" xalign={0.5} className="no-devices" />
                            )}
                        </box>
                    </box>

                    {/* Default Input Volume Control */}
                    {defaultMicrophone ? (
                        <VolumeSlider endpoint={defaultMicrophone} label="Input Volume" />
                    ) : (
                        <label label="No default input device" xalign={0.5} className="no-devices" />
                    )}
                </box>
            </box>
        </scrollable>
    );
}

const BatteryInfo = () => {
    const getBatteryDevice = () => {
        const upower = Battery.UPower.new();
        if (!upower) {
            console.error("Battery: Failed to initialize UPower");
            return null;
        }
    
        const devices = upower.get_devices();
        if (!devices) {
            console.error("Battery: Failed to get battery devices");
            return null;
        }
    
        for (const device of devices) {
            if (device.get_is_battery() && device.get_power_supply()) {
                return device;
            }
        }
    
        const display_device = upower.get_display_device();
        if (!display_device) {
            console.error("Battery: No battery device found");
            return null;
        }
        return display_device;
    };

    const BatteryInfo = () => {
        const bat = getBatteryDevice();
        if (!bat) {
            console.error("Battery: Cannot create BatteryInfo: no battery device");
            return <box />;
        }

        return (
            <box
                className="battery-info-container"
                vertical
                spacing={15}
                hexpand
            >
                <label label="Battery Information" xalign={0} className="battery-info-section-title" />

                <box vertical spacing={10} className="battery-percentage-container">
                    <slider
                        className={bind(bat, "percentage").as((percentage) => {
                            if (!percentage) return "battery-percentage-slider-red";
                            const percent = Math.floor(percentage * 100);
                            if (percent >= 100) return "battery-percentage-slider-green";
                            if (percent >= 80) return "battery-percentage-slider-blue";
                            if (percent >= 20) return "battery-percentage-slider-yellow";
                            return "battery-percentage-slider-red";
                        })}
                        hexpand
                        value={bind(bat, "percentage")}
                    />
                    <box spacing={10} hexpand>
                        <label
                            label={bind(Variable.derive([bind(bat, "state"), bind(bat, "timeToFull"), bind(bat, "timeToEmpty")], (state, timeToFull, timeToEmpty) => {
                                if (!state) return "Unknown";
                                
                                if (state === Battery.State.CHARGING) {
                                    if (timeToFull > 0) {
                                        const hours = Math.floor(timeToFull / 3600);
                                        const minutes = Math.floor((timeToFull % 3600) / 60);
                                        return `${hours}h ${minutes}m to full`;
                                    }
                                    return "Charging";
                                } else if (state === Battery.State.DISCHARGING) {
                                    if (timeToEmpty > 0) {
                                        const hours = Math.floor(timeToEmpty / 3600);
                                        const minutes = Math.floor((timeToEmpty % 3600) / 60);
                                        return `${hours}h ${minutes}m remaining`;
                                    }
                                    return "Discharging";
                                }
                                
                                const stateMap = {
                                    [Battery.State.EMPTY]: "Empty",
                                    [Battery.State.FULLY_CHARGED]: "Full",
                                    [Battery.State.PENDING_CHARGE]: "Pending",
                                    [Battery.State.PENDING_DISCHARGE]: "Pending Discharge"
                                };
                                return stateMap[state] || String(state);
                            }))}
                            xalign={0}
                            hexpand
                        />
                        <label
                            label={bind(bat, "percentage").as((percentage) => {
                                if (!percentage) return "N/A";
                                return `${Math.floor(percentage * 100)}%`;
                            })}
                            xalign={1}
                            hexpand
                        />
                    </box>
                </box>

                <box hexpand>
                    <label label="Energy Rate:" />
                    <label
                        label={bind(bat, "energyRate").as((rate) => {
                            if (!rate) return "N/A";
                            return `${rate.toFixed(1)} W`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Design Energy:" />
                    <label
                        label={bind(bat, "energyFullDesign").as((energyFullDesign) => {
                            if (!energyFullDesign) return "N/A";
                            return `${energyFullDesign.toFixed(1)} Wh`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Health:" />
                    <label
                        label={bind(bat, "capacity").as((capacity) => {
                            if (!capacity) {
                                return "N/A";
                            }
                            return `${(capacity * 100).toFixed(1)}%`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                {/* <box hexpand>
                    <label label="Change cycles:" />
                    <label
                        label={bind(bat, "chargeCycles").as((chargeCycles) => {
                            if (!chargeCycles) {
                                return "N/A";
                            }
                            return `${chargeCycles}`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box> */}

                <box hexpand>
                    <label label="Model:" />
                    <label
                        label={bind(bat, "model").as((model) => {
                            if (!model) return "N/A";
                            return `${model}`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Temperature:" />
                    <label
                        label={bind(bat, "temperature").as((temp) => {
                            if (!temp) return "N/A";
                            return `${temp.toFixed(1)}°C`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>

                <box hexpand>
                    <label label="Voltage:" />
                    <label
                        label={bind(bat, "voltage").as((voltage) => {
                            if (!voltage) {
                                return "N/A";
                            }
                            return `${voltage.toFixed(1)} V`;
                        })}
                        xalign={1}
                        hexpand
                    />
                </box>
            </box>
        );
    };


    const PowerProfile = () => {
        const power = PowerProfiles.get_default();
        if (!power) {
            console.error("Battery: Failed to initialize PowerProfiles");
            return <box />;
        }
    
        return (
            <box
                className="power-profile-container"
                vertical
                spacing={15}
                hexpand
            >
                <label label="Power Mode" xalign={0}/>
                <box
                    className="power-mode-buttons"
                    spacing={15}
                    hexpand
                >
                    <button
                        className={bind(power, "activeProfile").as(profile => 
                            `power-mode-button ${profile === "power-saver" ? "active" : ""}`
                        )}
                        label="Power Saver"
                        hexpand
                        onClicked={() => power.activeProfile = "power-saver"}
                        cursor={"hand1"}
                    />
                    <button
                        className={bind(power, "activeProfile").as(profile => 
                            `power-mode-button ${profile === "balanced" ? "active" : ""}`
                        )}
                        label="Balanced"
                        hexpand
                        onClicked={() => power.activeProfile = "balanced"}
                        cursor={"hand1"}
                    />
                    <button
                        className={bind(power, "activeProfile").as(profile => 
                            `power-mode-button ${profile === "performance" ? "active" : ""}`
                        )}
                        label="Performance"
                        hexpand
                        onClicked={() => power.activeProfile = "performance"}
                        cursor={"hand1"}
                    />
                </box>
            </box>
        );
    };

    const BatteryCharging = () => {
        const chargeMode = Variable("");
        execAsync("cat /sys/class/power_supply/BAT0/charge_control_end_threshold").then((v) => {
            if (v === "80") {
                chargeMode.set("preserve");
            } else {
                chargeMode.set("maximize");
            }
        });

        const setBatteryChargeMode = async (mode: string) => {
            try {
                if (mode === "preserve") {
                    await exec(`pkexec bash -c "echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold && echo 75 > /sys/class/power_supply/BAT0/charge_control_start_threshold"`);
                    chargeMode.set("preserve");
                } else {
                    await exec(`pkexec bash -c "echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold && echo 50 > /sys/class/power_supply/BAT0/charge_control_start_threshold"`);
                    chargeMode.set("maximize");
                }
            } catch (error) {
                console.error("Failed to set battery charge mode:", error);
            }
        };

        return (
            <box
                className="battery-charging-container"
                vertical
                spacing={15}
                hexpand
                onDestroy={() => {
                    chargeMode.drop();
                }}
            >
                <label label="Battery Charging" xalign={0} className="battery-charging-section-title" />
                
                <box vertical spacing={15}>
                    <button
                        className={bind(chargeMode).as(mode => 
                            `charge-mode-option ${mode === "maximize" ? "active" : ""}`
                        )}
                        onClicked={() => setBatteryChargeMode("maximize")}
                        cursor={"hand1"}
                    >
                        <box spacing={15} hexpand>
                            <box vertical spacing={5} hexpand>
                                <label 
                                    className={bind(chargeMode).as(mode => 
                                        `battery-charging-section-first ${mode === "maximize" ? "active" : ""}`
                                    )}
                                    label="Maximize Charge"
                                    xalign={0} 
                                />
                                <label
                                    className={bind(chargeMode).as(mode => 
                                        `battery-charging-section-second ${mode === "maximize" ? "active" : ""}`
                                    )}
                                    label="Uses full battery capacity. Degrades batteries more quickly." 
                                    xalign={0}
                                    wrap
                                />
                            </box>
                        </box>
                    </button>

                    <button
                        className={bind(chargeMode).as(mode => 
                            `charge-mode-option ${mode === "preserve" ? "active" : ""}`
                        )}
                        onClicked={() => setBatteryChargeMode("preserve")}
                        cursor={"hand1"}
                    >
                        <box spacing={15} hexpand>
                            <box vertical spacing={5} hexpand>
                                <label
                                    className={bind(chargeMode).as(mode => 
                                        `battery-charging-section-first ${mode === "preserve" ? "active" : ""}`
                                    )}
                                    label="Preserve Battery Health" 
                                    xalign={0} 
                                />
                                <label
                                    className={bind(chargeMode).as(mode => 
                                        `battery-charging-section-second ${mode === "preserve" ? "active" : ""}`
                                    )}
                                    label="Increases battery longevity by maintaining lower charge levels (80% max)." 
                                    xalign={0} 
                                    wrap
                                />
                            </box>
                        </box>
                    </button>
                </box>
            </box>
        );
    }

    return <box vertical spacing={25} className="battery-container">
        <BatteryInfo />
        <PowerProfile />
        <BatteryCharging />
    </box>
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
        {
            label: "Battery",
            icon: "battery-symbolic",
        },
    ];

    const content = Variable(<NotificationList />);
    const buttonSelected = Variable(0);

    const cleanup = () => {
        content.drop();
        buttonSelected.drop();
    };

    return (
        <box vertical className="content-container" spacing={30} onDestroy={cleanup}>
            <box spacing={10} className="button-container" halign={Gtk.Align.CENTER}>
                {buttons.map((button, index) => (
                    <button
                        cursor={"hand1"}
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
                            } else if (button.label === "Battery") {
                                content.set(<BatteryInfo />);
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