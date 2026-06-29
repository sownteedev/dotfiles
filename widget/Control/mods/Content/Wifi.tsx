import { bind, execAsync, GLib, Variable } from "astal";
import { Gtk } from "astal/gtk3";
import Network from "gi://AstalNetwork";

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
    return (
        info
            .toString()
            .trim()
            .slice(0, info.length - 2) + "?"
    );
};
export const IPAddress = Variable("");
export { getIPAddress };
getIPAddress().then((ip) => IPAddress.set(ip));

// Auto refresh IP address when wifi state changes
let wifiStateTimeout: number | null = null;
let wifiSignalId: number | null = null;

const refreshIPOnWifiChange = () => {
    if (wifiStateTimeout) {
        GLib.source_remove(wifiStateTimeout);
        wifiStateTimeout = null;
    }
    wifiStateTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
        if (wifi.enabled && wifi.active_access_point) {
            getIPAddress().then((ip) => IPAddress.set(ip));
        } else {
            IPAddress.set("N/A");
        }
        wifiStateTimeout = null;
        return false;
    });
};

// Listen to wifi state changes (store signal ID for potential cleanup)
wifiSignalId = wifi.connect("notify::state", refreshIPOnWifiChange);

// Cleanup function for global resources
export const cleanupGlobalResources = () => {
    if (wifiStateTimeout) {
        GLib.source_remove(wifiStateTimeout);
        wifiStateTimeout = null;
    }
    if (wifiSignalId && wifi) {
        wifi.disconnect(wifiSignalId);
        wifiSignalId = null;
    }
    IPAddress.drop();
};

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
        forgetTimeoutIds.forEach((id) => {
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
                    <label
                        label={bind(wifi, "ssid").as(
                            (ssid) => ssid || "Not Connected",
                        )}
                    />
                </box>
                <label label="" />
                <button
                    halign={Gtk.Align.END}
                    cursor={"hand1"}
                    onClicked={() => {
                        if (!isScanning.get()) {
                            startScan();
                        } else {
                            isScanning.set(false);
                        }
                    }}
                >
                    <icon icon="reload-icon" />
                </button>
            </centerbox>
            <box className="wifi-details" vertical spacing={10}>
                <box>
                    <label label="Frequency:" />
                    <label
                        label={bind(wifi, "frequency").as((freq) =>
                            freq ? `${(freq / 1000).toFixed(1)} GHz` : "N/A",
                        )}
                        xalign={1}
                        hexpand
                    />
                </box>
                <box>
                    <label label="Bandwidth:" />
                    <label
                        label={bind(wifi, "bandwidth").as((bw) =>
                            bw ? `${bw} Mbps` : "N/A",
                        )}
                        xalign={1}
                        hexpand
                    />
                </box>
                <box>
                    <label label="IP Address:" />
                    <label
                        label={bind(IPAddress).as((ip) => ip || "N/A")}
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

            scanTimeoutId = GLib.timeout_add(
                GLib.PRIORITY_DEFAULT,
                2000,
                () => {
                    cachedNetworks = wifi.access_points;
                    isScanning.set(false);
                    networksReady.set(true);
                    scanTimeoutId = null;
                    return false;
                },
            );
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
            const result = await execAsync(
                "nmcli -g NAME,TYPE connection show",
            );
            const connections = result.toString().trim().split("\n");
            const wifiConnections = new Set<string>();

            connections.forEach((line) => {
                const [name, type] = line.split(":");
                if (type === "802-11-wireless") {
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
            const timeoutId = GLib.timeout_add(
                GLib.PRIORITY_DEFAULT,
                2000,
                () => {
                    connectionError.set("");
                    return false;
                },
            );
            forgetTimeoutIds.push(timeoutId);
            updateStoredConnections();
            startScan();
        } catch (error) {
            connectionError.set(`Failed to forget: ${String(error)}`);
            const timeoutId = GLib.timeout_add(
                GLib.PRIORITY_DEFAULT,
                3000,
                () => {
                    connectionError.set("");
                    return false;
                },
            );
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
                    await execAsync(
                        `nmcli connection delete "${accessPoint.ssid}"`,
                    );
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
                    getIPAddress().then((ip) => IPAddress.set(ip));
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
                        <icon
                            icon={
                                selectedNetwork.get()?.icon_name ||
                                "network-wireless-symbolic"
                            }
                        />
                        <label
                            label={`Connect to ${selectedNetwork.get()?.ssid}`}
                        />
                    </box>
                    <box />
                    <button
                        halign={Gtk.Align.END}
                        cursor={"hand1"}
                        onClicked={() => {
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
                        visibility={false}
                        onActivate={() => {
                            connectToWifi(
                                selectedNetwork.get(),
                                passwordText.get(),
                            );
                        }}
                        onChanged={(self: Gtk.Entry) => {
                            passwordText.set(self.text);
                        }}
                        className={bind(connectionError).as((error) => {
                            if (error.includes("Connecting")) {
                                return "status-connecting";
                            }
                            if (error.includes("Wrong password") || error.includes("failed") || error.includes("Failed")) {
                                return "status-error";
                            }
                            return "";
                        })}
                    />
                    {bind(connectionError).as((error) => {
                        if (!error) return <box />;
                        const isConnecting = error.includes("Connecting");
                        const isSuccess = error.includes("Forgotten") || error.includes("success") || error.includes("Success");
                        const className = `connection-error-label${isConnecting ? " connecting" : isSuccess ? " success" : " error"}`;
                        return (
                            <label
                                className={className}
                                label={error}
                                wrap
                                xalign={0}
                            />
                        );
                    })}
                    <box halign={Gtk.Align.END}>
                        <button
                            className="connect-button"
                            cursor={"hand1"}
                            onClicked={() => {
                                connectToWifi(
                                    selectedNetwork.get(),
                                    passwordText.get(),
                                );
                            }}
                        >
                            {bind(connectionError).as((error) => {
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
                />,
            ];
        }

        return uniqueList.map((item) => {
            const isActiveNetwork =
                wifi.active_access_point &&
                wifi.active_access_point.ssid === item.ssid;

            return (
                <box
                    className={`network-item${
                        isActiveNetwork ? " active" : ""
                    }`}
                >
                    <button
                        className="network-item-btn"
                        cursor={"hand1"}
                        hexpand={true}
                        onClicked={async () => {
                            if (isActiveNetwork) {
                                return;
                            }

                            const needsPassword =
                                item.wpa_flags > 0 || item.rsn_flags > 0;

                            if (needsPassword) {
                                // Kiểm tra xem có stored connection không
                                if (storedConnections.get().has(item.ssid)) {
                                    // Có stored connection - thử kết nối
                                    try {
                                        connectionError.set("Connecting...");
                                        const result = await execAsync(
                                            `nmcli connection up "${item.ssid}"`,
                                        );
                                        const resultStr = result.toString();

                                        if (
                                            !resultStr.includes("error") &&
                                            !resultStr.includes("failed")
                                        ) {
                                            // Kết nối thành công với stored connection
                                            connectionError.set("");
                                            GLib.timeout_add(
                                                GLib.PRIORITY_DEFAULT,
                                                1000,
                                                () => {
                                                    startScan();
                                                    return false;
                                                },
                                            );

                                            // Refresh IP address after successful connection
                                            GLib.timeout_add(
                                                GLib.PRIORITY_DEFAULT,
                                                2000,
                                                () => {
                                                    getIPAddress().then((ip) =>
                                                        IPAddress.set(ip),
                                                    );
                                                    return false;
                                                },
                                            );
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
                        <box spacing={10} valign={Gtk.Align.CENTER}>
                            <icon icon={item.icon_name} />
                            <label label={item.ssid} xalign={0} hexpand />
                        </box>
                    </button>
                    <box spacing={10} halign={Gtk.Align.END} valign={Gtk.Align.CENTER}>
                        {storedConnections.get().has(item.ssid) && (
                            <button
                                className="forget-wifi-button action-button remove"
                                cursor={"hand1"}
                                onClicked={() => forgetWifi(item.ssid)}
                            >
                                <icon
                                    icon="edit-delete-symbolic"
                                    className="forget-wifi-icon"
                                />
                            </button>
                        )}
                        {(item.wpa_flags > 0 || item.rsn_flags > 0) && (
                            <icon
                                icon="security-high-symbolic"
                                className="security-icon"
                            />
                        )}
                    </box>
                </box>
            );
        });
    };

    return (
        <box
            vertical
            spacing={20}
            className="wifi-container"
            onDestroy={cleanup}
        >
            {bind(wifi, "enabled").as((enabled) => {
                if (!enabled) {
                    return (
                        <box vertical spacing={20}>
                            {bind(
                                Variable.derive(
                                    [bind(network, "wifi")],
                                    (wifi) => wifi,
                                ),
                            ).as((w) => (
                                <icon
                                    icon={bind(w, "iconName")}
                                    css={"font-size: 150px; margin-top: 200px"}
                                />
                            ))}
                            <label
                                label="Wifi is disabled"
                                xalign={0.5}
                                css={"font-size: 20px; font-weight: 500"}
                            />
                        </box>
                    );
                }

                return (
                    <box vertical spacing={20}>
                        {bind(showPasswordEntry).as((show) => {
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
                                            vscrollbarPolicy={
                                                Gtk.PolicyType.AUTOMATIC
                                            }
                                            hscrollbarPolicy={
                                                Gtk.PolicyType.NEVER
                                            }
                                            className="wifi-list"
                                        >
                                            <box vertical spacing={5}>
                                                {bind(networksReady).as(
                                                    (ready) => {
                                                        if (
                                                            ready &&
                                                            !isScanning.get()
                                                        ) {
                                                            isScanning.set(
                                                                true,
                                                            );
                                                        }
                                                        return renderNetworks();
                                                    },
                                                )}
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

export default WifiList;
