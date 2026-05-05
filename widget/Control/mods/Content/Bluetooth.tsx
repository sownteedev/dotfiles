import { bind, execAsync, GLib, Variable } from "astal";
import { Astal, Gtk, Gdk } from "astal/gtk3";
import Bluetooth from "gi://AstalBluetooth";
import { sanitizeUtf8 } from "../../../../utils/common";

const BluetoothList = () => {
    const bluetooth = Bluetooth.get_default();
    const isScanning = Variable(false);
    const scanTimeoutId = Variable<number | null>(null);

    // Track device connection states reactively to trigger re-renders
    const devicesStateTracker = Variable(0);

    // Cleanup function
    const cleanup = () => {
        const timeoutId = scanTimeoutId.get();
        if (timeoutId) {
            GLib.source_remove(timeoutId);
        }
        isScanning.drop();
        scanTimeoutId.drop();
        devicesStateTracker.drop();
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
            const timeoutId = GLib.timeout_add(
                GLib.PRIORITY_DEFAULT,
                30000,
                () => {
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
                },
            );
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
        const isRemoving = Variable(false);

        const deviceCleanup = () => {
            isConnecting.drop();
            isPairing.drop();
            isRemoving.drop();
        };

        const handlePair = async () => {
            if (!device || device.paired || isPairing.get()) return;

            const macAddress = device?.address;
            if (!macAddress) {
                console.error("Device has no MAC address");
                return;
            }

            try {
                isPairing.set(true);

                // Stop discovery if active to avoid conflicts
                if (bluetooth?.adapter && isScanning.get()) {
                    try {
                        bluetooth.adapter.stop_discovery();
                    } catch (e) {
                        // Ignore if already stopped
                    }
                }

                // Use bluetoothctl for more reliable pairing (won't freeze AGS)
                // Normalize MAC address to bluetoothctl format (AA:BB:CC:DD:EE:FF)
                let formattedMAC = macAddress.replace(/-/g, ":").toUpperCase();
                // Ensure it's in the right format
                if (!formattedMAC.match(/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/)) {
                    const clean = formattedMAC.replace(/:/g, "");
                    if (clean.length === 12) {
                        formattedMAC =
                            clean.match(/.{1,2}/g)?.join(":") || formattedMAC;
                    }
                }

                // bluetoothctl will handle passkey confirmation if needed
                await execAsync(`bluetoothctl pair ${formattedMAC}`);

                // Give it a moment for the pairing to register
                await new Promise((resolve) => setTimeout(resolve, 1000));

                // Auto-trust after successful pairing (like Blueman does)
                if (!device.trusted) {
                    try {
                        device.trusted = true;
                    } catch (e) {
                        // Ignore trust errors
                    }
                }
            } catch (error) {
                console.error("Failed to pair device:", error);
                // Try fallback API method if bluetoothctl fails
                try {
                    await device.pair();
                } catch (fallbackError) {
                    console.error("Fallback pair also failed:", fallbackError);
                }
            } finally {
                isPairing.set(false);
            }
        };

        const handleConnect = async () => {
            if (!device || device.connected || isConnecting.get()) return;

            const macAddress = device?.address;
            if (!macAddress) {
                console.error("Device has no MAC address");
                return;
            }

            try {
                isConnecting.set(true);

                // Stop discovery if active to avoid conflicts (like Blueman does)
                if (bluetooth?.adapter && isScanning.get()) {
                    try {
                        bluetooth.adapter.stop_discovery();
                    } catch (e) {
                        // Ignore if already stopped
                    }
                }

                // Auto-trust device before connecting (like Blueman does)
                if (!device.trusted) {
                    try {
                        device.trusted = true;
                    } catch (e) {
                        // Ignore trust errors, continue with connect
                    }
                }

                // Use bluetoothctl for more reliable connection (like Blueman)
                // Normalize MAC address to bluetoothctl format (AA:BB:CC:DD:EE:FF)
                let formattedMAC = macAddress.replace(/-/g, ":").toUpperCase();
                // Ensure it's in the right format (if not, try to fix it)
                if (!formattedMAC.match(/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/)) {
                    // If missing colons, add them
                    const clean = formattedMAC.replace(/:/g, "");
                    if (clean.length === 12) {
                        formattedMAC =
                            clean.match(/.{1,2}/g)?.join(":") || formattedMAC;
                    }
                }

                await execAsync(`bluetoothctl connect ${formattedMAC}`);

                // Give it a moment for the connection to register
                await new Promise((resolve) => setTimeout(resolve, 500));

                // Trigger reactive update of device list
                devicesStateTracker.set(devicesStateTracker.get() + 1);
            } catch (error) {
                console.error("Failed to connect device:", error);
                // Try fallback API method if bluetoothctl fails
                try {
                    await device.connect_device();
                } catch (fallbackError) {
                    console.error(
                        "Fallback connect also failed:",
                        fallbackError,
                    );
                }
            } finally {
                isConnecting.set(false);
            }
        };

        const handleDisconnect = async () => {
            if (!device || !device.connected || isConnecting.get()) return;

            const macAddress = device?.address;
            if (!macAddress) {
                console.error("Device has no MAC address");
                return;
            }

            try {
                isConnecting.set(true);

                // Use bluetoothctl for more reliable disconnection
                // Normalize MAC address to bluetoothctl format (AA:BB:CC:DD:EE:FF)
                let formattedMAC = macAddress.replace(/-/g, ":").toUpperCase();
                // Ensure it's in the right format (if not, try to fix it)
                if (!formattedMAC.match(/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/)) {
                    // If missing colons, add them
                    const clean = formattedMAC.replace(/:/g, "");
                    if (clean.length === 12) {
                        formattedMAC =
                            clean.match(/.{1,2}/g)?.join(":") || formattedMAC;
                    }
                }

                await execAsync(`bluetoothctl disconnect ${formattedMAC}`);

                // Give it a moment for the disconnection to register
                await new Promise((resolve) => setTimeout(resolve, 300));

                // Trigger reactive update of device list
                devicesStateTracker.set(devicesStateTracker.get() + 1);
            } catch (error) {
                console.error("Failed to disconnect device:", error);
                // Try fallback API method if bluetoothctl fails
                try {
                    await device.disconnect_device();
                } catch (fallbackError) {
                    console.error(
                        "Fallback disconnect also failed:",
                        fallbackError,
                    );
                }
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

        const handleRemove = async () => {
            if (!device || isRemoving.get()) return;

            const macAddress = device?.address;
            if (!macAddress) {
                console.error("Device has no MAC address");
                return;
            }

            try {
                isRemoving.set(true);

                // Normalize MAC address to bluetoothctl format (AA:BB:CC:DD:EE:FF)
                let formattedMAC = macAddress.replace(/-/g, ":").toUpperCase();
                if (!formattedMAC.match(/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/)) {
                    const clean = formattedMAC.replace(/:/g, "");
                    if (clean.length === 12) {
                        formattedMAC =
                            clean.match(/.{1,2}/g)?.join(":") || formattedMAC;
                    }
                }

                // Use bluetoothctl to remove device (like Blueman's \"Remove...\")
                await execAsync(`bluetoothctl remove ${formattedMAC}`);

                // Give it a moment for BlueZ to update device list
                await new Promise((resolve) => setTimeout(resolve, 500));
            } catch (error) {
                console.error("Failed to remove device:", error);
                // Fallback: try BlueZ API if available
                try {
                    if (typeof (device as any).remove === "function") {
                        await (device as any).remove();
                    }
                } catch (fallbackError) {
                    console.error(
                        "Fallback remove also failed:",
                        fallbackError,
                    );
                }
            } finally {
                isRemoving.set(false);
            }
        };

        // Format MAC address with colons
        const formatMAC = (address: string | null | undefined): string => {
            if (!address) return "";
            // Remove existing colons/dashes and reformat
            const clean = address.replace(/[:-]/g, "");
            if (clean.length !== 12) return address; // Invalid format, return as-is
            return clean.match(/.{1,2}/g)?.join("-") || address;
        };

        // Get device display name
        const getDeviceName = () => {
            const name = sanitizeUtf8(device?.alias || device?.name || "");
            // If no name or just MAC address-like, show MAC
            if (!name || name.match(/^[0-9A-Fa-f]{2}[:-]/)) {
                return formatMAC(device?.address) || "Unknown device";
            }
            return name;
        };

        // Get device secondary info (MAC if name exists, or device type)
        const getDeviceInfo = () => {
            const name = sanitizeUtf8(device?.alias || device?.name || "");
            const hasRealName = name && !name.match(/^[0-9A-Fa-f]{2}[:-]/);

            if (hasRealName && device?.address) {
                return formatMAC(device.address);
            }
            return null;
        };

        // Try to infer device type from available fields
        const getDeviceTypeLabel = () => {
            const rawType = (device?.device_type ||
                device?.type ||
                device?.deviceType) as string | number | undefined;

            if (rawType === null || rawType === undefined) return null;

            if (typeof rawType === "string") {
                const lower = rawType.toLowerCase();

                if (lower.includes("phone")) return "Phone";
                if (lower.includes("headset") || lower.includes("audio"))
                    return "Audio device";
                if (lower.includes("keyboard") || lower.includes("mouse"))
                    return "Input device";

                return rawType;
            }

            // Numeric enum – still useful to display
            return String(rawType);
        };

        // Map service UUIDs to human‑readable categories
        const getServicesLabel = () => {
            const uuids = (device?.uuids || (device as any)?.UUIDs) as
                | string[]
                | undefined;

            if (!uuids || !Array.isArray(uuids) || uuids.length === 0)
                return null;

            const services = new Set<string>();

            for (const raw of uuids) {
                const u = (raw || "").toString().toLowerCase();
                if (!u) continue;

                if (u.includes("a2dp") || u.includes("audio")) {
                    services.add("Audio");
                }
                if (u.includes("hsp") || u.includes("hfp")) {
                    services.add("Headset");
                }
                if (u.includes("hid")) {
                    services.add("Input");
                }
            }

            if (services.size === 0) return null;

            return `Services: ${Array.from(services).join(", ")}`;
        };

        const deviceName = getDeviceName();
        const deviceInfo = getDeviceInfo();
        const deviceType = getDeviceTypeLabel();
        const servicesLabel = getServicesLabel();

        const detailsParts = [
            deviceType ? `Type: ${deviceType}` : null,
            servicesLabel,
        ].filter(Boolean) as string[];

        const detailsText =
            detailsParts.length > 0 ? detailsParts.join(" • ") : null;

        return (
            <box className="bluetooth-device" onDestroy={deviceCleanup}>
                <box spacing={10} hexpand halign={Gtk.Align.START}>
                    <icon
                        icon={device?.icon || "bluetooth-symbolic"}
                        className="bluetooth-device-icon"
                    />
                    <box vertical hexpand>
                        <label
                            label={deviceName}
                            xalign={0}
                            className="bluetooth-device-name"
                        />
                        {deviceInfo && (
                            <label
                                label={deviceInfo}
                                xalign={0}
                                className="bluetooth-device-mac"
                            />
                        )}
                        {detailsText && (
                            <label
                                label={detailsText}
                                xalign={0}
                                className="bluetooth-device-details"
                            />
                        )}
                    </box>
                </box>

                <box spacing={5} halign={Gtk.Align.END}>
                    {/* Pair Button */}
                    <eventbox cursor={"hand1"}>
                        <button
                            className={`action-button pair ${
                                device?.paired ? "active" : ""
                            }`}
                            sensitive={
                                device && !device.paired && !isPairing.get()
                            }
                            onClicked={handlePair}
                            tooltipText={
                                device?.paired
                                    ? "Already paired"
                                    : "Pair device"
                            }
                        >
                            {bind(isPairing).as((pairing) => {
                                if (pairing) {
                                    return (
                                        <icon icon="sync-synchronizing-symbolic" />
                                    );
                                }
                                return (
                                    <icon
                                        icon={
                                            device?.paired
                                                ? "emblem-ok-symbolic"
                                                : "channel-secure-symbolic"
                                        }
                                    />
                                );
                            })}
                        </button>
                    </eventbox>

                    {/* Trust Button */}
                    <button
                        className={`action-button trust ${
                            device?.trusted ? "active" : ""
                        }`}
                        sensitive={device?.paired}
                        onClicked={toggleTrust}
                        tooltipText={
                            device?.trusted ? "Remove trust" : "Trust device"
                        }
                        cursor={"hand1"}
                    >
                        <icon
                            icon={
                                device?.trusted
                                    ? "security-high-symbolic"
                                    : "security-medium-symbolic"
                            }
                        />
                    </button>

                    {/* Connect Button */}
                    {bind(device, "connected").as((connected) => (
                        <button
                            className={`action-button connect ${
                                connected ? "active" : ""
                            }`}
                            sensitive={device?.paired && !isConnecting.get()}
                            onClicked={() => {
                                if (connected) {
                                    handleDisconnect();
                                } else {
                                    handleConnect();
                                }
                            }}
                            tooltipText={connected ? "Disconnect" : "Connect"}
                            cursor={"hand1"}
                        >
                            {bind(isConnecting).as((connecting) => {
                                if (connecting) {
                                    return (
                                        <icon icon="sync-synchronizing-symbolic" />
                                    );
                                }
                                return (
                                    <icon
                                        icon={
                                            connected
                                                ? "network-wireless-symbolic"
                                                : "network-wireless-disconnected-symbolic"
                                        }
                                    />
                                );
                            })}
                        </button>
                    ))}

                    {/* Remove Button */}
                    <button
                        className="action-button remove"
                        sensitive={!isRemoving.get()}
                        onClicked={handleRemove}
                        tooltipText="Remove device"
                        cursor={"hand1"}
                    >
                        {bind(isRemoving).as((removing) => {
                            if (removing) {
                                return (
                                    <icon icon="sync-synchronizing-symbolic" />
                                );
                            }
                            return <icon icon="user-trash-symbolic" />;
                        })}
                    </button>
                </box>
            </box>
        );
    };

    return (
        <box
            vertical
            spacing={15}
            className="bluetooth-container"
            onDestroy={cleanup}
        >
            {/* Check if bluetooth is available */}
            {!bluetooth ? (
                <box vertical spacing={20} className="bluetooth-unavailable">
                    <icon
                        icon="bluetooth-disabled-symbolic"
                        className="disabled-icon"
                    />
                    <label
                        label="Bluetooth not available"
                        xalign={0.5}
                        className="disabled-text"
                    />
                </box>
            ) : !bluetooth.adapter ? (
                <box vertical spacing={20} className="bluetooth-no-adapter">
                    <icon
                        icon="bluetooth-disabled-symbolic"
                        className="disabled-icon"
                    />
                    <label
                        label="No Bluetooth adapter found"
                        xalign={0.5}
                        className="disabled-text"
                    />
                </box>
            ) : (
                bind(bluetooth, "is_powered").as((powered) => {
                    if (!powered) {
                        return (
                            <box
                                vertical
                                spacing={20}
                                className="bluetooth-disabled"
                            >
                                <icon
                                    icon="bluetooth-disabled-symbolic"
                                    css={"font-size: 150px; margin-top: 200px"}
                                />
                                <label
                                    label="Bluetooth is disabled"
                                    xalign={0.5}
                                    css={"font-size: 20px; font-weight: 500"}
                                />
                            </box>
                        );
                    }

                    return (
                        <box vertical spacing={15}>
                            {/* Header with scan button */}
                            <centerbox className="bluetooth-header">
                                <label
                                    label="Bluetooth Devices"
                                    className="section-title"
                                    halign={Gtk.Align.START}
                                />
                                <box />
                                <button
                                    className={`scan-button ${bind(
                                        isScanning,
                                    ).as((scanning) =>
                                        scanning ? "active" : "",
                                    )}`}
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
                                    <icon
                                        icon={bind(isScanning).as((scanning) =>
                                            scanning
                                                ? "process-stop-symbolic"
                                                : "reload-icon",
                                        )}
                                    />
                                </button>
                            </centerbox>

                            {/* Device list */}
                            <scrollable
                                vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                                className="bluetooth-devices-scroll"
                            >
                                <box
                                    vertical
                                    spacing={15}
                                    className="devices-list"
                                >
                                    {bind(bluetooth, "devices").as(
                                        (devices) => {
                                            // Track state tracker to trigger reactive updates
                                            void devicesStateTracker.get();
                                            if (
                                                !devices ||
                                                devices.length === 0
                                            ) {
                                                return (
                                                    <label
                                                        label="No devices found"
                                                        xalign={0.5}
                                                        className="no-devices"
                                                    />
                                                );
                                            }

                                            // Filter out devices that don't have a human‑readable name
                                            const namedDevices = devices.filter(
                                                (d: any) => {
                                                    const rawName = (d?.alias ||
                                                        d?.name ||
                                                        "") as string;
                                                    const name = rawName
                                                        .toString()
                                                        .trim();
                                                    if (!name) return false;
                                                    // If name looks like a MAC address, also hide
                                                    return !/^[0-9A-Fa-f]{2}[:-]/.test(
                                                        name,
                                                    );
                                                },
                                            );

                                            if (namedDevices.length === 0) {
                                                return (
                                                    <label
                                                        label="No named devices"
                                                        xalign={0.5}
                                                        className="no-devices"
                                                    />
                                                );
                                            }

                                            // Sort devices: connected first, then paired
                                            const sortedDevices = [
                                                ...namedDevices,
                                            ].sort((a: any, b: any): any => {
                                                if (
                                                    a?.connected &&
                                                    !b?.connected
                                                )
                                                    return -1;
                                                if (
                                                    !a?.connected &&
                                                    b?.connected
                                                )
                                                    return 1;
                                                if (a?.paired && !b?.paired)
                                                    return -1;
                                                if (!a?.paired && b?.paired)
                                                    return 1;
                                            });

                                            // Group into sections: Paired (including connected) and Others
                                            const pairedDevices: any[] = [];
                                            const otherDevices: any[] = [];

                                            for (const d of sortedDevices) {
                                                if (d?.paired === true) {
                                                    pairedDevices.push(d);
                                                } else {
                                                    otherDevices.push(d);
                                                }
                                            }

                                            // Track connection states to trigger reactive updates
                                            // Read the tracker to make this reactive to state changes
                                            void devicesStateTracker.get();

                                            return (
                                                <>
                                                    {pairedDevices.length >
                                                        0 && (
                                                        <box
                                                            vertical
                                                            spacing={10}
                                                            className="devices-section"
                                                        >
                                                            <label
                                                                label="Paired devices"
                                                                xalign={0}
                                                                className="devices-section-title"
                                                            />
                                                            {pairedDevices.map(
                                                                (device) => (
                                                                    <DeviceItem
                                                                        device={
                                                                            device
                                                                        }
                                                                    />
                                                                ),
                                                            )}
                                                        </box>
                                                    )}

                                                    {otherDevices.length >
                                                        0 && (
                                                        <box
                                                            vertical
                                                            spacing={10}
                                                            className="devices-section"
                                                        >
                                                            <label
                                                                label="Other devices"
                                                                xalign={0}
                                                                className="devices-section-title"
                                                            />
                                                            {otherDevices.map(
                                                                (device) => (
                                                                    <DeviceItem
                                                                        device={
                                                                            device
                                                                        }
                                                                    />
                                                                ),
                                                            )}
                                                        </box>
                                                    )}
                                                </>
                                            );
                                        },
                                    )}
                                </box>
                            </scrollable>
                        </box>
                    );
                })
            )}
        </box>
    );
};

export default BluetoothList;
